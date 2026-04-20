#!/usr/bin/env python3
"""Prepare a single-question CSV for run_benchmark.py.

Reads the main compbiobench TSV, filters to one question_id,
and resolves file_paths to absolute paths under --data-dir.
"""
import argparse
import csv
import os
import sys


def main():
    parser = argparse.ArgumentParser(description="Prepare single-question CSV for run_benchmark.py")
    parser.add_argument("--question-id", required=True, help="Benchmark question ID to run")
    parser.add_argument("--tsv", required=True, help="Path to compbiobench.v1.tsv")
    parser.add_argument("--data-dir", required=True, help="Directory containing benchmark data files")
    parser.add_argument("--output", required=True, help="Output CSV path")
    args = parser.parse_args()

    with open(args.tsv) as f:
        reader = csv.DictReader(f, delimiter="\t")
        fieldnames = reader.fieldnames
        rows = list(reader)

    row = next((r for r in rows if r["question_id"] == args.question_id), None)
    if row is None:
        print(f"ERROR: question_id {args.question_id!r} not found in {args.tsv}", file=sys.stderr)
        available = [r["question_id"] for r in rows]
        suffix = "..." if len(available) > 10 else ""
        print(f"Available IDs: {available[:10]}{suffix}", file=sys.stderr)
        sys.exit(1)

    # file_paths column uses comma-separated relative paths (compbiobench convention)
    raw = row.get("file_paths", "").strip()
    if raw:
        abs_paths = [
            os.path.join(args.data_dir, p.strip())
            for p in raw.split(",")
            if p.strip()
        ]
        missing = [p for p in abs_paths if not os.path.exists(p)]
        if missing:
            print(f"ERROR: data files not found: {missing}", file=sys.stderr)
            print("Did you extract the data tar? See README.", file=sys.stderr)
            sys.exit(1)
        row["file_paths"] = ",".join(abs_paths)

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerow(row)

    print(f"Prepared: {args.output}")
    print(f"  question_id: {row['question_id']}")
    print(f"  domain:      {row.get('domain', 'N/A')}")
    print(f"  file_paths:  {row.get('file_paths', '(none)')}")


if __name__ == "__main__":
    main()
