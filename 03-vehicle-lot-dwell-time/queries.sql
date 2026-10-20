-- Vehicle lot dwell time and lot utilization analysis (SQLite dialect).
-- Table: vehicles(vehicle_id, arrival_date, arrival_source, vehicle_type, damage_on_arrival,
--                 lot_section, departure_date)
-- Dates are ISO text. departure_date is NULL for vehicles still on the lot at 2025-12-31.
--
-- Dwell time = days between arrival and departure. To avoid biasing dwell time downward
-- (vehicles that are still on the lot have not finished dwelling), dwell statistics use only
-- vehicles that arrived on or before 2025-11-30 and have departed. The "still_on_lot" block
-- shows how many vehicles that leaves out.
-- Each block starts with "-- name: <label>" so analysis.py can run them one by one.

-- name: overall_kpis
WITH departed AS (
    SELECT julianday(departure_date) - julianday(arrival_date) AS dwell_days
    FROM vehicles
    WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
),
ranked AS (
    SELECT dwell_days,
           ROW_NUMBER() OVER (ORDER BY dwell_days) AS rn,
           COUNT(*) OVER ()                        AS cnt
    FROM departed
)
SELECT
    (SELECT COUNT(*) FROM vehicles)                                      AS total_vehicles,
    COUNT(*)                                                             AS vehicles_in_dwell_analysis,
    ROUND(AVG(dwell_days), 1)                                            AS avg_dwell_days,
    (SELECT AVG(dwell_days) FROM ranked WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)) AS median_dwell_days,
    ROUND(100.0 * SUM(dwell_days > 14) / COUNT(*), 1)                    AS pct_over_14_days
FROM departed;

-- name: still_on_lot
SELECT
    COUNT(*)                                                             AS vehicles_on_lot_at_year_end,
    ROUND(AVG(julianday('2025-12-31') - julianday(arrival_date)), 1)     AS avg_age_days,
    SUM(arrival_date <= '2025-11-30')                                    AS arrived_before_dec_1
FROM vehicles
WHERE departure_date IS NULL;

-- name: dwell_by_source
WITH departed AS (
    SELECT arrival_source,
           julianday(departure_date) - julianday(arrival_date) AS dwell_days
    FROM vehicles
    WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
),
ranked AS (
    SELECT arrival_source, dwell_days,
           ROW_NUMBER() OVER (PARTITION BY arrival_source ORDER BY dwell_days) AS rn,
           COUNT(*) OVER (PARTITION BY arrival_source)                         AS cnt
    FROM departed
)
SELECT
    arrival_source,
    COUNT(*)                                                             AS vehicles,
    ROUND(AVG(dwell_days), 1)                                            AS avg_dwell_days,
    AVG(CASE WHEN rn IN ((cnt + 1) / 2, (cnt + 2) / 2) THEN dwell_days END) AS median_dwell_days,
    ROUND(100.0 * SUM(dwell_days > 14) / COUNT(*), 1)                    AS pct_over_14_days
FROM ranked
GROUP BY arrival_source
ORDER BY avg_dwell_days DESC;

-- name: dwell_by_damage
SELECT
    CASE damage_on_arrival WHEN 1 THEN 'Damaged on arrival' ELSE 'No damage' END AS condition,
    COUNT(*)                                                             AS vehicles,
    ROUND(AVG(julianday(departure_date) - julianday(arrival_date)), 1)   AS avg_dwell_days,
    ROUND(100.0 * SUM(julianday(departure_date) - julianday(arrival_date) > 14) / COUNT(*), 1) AS pct_over_14_days
FROM vehicles
WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
GROUP BY damage_on_arrival
ORDER BY damage_on_arrival DESC;

-- name: damage_rate_by_source
SELECT
    arrival_source,
    COUNT(*)                                                             AS vehicles,
    SUM(damage_on_arrival)                                               AS damaged,
    ROUND(100.0 * SUM(damage_on_arrival) / COUNT(*), 1)                  AS damage_rate_pct
FROM vehicles
GROUP BY arrival_source
ORDER BY damage_rate_pct DESC;

-- name: dwell_by_vehicle_type
SELECT
    vehicle_type,
    COUNT(*)                                                             AS vehicles,
    ROUND(AVG(julianday(departure_date) - julianday(arrival_date)), 1)   AS avg_dwell_days
FROM vehicles
WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
GROUP BY vehicle_type
ORDER BY avg_dwell_days DESC;

-- name: dwell_by_arrival_day_type
SELECT
    CASE WHEN strftime('%w', arrival_date) IN ('0', '6') THEN 'Weekend arrival' ELSE 'Weekday arrival' END AS arrival_day_type,
    COUNT(*)                                                             AS vehicles,
    ROUND(AVG(julianday(departure_date) - julianday(arrival_date)), 1)   AS avg_dwell_days
FROM vehicles
WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
GROUP BY arrival_day_type;

-- name: source_and_damage_combined
SELECT
    arrival_source,
    CASE damage_on_arrival WHEN 1 THEN 'Damaged' ELSE 'No damage' END    AS condition,
    COUNT(*)                                                             AS vehicles,
    ROUND(AVG(julianday(departure_date) - julianday(arrival_date)), 1)   AS avg_dwell_days
FROM vehicles
WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
GROUP BY arrival_source, damage_on_arrival
ORDER BY arrival_source, damage_on_arrival;

-- name: third_party_excess_lot_space
-- How much lot space does the extra dwell of third-party vehicles use, compared with
-- car hauler vehicles? "extra_vehicle_days" is (third-party avg dwell minus hauler avg dwell)
-- times the number of third-party vehicles. Dividing by 334 (the days from 2025-01-01 to
-- 2025-11-30, the arrival window used here) gives the average number of lot spaces tied up
-- by that gap.
WITH d AS (
    SELECT arrival_source,
           COUNT(*) AS n,
           AVG(julianday(departure_date) - julianday(arrival_date)) AS avg_dwell
    FROM vehicles
    WHERE departure_date IS NOT NULL AND arrival_date <= '2025-11-30'
    GROUP BY arrival_source
)
SELECT
    ROUND(tp.avg_dwell, 1)                                  AS third_party_avg_dwell,
    ROUND(h.avg_dwell, 1)                                   AS hauler_avg_dwell,
    tp.n                                                    AS third_party_vehicles,
    ROUND((tp.avg_dwell - h.avg_dwell) * tp.n, 0)           AS extra_vehicle_days,
    ROUND((tp.avg_dwell - h.avg_dwell) * tp.n / 334.0, 1)   AS avg_lot_spaces_tied_up
FROM d tp, d h
WHERE tp.arrival_source = 'Third Party' AND h.arrival_source = 'Car Hauler';

-- name: monthly_arrivals_and_dwell
SELECT
    substr(arrival_date, 1, 7)                                           AS month,
    COUNT(*)                                                             AS arrivals,
    ROUND(AVG(julianday(departure_date) - julianday(arrival_date)), 1)   AS avg_dwell_days
FROM vehicles
WHERE arrival_date <= '2025-11-30' AND departure_date IS NOT NULL
GROUP BY month
ORDER BY month;

-- name: daily_lot_inventory
-- Number of vehicles physically on the lot at the end of each day of 2025.
WITH RECURSIVE days(d) AS (
    SELECT '2025-01-01'
    UNION ALL
    SELECT date(d, '+1 day') FROM days WHERE d < '2025-12-31'
)
SELECT
    d                                                                    AS day,
    (SELECT COUNT(*) FROM vehicles v
      WHERE v.arrival_date <= d AND (v.departure_date IS NULL OR v.departure_date > d)) AS vehicles_on_lot
FROM days;

-- name: lot_inventory_summary
WITH RECURSIVE days(d) AS (
    SELECT '2025-02-01'
    UNION ALL
    SELECT date(d, '+1 day') FROM days WHERE d < '2025-12-31'
),
daily AS (
    SELECT d,
           (SELECT COUNT(*) FROM vehicles v
             WHERE v.arrival_date <= d AND (v.departure_date IS NULL OR v.departure_date > d)) AS on_lot
    FROM days
)
SELECT
    ROUND(AVG(on_lot), 0)  AS avg_vehicles_on_lot,
    MAX(on_lot)            AS peak_vehicles_on_lot,
    MIN(on_lot)            AS low_vehicles_on_lot
FROM daily;
