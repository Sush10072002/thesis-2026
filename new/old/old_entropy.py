import csv
import math

def entropy(p1):
    if p1 == 0 or p1 == 1:
        return 0.0
    p0 = 1 - p1
    return -(p0 * math.log2(p0) + p1 * math.log2(p1))


def normalize_bit(val):
    """
    Clean up cell values:
    - Handle None
    - Strip whitespace
    - Treat X/Z/multi-bit as non-binary → skip
    """
    if val is None:
        return None

    v = val.strip()

    if v in ("0", "1"):
        return v

    # If multi-bit but consists ONLY of 0/1:
    if all(ch in ("0", "1") for ch in v):
        # Only count it if it's a single bit
        if len(v) == 1:
            return v
        else:
            return None

    # X, Z, xxxx, zzzz, ???, empty → skip
    return None


def process_timeseries(csv_path):
    with open(csv_path, "r") as f:
        reader = csv.DictReader(f)
        header = reader.fieldnames

        if header is None:
            print("ERROR: CSV file is empty or unreadable.")
            return

        signal_list = [h for h in header if h.lower() != "time"]

        counts_0 = {sig: 0 for sig in signal_list}
        counts_1 = {sig: 0 for sig in signal_list}

        for row in reader:
            for sig in signal_list:
                val = normalize_bit(row.get(sig))

                if val == "0":
                    counts_0[sig] += 1
                elif val == "1":
                    counts_1[sig] += 1
                # else skip (X, Z, empty, multi-bit)

        print("\nENTROPY ANALYSIS\n" + "-"*72)
        print(f"{'Signal':20s} | {'Count(0)':9s} | {'Count(1)':9s} | {'p(0)':6s} | {'p(1)':6s} | Entropy")
        print("-"*72)

        entropy_values = {}

        for sig in signal_list:
            c0 = counts_0[sig]
            c1 = counts_1[sig]
            total = c0 + c1 if (c0 + c1) > 0 else 1
            p0 = c0 / total
            p1 = c1 / total
            H = entropy(p1)
            entropy_values[sig] = H

            print(f"{sig:20s} | {c0:9d} | {c1:9d} | {p0:6.2f} | {p1:6.2f} | {H:7.3f}")

        # SPARTAN threshold
        low_entropy = [s for s, h in entropy_values.items() if h < 0.14]

        print("\nSCAN RECOMMENDATIONS (Entropy < 0.14):")
        if low_entropy:
            print(", ".join(low_entropy))
        else:
            print("None.")


if __name__ == "__main__":
    process_timeseries("timeseries.csv")


