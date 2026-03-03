#!/usr/bin/env python3
"""
entropy_report.py — Entropy + controllability analysis for timeseries.csv

- First row: signal names (e.g., time,dut.CLOCK,...).
- Non-logic columns are skipped (anything whose values are NOT subset of {0,1,X,Z}).
- X/Z/x/z are treated as logic 0.

For each single-bit signal (width=1):
    Count(0), Count(1), p(0), p(1), entropy H.

For each multi-bit bus (width=W):
    Per-bit entropy H_j
    H_avg = average_j H_j
    H_min = min_j H_j
    low_bits = # { j | H_j < low_thresh }
    C(B) = 0.6 * H_avg + 0.4 * (1 - low_bits / W)

Also prints:
    scan recommendations for signals : s1, s2, ...

Usage:
    python3 entropy_report.py timeseries4.csv
    (optional) python3 entropy_report.py timeseries4.csv --low-thresh 0.14
"""

import csv
import math
import argparse
from typing import List, Dict, Any, Tuple


def binary_entropy(p1: float) -> float:
    """Entropy H(X) for Bernoulli(p1)."""
    p0 = 1.0 - p1
    h = 0.0
    if p1 > 0.0:
        h -= p1 * math.log2(p1)
    if p0 > 0.0:
        h -= p0 * math.log2(p0)
    return h


def detect_logic_columns(rows: List[Dict[str, str]], headers: List[str]) -> List[str]:
    """
    Return columns whose values are only from {0,1,X,Z} (ignores empty).
    'time' is skipped explicitly.
    """
    logic_cols = []
    allowed = set("01XZxz")
    for col in headers:
        if col == "time":
            continue
        chars = set()
        for r in rows:
            v = r.get(col)
            if v is None:
                continue
            v = v.strip()
            if not v:
                continue
            chars.update(v)
        if chars and chars.issubset(allowed):
            logic_cols.append(col)
    return logic_cols


def classify_signals(rows: List[Dict[str, str]], cols: List[str]) -> Tuple[List[str], Dict[str, int]]:
    """
    Decide which logic columns are single-bit vs multi-bit.
    Returns:
        single: list of signal names
        multi:  dict { signal_name -> width }
    """
    single = []
    multi = {}
    for col in cols:
        maxlen = 0
        for r in rows:
            v = (r.get(col) or "").strip()
            if not v:
                continue
            maxlen = max(maxlen, len(v))
        if maxlen <= 1:
            single.append(col)
        else:
            multi[col] = maxlen
    return single, multi


def analyze_single_bit(
    rows: List[Dict[str, str]],
    col: str,
    low_thresh: float,
) -> Dict[str, Any]:
    """Compute counts, probabilities, entropy for a single-bit signal."""
    c0 = c1 = 0
    for r in rows:
        v = (r.get(col) or "").strip()
        if not v:
            continue
        ch = v[-1]  # if somehow longer, take last char
        if ch in "XxZz" or ch == "0":
            c0 += 1
        elif ch == "1":
            c1 += 1
        else:
            # unknown character, ignore
            pass
    total = c0 + c1
    if total == 0:
        p0 = p1 = h = 0.0
    else:
        p0 = c0 / total
        p1 = c1 / total
        h = binary_entropy(p1)

    low_bits = 1 if h < low_thresh else 0
    width = 1
    controllability = 0.6 * h + 0.4 * (1 - low_bits / width)

    return {
        "signal": col,
        "count0": c0,
        "count1": c1,
        "p0": p0,
        "p1": p1,
        "entropy": h,
        "low_bits": low_bits,
        "controllability": controllability,
    }


def analyze_bus(
    rows: List[Dict[str, str]],
    col: str,
    width: int,
    low_thresh: float,
) -> Dict[str, Any]:
    """
    Analyze a multi-bit bus.
    Assumes bitstring is MSB..LSB (leftmost = MSB).

    X/Z mapped to 0 for each bit.
    """
    c0 = [0] * width
    c1 = [0] * width

    for r in rows:
        v = (r.get(col) or "").strip()
        if not v:
            continue
        # Normalize width: left-pad with 0 if shorter, trim left if longer
        if len(v) < width:
            v = v.rjust(width, "0")
        elif len(v) > width:
            v = v[-width:]
        for i, ch in enumerate(v):
            if ch in "XxZz" or ch == "0":
                c0[i] += 1
            elif ch == "1":
                c1[i] += 1
            else:
                # ignore unknown chars
                pass

    H_bits: List[float] = []
    for i in range(width):
        total = c0[i] + c1[i]
        if total == 0:
            H_bits.append(0.0)
        else:
            p1 = c1[i] / total
            H_bits.append(binary_entropy(p1))

    if H_bits:
        H_avg = sum(H_bits) / width
        H_min = min(H_bits)
        low_bits = sum(1 for h in H_bits if h < low_thresh)
    else:
        H_avg = H_min = 0.0
        low_bits = 0

    W = width
    controllability = 0.6 * H_avg + 0.4 * (1 - (low_bits / W if W > 0 else 0.0))

    return {
        "signal": col,
        "width": width,
        "H_avg": H_avg,
        "H_min": H_min,
        "low_bits": low_bits,
        "controllability": controllability,
        "H_bits": H_bits,
    }


def format_table(headers: List[str], rows: List[List[Any]]) -> str:
    """Pretty ASCII table."""
    if not rows:
        return "(no rows)"

    cols = len(headers)
    widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(str(val)))

    def fmt_row(row_vals: List[Any]) -> str:
        return "| " + " | ".join(str(val).ljust(widths[i]) for i, val in enumerate(row_vals)) + " |"

    sep = "+-" + "-+-".join("-" * w for w in widths) + "-+"
    out_lines = [sep, fmt_row(headers), sep]
    for r in rows:
        out_lines.append(fmt_row(r))
    out_lines.append(sep)
    return "\n".join(out_lines)


def wrap_list_for_print(names: List[str], width: int = 80) -> str:
    """Wrap a comma-separated list of names across lines."""
    lines: List[str] = []
    line = ""
    for name in names:
        chunk = (", " if line else "") + name
        if len(line) + len(chunk) > width:
            lines.append(line)
            line = name
        else:
            line += chunk
    if line:
        lines.append(line)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Entropy + controllability analysis for timeseries CSV.")
    parser.add_argument("csv_file", help="Path to timeseries.csv")
    parser.add_argument(
        "--low-thresh",
        type=float,
        default=0.14,
        help="Low-entropy threshold (default: 0.14)",
    )
    args = parser.parse_args()

    # Load CSV
    with open(args.csv_file, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        print("No data rows found in CSV.")
        return

    headers = list(rows[0].keys())

    # Detect logic columns
    logic_cols = detect_logic_columns(rows, headers)
    if not logic_cols:
        print("No logic signals (0/1/X/Z) found.")
        return

    single_signals, bus_signals = classify_signals(rows, logic_cols)

    # --- Single-bit analysis ---
    single_stats = [analyze_single_bit(rows, col, args.low_thresh) for col in single_signals]
    single_stats.sort(key=lambda s: s["signal"])

    # --- Multi-bit analysis ---
    bus_stats = [analyze_bus(rows, col, width, args.low_thresh) for col, width in bus_signals.items()]
    bus_stats.sort(key=lambda b: b["signal"])

    # Print single-bit table
    print("SINGLE-BIT SIGNALS")
    single_rows = []
    for s in single_stats:
        single_rows.append(
            [
                s["signal"],
                s["count0"],
                s["count1"],
                f"{s['p0']:.3f}",
                f"{s['p1']:.3f}",
                f"{s['entropy']:.3f}",
            ]
        )
    print(
        format_table(
            ["Signal", "Count(0)", "Count(1)", "p(0)", "p(1)", "Entropy"],
            single_rows,
        )
    )
    print()

    # Print multi-bit table
    print("MULTI-BIT BUSES")
    bus_rows = []
    for b in bus_stats:
        bus_rows.append(
            [
                b["signal"],
                b["width"],  # Count = bus width (bits)
                f"{b['H_avg']:.3f}",
                f"{b['H_min']:.3f}",
                b["low_bits"],
                f"{b['controllability']:.3f}",
            ]
        )
    print(
        format_table(
            ["Signal", "Bit Count", "Average Entropy", "Min. Entropy", "#low-entropy bits", "C(B)"],
            bus_rows,
        )
    )
    print()

    # --- Scan recommendations (H < low_thresh) ---
    scan_recs: List[Tuple[str, float]] = []

    # Single-bit
    for s in single_stats:
        if s["entropy"] < args.low_thresh:
            scan_recs.append((s["signal"], s["entropy"]))

    # Multi-bit bits: represent as signal[bit_index]
    for b in bus_stats:
        W = b["width"]
        for idx, h in enumerate(b["H_bits"]):
            if h < args.low_thresh:
                # Assume leftmost char is MSB => bit index = W-1-idx
                bit_index = W - 1 - idx
                scan_recs.append((f"{b['signal']}[{bit_index}]", h))

    if scan_recs:
        scan_recs.sort(key=lambda x: x[1])  # sort by entropy ascending
        names_only = [name for name, _ in scan_recs]
        print(f"scan recommendations for signals (H < {args.low_thresh}):")
        print(wrap_list_for_print(names_only, width=100))
    else:
        print(f"No signals/bits with entropy < {args.low_thresh} (no scan recommendations).")


if __name__ == "__main__":
    main()

