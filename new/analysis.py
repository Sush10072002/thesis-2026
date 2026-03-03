#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
combined_analysis.py - Combined Entropy + Spectral analysis for timeseries.csv

Performs both:
  1. Entropy analysis (H, controllability C(B))
  2. Spectral analysis (SC_avg, PO correlation)

Outputs:
  - Unified console report
  - CSV file with: signal, entropy/avg_entropy, SC_avg, PO_cos

Usage:
    python3 combined_analysis.py timeseries.csv
    python3 combined_analysis.py timeseries.csv --output results.csv --window 16 --low-thresh 0.14
"""

import csv
import math
import argparse
from typing import Dict, List, Any, Tuple
import numpy as np


# =====================================================================
# ENTROPY ANALYSIS FUNCTIONS (from entropy.py)
# =====================================================================

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
    """Return columns whose values are only from {0,1,X,Z} (ignores empty). 'time' is skipped."""
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
    """Decide which logic columns are single-bit vs multi-bit."""
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


def analyze_single_bit(rows: List[Dict[str, str]], col: str, low_thresh: float) -> Dict[str, Any]:
    """Compute counts, probabilities, entropy for a single-bit signal."""
    c0 = c1 = 0
    for r in rows:
        v = (r.get(col) or "").strip()
        if not v:
            continue
        ch = v[-1]
        if ch in "XxZz" or ch == "0":
            c0 += 1
        elif ch == "1":
            c1 += 1
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
        "width": 1,
        "count0": c0,
        "count1": c1,
        "p0": p0,
        "p1": p1,
        "entropy": h,
        "low_bits": low_bits,
        "controllability": controllability,
    }


def analyze_bus(rows: List[Dict[str, str]], col: str, width: int, low_thresh: float) -> Dict[str, Any]:
    """Analyze a multi-bit bus."""
    c0 = [0] * width
    c1 = [0] * width

    for r in rows:
        v = (r.get(col) or "").strip()
        if not v:
            continue
        if len(v) < width:
            v = v.rjust(width, "0")
        elif len(v) > width:
            v = v[-width:]
        for i, ch in enumerate(v):
            if ch in "XxZz" or ch == "0":
                c0[i] += 1
            elif ch == "1":
                c1[i] += 1

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


# =====================================================================
# SPECTRAL ANALYSIS FUNCTIONS (from spectral.py)
# =====================================================================

def hadamard(R: int) -> np.ndarray:
    """Generate an R x R Hadamard matrix. R must be a power of two."""
    if R <= 0 or (R & (R - 1)) != 0:
        raise ValueError(f"R must be a positive power of 2, got {R}")
    H = np.array([[1]], dtype=int)
    while H.shape[0] < R:
        H = np.block([[H, H], [H, -H]])
    return H


def build_bit_traces_from_rows(rows: List[Dict[str, str]], headers: List[str]) -> Dict[str, Tuple[np.ndarray, int]]:
    """Build +-1 bit traces from CSV rows for spectral analysis."""
    traces = {}
    
    # Skip 'time' column
    cols = [h for h in headers if h.lower() != "time"]
    
    for col in cols:
        # Collect all values
        values = []
        max_width = 0
        
        for r in rows:
            v = (r.get(col) or "").strip()
            if not v:
                values.append(None)
                continue
                
            # Check if it's logic values
            if all(ch in "01XZxz" for ch in v):
                max_width = max(max_width, len(v))
                values.append(v)
            else:
                values.append(None)
        
        if max_width == 0:
            continue
            
        # Build bit matrix
        bit_lists = [[] for _ in range(max_width)]
        
        for v in values:
            if v is None:
                bits = [0] * max_width
            else:
                # Normalize width
                if len(v) < max_width:
                    v = v.rjust(max_width, "0")
                elif len(v) > max_width:
                    v = v[-max_width:]
                    
                bits = []
                for ch in v:
                    if ch in "XxZz" or ch == "0":
                        bits.append(0)
                    elif ch == "1":
                        bits.append(1)
                    else:
                        bits.append(0)
            
            for i, b in enumerate(bits):
                bit_lists[i].append(+1 if b == 1 else -1)
        
        bit_matrix = np.array(bit_lists, dtype=int)
        traces[col] = (bit_matrix, max_width)
    
    return traces


def compute_spectrum_for_signal(bit_matrix: np.ndarray, R: int, H: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """Compute spectral magnitudes and SC_avg per bit."""
    width, T = bit_matrix.shape
    if T < R:
        raise ValueError(f"Not enough samples ({T}) for window R={R}")

    step = R
    nwin = (T - R) // step + 1
    if nwin <= 0:
        raise ValueError(f"Not enough samples ({T}) for window R={R}")

    avg_abs_sc = np.zeros((width, R), dtype=float)

    for w in range(nwin):
        start = w * step
        seg = bit_matrix[:, start:start + R]
        if seg.shape[1] < R:
            break

        seg_T = seg.T
        sc = H @ seg_T
        avg_abs_sc += np.abs(sc.T)

    avg_abs_sc /= float(nwin)

    # Sequency weights
    w_vec = np.arange(1, R + 1, dtype=float)
    sc_avg_bits = (avg_abs_sc * w_vec).sum(axis=1) / float(R)

    return avg_abs_sc, sc_avg_bits


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two 1D vectors."""
    num = float(np.dot(a, b))
    den = float(np.linalg.norm(a) * np.linalg.norm(b))
    if den == 0.0:
        return 0.0
    return num / den


def identify_pos(all_names: List[str], po_prefixes: List[str], po_names: List[str]) -> List[str]:
    """Identify primary outputs based on prefixes and explicit names."""
    pos: List[str] = []
    name_set = set(all_names)

    for p in po_prefixes:
        for n in all_names:
            if n.startswith(p):
                pos.append(n)

    for n in po_names:
        if n in name_set and n not in pos:
            pos.append(n)

    return pos


# =====================================================================
# TABLE FORMATTING
# =====================================================================

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


# =====================================================================
# MAIN
# =====================================================================

def main():
    parser = argparse.ArgumentParser(description="Combined Entropy + Spectral analysis for timeseries CSV.")
    parser.add_argument("csv_file", help="Path to timeseries.csv")
    parser.add_argument("--output", "-o", default="results.csv", help="Output CSV file (default: results.csv)")
    parser.add_argument("--window", "-R", type=int, default=16, help="Walsh window length R (power of 2, default=16)")
    parser.add_argument("--low-thresh", type=float, default=0.14, help="Low-entropy threshold (default: 0.14)")
    parser.add_argument("--po-prefix", action="append", default=None, help="Primary output prefix (default: tb_top.)")
    parser.add_argument("--po-name", action="append", default=[], help="Explicit primary output signal name(s)")
    args = parser.parse_args()

    # Set default PO prefix if not specified
    if args.po_prefix is None:
        args.po_prefix = ["tb_top."]

    R = args.window
    H = hadamard(R)

    # ========== LOAD CSV ==========
    with open(args.csv_file, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        print("No data rows found in CSV.")
        return

    headers = list(rows[0].keys())

    # ========== ENTROPY ANALYSIS ==========
    logic_cols = detect_logic_columns(rows, headers)
    if not logic_cols:
        print("No logic signals (0/1/X/Z) found.")
        return

    single_signals, bus_signals = classify_signals(rows, logic_cols)

    # Analyze single-bit signals
    single_stats = [analyze_single_bit(rows, col, args.low_thresh) for col in single_signals]
    single_stats.sort(key=lambda s: s["signal"])

    # Analyze multi-bit buses
    bus_stats = [analyze_bus(rows, col, width, args.low_thresh) for col, width in bus_signals.items()]
    bus_stats.sort(key=lambda b: b["signal"])

    # ========== SPECTRAL ANALYSIS ==========
    traces = build_bit_traces_from_rows(rows, headers)
    all_signal_names = list(traces.keys())
    pos = identify_pos(all_signal_names, args.po_prefix, args.po_name)

    spectral_results = {}
    po_spectra: Dict[str, np.ndarray] = {}

    for name, (bit_matrix, width) in traces.items():
        T = bit_matrix.shape[1]
        if T < R:
            continue

        try:
            avg_abs_sc_bits, sc_avg_bits = compute_spectrum_for_signal(bit_matrix, R, H)
        except ValueError:
            continue

        bus_sc_avg = float(sc_avg_bits.mean())
        bus_sc_vec = avg_abs_sc_bits.mean(axis=0)

        if name in pos:
            po_spectra[name] = bus_sc_vec

        spectral_results[name] = {
            "sc_avg": bus_sc_avg,
            "sc_vec": bus_sc_vec,
            "width": width,
        }

    # Compute observability (PO correlation)
    po_names = list(po_spectra.keys())
    for name, rec in spectral_results.items():
        if not po_names:
            rec["po_match"] = None
            rec["po_cosine"] = None
            continue
        best_po = None
        best_cos = -1.0
        for po_name in po_names:
            cos = cosine_similarity(rec["sc_vec"], po_spectra[po_name])
            if cos > best_cos:
                best_cos = cos
                best_po = po_name
        rec["po_match"] = best_po
        rec["po_cosine"] = best_cos

    # ========== COMBINE RESULTS ==========
    combined = {}

    # Add single-bit signals
    for s in single_stats:
        name = s["signal"]
        combined[name] = {
            "signal": name,
            "width": 1,
            "entropy": s["entropy"],
            "avg_entropy": s["entropy"],
            "controllability": s["controllability"],
            "count0": s["count0"],
            "count1": s["count1"],
            "p0": s["p0"],
            "p1": s["p1"],
        }

    # Add multi-bit buses
    for b in bus_stats:
        name = b["signal"]
        combined[name] = {
            "signal": name,
            "width": b["width"],
            "entropy": None,
            "avg_entropy": b["H_avg"],
            "controllability": b["controllability"],
            "H_min": b["H_min"],
            "low_bits": b["low_bits"],
        }

    # Add spectral data
    for name, spec in spectral_results.items():
        if name not in combined:
            # Signal not in entropy analysis (shouldn't happen, but handle it)
            combined[name] = {
                "signal": name,
                "width": spec["width"],
                "entropy": None,
                "avg_entropy": None,
                "controllability": None,
            }
        combined[name]["sc_avg"] = spec["sc_avg"]
        combined[name]["po_cosine"] = spec["po_cosine"]
        combined[name]["po_match"] = spec["po_match"]

    # ========== PRINT REPORT ==========
    print("=" * 80)
    print("COMBINED ENTROPY + SPECTRAL ANALYSIS REPORT")
    print("=" * 80)
    print()

    # Single-bit signals table
    print("SINGLE-BIT SIGNALS")
    single_rows = []
    for s in single_stats:
        name = s["signal"]
        sc_avg = combined[name].get("sc_avg", None)
        po_cos = combined[name].get("po_cosine", None)
        
        single_rows.append([
            name,
            s["count0"],
            s["count1"],
            f"{s['p0']:.3f}",
            f"{s['p1']:.3f}",
            f"{s['entropy']:.3f}",
            f"{sc_avg:.4f}" if sc_avg is not None else "n/a",
            f"{po_cos:.3f}" if po_cos is not None else "n/a",
        ])
    
    print(format_table(
        ["Signal", "Count(0)", "Count(1)", "p(0)", "p(1)", "H", "SC_avg", "PO_cos"],
        single_rows,
    ))
    print()

    # Multi-bit buses table
    print("MULTI-BIT BUSES")
    bus_rows = []
    for b in bus_stats:
        name = b["signal"]
        sc_avg = combined[name].get("sc_avg", None)
        po_cos = combined[name].get("po_cosine", None)
        
        bus_rows.append([
            name,
            b["width"],
            f"{b['H_avg']:.3f}",
            f"{b['H_min']:.3f}",
            b["low_bits"],
            f"{b['controllability']:.3f}",
            f"{sc_avg:.4f}" if sc_avg is not None else "n/a",
            f"{po_cos:.3f}" if po_cos is not None else "n/a",
        ])
    
    print(format_table(
        ["Signal", "W", "H_avg", "H_min", "#low", "C(B)", "SC_avg", "PO_cos"],
        bus_rows,
    ))
    print()

    # ========== EXPORT CSV ==========
    output_rows = []
    for name in sorted(combined.keys()):
        rec = combined[name]
        entropy_val = rec["entropy"] if rec["entropy"] is not None else rec["avg_entropy"]
        sc_avg_val = rec.get("sc_avg", None)
        po_cos_val = rec.get("po_cosine", None)
        
        output_rows.append({
            "signal": name,
            "entropy": f"{entropy_val:.6f}" if entropy_val is not None else "",
            "SC_avg": f"{sc_avg_val:.6f}" if sc_avg_val is not None else "",
            "PO_cos": f"{po_cos_val:.6f}" if po_cos_val is not None else "",
        })

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["signal", "entropy", "SC_avg", "PO_cos"])
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"Results exported to: {args.output}")
    print()
    print("CSV columns: signal, entropy (or avg_entropy for multi-bit), SC_avg, PO_cos")


if __name__ == "__main__":
    main()
