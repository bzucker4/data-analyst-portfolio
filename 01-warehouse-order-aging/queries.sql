-- Warehouse order aging and late shipment analysis (SQLite dialect).
-- Table: orders(order_id, order_date, ship_by_date, shipped_date, zone, priority, region, lines, units)
-- Dates are ISO text (YYYY-MM-DD). shipped_date is NULL for orders still open at the snapshot date.
-- Each block starts with "-- name: <label>" so analysis.py can run them one by one.

-- name: overall_kpis
SELECT
    COUNT(*)                                                        AS total_orders,
    SUM(shipped_date IS NOT NULL)                                   AS shipped_orders,
    SUM(shipped_date IS NULL)                                       AS open_orders,
    SUM(shipped_date > ship_by_date)                                AS late_shipped,
    ROUND(100.0 * SUM(shipped_date > ship_by_date)
          / SUM(shipped_date IS NOT NULL), 1)                       AS late_rate_pct,
    ROUND(AVG(julianday(shipped_date) - julianday(order_date)), 2)  AS avg_days_to_ship
FROM orders;

-- name: late_by_zone
SELECT
    zone,
    COUNT(*)                                                         AS shipped_orders,
    SUM(shipped_date > ship_by_date)                                 AS late_orders,
    ROUND(100.0 * SUM(shipped_date > ship_by_date) / COUNT(*), 1)    AS late_rate_pct,
    ROUND(AVG(julianday(shipped_date) - julianday(order_date)), 2)   AS avg_days_to_ship
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY zone
ORDER BY late_rate_pct DESC;

-- name: late_by_order_weekday
SELECT
    CASE CAST(strftime('%w', order_date) AS INTEGER)
        WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu'
        WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat' ELSE 'Sun'
    END                                                              AS order_weekday,
    COUNT(*)                                                         AS shipped_orders,
    ROUND(100.0 * SUM(shipped_date > ship_by_date) / COUNT(*), 1)    AS late_rate_pct
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY strftime('%w', order_date)
ORDER BY (CAST(strftime('%w', order_date) AS INTEGER) + 6) % 7;

-- name: late_by_priority
SELECT
    priority,
    COUNT(*)                                                         AS shipped_orders,
    ROUND(100.0 * SUM(shipped_date > ship_by_date) / COUNT(*), 1)    AS late_rate_pct
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY priority;

-- name: month_end_effect
-- Orders placed in the last three days of a month versus all other days.
SELECT
    CASE WHEN julianday(date(order_date, 'start of month', '+1 month', '-1 day'))
              - julianday(order_date) <= 2
         THEN 'Last 3 days of month' ELSE 'Other days' END           AS period,
    COUNT(*)                                                         AS shipped_orders,
    ROUND(100.0 * SUM(shipped_date > ship_by_date) / COUNT(*), 1)    AS late_rate_pct
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY period;

-- name: weekly_trend
SELECT
    date(order_date, 'weekday 0', '-6 days')                         AS week_start,
    COUNT(*)                                                         AS shipped_orders,
    ROUND(100.0 * SUM(shipped_date > ship_by_date) / COUNT(*), 1)    AS late_rate_pct
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY week_start
ORDER BY week_start;

-- name: open_order_aging
-- Orders still unshipped on the snapshot date (2025-06-30), bucketed by age in days.
SELECT
    zone,
    SUM(julianday('2025-06-30') - julianday(order_date) <= 1)                                  AS "0-1 days",
    SUM(julianday('2025-06-30') - julianday(order_date) BETWEEN 2 AND 3)                       AS "2-3 days",
    SUM(julianday('2025-06-30') - julianday(order_date) >= 4)                                  AS "4+ days",
    COUNT(*)                                                                                   AS total_open,
    SUM(ship_by_date < '2025-06-30')                                                           AS already_past_ship_by
FROM orders
WHERE shipped_date IS NULL
GROUP BY zone
ORDER BY total_open DESC;

-- name: shipments_by_ship_weekday
-- Evidence for weekend coverage: how many orders actually leave on each day of the week.
SELECT
    CASE CAST(strftime('%w', shipped_date) AS INTEGER)
        WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu'
        WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat' ELSE 'Sun'
    END                                                              AS ship_weekday,
    COUNT(*)                                                         AS orders_shipped
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY strftime('%w', shipped_date)
ORDER BY (CAST(strftime('%w', shipped_date) AS INTEGER) + 6) % 7;

-- name: same_day_ship_rate_by_zone
-- Share of orders that ship the day they are placed, and share that take 3 or more days.
-- A zone that regularly carries orders over to the next day is short on shipping capacity.
SELECT
    zone,
    COUNT(*)                                                                    AS shipped_orders,
    ROUND(100.0 * SUM(shipped_date = order_date) / COUNT(*), 1)                 AS shipped_same_day_pct,
    ROUND(100.0 * SUM(julianday(shipped_date) - julianday(order_date) >= 3)
          / COUNT(*), 1)                                                        AS took_3plus_days_pct
FROM orders
WHERE shipped_date IS NOT NULL
GROUP BY zone
ORDER BY shipped_same_day_pct;
