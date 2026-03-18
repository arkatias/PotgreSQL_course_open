-- ============================================================================
-- ПАРА 6: Соединения таблиц (JOIN) — все типы
-- Демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Зачем нужны соединения
-- ============================================================================

-- Информация о маршрутах — аэропорты, самолёт — хранится в таблице routes
SELECT route_no, departure_airport, arrival_airport, airplane_code
FROM routes
LIMIT 5;

-- А названия городов хранятся в таблице airports
SELECT airport_code, city, airport_name
FROM airports
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 2: Первый INNER JOIN
-- ============================================================================

-- Соединяем routes с airports по коду аэропорта вылета
SELECT
    r.route_no,
    r.departure_airport,
    a.city,
    a.airport_name
FROM routes r
INNER JOIN airports a ON r.departure_airport = a.airport_code
LIMIT 10;

-- INNER можно опустить (JOIN = INNER JOIN по умолчанию)
SELECT
    r.route_no,
    r.departure_airport,
    a.city,
    a.airport_name
FROM routes r
JOIN airports a ON r.departure_airport = a.airport_code
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 3: Алиасы таблиц
-- ============================================================================

-- Без алиасов — громоздко
SELECT
    routes.route_no,
    routes.departure_airport,
    airports.city
FROM routes
JOIN airports ON routes.departure_airport = airports.airport_code
LIMIT 5;

-- С алиасами — компактно и читаемо
SELECT
    r.route_no,
    r.departure_airport,
    a.city
FROM routes r
JOIN airports a ON r.departure_airport = a.airport_code
LIMIT 5;

--без алиасов неоднозначно, и возможна ошибка
SELECT
    flight_id,
    flight_id,  -- та же колонка из другой таблицы
    price
FROM flights
JOIN segments ON flights.flight_id = segments.flight_id
LIMIT 5;

-- Когда колонки одинаковые — алиасы обязательны для ясности
SELECT
    f.flight_id,
    s.flight_id,  -- та же колонка из другой таблицы
    s.price
FROM flights f
JOIN segments s ON f.flight_id = s.flight_id
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 4: Соединение с условиями в WHERE
-- ============================================================================

-- Маршруты из московских аэропортов
SELECT
    r.route_no,
    a.airport_name,
    a.city,
    r.departure_airport
FROM routes r
JOIN airports a ON r.departure_airport = a.airport_code
WHERE a.city = 'Moscow';

-- Отменённые рейсы с названием города вылета
SELECT
    f.flight_id,
    f.route_no,
    a.city AS departure_city,
    f.status
FROM flights f
JOIN routes r ON f.route_no = r.route_no
JOIN airports a ON r.departure_airport = a.airport_code
WHERE f.status = 'Cancelled' and a.city = 'Moscow'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 5: Соединение одной таблицы дважды
-- ============================================================================

-- Маршруты с городами вылета И прилёта
-- Таблица airports используется 2 раза с разными алиасами
SELECT
    r.route_no,
    dep.city AS departure_city,
    arr.city AS arrival_city
FROM routes r
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
LIMIT 10;

-- То же с фильтрацией
SELECT
    r.route_no,
    dep.city AS from_city,
    arr.city AS to_city
FROM routes r
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
WHERE dep.city = 'Moscow'
  AND arr.city = 'Yekaterinburg';

-- ============================================================================
-- ЧАСТЬ 6: Соединение трёх и более таблиц
-- ============================================================================

-- Полная информация о маршруте: города + самолёт
select
	f.flight_id,
    r.route_no,
    dep.city AS from_city,
    arr.city AS to_city,
    ap.model AS airplane,
    r.days_of_week,
    f.scheduled_departure
FROM routes r
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
JOIN airplanes ap ON r.airplane_code = ap.airplane_code
JOIN flights f ON f.route_no = r.route_no
LIMIT 10;

-- Рейсы с полной информацией: flights → routes → airports + airplanes
SELECT
    f.flight_id,
    f.route_no,
    dep.city AS from_city,
    arr.city AS to_city,
    ap.model AS airplane,
    f.scheduled_departure
FROM flights f
JOIN routes r ON f.route_no = r.route_no
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
JOIN airplanes ap ON r.airplane_code = ap.airplane_code
WHERE f.status = 'Scheduled'
ORDER BY f.scheduled_departure
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 7: JOIN с агрегацией
-- ============================================================================

-- Количество маршрутов по городам вылета
SELECT
    a.city,
    count(*) AS routes_count
FROM routes r
JOIN airports a ON r.departure_airport = a.airport_code
GROUP BY a.city
ORDER BY routes_count DESC
LIMIT 10;

-- Выручка по маршрутам
SELECT
    dep.city AS from_city,
    arr.city AS to_city,
    count(DISTINCT f.flight_id) AS flights,
    sum(s.price) AS revenue,
    round(avg(s.price), 2) AS avg_ticket
FROM flights f
JOIN routes r ON f.route_no = r.route_no
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
JOIN segments s ON f.flight_id = s.flight_id
GROUP BY dep.city, arr.city
HAVING sum(s.price) > 50000000
ORDER BY revenue DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 8: USING — короткий синтаксис
-- ============================================================================

-- Когда колонки называются одинаково
SELECT
    f.flight_id,
    f.route_no,
    s.ticket_no,
    s.price
FROM flights f
JOIN segments s USING (flight_id)
LIMIT 10;

-- USING с несколькими колонками
SELECT *
FROM segments s
JOIN boarding_passes bp USING (ticket_no, flight_id)
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 9: Самосоединение (Self-Join)
-- ============================================================================

-- Найти пары аэропортов с маршрутами в обе стороны
SELECT DISTINCT
    r1.departure_airport AS airport_a,
    r1.arrival_airport AS airport_b
FROM routes r1
JOIN routes r2
    ON r1.departure_airport = r2.arrival_airport
   AND r1.arrival_airport = r2.departure_airport
WHERE r1.departure_airport < r1.arrival_airport  -- убираем дубли (A-B = B-A)
LIMIT 20;

-- ============================================================================
-- ЧАСТЬ 10: Цепочка соединений (от бронирования к рейсу)
-- ============================================================================

-- Полная цепочка: от бронирования до городов
SELECT
    b.book_ref,
    t.passenger_name,
    dep.city AS from_city,
    arr.city AS to_city,
    f.scheduled_departure,
    s.fare_conditions,
    s.price
FROM bookings b
JOIN tickets t ON b.book_ref = t.book_ref
JOIN segments s ON t.ticket_no = s.ticket_no
JOIN flights f ON s.flight_id = f.flight_id
JOIN routes r ON f.route_no = r.route_no
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
ORDER BY b.book_ref, f.scheduled_departure
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 11: LEFT JOIN — базовый синтаксис
-- ============================================================================

-- LEFT JOIN: все строки из левой таблицы + совпадения из правой
-- Все аэропорты с количеством исходящих маршрутов
SELECT
    a.airport_code,
    a.city,
    count(r.route_no) AS routes_count
FROM airports a
LEFT JOIN routes r ON a.airport_code = r.departure_airport
GROUP BY a.airport_code, a.city
ORDER BY routes_count
LIMIT 15;

-- Сравним с INNER JOIN
SELECT
    a.airport_code,
    a.city,
    count(r.route_no) AS routes_count
FROM airports a
INNER JOIN routes r ON a.airport_code = r.departure_airport
GROUP BY a.airport_code, a.city
ORDER BY routes_count
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 12: LEFT JOIN для поиска отсутствующих данных
-- ============================================================================

-- Паттерн: LEFT JOIN + WHERE ... IS NULL
-- Найти аэропорты БЕЗ исходящих маршрутов
SELECT
    a.airport_code,
    a.city,
    a.airport_name,
    r.*
FROM airports a
LEFT JOIN routes r ON a.airport_code = r.departure_airport
WHERE r.route_no IS NULL;

-- ============================================================================
-- ЧАСТЬ 13: Разница между условием в ON и WHERE
-- ============================================================================

-- Условие в ON: применяется ДО соединения (сохраняет все строки left)
SELECT
    r.route_no,
    r.departure_airport,
    f.flight_id,
    f.status
FROM routes r
LEFT JOIN flights f
    ON r.route_no = f.route_no
   AND f.status = 'Cancelled'  -- условие в ON
ORDER BY r.route_no
LIMIT 1500;

-- Условие в WHERE: применяется ПОСЛЕ (превращает LEFT в INNER!)
SELECT
    r.route_no,
    r.departure_airport,
    f.flight_id,
    f.status
FROM routes r
LEFT JOIN flights f ON r.route_no = f.route_no
WHERE f.status = 'Cancelled'  -- убирает NULL, теряем маршруты без отмен
ORDER BY r.route_no
LIMIT 1500;

-- ============================================================================
-- ЧАСТЬ 14: RIGHT JOIN
-- ============================================================================

-- RIGHT JOIN (используется редко)
SELECT
    r.route_no,
    a.city
FROM airports a
RIGHT JOIN routes r ON a.airport_code = r.departure_airport
LIMIT 5;

-- Эквивалентный LEFT JOIN (таблицы поменяны местами)
SELECT
    r.route_no,
    a.city
FROM routes r
LEFT JOIN airports a ON r.departure_airport = a.airport_code
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 15: FULL OUTER JOIN
-- ============================================================================

-- Демонстрация на синтетическом примере
SELECT *
FROM (VALUES (1, 'A'), (2, 'B'), (3, 'C'), (7, 'D')) AS left_t(id, name)
FULL JOIN (VALUES (2, 100), (3, 200), (4, 400), (7, 600)) AS right_t(id, value)
    ON left_t.id = right_t.id
order by 1;

-- Результат:
-- id=1: A, NULL, NULL (только слева)
-- id=2: B, 2, 100 (совпадение)
-- id=3: C, 3, 200 (совпадение)
-- id=4: NULL, 4, 400 (только справа)

-- Сравнение запланированных и выполненных рейсов по маршрутам
SELECT
    COALESCE(s.route_no, a.route_no) AS route_no,
    s.scheduled_count,
    a.arrived_count,
    COALESCE(s.scheduled_count, 0) + COALESCE(a.arrived_count, 0) AS difference
FROM (
    SELECT route_no, count(*) AS scheduled_count
    FROM flights
    WHERE status = 'Scheduled'
    GROUP BY route_no
) s
FULL JOIN (
    SELECT route_no, count(*) AS arrived_count
    FROM flights
    WHERE status = 'Arrived'
    GROUP BY route_no
) a ON s.route_no = a.route_no
ORDER BY route_no
LIMIT 20;

-- ============================================================================
-- ЧАСТЬ 16: CROSS JOIN — декартово произведение
-- ============================================================================

-- Все возможные пары аэропортов
SELECT
    a1.airport_code AS from_airport,
    a2.airport_code AS to_airport
FROM airports a1
CROSS JOIN airports a2
WHERE a1.airport_code != a2.airport_code
ORDER BY a1.airport_code, a2.airport_code
LIMIT 20;

-- Матрица: месяцы × классы + данные (CROSS JOIN + LEFT JOIN)
SELECT
    m.month_num,
    fc.fare_conditions,
    COALESCE(stats.tickets_count, 0) AS tickets,
    COALESCE(stats.revenue, 0) AS revenue
FROM generate_series(1, 12) AS m(month_num)
CROSS JOIN (SELECT DISTINCT fare_conditions FROM segments) fc
LEFT JOIN (
    SELECT
        extract(month from f.scheduled_departure)::int AS month_num,
        s.fare_conditions,
        count(*) AS tickets_count,
        sum(s.price) AS revenue
    FROM flights f
    JOIN segments s ON f.flight_id = s.flight_id
    WHERE extract(year from f.scheduled_departure) = 2026
    GROUP BY 1, 2
) stats ON m.month_num = stats.month_num
       AND fc.fare_conditions = stats.fare_conditions
ORDER BY m.month_num, fc.fare_conditions;

-- ============================================================================
-- ЧАСТЬ 17: Поиск "сирот" — данных без связей
-- ============================================================================

-- Рейсы без проданных билетов
SELECT
    f.flight_id,
    f.route_no,
    f.scheduled_departure,
    dep.city AS from_city,
    arr.city AS to_city
FROM flights f
JOIN routes r ON f.route_no = r.route_no
JOIN airports dep ON r.departure_airport = dep.airport_code
JOIN airports arr ON r.arrival_airport = arr.airport_code
LEFT JOIN segments s ON f.flight_id = s.flight_id
WHERE s.ticket_no IS NULL
LIMIT 20;

-- ============================================================================
-- ПРАКТИЧЕСКИЕ ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Маршруты с названиями аэропортов вылета

-- Задание 2: Маршруты с городами вылета и прилёта

-- Задание 3: Все рейсы из Москвы

-- Задание 4: Количество маршрутов по моделям самолётов

-- Задание 5: Аэропорты без исходящих маршрутов

-- Задание 6: Все самолёты с количеством маршрутов (включая 0)

-- Задание 7: Все возможные маршруты между городами
