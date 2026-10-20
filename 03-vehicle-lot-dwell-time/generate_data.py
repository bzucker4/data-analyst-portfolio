"""Generate synthetic vehicle lot data (SYNTHETIC DATA, no real vehicles or VINs).

Each vehicle has an arrival source, a type, a damage-on-arrival flag, a lot section, and an
arrival and departure date. Dwell time depends on source, damage, vehicle type, and
whether the vehicle arrived on a weekend. Those relationships are built into the generator
so the analysis has something to find; the findings show the method, not real-world facts.

Run:  python generate_data.py
Output: data/vehicles.csv
"""
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 21
START = date(2025, 1, 1)
END = date(2025, 12, 31)  # snapshot date; vehicles departing after this are still on the lot

# source -> (share of arrivals, median dwell days, probability of damage on arrival)
SOURCES = {
    "Car Hauler": (0.55, 6.0, 0.06),
    "Third Party": (0.30, 11.0, 0.14),
    "Local Transfer": (0.15, 4.0, 0.03),
}
TYPE_EXTRA_DAYS = {"Sedan": 0.0, "SUV": 0.5, "Truck": 2.0, "Van": 1.0}
SECTIONS = ["A", "B", "C", "D"]
ARRIVAL_WEEKDAY_WEIGHTS = [1.3, 1.2, 1.0, 1.0, 1.1, 0.4, 0.2]  # Mon..Sun


def main() -> None:
    rng = np.random.default_rng(SEED)
    days = [START + timedelta(days=i) for i in range((END - START).days + 1)]
    day_weights = np.array([ARRIVAL_WEEKDAY_WEIGHTS[d.weekday()] for d in days], dtype=float)
    day_weights /= day_weights.sum()

    n_vehicles = 4500
    arrival_days = rng.choice(len(days), size=n_vehicles, p=day_weights)
    src_names = list(SOURCES)
    src_probs = [SOURCES[s][0] for s in src_names]

    rows = []
    for idx, di in enumerate(sorted(arrival_days)):
        arrival = days[int(di)]
        source = str(rng.choice(src_names, p=src_probs))
        vtype = str(rng.choice(list(TYPE_EXTRA_DAYS), p=[0.35, 0.30, 0.25, 0.10]))
        damaged = bool(rng.random() < SOURCES[source][2])

        median = SOURCES[source][1] + TYPE_EXTRA_DAYS[vtype]
        if damaged:
            median += 5.0
        if arrival.weekday() >= 5:
            median += 1.0
        dwell = max(1, int(round(rng.lognormal(np.log(median), 0.45))))
        departure = arrival + timedelta(days=dwell)

        rows.append(
            {
                "vehicle_id": f"VEH-{idx + 1:05d}",
                "arrival_date": arrival,
                "arrival_source": source,
                "vehicle_type": vtype,
                "damage_on_arrival": int(damaged),
                "lot_section": str(rng.choice(SECTIONS)),
                "departure_date": departure if departure <= END else None,
            }
        )

    df = pd.DataFrame(rows)
    out = Path(__file__).parent / "data" / "vehicles.csv"
    df.to_csv(out, index=False)
    print(f"Wrote {len(df):,} vehicles to {out} ({df['departure_date'].isna().sum():,} still on lot at {END})")


if __name__ == "__main__":
    main()
