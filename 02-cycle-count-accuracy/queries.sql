-- Cycle count accuracy analysis (SQLite dialect).
-- Tables:
--   cycle_counts(count_id, sku, count_date, shift, counter_id, system_qty, counted_qty)
--   skus(sku, category, abc_class, unit_cost)
-- A count is "accurate" when counted_qty equals system_qty exactly.
-- Variance = counted_qty - system_qty (negative means the shelf had less than the system said).
-- Each block starts with "-- name: <label>" so analysis.py can run them one by one.

-- name: overall_kpis
SELECT
    COUNT(*)                                                               AS counts,
    COUNT(DISTINCT c.sku)                                                  AS skus_counted,
    MIN(c.count_date)                                                      AS first_count,
    MAX(c.count_date)                                                      AS last_count,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct,
    ROUND(100.0 * SUM(ABS(c.counted_qty - c.system_qty) <= 0.02 * c.system_qty)
          / COUNT(*), 1)                                                   AS within_2pct_pct,
    ROUND(100.0 * SUM(c.counted_qty < c.system_qty) / COUNT(*), 1)         AS short_pct,
    ROUND(100.0 * SUM(c.counted_qty > c.system_qty) / COUNT(*), 1)         AS over_pct,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 0)         AS abs_variance_usd,
    ROUND(SUM((c.counted_qty - c.system_qty) * s.unit_cost), 0)            AS net_variance_usd
FROM cycle_counts c
JOIN skus s USING (sku);

-- name: accuracy_by_category
SELECT
    s.category,
    COUNT(*)                                                               AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct,
    ROUND(100.0 * SUM(c.counted_qty < c.system_qty) / COUNT(*), 1)         AS short_pct,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 0)         AS abs_variance_usd,
    ROUND(SUM((c.counted_qty - c.system_qty) * s.unit_cost), 0)            AS net_variance_usd
FROM cycle_counts c
JOIN skus s USING (sku)
GROUP BY s.category
ORDER BY exact_accuracy_pct;

-- name: accuracy_by_shift
SELECT
    c.shift,
    COUNT(*)                                                               AS counts,
    COUNT(DISTINCT c.counter_id)                                           AS counters,
    GROUP_CONCAT(DISTINCT c.counter_id)                                    AS counter_ids,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct
FROM cycle_counts c
GROUP BY c.shift
ORDER BY exact_accuracy_pct DESC;

-- name: accuracy_by_category_and_shift
-- Checks whether the night-shift gap is just a different category mix. It is not:
-- night is lowest within most categories.
SELECT
    s.category,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Day'     THEN c.counted_qty = c.system_qty END)
          / SUM(c.shift = 'Day'), 1)                                       AS day_pct,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Evening' THEN c.counted_qty = c.system_qty END)
          / SUM(c.shift = 'Evening'), 1)                                   AS evening_pct,
    ROUND(100.0 * SUM(CASE WHEN c.shift = 'Night'   THEN c.counted_qty = c.system_qty END)
          / SUM(c.shift = 'Night'), 1)                                     AS night_pct
FROM cycle_counts c
JOIN skus s USING (sku)
GROUP BY s.category
ORDER BY night_pct;

-- name: accuracy_by_counter
SELECT
    c.counter_id,
    c.shift,
    COUNT(*)                                                               AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct
FROM cycle_counts c
GROUP BY c.counter_id, c.shift
ORDER BY exact_accuracy_pct DESC;

-- name: accuracy_by_abc_class
SELECT
    s.abc_class,
    COUNT(DISTINCT c.sku)                                                  AS skus,
    COUNT(*)                                                               AS counts,
    ROUND(1.0 * COUNT(*) / COUNT(DISTINCT c.sku), 1)                       AS counts_per_sku,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct,
    ROUND(SUM(ABS(c.counted_qty - c.system_qty) * s.unit_cost), 0)         AS abs_variance_usd
FROM cycle_counts c
JOIN skus s USING (sku)
GROUP BY s.abc_class
ORDER BY s.abc_class;

-- name: monthly_trend
SELECT
    SUBSTR(c.count_date, 1, 7)                                             AS month,
    COUNT(*)                                                               AS counts,
    ROUND(100.0 * SUM(c.counted_qty = c.system_qty) / COUNT(*), 1)         AS exact_accuracy_pct,
    ROUND(100.0 * SUM(CASE WHEN s.category = 'Produce'
                           THEN c.counted_qty = c.system_qty END)
          / SUM(s.category = 'Produce'), 1)                                AS produce_pct,
    ROUND(100.0 * SUM(CASE WHEN s.category = 'Dairy'
                           THEN c.counted_qty = c.system_qty END)
          / SUM(s.category = 'Dairy'), 1)                                  AS dairy_pct
FROM cycle_counts c
JOIN skus s USING (sku)
GROUP BY month
ORDER BY month;
