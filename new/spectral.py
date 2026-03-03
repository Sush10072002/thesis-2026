#!/usr/bin/env python3
"""
spectral.py - SPARTAN-style spectral analysis on RTL timeseries CSV.

Usage:
    python3 spectral.py timeseries.csv > spectral_report.txt

What it does:
    - Reads a CSV where the first row has signal/bus names.
    - Assumes (by default) the first column is "time" and ignores it.
    - Handles single-bit signals and multi-bit buses with 0/1/X/Z values.
      * X/Z are treated as 0.
    - Maps 0 -> -1, 1 -> +1 for spectral analysis.
    - Uses a length-R (default R=16) Rademacher–Walsh/Hadamard basis.
    - Slides non-overlapping windows of length R over time,
      computes spectral coefficients, then averages |SC_j|.
    - Computes a sequency-weighted average:
          SC_avg = (sum_j (w_j * |SC_j|)) / R,  w_j = (j+1)
      Lower SC_avg => harder to control (scan candidate).
    - For multi-bit buses: computes spectra bit-by-bit and averages
      SC_avg across bits to get a bus-level SC_avg.
    - Optionally computes an "observability proxy" by correlating each
      signal's spectrum with any primary-output (PO) spectrum.

Notes:
    - This is a *signal-level* spectral measure. It does NOT know the
      structural fanout cone. For observability, it just correlates each
      signal with all POs you tell it about and keeps the best match.
    - Default PO heuristic: any signal with name starting with "tb_top.".
      You can override with --po-prefix and/or --po-name.
"""

import argparse
import math
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd


# ---------------------------------------------------------------------
# Rademacher–Walsh / Hadamard basis
# ---------------------------------------------------------------------

def hadamard(R: int) -> np.ndarray:
    """
    Generate an R x R Hadamard matrix (Sylvester construction).
    R must be a power of two.
    Entries are ±1 (integer).
    """
    if R <= 0 or (R & (R - 1)) != 0:
        raise ValueError(f"R must be a positive power of 2, got {R}")
    H = np.array([[1]], dtype=int)
    while H.shape[0] < R:
        H = np.block([[H, H],
                      [H, -H]])
    if H.shape[0] != R:
        raise RuntimeError("Hadamard construction failed")
    return H


# ---------------------------------------------------------------------
# Parsing CSV and building ±1 traces
# ---------------------------------------------------------------------
def parse_sample_bits(val: str):
    """
    Parse CSV cell into a list of bits [0/1].
    Handles:
        - binary strings: "0101", "XXXXXXXX", etc.
        - decimal numbers: "0.0", "3.0", "12", etc.
        - X/Z treated as 0
    """
    s = str(val).strip()
    if s == "" or s.lower() == "nan":
        return None

    # Case 1: decimal or integer numeric
    if all(ch in "0123456789.-" for ch in s):
        try:
            intval = int(float(s))
            if intval < 0:
                intval = 0
            # Return integer; build_bit_traces will convert to binary of correct width
            return intval
        except ValueError:
            pass  # fall through to bitstring handling

    # Case 2: bitstring like 0101 or XXXX
    bits = []
    for ch in s:
        if ch == '0':
            bits.append(0)
        elif ch == '1':
            bits.append(1)
        elif ch in ('x', 'X', 'z', 'Z'):
            bits.append(0)
        else:
            raise ValueError(f"Unexpected character '{ch}' in value '{s}'")

    return bits

def build_bit_traces(df: pd.DataFrame):
    traces = {}

    cols = list(df.columns)
    if cols and cols[0].lower() == "time":
        cols = cols[1:]

    for col in cols:
        series = df[col].astype(str)

        # First pass: detect max integer value and max bitstring width
        max_int = 0
        max_width = 0
        parsed_vals = []

        for v in series:
            p = parse_sample_bits(v)
            parsed_vals.append(p)

            if p is None:
                continue

            if isinstance(p, int):
                if p > max_int:
                    max_int = p
            else:
                # it's a list of bits
                max_width = max(max_width, len(p))

        # compute width for int values
        if max_int > 0:
            int_width = max_int.bit_length()
        else:
            int_width = 1

        width = max(max_width, int_width)

        # Second pass: generate final bit traces
        bit_lists = [[] for _ in range(width)]

        for p in parsed_vals:
            if p is None:
                bits = [0] * width
            elif isinstance(p, int):
                b = bin(p)[2:].zfill(width)
                bits = [int(x) for x in b]
            else:
                bits = p
                if len(bits) < width:
                    bits = [0] * (width - len(bits)) + bits
                else:
                    bits = bits[-width:]

            for i, b in enumerate(bits):
                bit_lists[i].append(+1 if b == 1 else -1)

        traces[col] = (np.array(bit_lists), width)

    return traces


# ---------------------------------------------------------------------
# Spectral analysis core
# ---------------------------------------------------------------------

def compute_spectrum_for_signal(bit_matrix: np.ndarray,
                                R: int,
                                H: np.ndarray
                                ) -> Tuple[np.ndarray, np.ndarray]:
    """
    Compute spectral magnitudes and SC_avg per bit for a given signal.

    Args:
        bit_matrix: shape (width, T), entries ±1
        R: window length
        H: R x R Hadamard/Rademacher–Walsh matrix

    Returns:
        (avg_abs_sc, sc_avg_bits):
            avg_abs_sc: shape (width, R) = average |SC_j| for each bit and sequency j
            sc_avg_bits: shape (width,) = sequency-weighted SC_avg per bit
    """
    width, T = bit_matrix.shape
    if T < R:
        raise ValueError(f"Not enough samples ({T}) for window R={R}")

    step = R  # non-overlapping windows
    nwin = (T - R) // step + 1
    if nwin <= 0:
        raise ValueError(f"Not enough samples ({T}) for window R={R}")

    avg_abs_sc = np.zeros((width, R), dtype=float)

    # We do: for each window, SC = H @ window (per bit),
    # accumulate |SC| and then average.
    for w in range(nwin):
        start = w * step
        seg = bit_matrix[:, start:start + R]  # (width, R)
        if seg.shape[1] < R:
            break

        seg_T = seg.T  # (R, width)
        sc = H @ seg_T  # (R, width)
        # sc.T: (width, R)
        avg_abs_sc += np.abs(sc.T)

    avg_abs_sc /= float(nwin)

    # Sequency weights w_j ∝ j+1
    w_vec = np.arange(1, R + 1, dtype=float)  # (R,)
    # SC_avg_bits = (Σ_j w_j |SC_j|) / R
    sc_avg_bits = (avg_abs_sc * w_vec).sum(axis=1) / float(R)

    return avg_abs_sc, sc_avg_bits


# ---------------------------------------------------------------------
# Observability proxy: SC correlation with “PO” spectra
# ---------------------------------------------------------------------

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Cosine similarity between two 1D vectors.
    """
    num = float(np.dot(a, b))
    den = float(np.linalg.norm(a) * np.linalg.norm(b))
    if den == 0.0:
        return 0.0
    return num / den


def identify_pos(all_names: List[str],
                 po_prefixes: List[str],
                 po_names: List[str]) -> List[str]:
    """
    Heuristic: any signal explicitly listed in po_names plus
    any signal whose name starts with a prefix in po_prefixes
    is treated as a primary output.
    """
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


# ---------------------------------------------------------------------
# Main driver
# ---------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="SPARTAN-style spectral analysis on timeseries CSV")
    ap.add_argument("csv_file", help="Input timeseries CSV (first row = signal names)")
    ap.add_argument("--window", "-R", type=int, default=16,
                    help="Walsh window length R (power of 2, default=16)")
    ap.add_argument("--po-prefix", action="append", default=["tb_top."],
                    help="Treat any signal starting with this prefix as a primary output (can repeat). "
                         "Default: tb_top.")
    ap.add_argument("--po-name", action="append", default=[],
                    help="Explicit primary output signal name(s) (can repeat).")
    args = ap.parse_args()

    R = args.window
    H = hadamard(R)

    df = pd.read_csv(args.csv_file)
    traces = build_bit_traces(df)

    if not traces:
        raise RuntimeError("No usable signals found in CSV")

    all_signal_names = list(traces.keys())
    pos = identify_pos(all_signal_names, args.po_prefix, args.po_name)

    # Compute spectra and SC_avg for all signals
    per_signal_results = []

    # Pre-compute PO spectra for observability proxy
    po_spectra: Dict[str, np.ndarray] = {}

    for name, (bit_matrix, width) in traces.items():
        T = bit_matrix.shape[1]
        if T < R:
            # Skip too-short signals
            continue

        try:
            avg_abs_sc_bits, sc_avg_bits = compute_spectrum_for_signal(bit_matrix, R, H)
        except ValueError:
            continue

        # Aggregate across bits for multi-bit buses
        bus_sc_avg = float(sc_avg_bits.mean())
        # Bus-level SC vector = mean over bits of |SC_j|
        bus_sc_vec = avg_abs_sc_bits.mean(axis=0)  # (R,)

        # Cache PO spectra if this is a PO
        if name in pos:
            po_spectra[name] = bus_sc_vec

        per_signal_results.append({
            "name": name,
            "width": width,
            "T": T,
            "sc_avg": bus_sc_avg,
            "sc_vec": bus_sc_vec,
        })

    # Observability proxy: max cosine similarity with any PO SC vector
    po_names = list(po_spectra.keys())

    for rec in per_signal_results:
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

    # Sort by SC_avg ascending => hardest-to-control first
    per_signal_results.sort(key=lambda r: r["sc_avg"])

    # -----------------------------------------------------------------
    # Print report
    # -----------------------------------------------------------------
    print(f"SPECTRAL ANALYSIS REPORT (R={R}, non-overlapping windows)")
    print("=" * 72)
    print(f"{'Signal':40s} {'W':>3s} {'T':>7s} {'SC_avg':>10s} {'Best_PO':>20s} {'PO_cos':>8s}")
    print("-" * 72)

    for rec in per_signal_results:
        name = rec["name"]
        width = rec["width"]
        T = rec["T"]
        sc_avg = rec["sc_avg"]
        po_match = rec["po_match"] if rec["po_match"] is not None else "-"
        po_cos = rec["po_cosine"]
        po_cos_str = f"{po_cos:6.3f}" if po_cos is not None else "   n/a"

        print(f"{name:40.40s} {width:3d} {T:7d} {sc_avg:10.4f} {po_match:20.20s} {po_cos_str:>8s}")

    print("\nNotes:")
    print("  - Lower SC_avg => harder to control (strong scan candidates).")
    print("  - PO_cos is a crude observability proxy (max cosine similarity")
    print("    between a signal's spectrum and any PO spectrum).")
    print("  - You’ll still rank/registers by SCC etc. outside this script.")


if __name__ == "__main__":
    main()

