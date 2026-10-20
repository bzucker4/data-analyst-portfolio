# Data Analyst Portfolio

Portfolio case studies using SQL, Python, CSV datasets, and interactive visualization.

## Projects

### 01 · Warehouse Order Aging

**Resume-ready summary:** Built an interactive operations dashboard with HTML, JavaScript, Chart.js, and CSV data to analyze 21,950 simulated warehouse orders. Defined shipment lateness against ship-by dates, developed KPI cards and filters, and compared late-shipment rates across warehouse zones, order priorities, regions, and weeks.

**Selected findings from the simulated dataset:**
- Overall late-shipment rate: **6.4%** (1,397 of 21,780 shipped orders); average time to ship: **0.74 days**.
- Frozen zone: **31.7% late**, accounting for about **74% of all late shipments**.
- Friday orders: **19.5% late**, the highest rate by order weekday; standard orders were **7.6% late**, compared with 0% for expedited orders.
- Recommended next steps: review Frozen-zone workflow and Friday/weekend handoffs, then monitor weekly late rates.

[**Open the live interactive dashboard**](https://bzucker4.github.io/data-analyst-portfolio/01-warehouse-order-aging/)

- [Project overview, findings, and recommendations](./01-warehouse-order-aging/README.md)
- [SQL queries](./01-warehouse-order-aging/queries.sql)
- [Python analysis](./01-warehouse-order-aging/analysis.py)
- [Results summary](./01-warehouse-order-aging/results.md)

### 02 · Cycle Count Accuracy
- [Dataset](./02-cycle-count-accuracy/data/cycle_counts.csv)
- [SKU reference data](./02-cycle-count-accuracy/data/skus.csv)

### 03 · Vehicle Lot Dwell Time
- [Vehicle dataset](./03-vehicle-lot-dwell-time/data/vehicles.csv)
- [Daily lot inventory chart](./03-vehicle-lot-dwell-time/charts/daily_lot_inventory.png)

## Run and publish

The Warehouse Order Aging dashboard is a static HTML page. To publish it, enable GitHub Pages for the repository using the `main` branch and `/(root)` as the source. Then open the project dashboard URL.

## Data note

These are simulated portfolio datasets. Findings illustrate analytical methods and should not be presented as results from a real employer.
