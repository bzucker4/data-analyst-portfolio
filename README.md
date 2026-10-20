# Data Analyst Portfolio

**Brian Zucker** | Google Data Analytics Certified | Webster, NY

I come from warehouse, inventory, and delivery operations, and I am moving into data analytics.
These projects take problems I know from that work (late orders, count accuracy, lot dwell time)
and analyze them end to end: generate or load the data, query it in SQL, analyze it in Python,
chart it, and write up what to do about it.

> **About the data:** All three datasets are synthetic. I generated them with seeded scripts in
> each project folder, because real company data is not public. Patterns were built into the generators, so each analysis demonstrates method
> and reporting, not facts about a real operation. Every README says so and lists its limitations.

## Projects

| Project | Business question | Headline result |
|---|---|---|
| [01 Warehouse Order Aging](01-warehouse-order-aging/) | Which orders ship late, and where should a manager act first? | Frozen was 15% of orders but 74% of late shipments. Friday orders were late 19.5% of the time. |
| [02 Cycle Count Accuracy](02-cycle-count-accuracy/) | Where is the inventory record wrong, and what does it cost? | Shrink was 2.7 times overage. The top 10% of SKUs held 69% of dollar variance. Night shift was least accurate. |
| [03 Vehicle Lot Dwell Time](03-vehicle-lot-dwell-time/) | What makes vehicles sit longer, and how much lot space does it use? | Third-party vehicles dwelled about twice as long as hauler vehicles, tying up roughly 23 lot spaces. |

## Skills shown

- **SQL (SQLite):** joins, CTEs, recursive CTEs, window functions (`ROW_NUMBER`, `NTILE`,
  `COUNT OVER`), conditional aggregation, date handling, calculating a median without a built-in
  function.
- **Python:** pandas for loading and reshaping data, matplotlib for charts, a seeded simulation
  to build realistic datasets, scripts that rerun from scratch.
- **Analysis habits:** checking a likely explanation and ruling it out (month-end volume), testing
  that a result holds inside subgroups (shift effect by category, damage effect by source),
  handling vehicles that have not left the lot yet, and stating limitations.
- **Communication:** each project ends with recommendations a manager could act on.

## Repository layout

```
01-warehouse-order-aging/    generate_data.py, queries.sql, analysis.py, results.md, charts/, data/
02-cycle-count-accuracy/     same structure
03-vehicle-lot-dwell-time/   same structure
requirements.txt
```

## Run any project

```
pip install -r requirements.txt
cd 01-warehouse-order-aging
python generate_data.py
python analysis.py
```

Tested with Python 3.13. The data scripts use fixed seeds, so results are identical on every run.

## Contact

Brian.copy@proton.me | [LinkedIn](https://www.linkedin.com/in/brian-zucker-3b8767443/)
