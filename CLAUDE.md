# bubo — Claude Code context

## What this repo is

Benchmark runner for [compbiobench](https://github.com/compbiobench/compbiobench) on the Euler HPC cluster. Runs computational biology tasks through the Codex CLI inside a Singularity container.

## Key paths

| What | Where |
|---|---|
| This repo | `~/src/bubo/` |
| Benchmark data (TSV + data files) | `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/` |
| Singularity image (4-6 GB, already built) | `/cluster/project/beltrao/jbuhmann/agentic_ai/images/compbio-codex.sif` |
| Benchmark runner (compbiobench-runner) | `~/src/compbiobench-runner/` |
| Results output | `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/results/` |
| Codex auth tokens | `~/src/bubo/codex/home-codex/` (gitignored) |

## Status

- Image is built and working
- Codex is authenticated (ChatGPT account, model `gpt-5.4`)
- First task `bam-infer-read-length-q1` ran successfully, answer `2x101`

## How to run a task

```bash
# Interactive (on a compute node)
srun --cpus-per-task=2 --mem-per-cpu=8G --time=2:00:00 --pty bash
module load eth_proxy
~/src/bubo/codex/bin/run-task bam-infer-read-length-q1

# SLURM batch
sbatch ~/src/bubo/codex/slurm/run-single-task.sh bam-infer-read-length-q1
```

## Important design decisions

- **Model**: only `gpt-5.4` works via `codex exec` with a ChatGPT account (other models in the interactive picker fail via the API)
- **Conda isolation**: per-question conda env clones go to `$TMPDIR/conda_envs/` (job-specific scratch), not RAM — avoids OOM failures and is safe for parallel SLURM jobs
- **No `--writable-tmpfs`**: removed because it backed conda clones in RAM (~2-4 GB each), causing `No space left on device`
- **`cd /app` before benchmark**: the model test in `run_benchmark.py` calls `codex exec` without `--skip-git-repo-check`, so it must run from a git repo — `/app` is the compbiobench-runner bind mount
- **Euler quirks**: use `--mem-per-cpu` not `--mem`; load `module load eth_proxy` for outbound network

## Next steps

- Run more benchmark tasks (100 questions in the TSV)
- Submit parallel SLURM jobs (one question per job)
- Review results in `/cluster/project/beltrao/jbuhmann/agentic_ai/compbiobench/results/`
