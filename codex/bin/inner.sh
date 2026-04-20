#!/usr/bin/env bash
# Runs inside the Singularity container.
# Prepares a single-question CSV then calls run_benchmark.py.
set -euo pipefail

QUESTION_ID=${1:?inner.sh requires <question_id> as first argument}
MODEL=${2:?inner.sh requires <model> as second argument}
EFFORT=${3:-medium}
TIMEOUT_MIN=${4:-30}

TASK_CSV=/tmp/single_task.csv

export PATH=/opt/conda/bin:$PATH

# Direct conda env clones and package cache to /tmp (bound to job-specific $TMPDIR on Euler).
# This keeps each job isolated and avoids RAM pressure from --writable-tmpfs.
mkdir -p /tmp/conda_envs /tmp/conda_pkgs
export CONDA_ENVS_DIRS=/tmp/conda_envs:/opt/conda/envs
export CONDA_PKGS_DIRS=/tmp/conda_pkgs

echo "=== prep: $QUESTION_ID ==="
python3 /repo/bin/prep_task.py \
    --question-id "$QUESTION_ID" \
    --tsv /compbio/compbiobench.v1.tsv \
    --data-dir /compbio/data \
    --output "$TASK_CSV"

echo "=== run: llm=codex model=$MODEL effort=$EFFORT timeout=${TIMEOUT_MIN}m ==="
cd /app
python /app/run_benchmark.py run \
    --llm codex \
    -m "$MODEL" \
    --model-reasoning-effort "$EFFORT" \
    -i "$TASK_CSV" \
    -n 1 \
    -t "$TIMEOUT_MIN" \
    --results-dir /results
