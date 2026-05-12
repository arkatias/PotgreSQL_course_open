-- =====================================================
-- Пара 10: Операции над множествами.
-- Демонстрационные запросы
-- =====================================================

-- =====================================================
-- 1. UNION — ОБЪЕДИНЕНИЕ РЕЗУЛЬТАТОВ
-- =====================================================

-- Простой UNION: все уникальные аэропорты
SELECT departure_airport AS airport FROM timetable
UNION
SELECT arrival_airport AS airport FROM timetable
ORDER BY airport;

-- Количество уникальных аэропортов
SELECT count(*)
FROM (
    SELECT departure_airport AS airport FROM timetable
    UNION
    SELECT arrival_airport AS airport FROM timetable
) all_airports;

-- UNION с дополнительной информацией
SELECT departure_airport AS airport, 'Отправление' AS type
FROM timetable
UNION
SELECT arrival_airport AS airport, 'Прибытие' AS type
FROM timetable
ORDER BY airport, type;

-- =====================================================
-- 2. UNION ALL — БЕЗ УДАЛЕНИЯ ДУБЛИКАТОВ
-- =====================================================

-- UNION ALL быстрее, сохраняет все строки
SELECT departure_airport AS airport, 'dep' AS type FROM timetable
UNION ALL
SELECT arrival_airport,  'arr' FROM timetable
LIMIT 20;

-- Сравнение количества строк
SELECT 'UNION' AS operation, count(*) AS rows
FROM (
    SELECT departure_airport FROM timetable
    UNION
    SELECT arrival_airport FROM timetable
) u
UNION ALL
SELECT 'UNION ALL', count(*)
FROM (
    SELECT departure_airport FROM timetable
    UNION ALL
    SELECT arrival_airport FROM timetable
) ua;

-- =====================================================
-- 3. ОБЪЕДИНЕНИЕ РАЗНЫХ ИСТОЧНИКОВ
-- =====================================================

-- Сводный отчёт из разных таблиц
SELECT 'Всего бронирований' AS metric, count(*) AS value FROM bookings
UNION ALL
SELECT 'Всего билетов', count(*) FROM tickets
UNION ALL
SELECT 'Всего рейсов', count(*) FROM flights
UNION ALL
SELECT 'Уникальных пассажиров', count(DISTINCT passenger_id) FROM tickets
UNION ALL
SELECT 'Аэропортов', count(*) FROM airports
UNION ALL
SELECT 'Типов самолётов', count(*) FROM airplanes;


SELECT flight_id::text, scheduled_departure::text
FROM flights
union all
SELECT ticket_no::text, passenger_id::text
FROM tickets;


-- =====================================================
-- 4. INTERSECT — ПЕРЕСЕЧЕНИЕ МНОЖЕСТВ
-- =====================================================

-- Аэропорты, которые являются и отправлением, и прибытием
SELECT  departure_airport AS airport FROM timetable
INTERSECT
SELECT  arrival_airport AS airport FROM timetable
ORDER BY airport;

-- Города с рейсами в обе стороны
SELECT DISTINCT a.city
FROM timetable f
JOIN airports a ON f.departure_airport = a.airport_code
INTERSECT
SELECT DISTINCT a.city
FROM timetable f
JOIN airports a ON f.arrival_airport = a.airport_code
ORDER BY city;

-- =====================================================
-- 5. EXCEPT — РАЗНОСТЬ МНОЖЕСТВ
-- =====================================================

-- Аэропорты только отправления (не являются пунктами прибытия)
SELECT  departure_airport FROM timetable
EXCEPT
SELECT arrival_airport FROM timetable;

-- Аэропорты только прибытия (не являются пунктами отправления)
SELECT arrival_airport FROM timetable
EXCEPT
SELECT departure_airport FROM timetable;

-- Билеты без посадочных талонов
SELECT ticket_no, flight_id FROM segments
EXCEPT
SELECT ticket_no, flight_id FROM boarding_passes
LIMIT 20;

-- Подсчёт билетов без посадочных
SELECT count(*) AS tickets_without_boarding
FROM (
    SELECT ticket_no, flight_id FROM segments
    EXCEPT
    SELECT ticket_no, flight_id FROM boarding_passes
) no_boarding;

-- =====================================================
-- 6. КОМБИНИРОВАНИЕ ОПЕРАЦИЙ
-- =====================================================

-- Все аэропорты минус те, что и отправление, и прибытие
(
    SELECT DISTINCT departure_airport AS airport FROM timetable
    UNION
    SELECT DISTINCT arrival_airport FROM timetable
)
EXCEPT
(
    SELECT DISTINCT departure_airport FROM timetable
    INTERSECT
    SELECT DISTINCT arrival_airport FROM timetable
);