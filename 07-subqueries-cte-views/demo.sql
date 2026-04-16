-- ============================================================================
-- ПАРА 7: Подзапросы (Subqueries) и CTE (Common Table Expressions)
-- Демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ I: ПОДЗАПРОСЫ
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Введение в подзапросы
-- ============================================================================

-- Подзапрос — это запрос внутри другого запроса
-- Подзапрос выполняется первым, результат используется внешним запросом

-- Простой пример: средняя стоимость бронирования
SELECT avg(total_amount) FROM bookings;

-- Использование этого значения в другом запросе
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount > (SELECT avg(total_amount) FROM bookings)
ORDER BY total_amount DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 2: Скалярные подзапросы в SELECT
-- ============================================================================

-- Скалярный подзапрос возвращает ОДНО значение (одна строка, одна колонка)

-- Добавляем среднее значение к каждой строке
SELECT
    book_ref,
    total_amount,
    (SELECT avg(total_amount) FROM bookings) AS avg_amount
FROM bookings
LIMIT 10;

-- Вычисление отклонения от среднего
SELECT
    book_ref,
    total_amount,
    (SELECT avg(total_amount) FROM bookings) AS avg_amount,
    total_amount - (SELECT avg(total_amount) FROM bookings) AS deviation,
    round(
        100.0 * total_amount / (SELECT avg(total_amount) FROM bookings),
        1
    ) AS pct_of_avg
FROM bookings
ORDER BY deviation DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 3: Скалярные подзапросы в WHERE
-- ============================================================================

-- Бронирования выше среднего
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount > (SELECT avg(total_amount) FROM bookings)
ORDER BY total_amount DESC
LIMIT 10;

-- Бронирования ниже среднего
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount < (SELECT avg(total_amount) FROM bookings)
ORDER BY total_amount
LIMIT 10;

-- Самое дорогое бронирование
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount = (SELECT max(total_amount) FROM bookings);

-- ============================================================================
-- ЧАСТЬ 4: Подзапросы с IN
-- ============================================================================

-- IN проверяет, входит ли значение в результат подзапроса

-- Маршруты из московских аэропортов
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE departure_airport IN (
    SELECT airport_code
    FROM airports
    WHERE city = 'Moscow'
)
ORDER BY route_no
LIMIT 10;

-- То же через JOIN (сравните)
SELECT r.route_no, r.departure_airport, r.arrival_airport
FROM routes r
JOIN airports a ON r.departure_airport = a.airport_code
WHERE a.city = 'Moscow'
ORDER BY r.route_no
LIMIT 10;

-- IN с несколькими значениями из подзапроса
SELECT route_no, arrival_airport
FROM routes
WHERE arrival_airport IN (
    SELECT airport_code
    FROM airports
    WHERE city IN ('Sochi', 'Moscow')
)
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 5: NOT IN и проблема с NULL
-- ============================================================================

-- Демонстрация проблемы с NULL
-- Создадим тестовые данные
SELECT * FROM (VALUES (1), (2), (3)) AS t(id)
WHERE id NOT IN (SELECT * FROM (VALUES (1), (2)) AS s(id));
-- Результат: 3

-- Теперь добавим NULL
SELECT * FROM (VALUES (1), (2), (3)) AS t(id)
WHERE id NOT IN (SELECT * FROM (VALUES (1), (NULL)) AS s(id));
-- Результат: ПУСТО! Потому что 3 NOT IN (1, NULL) = UNKNOWN

-- Решение 1: исключить NULL из подзапроса
SELECT * FROM (VALUES (1), (2), (3)) AS t(id)
WHERE id NOT IN (
    SELECT id FROM (VALUES (1), (NULL)) AS s(id)
    WHERE id IS NOT NULL
);

-- Решение 2: использовать NOT EXISTS (рекомендуется)

-- ============================================================================
-- ЧАСТЬ 6: EXISTS и NOT EXISTS
-- ============================================================================

-- EXISTS возвращает TRUE, если подзапрос вернул хотя бы одну строку

-- Аэропорты, из которых есть маршруты
SELECT airport_code, city, airport_name
FROM airports a
WHERE EXISTS (
    SELECT 1  -- значение не важно, важен факт наличия строк
    FROM routes r
    WHERE r.departure_airport = a.airport_code
)
ORDER BY city;

-- NOT EXISTS: аэропорты БЕЗ исходящих маршрутов
SELECT airport_code, city, airport_name
FROM airports a
WHERE NOT EXISTS (
    SELECT 1
    FROM routes r
    WHERE r.departure_airport = a.airport_code
);

-- NOT EXISTS безопаснее NOT IN (корректно работает с NULL)
-- Аэропорты без входящих маршрутов
SELECT airport_code, city
FROM airports a
WHERE NOT EXISTS (
    SELECT 1
    FROM routes r
    WHERE r.arrival_airport = a.airport_code
);

-- ============================================================================
-- ЧАСТЬ 7: Сравнение IN и EXISTS
-- ============================================================================

-- IN — проверяет вхождение значения в список
SELECT route_no, departure_airport
FROM routes
WHERE departure_airport IN (
    SELECT airport_code FROM airports WHERE city = 'Москва'
)
LIMIT 5;

-- EXISTS — проверяет наличие связанных строк (коррелированный)
SELECT route_no, departure_airport
FROM routes r
WHERE EXISTS (
    SELECT 1 FROM airports a
    WHERE a.airport_code = r.departure_airport
      AND a.city = 'Moscow'
)
LIMIT 5;

-- Результат одинаковый, но EXISTS всегда коррелированный

-- ============================================================================
-- ЧАСТЬ 8: ANY и ALL
-- ============================================================================

-- ANY: хотя бы одно значение удовлетворяет условию
-- = ANY эквивалентен IN

SELECT ticket_no, price
FROM segments
WHERE price = ANY (
    SELECT price FROM segments WHERE fare_conditions = 'Business'
)
LIMIT 10;

-- > ANY: больше хотя бы одного значения
SELECT ticket_no, price, fare_conditions
FROM segments
WHERE price > ANY (
    SELECT price FROM segments WHERE fare_conditions = 'Economy'
)
AND fare_conditions  != 'Economy'  -- эконом дороже какого-то эконома
LIMIT 10;

-- ALL: все значения удовлетворяют условию
-- > ALL: больше ВСЕХ значений

-- Сегменты дороже ВСЕХ сегментов эконом-класса
SELECT ticket_no, price, fare_conditions
FROM segments
WHERE price > ALL (
    SELECT price FROM segments WHERE fare_conditions = 'Economy'
)
ORDER BY price
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 9: Подзапросы в FROM (derived tables)
-- ============================================================================

-- Подзапрос в FROM создаёт временную таблицу
SELECT city_stats.city,
 city_stats.routes_count
FROM (
 SELECT a.city,
 count(*) AS routes_count
 FROM routes r
 JOIN airports a
 ON r.departure_airport = a.airport_code
 GROUP BY a.city
) AS city_stats -- алиас обязателен!
WHERE city_stats.routes_count > 10
ORDER BY city_stats.routes_count DESC;


-- Статистика по городам с фильтрацией
SELECT
    city_stats.city,
    city_stats.routes_count,
    city_stats.total_revenue
FROM (
    SELECT
        a.city,
        count(DISTINCT r.route_no) AS routes_count,
        sum(s.price) AS total_revenue
    FROM routes r
    JOIN airports a ON r.departure_airport = a.airport_code
    JOIN flights f ON r.route_no = f.route_no
    JOIN segments s ON f.flight_id = s.flight_id
    GROUP BY a.city
) AS city_stats  -- алиас обязателен!
WHERE city_stats.routes_count > 10
ORDER BY city_stats.total_revenue DESC
LIMIT 10;

-- Двойная агрегация: среднее от суммы
SELECT
    round(avg(daily_revenue), 2) AS avg_daily_revenue
FROM (
    SELECT
        book_date::date AS day,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily_stats;

-- ============================================================================
-- ЧАСТЬ 10: Коррелированные подзапросы
-- ============================================================================

-- Некоррелированный: не зависит от внешнего запроса
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount > (SELECT avg(total_amount) FROM bookings);
-- Подзапрос выполняется ОДИН раз

-- Коррелированный: ссылается на внешний запрос
SELECT
    s.ticket_no,
    s.fare_conditions,
    s.price,
    (
        SELECT avg(price)
        FROM segments s2
        WHERE s2.fare_conditions = s.fare_conditions  -- ссылка на s
    ) AS class_avg
FROM segments s
LIMIT 10;
-- Подзапрос выполняется для КАЖДОЙ строки!

-- Сегменты дороже среднего в своём классе
SELECT
    s.ticket_no,
    s.fare_conditions,
    s.price
FROM segments s
WHERE s.price > (
    SELECT avg(price)
    FROM segments s2
    WHERE s2.fare_conditions = s.fare_conditions
)
ORDER BY s.fare_conditions, s.price DESC
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 11: Оптимизация коррелированных подзапросов
-- ============================================================================

-- Медленно: коррелированный подзапрос
SELECT
    s.ticket_no,
    s.fare_conditions,
    s.price
FROM segments s
WHERE s.price > (
    SELECT avg(price)
    FROM segments s2
    WHERE s2.fare_conditions = s.fare_conditions
);

-- Быстрее: JOIN с предвычисленным агрегатом
SELECT
    s.ticket_no,
    s.fare_conditions,
    s.price
FROM segments s
JOIN (
    SELECT fare_conditions, avg(price) AS avg_price
    FROM segments
    GROUP BY fare_conditions
) class_avgs ON s.fare_conditions = class_avgs.fare_conditions
WHERE s.price > class_avgs.avg_price;

-- ============================================================================
-- ЧАСТЬ 12: Коррелированный подзапрос в SELECT
-- ============================================================================

-- Количество маршрутов для каждого аэропорта
SELECT
    a.airport_code,
    a.city,
    (
        SELECT count(*)
        FROM routes r
        WHERE r.departure_airport = a.airport_code
    ) AS departures,
    (
        SELECT count(*)
        FROM routes r
        WHERE r.arrival_airport = a.airport_code
    ) AS arrivals
FROM airports a
ORDER BY departures DESC
LIMIT 10;

-- То же через LEFT JOIN (эффективнее)
SELECT
    a.airport_code,
    a.city,
    count(DISTINCT r_dep.route_no) AS departures,
    count(DISTINCT r_arr.route_no) AS arrivals
FROM airports a
LEFT JOIN routes r_dep ON a.airport_code = r_dep.departure_airport
LEFT JOIN routes r_arr ON a.airport_code = r_arr.arrival_airport
GROUP BY a.airport_code, a.city
ORDER BY departures DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 13: Вложенные подзапросы
-- ============================================================================

-- Подзапрос внутри подзапроса (не рекомендуется для сложных случаев)
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount > (
    SELECT avg(total_amount)
    FROM bookings
    WHERE book_ref IN (
        SELECT book_ref
        FROM tickets
        WHERE passenger_name LIKE 'ALEKSANDR%'
    )
)
ORDER BY total_amount DESC
LIMIT 10;

-- Лучше разбить на части с помощью CTE (см. дальше)

-- ============================================================================
-- ЧАСТЬ 14: LATERAL — боковые подзапросы
-- ============================================================================

-- LATERAL позволяет подзапросу ссылаться на предыдущие таблицы в FROM

-- Топ-3 маршрута для каждого аэропорта по количеству рейсов
SELECT
    a.airport_code
   ,a.city
   ,top_routes.route_no
   ,top_routes.arrival_airport
   ,top_routes.flights
FROM airports a
CROSS JOIN LATERAL (
    SELECT r.route_no, r.arrival_airport, count(f.flight_id) AS flights
    FROM routes r
    JOIN flights f ON r.route_no = f.route_no
    WHERE r.departure_airport = a.airport_code
    GROUP BY r.route_no, r.arrival_airport
    ORDER BY flights DESC
    LIMIT 5
) AS top_routes
ORDER BY a.city ,top_routes.flights DESC 
LIMIT 20;

-- Последний рейс для каждого маршрута
SELECT
    r.route_no,
    r.departure_airport,
    r.arrival_airport,
    last_flight.flight_id,
    last_flight.scheduled_departure
FROM routes r
CROSS JOIN LATERAL (
    SELECT flight_id, scheduled_departure
    FROM flights f
    WHERE f.route_no = r.route_no
    ORDER BY scheduled_departure DESC
    LIMIT 1
) last_flight
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ II: CTE (Common Table Expressions)
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 15: Введение в CTE
-- ============================================================================

-- CTE — это именованный временный результат запроса
-- Существует только во время выполнения запроса

-- Сравнение: подзапрос vs CTE

-- Подзапрос в FROM
SELECT *
FROM (
    SELECT city, count(*) AS airport_count
    FROM airports
    GROUP BY city
) AS city_stats
WHERE airport_count > 1;

-- То же с CTE — более читаемо
WITH city_stats AS (
    SELECT city, count(*) AS airport_count
    FROM airports
    GROUP BY city
)
SELECT * FROM city_stats
WHERE airport_count > 1;

-- ============================================================================
-- ЧАСТЬ 16: CTE — читаемость сложных запросов
-- ============================================================================

-- Без CTE — всё в одном запросе (сложно читать)
SELECT
    a.city,
    flight_stats.total_flights,
    flight_stats.avg_passengers
FROM airports a
JOIN (
    SELECT
        r.departure_airport,
        count(*) AS total_flights,
        avg(passenger_count) AS avg_passengers
    FROM flights f
    JOIN routes r ON f.route_no = r.route_no
    JOIN (
        SELECT flight_id, count(*) AS passenger_count
        FROM segments
        GROUP BY flight_id
    ) pc ON f.flight_id = pc.flight_id
    GROUP BY r.departure_airport
) flight_stats ON a.airport_code = flight_stats.departure_airport
WHERE flight_stats.total_flights > 500
ORDER BY flight_stats.total_flights DESC
LIMIT 10;

-- С CTE — логические блоки с именами
WITH
    -- Количество пассажиров на рейс
    passengers_per_flight AS (
        SELECT flight_id, count(*) AS passenger_count
        FROM segments
        GROUP BY flight_id
    ),
    -- Статистика по аэропортам
    airport_flight_stats AS (
        SELECT
            r.departure_airport,
            count(*) AS total_flights,
            round(avg(ppf.passenger_count), 1) AS avg_passengers
        FROM flights f
        JOIN routes r ON f.route_no = r.route_no
        JOIN passengers_per_flight ppf ON f.flight_id = ppf.flight_id
        GROUP BY r.departure_airport
    )
-- Основной запрос
SELECT
    a.city,
    afs.total_flights,
    afs.avg_passengers
FROM airports a
JOIN airport_flight_stats afs ON a.airport_code = afs.departure_airport
WHERE afs.total_flights > 500
ORDER BY afs.total_flights DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 17: Множественные CTE
-- ============================================================================

-- Несколько CTE, где каждый следующий может использовать предыдущие
WITH
    -- CTE 1: Московские аэропорты
    moscow_airports AS (
        SELECT airport_code, airport_name
        FROM airports
        WHERE city = 'Moscow'
    ),
    -- CTE 2: Маршруты из Москвы (использует moscow_airports)
    moscow_routes AS (
        SELECT r.*
        FROM routes r
        WHERE r.departure_airport IN (SELECT airport_code FROM moscow_airports)
    ),
    -- CTE 3: Статистика по направлениям
    destination_stats AS (
        SELECT
            arrival_airport,
            count(*) AS routes_count,
            count(DISTINCT airplane_code) AS airplane_types
        FROM moscow_routes
        GROUP BY arrival_airport
    )
-- Финальный запрос
SELECT
    a.city AS destination_city,
    ds.routes_count,
    ds.airplane_types
FROM destination_stats ds
JOIN airports a ON ds.arrival_airport = a.airport_code
ORDER BY ds.routes_count DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 18: Переиспользование CTE
-- ============================================================================

-- Один CTE используется несколько раз в запросе
WITH route_stats AS (
    SELECT
        r.departure_airport,
        r.arrival_airport,
        count(f.flight_id) AS flights_count
    FROM routes r
    JOIN flights f ON r.route_no = f.route_no
    GROUP BY r.departure_airport, r.arrival_airport
)
SELECT
    r1.departure_airport AS airport_a,
    r1.arrival_airport AS airport_b,
    r1.flights_count AS flights_a_to_b,
    COALESCE(r2.flights_count, 0) AS flights_b_to_a,
    r1.flights_count - COALESCE(r2.flights_count, 0) AS imbalance
FROM route_stats r1
LEFT JOIN route_stats r2  -- тот же CTE!
    ON r1.departure_airport = r2.arrival_airport
   AND r1.arrival_airport = r2.departure_airport
ORDER BY abs(r1.flights_count - COALESCE(r2.flights_count, 0)) DESC
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 19: Рекурсивные CTE — введение
-- ============================================================================

-- WITH RECURSIVE позволяет CTE ссылаться на самого себя

-- Простейший пример: числа от 1 до 10
WITH RECURSIVE numbers AS (
    -- Базовый случай (anchor member)
    SELECT 1 AS n

    UNION ALL

    -- Рекурсивный случай (recursive member)
    SELECT n + 1
    FROM numbers
    WHERE n < 100  -- условие остановки!
)
SELECT * FROM numbers;

-- ============================================================================
-- ЧАСТЬ 20: Как работает рекурсия
-- ============================================================================

-- Шаг 1: Выполняется базовый запрос → {1}
-- Шаг 2: Рекурсивный запрос с {1} → {2}
-- Шаг 3: Рекурсивный запрос с {2} → {3}
-- ...
-- Шаг 10: Рекурсивный запрос с {9} → {10}
-- Шаг 11: Рекурсивный запрос с {10} → {} (пусто, n=10 не < 10)
-- Результат: {1} ∪ {2} ∪ ... ∪ {10} = {1,2,3,4,5,6,7,8,9,10}

-- Демонстрация с выводом шагов
WITH RECURSIVE numbers AS (
    SELECT 1 AS n, 'base' AS step

    UNION ALL

    SELECT n + 1, 'step ' || (n + 1)
    FROM numbers
    WHERE n < 5
)
SELECT * FROM numbers;

-- ============================================================================
-- ЧАСТЬ 21: Генерация последовательностей
-- ============================================================================

-- Генерация дат
WITH RECURSIVE dates AS (
    SELECT '2017-08-01'::date AS dt

    UNION ALL

    SELECT dt + 1
    FROM dates
    WHERE dt < '2017-08-10'
)
SELECT * FROM dates;

-- Альтернатива: generate_series (встроенная функция PostgreSQL)
SELECT generate_series('2017-08-01'::date, '2017-08-10'::date, '1 day'::interval)::date AS dt;

-- Числа Фибоначчи
WITH RECURSIVE fib AS (
    SELECT 1 AS n, 1::bigint AS fib_n, 1::bigint AS fib_n_plus_1

    UNION ALL

    SELECT n + 1, fib_n_plus_1, fib_n + fib_n_plus_1
    FROM fib
    WHERE n < 20
)
SELECT n, fib_n FROM fib;

-- ============================================================================
-- ЧАСТЬ 22: Поиск маршрутов — базовый пример
-- ============================================================================

-- Найдём все способы добраться из SVO (Шереметьево)

-- Сначала посмотрим прямые маршруты
SELECT DISTINCT arrival_airport
FROM routes
WHERE departure_airport = 'SVO'
ORDER BY arrival_airport;

-- Теперь с пересадками
WITH RECURSIVE route_paths AS (
    -- Базовый случай: прямые маршруты из SVO
    SELECT DISTINCT
        'SVO' AS origin,
        arrival_airport AS destination,
        1 AS hops,
        ARRAY['SVO', arrival_airport] AS path
    FROM routes
    WHERE departure_airport = 'SVO'

    UNION

    -- Рекурсивный случай: добавляем пересадку
    SELECT
        rp.origin,
        r.arrival_airport,
        rp.hops + 1,
        rp.path || r.arrival_airport
    FROM route_paths rp
    JOIN routes r ON rp.destination = r.departure_airport
    WHERE rp.hops < 2  -- максимум 1 пересадка
      AND NOT r.arrival_airport = ANY(rp.path)  -- избегаем циклов
)
SELECT DISTINCT destination, hops, path
FROM route_paths
WHERE destination = 'BER'  
ORDER BY hops, path;

-- ============================================================================
-- ЧАСТЬ 23: Маршруты между городами
-- ============================================================================

-- Более практичный пример: маршруты между городами
WITH RECURSIVE city_routes AS (
    -- Базовый случай: прямые маршруты из Москвы
    SELECT DISTINCT
        dep.city AS origin,
        arr.city AS current_city,
        1 AS transfers,
        ARRAY[dep.city, arr.city] AS path
    FROM routes r
    JOIN airports dep ON r.departure_airport = dep.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE dep.city = 'Moscow'

    UNION

    -- Рекурсивный случай
    SELECT DISTINCT
        cr.origin,
        arr.city,
        cr.transfers + 1,
        cr.path || arr.city
    FROM city_routes cr
    JOIN airports dep ON dep.city = cr.current_city
    JOIN routes r ON r.departure_airport = dep.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE cr.transfers < 3  -- до 2 пересадок
      AND NOT arr.city = ANY(cr.path)  -- без циклов
)
SELECT current_city, transfers, path
FROM city_routes
WHERE current_city = 'Berlin'
ORDER BY transfers, path
LIMIT 20;

-- ============================================================================
-- ЧАСТЬ 24: Защита от бесконечной рекурсии
-- ============================================================================

-- 1. Условие остановки в WHERE (обязательно!)
-- WHERE depth < max_depth

-- 2. Проверка на циклы через массив пути
-- WHERE NOT new_node = ANY(path_array)

-- 3. LIMIT в основном запросе (на всякий случай)

-- Безопасная версия поиска достижимых аэропортов
WITH RECURSIVE safe_routes AS (
    SELECT
        'SVO' AS airport,
        ARRAY['SVO'] AS visited,
        0 AS depth
    UNION ALL
    SELECT
        r.arrival_airport,
        sr.visited || r.arrival_airport,
        sr.depth + 1
    FROM safe_routes sr
    JOIN routes r ON sr.airport = r.departure_airport
    WHERE sr.depth < 2  -- ограничение глубины
      AND NOT r.arrival_airport = ANY(sr.visited)  -- без циклов
)
SELECT DISTINCT airport, depth
FROM safe_routes
ORDER BY depth, airport
LIMIT 30;

-- ============================================================================
-- ЧАСТЬ 25: Практические примеры
-- ============================================================================

-- Пример 1: Самый дорогой сегмент каждого класса
SELECT s.ticket_no, s.fare_conditions, s.price
FROM segments s
WHERE s.price = (
    SELECT max(price)
    FROM segments s2
    WHERE s2.fare_conditions = s.fare_conditions
);

-- Пример 2: Маршруты с выручкой выше средней (CTE)
WITH route_revenue AS (
    SELECT
        r.departure_airport,
        r.arrival_airport,
        sum(s.price) AS revenue
    FROM routes r
    JOIN flights f ON r.route_no = f.route_no
    JOIN segments s ON f.flight_id = s.flight_id
    GROUP BY r.departure_airport, r.arrival_airport
)
SELECT departure_airport, arrival_airport, revenue
FROM route_revenue
WHERE revenue > (SELECT avg(revenue) FROM route_revenue)
ORDER BY revenue DESC
LIMIT 10;

-- Пример 3: Пассажиры с несколькими перелётами
SELECT
    t.passenger_name,
    (
        SELECT count(*)
        FROM segments s
        WHERE s.ticket_no = t.ticket_no
    ) AS flights_count
FROM tickets t
WHERE (
    SELECT count(*)
    FROM segments s
    WHERE s.ticket_no = t.ticket_no
) > 3
LIMIT 10;

-- Пример 4: Заполнение пропусков в данных (рекурсивный CTE + LEFT JOIN)
WITH RECURSIVE all_dates AS (
    SELECT min(book_date)::date AS dt FROM bookings

    UNION ALL

    SELECT dt + 1
    FROM all_dates
    WHERE dt < (SELECT max(book_date)::date FROM bookings)
)
SELECT
    ad.dt,
    COALESCE(b.bookings_count, 0) AS bookings,
    COALESCE(b.revenue, 0) AS revenue
FROM all_dates ad
LEFT JOIN (
    SELECT
        book_date::date AS dt,
        count(*) AS bookings_count,
        sum(total_amount) AS revenue
    FROM bookings
    GROUP BY book_date::date
) b ON ad.dt = b.dt
ORDER BY ad.dt
LIMIT 30;

-- ============================================================================
-- ЧАСТЬ III: VIEW (представления)
-- ============================================================================

-- VIEW как "сохранённый запрос" для переиспользования
CREATE OR REPLACE VIEW v_route_revenue AS
SELECT
    r.departure_airport,
    r.arrival_airport,
    count(DISTINCT f.flight_id) AS flights_count,
    sum(s.price) AS total_revenue
FROM routes r
JOIN flights f ON r.route_no = f.route_no
JOIN segments s ON f.flight_id = s.flight_id
GROUP BY r.departure_airport, r.arrival_airport;

-- Использование VIEW как обычной таблицы
SELECT
    dep.city AS from_city,
    arr.city AS to_city,
    vr.flights_count,
    round(vr.total_revenue / 1000000, 2) AS revenue_mln
FROM v_route_revenue vr
JOIN airports dep ON vr.departure_airport = dep.airport_code
JOIN airports arr ON vr.arrival_airport = arr.airport_code
ORDER BY vr.total_revenue DESC
LIMIT 10;

-- Создание представления поверх CTE
CREATE OR REPLACE VIEW v_busy_cities AS
WITH city_stats AS (
    SELECT
        a.city,
        count(DISTINCT r.route_no) AS routes_count
    FROM airports a
    JOIN routes r ON a.airport_code = r.departure_airport
    GROUP BY a.city
)
SELECT *
FROM city_stats
WHERE routes_count > 10;

SELECT * FROM v_busy_cities ORDER BY routes_count DESC;

-- Простой обновляемый VIEW
CREATE OR REPLACE VIEW v_moscow_airports AS
SELECT *
FROM airports
WHERE city = 'Москва'
WITH CHECK OPTION;

-- Просмотр определения VIEW
SELECT pg_get_viewdef('v_route_revenue', true);

-- ============================================================================
-- MATERIALIZED VIEW (материализованные представления)
-- ============================================================================

-- MATERIALIZED VIEW хранит результат запроса на диске
CREATE MATERIALIZED VIEW mv_route_revenue AS
SELECT
    r.departure_airport,
    r.arrival_airport,
    count(DISTINCT f.flight_id) AS flights_count,
    sum(s.price) AS total_revenue
FROM routes r
JOIN flights f ON r.route_no = f.route_no
JOIN segments s ON f.flight_id = s.flight_id
GROUP BY r.departure_airport, r.arrival_airport;

-- Запрос к MV обычно дешевле, чем к исходной агрегации
SELECT *
FROM mv_route_revenue
ORDER BY total_revenue DESC
LIMIT 10;

-- Для REFRESH CONCURRENTLY нужен уникальный индекс
CREATE UNIQUE INDEX idx_mv_route_revenue_key
ON mv_route_revenue (departure_airport, arrival_airport);

-- Полное обновление
REFRESH MATERIALIZED VIEW mv_route_revenue;

-- Обновление без блокировки чтения (при наличии уникального индекса)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_route_revenue;

-- ============================================================================
-- ПРАКТИЧЕСКИЕ ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Бронирования дороже среднего

-- Задание 2: Маршруты из городов-миллионников (IN)

-- Задание 3: Аэропорты без маршрутов (NOT EXISTS)

-- Задание 4: Сегменты дороже среднего в своём классе

-- Задание 5: CTE для статистики по городам

-- Задание 6: Маршруты между двумя городами (до 2 пересадок)

-- Задание 7: Создать VIEW с количеством рейсов и выручкой по направлениям

-- Задание 8: Создать MATERIALIZED VIEW с дневной выручкой и выполнить REFRESH

-- ============================================================================
-- ОТВЕТЫ НА ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Бронирования дороже среднего
SELECT book_ref, book_date, total_amount
FROM bookings
WHERE total_amount > (SELECT avg(total_amount) FROM bookings)
ORDER BY total_amount DESC
LIMIT 20;

-- Задание 2: Маршруты из крупных городов (с > 10 маршрутов)
SELECT r.route_no, r.departure_airport, r.arrival_airport
FROM routes r
WHERE r.departure_airport IN (
    SELECT a.airport_code
    FROM airports a
    JOIN routes r2 ON a.airport_code = r2.departure_airport
    GROUP BY a.airport_code
    HAVING count(*) > 10
)
LIMIT 20;

-- Задание 3: Аэропорты без маршрутов (NOT EXISTS)
SELECT airport_code, city, airport_name
FROM airports a
WHERE NOT EXISTS (
    SELECT 1 FROM routes r
    WHERE r.departure_airport = a.airport_code
       OR r.arrival_airport = a.airport_code
);

-- Задание 4: Сегменты дороже среднего в своём классе
SELECT
    s.ticket_no,
    s.fare_conditions,
    s.price
FROM segments s
WHERE s.price > (
    SELECT avg(price)
    FROM segments s2
    WHERE s2.fare_conditions = s.fare_conditions
)
ORDER BY s.fare_conditions, s.price DESC
LIMIT 20;

-- Задание 5: CTE для статистики по городам
WITH city_route_stats AS (
    SELECT
        a.city,
        count(DISTINCT r.route_no) AS total_routes,
        count(DISTINCT r.departure_airport) AS departure_airports,
        count(DISTINCT r.airplane_code) AS airplane_types
    FROM airports a
    JOIN routes r ON a.airport_code = r.departure_airport
    GROUP BY a.city
)
SELECT *
FROM city_route_stats
ORDER BY total_routes DESC
LIMIT 15;

-- Задание 6: Маршруты из Москвы во Владивосток (до 2 пересадок)
WITH RECURSIVE paths AS (
    SELECT DISTINCT
        dep.city AS origin,
        arr.city AS destination,
        0 AS transfers,
        ARRAY[dep.city, arr.city] AS path
    FROM routes r
    JOIN airports dep ON r.departure_airport = dep.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE dep.city = 'Moscow'

    UNION

    SELECT
        p.origin,
        arr.city,
        p.transfers + 1,
        p.path || arr.city
    FROM paths p
    JOIN airports curr ON curr.city = p.destination
    JOIN routes r ON r.departure_airport = curr.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE p.transfers < 2
      AND NOT arr.city = ANY(p.path)
)
SELECT DISTINCT destination, transfers, path
FROM paths
WHERE destination = 'Yekaterinburg'
ORDER BY destination;

-- ============================================================================
-- Задание 7: VIEW со статистикой маршрутов
CREATE OR REPLACE VIEW v_route_stats_hw AS
SELECT
    r.departure_airport,
    r.arrival_airport,
    count(DISTINCT f.flight_id) AS flights_count,
    sum(s.price) AS revenue
FROM routes r
JOIN flights f ON r.route_no = f.route_no
JOIN segments s ON f.flight_id = s.flight_id
GROUP BY r.departure_airport, r.arrival_airport;

SELECT *
FROM v_route_stats_hw
ORDER BY revenue DESC
LIMIT 20;

-- ============================================================================
-- Задание 8: MATERIALIZED VIEW с дневной выручкой
CREATE MATERIALIZED VIEW mv_daily_revenue_hw AS
SELECT
    book_date::date AS day,
    sum(total_amount) AS revenue
FROM bookings
GROUP BY book_date::date;

CREATE UNIQUE INDEX idx_mv_daily_revenue_hw_day
ON mv_daily_revenue_hw (day);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue_hw;

SELECT *
FROM mv_daily_revenue_hw
ORDER BY day DESC
LIMIT 10;

-- ============================================================================
-- ДОМАШНИЕ ЗАДАНИЯ
-- ============================================================================

-- ДЗ 1: Пассажиры с сегментами дороже 100000
SELECT DISTINCT t.passenger_name
FROM tickets t
WHERE t.ticket_no IN (
    SELECT ticket_no
    FROM segments
    WHERE price > 100000
)
LIMIT 20;

-- ДЗ 2: Рейсы с количеством пассажиров выше среднего
SELECT f.flight_id, f.route_no, count(s.ticket_no) AS passengers
FROM flights f
JOIN segments s ON f.flight_id = s.flight_id
GROUP BY f.flight_id, f.route_no
HAVING count(s.ticket_no) > (
    SELECT avg(pass_count) FROM (
        SELECT count(*) AS pass_count
        FROM segments
        GROUP BY flight_id
    ) t
)
ORDER BY passengers DESC
LIMIT 20;

-- ДЗ 3: Маршруты без отменённых рейсов
SELECT r.route_no, r.departure_airport, r.arrival_airport
FROM routes r
WHERE NOT EXISTS (
    SELECT 1
    FROM flights f
    WHERE f.route_no = r.route_no
      AND f.status = 'Cancelled'
)
LIMIT 20;

-- ДЗ 4: Топ-10 маршрутов по выручке (CTE)
WITH route_revenue AS (
    SELECT
        r.departure_airport,
        r.arrival_airport,
        sum(s.price) AS total_revenue,
        count(DISTINCT f.flight_id) AS flights_count
    FROM routes r
    JOIN flights f ON r.route_no = f.route_no
    JOIN segments s ON f.flight_id = s.flight_id
    GROUP BY r.departure_airport, r.arrival_airport
)
SELECT
    dep.city AS from_city,
    arr.city AS to_city,
    rr.flights_count,
    round(rr.total_revenue / 1000000, 2) AS revenue_mln
FROM route_revenue rr
JOIN airports dep ON rr.departure_airport = dep.airport_code
JOIN airports arr ON rr.arrival_airport = arr.airport_code
ORDER BY rr.total_revenue DESC
LIMIT 10;

-- ДЗ 5: Маршруты Москва → Владивосток (до 3 пересадок)
WITH RECURSIVE routes_search AS (
    SELECT DISTINCT
        arr.city AS current,
        1 AS transfers,
        ARRAY['Москва', arr.city] AS path
    FROM routes r
    JOIN airports dep ON r.departure_airport = dep.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE dep.city = 'Москва'

    UNION

    SELECT DISTINCT
        arr.city,
        rs.transfers + 1,
        rs.path || arr.city
    FROM routes_search rs
    JOIN airports curr ON curr.city = rs.current
    JOIN routes r ON r.departure_airport = curr.airport_code
    JOIN airports arr ON r.arrival_airport = arr.airport_code
    WHERE rs.transfers < 3
      AND NOT arr.city = ANY(rs.path)
)
SELECT transfers, path
FROM routes_search
WHERE current = 'Владивосток'
ORDER BY transfers, path;

