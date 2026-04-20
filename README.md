# bubo

## codex

Runs [compbiobench](https://github.com/compbiobench/compbiobench) benchmark tasks via the Codex CLI inside a Singularity container on Euler. Follows the [euler-vibe](https://github.com/jurgjn/euler-vibe) sandboxing pattern.

### Directory structure

```
codex/
├── images/
│   └── compbio-codex.def     # Singularity image definition (recipe)
├── bin/
│   ├── run-task              # Entry point — launches container and runs one task
│   ├── inner.sh              # Runs inside container: preps CSV, calls run_benchmark.py
│   └── prep_task.py          # Filters benchmark TSV to one question, resolves file paths
├── slurm/
│   └── run-single-task.sh    # SLURM batch wrapper around run-task
├── home-codex/               # Persistent Codex auth tokens (survives across runs)
└── environment.yml           # conda env spec for the compbio-benchmark base env
```

### One-time setup

**1. Extract benchmark data** (already done):
```bash
mkdir -p /cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/data
tar -xf /cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/compbiobench_v1_data.tar \
    -C /cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/data/
```

**2. Build the Singularity image** (~30-45 min, submit as a job to avoid running on login node):
```bash
mkdir -p /cluster/project/beltrao/jbuhmann/agentic_ai/images
sbatch --job-name=build-sif --time=2:00:00 --mem=8G --wrap \
    "singularity build \
        /cluster/project/beltrao/jbuhmann/agentic_ai/images/compbio-codex.sif \
        $HOME/src/bubo/codex/images/compbio-codex.def"
```

The `.sif` image (~4-6 GB) is stored on project storage, not home, because home has limited quota.
The `.def` file is the recipe (text); the `.sif` is the built binary — same relationship as Dockerfile → Docker image.

**3. Authenticate Codex** (one-time interactive step, tokens saved to `home-codex/`):
```bash
module load eth_proxy
singularity exec --cleanenv --containall \
    --home ~/src/bubo/codex/home-codex:/home \
    /cluster/project/beltrao/jbuhmann/agentic_ai/images/compbio-codex.sif \
    codex auth
```

### Running a task

**Interactively** (on a compute node):
```bash
srun --cpus-per-task=2 --mem-per-cpu=8G --time=2:00:00 --pty bash
module load eth_proxy
~/src/bubo/codex/bin/run-task bam-infer-read-length-q1
```

**As a SLURM batch job:**
```bash
sbatch ~/src/bubo/codex/slurm/run-single-task.sh bam-infer-read-length-q1
```

Results appear in `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/results/`.

### What happens when you run a task

`run-task` launches the Singularity container and calls `inner.sh` inside it:

1. `prep_task.py` reads the benchmark TSV, extracts the one question, resolves the relative `file_paths` to absolute paths under `/compbio/data/`, writes `/tmp/single_task.csv`
2. `run_benchmark.py run` clones the `compbio-benchmark` conda env for the question, copies the data file into a workspace, builds a prompt, runs `codex exec`, saves trace + result to `/results/`

Output per question:
```
results/codex_gpt-5.4_<timestamp>/questions/<question_id>/
├── prompt.md        # what was sent to Codex
├── trace.md         # full reasoning chain with tool calls
├── result.json      # answer, tokens, cost, timing
├── raw_stdout.jsonl # raw Codex JSONL output
└── workspace/       # data files the agent worked with
```

### Container filesystem access

The container is launched with `--containall` (no host paths visible by default) and `--cleanenv` (no host env vars). Access is limited to the explicitly bound paths below.

| Container path | Host path | Access |
|---|---|---|
| `/compbio` | `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/` | read-only |
| `/app` | `~/src/compbiobench-runner/` | read-only |
| `/repo` | `~/src/bubo/codex/` | read-only |
| `/results` | `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/results/` | read-write |
| `/home` | `~/src/bubo/codex/home-codex/` | read-write (Codex auth tokens) |
| `/tmp` | per-job tmpdir (`$TMPDIR/compbio.<pid>`) | read-write |

Only `/results` and `/home` persist after the job ends. Everything else — including any packages the agent installs — is gone when the container exits.

**Network:** unrestricted outbound access (required for `internet_required=True` benchmark tasks).

**Codex's own internal sandbox** (`bubblewrap`) is explicitly disabled via `--dangerously-bypass-approvals-and-sandbox` — Singularity is the sole filesystem boundary.

### Conda env isolation and parallel safety

`run_benchmark.py` clones the `compbio-benchmark` conda env once per question (for reproducibility). The clones are directed to `/tmp/conda_envs/` via `CONDA_ENVS_DIRS`, which is bound to Euler's per-job `$TMPDIR` — so:

- Clones go to scratch disk, not RAM (avoids out-of-memory failures)
- Each SLURM job has its own `$TMPDIR` → clones are fully isolated across parallel jobs on different nodes
- Clones are automatically cleaned up when the job ends

This replaces an earlier `--writable-tmpfs` approach (RAM-backed overlay), which caused `No space left on device` errors because the conda clone (~2-4 GB) exceeded available RAM.

### Model availability

Codex CLI behaviour depends on account type. With a **ChatGPT account**, only certain models are available via `codex exec`. Use `codex` interactively to see the current list. As of April 2026, `gpt-5.4` is the default and works reliably. The model name must also be present in `run_benchmark.py`'s `CodexProvider.model_pricing` table — currently `gpt-5.4`, `gpt-5.3-codex`, and `gpt-5.1-codex-mini` are configured there.

### Cluster-specific notes

- Use `--mem-per-cpu` instead of `--mem` for `srun`/`sbatch` on Euler
- Load `module load eth_proxy` before any outbound network access (including `codex auth` and benchmark tasks with `internet_required=True`)
- The proxy must be loaded on the host before entering the container — `--cleanenv` strips env vars, but the proxy works at the network level so it is still active inside the container
