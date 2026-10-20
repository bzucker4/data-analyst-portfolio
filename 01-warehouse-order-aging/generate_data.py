"""Generate a synthetic warehouse order dataset (SYNTHETIC DATA, not real company data).

The simulation is a simple capacity-limited queue. Orders arrive each day with a weekday
pattern and a month-end bump, and each storage zone can only ship a limited number of
orders per day. Backlog and late shipments emerge from that capacity limit, which makes
the dataset behave like real order data without using any real records.

Run:  python generate_data.py
Output: data/orders.csv
"""
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
START = date(2025, 1, 1)
END = date(2025, 6, 30)  # last day of activity; open orders are measured as of this date

# Share of incoming orders per zone and daily shipping capacity per zone (weekdays).
ZONES = {
    "Ambient": {"share": 0.55, "cap": 90},
    "Refrigerated": {"share": 0.20, "cap": 34},
    "Frozen": {"share": 0.15, "cap": 24},
    "Specialty": {"share": 0.10, "cap": 19},
}
WEEKDAY_VOLUME = [1.35, 1.15, 1.00, 1.00, 0.90, 0.30, 0.30]  # Mon..Sun order volume
WEEKDAY_CAPACITY = [1.0, 1.0, 1.0, 1.0, 1.0, 0.30, 0.0]  # Mon..Sun shipping capacity
BASE_DAILY_ORDERS = 140
SLA_DAYS = {"Standard": 2, "Expedited": 1}
REGIONS = ["North", "South", "East", "West"]


def month_end_factor(d: date) -> float:
    """Volume bump in the last three days of each month."""
    next_month = (d.replace(day=28) + timedelta(days=4)).replace(day=1)
    days_left = (next_month - d).days
    return 1.25 if days_left <= 3 else 1.0


def main() -> None:
    rng = np.random.default_rng(SEED)
    zone_names = list(ZONES)
    zone_probs = [ZONES[z]["share"] for z in zone_names]

    orders = []  # list of dicts, shipped_date filled in by the queue below
    backlog = {z: [] for z in zone_names}  # indexes into `orders`

    day = START
    while day <= END:
        wd = day.weekday()
        expected = BASE_DAILY_ORDERS * WEEKDAY_VOLUME[wd] * month_end_factor(day)
        n_new = int(rng.poisson(expected))
        for _ in range(n_new):
            zone = rng.choice(zone_names, p=zone_probs)
            priority = "Expedited" if rng.random() < 0.15 else "Standard"
            lines = int(rng.poisson(3)) + 1
            orders.append(
                {
                    "order_id": f"ORD-{len(orders) + 1:06d}",
                    "order_date": day,
                    "ship_by_date": day + timedelta(days=SLA_DAYS[priority]),
                    "shipped_date": None,
                    "zone": zone,
                    "priority": priority,
                    "region": rng.choice(REGIONS),
                    "lines": lines,
                    "units": int(lines * rng.integers(1, 12)),
                }
            )
            backlog[zone].append(len(orders) - 1)

        # Ship from each zone's backlog: expedited first, then oldest first.
        for zone in zone_names:
            cap_today = ZONES[zone]["cap"] * WEEKDAY_CAPACITY[wd]
            cap_today = int(round(cap_today * rng.normal(1.0, 0.08)))  # labor variation
            queue = sorted(
                backlog[zone],
                key=lambda i: (orders[i]["priority"] != "Expedited", orders[i]["order_date"], i),
            )
            shipped_now, remaining = queue[:cap_today], queue[cap_today:]
            for i in shipped_now:
                orders[i]["shipped_date"] = day
            backlog[zone] = remaining
        day += timedelta(days=1)

    df = pd.DataFrame(orders)
    out = Path(__file__).parent / "data" / "orders.csv"
    df.to_csv(out, index=False)
    open_orders = df["shipped_date"].isna().sum()
    print(f"Wrote {len(df):,} orders to {out} ({open_orders:,} still open as of {END})")


if __name__ == "__main__":
    main()
