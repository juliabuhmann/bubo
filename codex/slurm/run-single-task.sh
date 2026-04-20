#!/usr/bin/env bash
#SBATCH --job-name=compbio-bench
#SBATCH --time=2:00:00
#SBATCH --mem-per-cpu=8G
#SBATCH --cpus-per-task=2
#SBATCH --output=/cluster/home/buhmanju/src/bubo/logs/slurm-%j.out
#SBATCH --error=/cluster/home/buhmanju/src/bubo/logs/slurm-%j.err

# Usage: sbatch slurm/run-single-task.sh <question_id> [model] [effort] [timeout_min]
# Example: sbatch slurm/run-single-task.sh bam-infer-read-length-q1

set -euo pipefail

module load eth_proxy

QUESTION_ID=${1:?Usage: sbatch slurm/run-single-task.sh <question_id>}
MODEL=${2:-gpt-5.4}
EFFORT=${3:-medium}
TIMEOUT_MIN=${4:-30}

REPO_DIR=/cluster/home/buhmanju/src/bubo/codex

mkdir -p /cluster/home/buhmanju/src/bubo/logs

echo "SLURM job $SLURM_JOB_ID: $QUESTION_ID on $(hostname)"
"$REPO_DIR/bin/run-task" "$QUESTION_ID" "$MODEL" "$EFFORT" "$TIMEOUT_MIN"
