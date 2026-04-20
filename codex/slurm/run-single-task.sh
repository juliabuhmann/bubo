#!/usr/bin/env bash
#SBATCH --job-name=compbio-bench
#SBATCH --time=2:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=2
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err

# Usage: sbatch slurm/run-single-task.sh <question_id> [model] [effort] [timeout_min]
# Example: sbatch slurm/run-single-task.sh bam-infer-read-length-q1

QUESTION_ID=${1:?Usage: sbatch slurm/run-single-task.sh <question_id>}
MODEL=${2:-o4-mini}
EFFORT=${3:-medium}
TIMEOUT_MIN=${4:-30}

SCRIPT_DIR=$(dirname "$(realpath "$0")")
REPO_DIR=$(dirname "$SCRIPT_DIR")

mkdir -p "$REPO_DIR/logs"

echo "SLURM job $SLURM_JOB_ID: $QUESTION_ID on $(hostname)"
"$REPO_DIR/bin/run-task" "$QUESTION_ID" "$MODEL" "$EFFORT" "$TIMEOUT_MIN"
