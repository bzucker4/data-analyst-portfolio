"""Generate synthetic SKU and cycle count data (SYNTHETIC DATA, not real company data).

Each SKU gets an ABC velocity class. A-class items are counted monthly, B-class quarterly,
C-class twice a year. Count errors are drawn with higher probability for perishable
categories, for evening and night shifts, and during the November/December rush. These
patterns are built into the generator so the analysis has something to find, which means
the findings demonstrate the method, not facts about any real warehouse.

Run:  python generate_data.py
Output: data/skus.csv, data/cycle_counts.csv
"""
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 7
N_SKUS = 1200
YEAR_START = date(2025, 1, 1)

# category -> (share of SKUs, median unit cost, base probability that a count is off)
CATEGORIES = {
    "Dry Goods": (0.28, 4.0, 0.10),
    "Beverages": (0.18, 6.0, 0.14),
    "Produce": (0.12, 3.0, 0.35),
    "Dairy": (0.10, 4.5, 0.28),
    "Frozen": (0.14, 7.5, 0.18),
    "Household": (0.18, 9.0, 0.09),
}
ABC = {"A": (0.20, 12, (200, 800)), "B": (0.30, 4, (50, 300)), "C": (0.50, 2, (5, 100))}
SHIFT_RISK = {"Day": 1.0, "Evening": 1.15, "Night": 1.5}
COUNTERS = {"Day": ["C01", "C02", "C03"], "Evening": ["C04", "C05"], "Night": ["C06", "C07", "C08"]}


def working_day(rng, month_index: int) -> date:
    """Random weekday inside a given month (0 = January)."""
    first = date(YEAR_START.year, month_index + 1, 1)
    while True:
        d = first + timedelta(days=int(rng.integers(0, 28)))
        if d.weekday() < 5:
            return d


def main() -> None:
    rng = np.random.default_rng(SEED)

    cats = list(CATEGORIES)
    cat_probs = [CATEGORIES[c][0] for c in cats]
    abc_keys = list(ABC)
    abc_probs = [ABC[k][0] for k in abc_keys]

    skus = []
    for i in range(N_SKUS):
        cat = str(rng.choice(cats, p=cat_probs))
        cls = str(rng.choice(abc_keys, p=abc_probs))
        median_cost = CATEGORIES[cat][1]
        skus.append(
            {
                "sku": f"SKU-{i + 1:04d}",
                "category": cat,
                "abc_class": cls,
                "unit_cost": round(float(rng.lognormal(np.log(median_cost), 0.5)), 2),
            }
        )
    skus_df = pd.DataFrame(skus)

    counts = []
    for row in skus:
        cls = row["abc_class"]
        n_counts = ABC[cls][1]
        # Spread counts evenly across the year (monthly, quarterly, or twice a year), with a
        # random starting month per SKU so the monthly count volume stays roughly level.
        offset = int(rng.integers(0, 12))
        months = (offset + np.arange(n_counts) * 12 // n_counts) % 12
        for m in months:
            d = working_day(rng, int(m))
            shift = str(rng.choice(list(SHIFT_RISK), p=[0.5, 0.25, 0.25]))
            counter = str(rng.choice(COUNTERS[shift]))
            lo, hi = ABC[cls][2]
            system_qty = int(rng.integers(lo, hi + 1))

            p_off = CATEGORIES[row["category"]][2] * SHIFT_RISK[shift]
            if d.month in (11, 12):
                p_off *= 1.3
            counted = system_qty
            if rng.random() < min(p_off, 0.95):
                size = max(1, int(round(system_qty * rng.uniform(0.01, 0.08))))
                counted = system_qty - size if rng.random() < 0.70 else system_qty + size
            counts.append(
                {
                    "count_id": f"CNT-{len(counts) + 1:06d}",
                    "sku": row["sku"],
                    "count_date": d,
                    "shift": shift,
                    "counter_id": counter,
                    "system_qty": system_qty,
                    "counted_qty": max(counted, 0),
                }
            )

    counts_df = pd.DataFrame(counts).sort_values("count_date").reset_index(drop=True)
    data_dir = Path(__file__).parent / "data"
    skus_df.to_csv(data_dir / "skus.csv", index=False)
    counts_df.to_csv(data_dir / "cycle_counts.csv", index=False)
    print(f"Wrote {len(skus_df):,} SKUs and {len(counts_df):,} cycle counts to {data_dir}")


if __name__ == "__main__":
    main()
