-- Cycle count accuracy and inventory variance analysis (SQLite dialect).
-- Tables:
--   skus(sku, category, abc_class, unit_cost)
--   cycle_counts(count_id, sku, count_date, shift, counter_id, system_qty, counted_qty)
-- A count is "exact" when counted_qty equals system_qty. A count is "within 2%" when the
-- absolute difference is at most 2% of the system quantity.
-- Each block starts with "-- name: <label>" so analysis.py can run them one by one.

-- name: overall_kpis
SELECT
    COUNT(*)                                                                    AS total_counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct,
    ROUND(100.0 * SUM(ABS(c.counted_qty - c.system_qty) <= 0.02 * c.system_qty)
          / COUNT(*), 1)                                                        AS within_2pct_pct,
    SUM(c.counted_qty - c.system_qty)                                           AS net_unit_variance,
    ROUND(SUM((c.counted_qty - c.system_qty) * s.unit_cost), 2)                 AS net_dollar_variance,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 2)              AS gross_dollar_variance
FROM cycle_counts c
JOIN skus s ON s.sku = c.sku;

-- name: accuracy_by_category
SELECT
    s.category,
    COUNT(*)                                                                    AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct,
    ROUND(SUM(CASE WHEN c.counted_qty < c.system_qty
                   THEN (c.system_qty - c.counted_qty) * s.unit_cost ELSE 0 END), 2) AS shrink_dollars,
    ROUND(SUM(CASE WHEN c.counted_qty > c.system_qty
                   THEN (c.counted_qty - c.system_qty) * s.unit_cost ELSE 0 END), 2) AS overage_dollars
FROM cycle_counts c
JOIN skus s ON s.sku = c.sku
GROUP BY s.category
ORDER BY exact_match_pct;

-- name: accuracy_by_shift
SELECT
    c.shift,
    COUNT(*)                                                                    AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct
FROM cycle_counts c
GROUP BY c.shift
ORDER BY exact_match_pct;

-- name: accuracy_by_counter
SELECT
    c.counter_id,
    c.shift,
    COUNT(*)                                                                    AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct
FROM cycle_counts c
GROUP BY c.counter_id, c.shift
ORDER BY exact_match_pct;

-- name: accuracy_by_abc_class
SELECT
    s.abc_class,
    COUNT(*)                                                                    AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 2)              AS gross_dollar_variance
FROM cycle_counts c
JOIN skus s ON s.sku = c.sku
GROUP BY s.abc_class
ORDER BY s.abc_class;

-- name: monthly_trend
SELECT
    substr(c.count_date, 1, 7)                                                  AS month,
    COUNT(*)                                                                    AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)              AS exact_match_pct
FROM cycle_counts c
GROUP BY month
ORDER BY month;

-- name: top_10_skus_by_dollar_variance
SELECT
    s.sku,
    s.category,
    s.abc_class,
    COUNT(*)                                                                    AS counts,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 2)              AS gross_dollar_variance
FROM cycle_counts c
JOIN skus s ON s.sku = c.sku
GROUP BY s.sku
ORDER BY gross_dollar_variance DESC
LIMIT 10;

-- name: share_of_variance_from_top_decile
-- How concentrated is the dollar variance? Share of total held by the top 10% of SKUs.
WITH per_sku AS (
    SELECT s.sku, SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost) AS gross_var
    FROM cycle_counts c
    JOIN skus s ON s.sku = c.sku
    GROUP BY s.sku
),
ranked AS (
    SELECT gross_var, NTILE(10) OVER (ORDER BY gross_var DESC) AS decile FROM per_sku
)
SELECT
    ROUND(100.0 * SUM(CASE WHEN decile = 1 THEN gross_var ELSE 0 END) / SUM(gross_var), 1)
        AS top_10pct_skus_share_of_variance_pct
FROM ranked;

-- name: accuracy_by_shift_within_category
-- Robustness check: does the night-shift gap hold inside each category, or is it just a
-- difference in which categories each shift counts?
SELECT
    s.category,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Day'     AND c.counted_qty = c.system_qty THEN 1 ELSE 0 END)
          / SUM(c.shift = 'Day'), 1)                                            AS day_exact_pct,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Evening' AND c.counted_qty = c.system_qty THEN 1 ELSE 0 END)
          / SUM(c.shift = 'Evening'), 1)                                        AS evening_exact_pct,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Night'   AND c.counted_qty = c.system_qty THEN 1 ELSE 0 END)
          / SUM(c.shift = 'Night'), 1)                                          AS night_exact_pct
FROM cycle_counts c
JOIN skus s ON s.sku = c.sku
GROUP BY s.category
ORDER BY s.category;
