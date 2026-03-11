-- ============================================================================
-- ПАРА 5: Агрегатные функции и группировка данных (GROUP BY, HAVING)
-- Единый демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Базовые агрегатные функции
-- ============================================================================

-- 1. Сколько всего рейсов
SELECT count(*) AS total_flights
FROM flights;

-- 2. COUNT(*) vs COUNT(column) vs COUNT(DISTINCT)
SELECT
    count(*) AS total_rows,
    count(actual_departure) AS non_null_actual_departure,
    count(DISTINCT status) AS unique_statuses
FROM flights;

-- 3. SUM и AVG по бронированиям
SELECT
    sum(total_amount) AS total_revenue,
    round(avg(total_amount), 2) AS avg_booking
FROM bookings;

-- 4. MIN/MAX по датам и суммам
SELECT
    min(book_date) AS first_booking,
    max(book_date) AS last_booking,
    min(total_amount) AS min_amount,
    max(total_amount) AS max_amount
FROM bookings;

-- 5. Поведение агрегатов с NULL
SELECT
    sum(x) AS sum_x,
    avg(x) AS avg_x,
    count(x) AS count_non_null,
    count(*) AS count_all
FROM (VALUES (10), (20), (NULL), (30)) AS t(x);

-- ============================================================================
-- ЧАСТЬ 2: GROUP BY
-- ============================================================================

-- 6. Количество рейсов по статусам
SELECT
    status,
    count(*) AS flights_count
FROM flights
GROUP BY status
ORDER BY flights_count DESC;

-- 7. Группировка по двум колонкам
SELECT
    departure_airport,
    arrival_airport,
    count(*) AS flights_count
FROM timetable
GROUP BY departure_airport, arrival_airport
ORDER BY flights_count DESC
LIMIT 10;

-- 8. Группировка по выражению (помесячно)
SELECT
    date_trunc('month', book_date) AS month,
    count(*) AS bookings_count,
    round(sum(total_amount), 2) AS revenue
FROM bookings
GROUP BY date_trunc('month', book_date)
ORDER BY month;

-- ============================================================================
-- ЧАСТЬ 3: HAVING и связка WHERE + GROUP BY + HAVING
-- ============================================================================

-- 9. HAVING: фильтрация групп
SELECT
    status,
    count(*) AS flights_count
FROM flights
GROUP BY status
HAVING count(*) > 1000
ORDER BY flights_count DESC;

-- 10. WHERE + GROUP BY + HAVING
SELECT
    route_no,
    count(*) AS flights_count
FROM flights
WHERE scheduled_departure >= '2017-01-01'
  AND scheduled_departure <  '2018-01-01'
GROUP BY route_no
HAVING count(*) >= 20
ORDER BY flights_count DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 4: Условная агрегация и практический отчёт
-- ============================================================================

-- 11. FILTER: несколько метрик по статусам
SELECT
    departure_airport,
    count(*) AS total,
    count(*) FILTER (WHERE status = 'Arrived') AS arrived,
    count(*) FILTER (WHERE status = 'Cancelled') AS cancelled,
    round(100.0 * count(*) FILTER (WHERE status = 'Cancelled') / count(*), 2)
        AS cancelled_pct
FROM timetable
GROUP BY departure_airport
HAVING count(*) >= 100
ORDER BY cancelled_pct DESC
LIMIT 10;


SELECT
    departure_airport,
    count(*) AS total,
    sum(CASE WHEN status = 'Arrived' THEN 1 ELSE 0 END) AS arrived,
    sum(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    round(
        100.0 * sum(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / count(*),
        2
    ) AS cancelled_pct
FROM timetable
GROUP BY departure_airport
HAVING count(*) >= 100
ORDER BY cancelled_pct DESC
LIMIT 10;

-- 12. Мини-отчёт по выручке аэропортов вылета
SELECT
    t.departure_airport,
    count(DISTINCT t.flight_id) AS flights,
    count(s.ticket_no) AS tickets,
    round(sum(s.price), 2) AS revenue,
    round(avg(s.price), 2) AS avg_ticket_price
FROM timetable t
JOIN segments s ON s.flight_id = t.flight_id
GROUP BY t.departure_airport
HAVING count(*) >= 100
ORDER BY revenue DESC
LIMIT 10;

-- ============================================================================
-- ДОМАШНЯЯ ПРАКТИКА (без решений)
-- ============================================================================

-- 1) Количество рейсов по каждому статусу
-- 2) Средняя цена сегмента по fare_conditions
-- 3) Выручка по месяцам из bookings
-- 4) Топ-10 route_no по количеству рейсов (с HAVING)
-- 5) Аэропорты с наибольшей долей отмен через FILTER

-- ============================================================================
-- РЕШЕНИЯ К ПРАКТИКЕ
-- ============================================================================
-- 1) Количество рейсов по каждому статусу
SELECT
    status,
    count(*) AS flights_count
FROM flights
GROUP BY status
ORDER BY flights_count DESC;

-- 2) Средняя цена сегмента по fare_conditions
SELECT
    fare_conditions,
    round(avg(price), 2) AS avg_segment_price
FROM segments
GROUP BY fare_conditions
ORDER BY avg_segment_price DESC;

-- 3) Выручка по месяцам из bookings
SELECT
    date_trunc('month', book_date) AS month,
    count(*) AS bookings_count,
    round(sum(total_amount), 2) AS revenue
FROM bookings
GROUP BY date_trunc('month', book_date)
ORDER BY month;

-- 4) Топ-10 route_no по количеству рейсов (с HAVING)
SELECT
    route_no,
    count(*) AS flights_count
FROM flights
GROUP BY route_no
HAVING count(*) >= 20
ORDER BY flights_count DESC
LIMIT 10;

-- 5) Аэропорты с наибольшей долей отмен через FILTER
SELECT
    departure_airport,
    count(*) AS total_flights,
    count(*) FILTER (WHERE status = 'Cancelled') AS cancelled_flights,
    round(100.0 * count(*) FILTER (WHERE status = 'Cancelled') / count(*), 2)
        AS cancelled_pct
FROM timetable
GROUP BY departure_airport
HAVING count(*) >= 100
ORDER BY cancelled_pct DESC
LIMIT 10;