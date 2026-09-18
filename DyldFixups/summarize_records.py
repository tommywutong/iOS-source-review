#!/usr/bin/env python3
"""Summarize immutable DYLDLAB records without changing them."""

from __future__ import annotations

import argparse
import re
import statistics
from collections import defaultdict
from pathlib import Path

FIELD = re.compile(r"(\w+)=([^\s]+)")


def parse(lines: list[str], prefix: str) -> dict[str, list[dict[str, str]]]:
    samples: dict[str, list[dict[str, str]]] = defaultdict(list)
    for line in lines:
        if not line.startswith(prefix):
            continue
        values = dict(FIELD.findall(line))
        if variant := values.get("variant"):
            samples[variant].append(values)
    return samples


def mean(values: list[int | float]) -> str:
    return f"{statistics.mean(values):.3f}" if values else "-"


def constructor_to_main_ms(value: dict[str, str]) -> float | None:
    start = value.get("constructor_ns")
    end = value.get("main_entry_ns")
    if not start or not end:
        return None
    return (int(end) - int(start)) / 1_000_000


def record_paths(record: Path) -> list[Path]:
    """Keep each variant's run=1 before its run=2–5 companion file."""
    preferred = [
        "run-output.txt",
        "first-launch.txt",
        "rebasesparse-rest.txt",
        "bindrepeated-rest.txt",
        "bindunique-rest.txt",
        "initheavy-rest.txt",
    ]
    return [record / name for name in preferred if (record / name).is_file()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("record", type=Path)
    args = parser.parse_args()

    lines: list[str] = []
    for path in record_paths(args.record):
        lines.extend(path.read_text(errors="replace").splitlines())

    results = parse(lines, "DYLDLAB_RESULT")
    timelines = parse(lines, "DYLDLAB_TIMELINE")
    print("variant,samples,first_faults,first_pageins,steady_faults_mean,steady_pageins_mean,constructor_to_main_ms_mean")
    for variant in sorted(set(results) | set(timelines)):
        samples = results[variant]
        faults = [int(sample["faults"]) for sample in samples if "faults" in sample]
        pageins = [int(sample["pageins"]) for sample in samples if "pageins" in sample]
        timings = [
            value
            for value in (constructor_to_main_ms(sample) for sample in timelines[variant])
            if value is not None
        ]
        print(
            f"{variant},{len(samples)},"
            f"{faults[0] if faults else '-'},"
            f"{pageins[0] if pageins else '-'},"
            f"{mean(faults[1:])},{mean(pageins[1:])},{mean(timings)}"
        )


if __name__ == "__main__":
    main()
