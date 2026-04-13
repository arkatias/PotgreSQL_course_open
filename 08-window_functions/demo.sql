-- =====================================================
-- Пара 8: Оконные функции — полный курс
-- Демонстрационные запросы
-- =====================================================

-- =====================================================
-- 1. ВВЕДЕНИЕ В ОКОННЫЕ ФУНКЦИИ
-- =====================================================

-- Проблема: хотим видеть и детали, и агрегаты
-- Агрегатная функция "схлопывает" строки:
SELECT
    departure_airport,
    count(*) AS flights_count
FROM timetable
GROUP BY departure_airport
ORDER BY flights_count DESC
LIMIT 10;

-- Решение: оконная функция сохраняет все строки
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    count(*) OVER () AS total_flights
FROM timetable
LIMIT 10;

-- =====================================================
-- 2. OVER() БЕЗ ПАРАМЕТРОВ
-- =====================================================

-- Несколько агрегатов одновременно
SELECT
    flight_id,
    departure_airport,
    count(*) OVER () AS total_flights,
    min(scheduled_departure) OVER () AS first_flight,
    max(scheduled_departure) OVER () AS last_flight
FROM timetable
LIMIT 10;

-- =====================================================
-- 3. PARTITION BY — РАЗБИЕНИЕ НА ОКНА
-- =====================================================

-- Подсчёт рейсов для каждого аэропорта отправления
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    count(*) OVER (PARTITION BY departure_airport) AS airport_flights
FROM timetable
ORDER BY departure_airport, scheduled_departure
LIMIT 2000;

-- Несколько колонок в PARTITION BY (группировка по маршруту)
SELECT
    flight_id,
    departure_airport,
    arrival_airport,
    count(*) OVER (
        PARTITION BY departure_airport, arrival_airport
    ) AS route_flights
FROM timetable
ORDER BY departure_airport, arrival_airport, flight_id
LIMIT 20;

-- =====================================================
-- 4. ORDER BY В ОКНЕ (НАКОПИТЕЛЬНЫЕ ЗНАЧЕНИЯ)
-- =====================================================

-- Без ORDER BY: count = общее количество в группе
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    count(*) OVER (PARTITION BY departure_airport) AS total_in_airport
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 10;

-- С ORDER BY: count = накопительное количество (running count)
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    count(*) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS running_count
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 10;

-- =====================================================
-- 5. SUM КАК ОКОННАЯ ФУНКЦИЯ
-- =====================================================

-- Общая сумма по всем билетам
SELECT
    ticket_no,
    flight_id,
    fare_conditions,
    price,
    sum(price) OVER () AS total_revenue
FROM segments
LIMIT 10;

-- Накопительная сумма (Running Total)
SELECT
    book_date::date AS dt,
    total_amount,
    sum(total_amount) OVER (ORDER BY book_date) AS running_total
FROM bookings
ORDER BY book_date
LIMIT 20;

-- Накопительная сумма по дням (с предварительной группировкой)
SELECT
    dt,
    daily_amount,
    sum(daily_amount) OVER (ORDER BY dt) AS running_total
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_amount
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 20;

-- =====================================================
-- 6. AVG КАК ОКОННАЯ ФУНКЦИЯ
-- =====================================================

-- Сравнение со средним: насколько цена отличается от средней по классу
SELECT
    ticket_no,
    fare_conditions,
    price,
    round(avg(price) OVER (PARTITION BY fare_conditions), 2) AS avg_in_class,
    round(price - avg(price) OVER (PARTITION BY fare_conditions), 2) AS diff_from_avg
FROM segments
LIMIT 20;

-- Доля выручки маршрута в аэропорту и в общей
SELECT
    departure_airport,
    arrival_airport,
    route_revenue,
    airport_revenue,
    total_revenue,
    round(100.0 * route_revenue / airport_revenue, 2) AS pct_of_airport,
    round(100.0 * route_revenue / total_revenue, 2) AS pct_of_total
FROM (
    SELECT
        t.departure_airport,
        t.arrival_airport,
        sum(s.price) AS route_revenue,
        sum(sum(s.price)) OVER (PARTITION BY t.departure_airport) AS airport_revenue,
        sum(sum(s.price)) OVER () AS total_revenue
    FROM timetable t
    JOIN segments s ON t.flight_id = s.flight_id
    GROUP BY t.departure_airport, t.arrival_airport
) sub
ORDER BY route_revenue DESC
LIMIT 20;

-- =====================================================
-- 7. ROW_NUMBER()
-- =====================================================

-- Простая нумерация строк
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    row_number() OVER (ORDER BY scheduled_departure) AS rn
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 10;

-- Нумерация с PARTITION BY (сбрасывается для каждой группы)
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    row_number() OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS flight_num_in_airport
FROM timetable
WHERE departure_airport IN ('SVO', 'DME', 'VKO')
ORDER BY departure_airport, scheduled_departure
offset 1750
LIMIT 300;

select count(*) from timetable
where departure_airport = 'DME';

-- =====================================================
-- 8. ТОП-N ЗАПИСЕЙ В КАЖДОЙ ГРУППЕ
-- =====================================================

-- Топ-3 самых дорогих билета для каждого класса обслуживания
WITH ranked AS (
    SELECT
        ticket_no,
        fare_conditions,
        price,
        row_number() OVER (
            PARTITION BY fare_conditions
            ORDER BY price DESC
        ) AS rn
    FROM segments
)
SELECT *
FROM ranked
WHERE rn <= 3
ORDER BY fare_conditions, rn;

-- Топ-5 рейсов с наибольшей выручкой для каждого аэропорта
WITH flight_revenue AS (
    SELECT
        t.flight_id,
        t.departure_airport,
        a.city,
        sum(s.price) AS revenue,
        row_number() OVER (
            PARTITION BY t.departure_airport
            ORDER BY sum(s.price) DESC
        ) AS rn
    FROM timetable t
    JOIN segments s ON t.flight_id = s.flight_id
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY t.flight_id, t.departure_airport, a.city
)
SELECT flight_id, departure_airport, city, revenue, rn
FROM flight_revenue
WHERE rn <= 5
ORDER BY city, rn;

-- =====================================================
-- 9. RANK() и DENSE_RANK()
-- =====================================================

-- Демонстрация разницы между ROW_NUMBER, RANK и DENSE_RANK
WITH revenue_by_class AS (
    SELECT
        fare_conditions,
        round(price, -4) AS price_bucket
    FROM segments
    LIMIT 100
)
SELECT
    fare_conditions,
    price_bucket,
    row_number() OVER (ORDER BY price_bucket DESC) AS row_num,
    rank() OVER (ORDER BY price_bucket DESC) AS rnk,
    dense_rank() OVER (ORDER BY price_bucket DESC) AS dense_rnk
FROM revenue_by_class
ORDER BY price_bucket DESC
LIMIT 20;

-- Ранжирование аэропортов по количеству рейсов
SELECT
    departure_airport,
    city,
    flights_count,
    rank() OVER (ORDER BY flights_count DESC) AS rnk,
    dense_rank() OVER (ORDER BY flights_count DESC) AS dense_rnk
FROM (
    SELECT
        a.airport_code AS departure_airport,
        a.city,
        count(*) AS flights_count
    FROM timetable t
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY a.airport_code, a.city
) sub
ORDER BY flights_count DESC
LIMIT 20;

-- =====================================================
-- 10. НЕСКОЛЬКО ОКОННЫХ ФУНКЦИЙ В ОДНОМ ЗАПРОСЕ
-- =====================================================

-- Полная статистика по аэропортам
SELECT
    departure_airport,
    city,
    flights_count,
    row_number() OVER (ORDER BY flights_count DESC) AS position,
    sum(flights_count) OVER () AS total,
    round(100.0 * flights_count / sum(flights_count) OVER (), 2) AS percentage,
    sum(flights_count) OVER (ORDER BY flights_count DESC) AS running_total
FROM (
    SELECT
        a.airport_code AS departure_airport,
        a.city,
        count(*) AS flights_count
    FROM timetable t
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY a.airport_code, a.city
) sub
ORDER BY flights_count DESC
LIMIT 15;

-- =====================================================
-- 11. ИМЕНОВАННЫЕ ОКНА (WINDOW)
-- =====================================================

-- С именованным окном (чище и понятнее)
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    count(*) OVER w AS running_count,
    sum(1) OVER w AS running_sum,
    min(scheduled_departure) OVER w AS first_flight
FROM timetable
WHERE departure_airport = 'SVO'
WINDOW w AS (PARTITION BY departure_airport ORDER BY scheduled_departure)
ORDER BY scheduled_departure
LIMIT 10;

-- Несколько именованных окон
SELECT
    flight_id,
    departure_airport,
    arrival_airport,
    count(*) OVER by_departure AS dep_count,
    count(*) OVER by_arrival AS arr_count,
    count(*) OVER () AS total_count
FROM timetable
WINDOW
    by_departure AS (PARTITION BY departure_airport),
    by_arrival AS (PARTITION BY arrival_airport)
LIMIT 20;

-- =====================================================
-- 12. ОКОННЫЕ ФУНКЦИИ И ПОРЯДОК ВЫПОЛНЕНИЯ
-- =====================================================

-- Ошибка: нельзя фильтровать по оконной функции в WHERE
 SELECT *, row_number() OVER (ORDER BY price) AS rn
 FROM segments
 WHERE rn <= 10;  -- ERROR!

-- Правильно: через CTE
WITH ranked AS (
    SELECT
        ticket_no,
        flight_id,
        price,
        row_number() OVER (ORDER BY price DESC) AS rn
    FROM segments
)
SELECT *
FROM ranked
WHERE rn <= 10;

-- =====================================================
-- 13. LAG() — ПРЕДЫДУЩЕЕ ЗНАЧЕНИЕ
-- =====================================================

-- Базовый пример LAG
SELECT
    book_date::date AS dt,
    total_amount,
    lag(total_amount) OVER (ORDER BY book_date) AS prev_amount
FROM bookings
ORDER BY book_date
LIMIT 15;

-- LAG с указанием смещения
SELECT
    book_date::date AS dt,
    total_amount,
    lag(total_amount, 1) OVER (ORDER BY book_date) AS prev_1,
    lag(total_amount, 2) OVER (ORDER BY book_date) AS prev_2,
    lag(total_amount, 3) OVER (ORDER BY book_date) AS prev_3
FROM bookings
ORDER BY book_date
LIMIT 15;

-- LAG с PARTITION BY
SELECT
    fare_conditions,
    ticket_no,
    price,
    lag(price) OVER (
        PARTITION BY fare_conditions
        ORDER BY price
    ) AS prev_in_class
FROM segments
ORDER BY fare_conditions, price
LIMIT 20;

-- =====================================================
-- 14. LEAD() — СЛЕДУЮЩЕЕ ЗНАЧЕНИЕ
-- =====================================================

-- Базовый пример LEAD
SELECT
    book_date::date AS dt,
    total_amount,
    lead(total_amount) OVER (ORDER BY book_date) AS next_amount
FROM bookings
ORDER BY book_date
LIMIT 15;

-- Время между рейсами
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    lead(scheduled_departure) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS next_flight,
    lead(scheduled_departure) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) - scheduled_departure AS time_to_next
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 15;

-- =====================================================
-- 15. ВЫЧИСЛЕНИЕ ИЗМЕНЕНИЙ (CHANGE)
-- =====================================================

-- Изменение выручки по дням
SELECT
    dt,
    daily_revenue,
    lag(daily_revenue) OVER (ORDER BY dt) AS prev_revenue,
    daily_revenue - lag(daily_revenue) OVER (ORDER BY dt) AS change_abs,
    round(100.0 * (daily_revenue - lag(daily_revenue) OVER (ORDER BY dt))
          / lag(daily_revenue) OVER (ORDER BY dt), 2) AS change_pct
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 20;

-- Month-over-Month сравнение
SELECT
    booking_month,
    monthly_revenue,
    lag(monthly_revenue) OVER (ORDER BY booking_month) AS prev_month,
    monthly_revenue - lag(monthly_revenue) OVER (ORDER BY booking_month) AS mom_change,
    round(100.0 * (monthly_revenue - lag(monthly_revenue) OVER (ORDER BY booking_month))
          / nullif(lag(monthly_revenue) OVER (ORDER BY booking_month), 0), 2) AS mom_pct
FROM (
    SELECT
        date_trunc('month', book_date)::date AS booking_month,
        sum(total_amount) AS monthly_revenue
    FROM bookings
    GROUP BY date_trunc('month', book_date)
) monthly
ORDER BY booking_month;

-- =====================================================
-- 16. FIRST_VALUE, LAST_VALUE, NTH_VALUE
-- =====================================================

-- FIRST_VALUE — первый рейс из каждого аэропорта
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    first_value(flight_id) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS first_flight_id,
    first_value(scheduled_departure) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS first_flight_time
FROM timetable
WHERE departure_airport IN ('SVO', 'LED', 'DME')
ORDER BY departure_airport, scheduled_departure
LIMIT 20;

-- LAST_VALUE — проблема с рамкой по умолчанию
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    last_value(flight_id) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS last_flight_wrong  -- это будет текущая строка!
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 10;

-- LAST_VALUE — правильно с явной рамкой
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    last_value(flight_id) OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_flight_correct
FROM timetable
WHERE departure_airport = 'SVO'
ORDER BY scheduled_departure
LIMIT 10;

-- NTH_VALUE — N-ное значение
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    nth_value(scheduled_departure, 1) OVER w AS flight_1,
    nth_value(scheduled_departure, 5) OVER w AS flight_5,
    nth_value(scheduled_departure, 10) OVER w AS flight_10
FROM timetable
WHERE departure_airport = 'SVO'
WINDOW w AS (
    PARTITION BY departure_airport
    ORDER BY scheduled_departure
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY scheduled_departure
LIMIT 15;

-- =====================================================
-- 17. РАМКИ ОКОН (WINDOW FRAMES)
-- =====================================================

-- Демонстрация разницы ROWS vs RANGE
WITH sample_data AS (
    SELECT generate_series AS id,
           (generate_series % 3 + 1) * 10 AS value
    FROM generate_series(1, 12)
)
SELECT
    id,
    value,
    sum(value) OVER (ORDER BY value ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS rows_sum,
    sum(value) OVER (ORDER BY value RANGE BETWEEN CURRENT ROW AND CURRENT ROW) AS range_sum
FROM sample_data
ORDER BY value, id;

-- Разные варианты рамок
SELECT
    dt,
    daily_revenue,
    sum(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    sum(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS last_3_days
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 15;

-- =====================================================
-- 18. СКОЛЬЗЯЩЕЕ СРЕДНЕЕ (MOVING AVERAGE)
-- =====================================================

-- 7-дневное скользящее среднее выручки
SELECT
    dt,
    daily_revenue,
    round(avg(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS ma_7d
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 30;

-- Центрированное скользящее среднее
SELECT
    dt,
    daily_revenue,
    round(avg(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
    ), 2) AS centered_ma_7d
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 30;

-- Скользящие минимум и максимум за 7 дней
SELECT
    dt,
    daily_revenue,
    min(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS min_7d,
    max(daily_revenue) OVER (
        ORDER BY dt
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS max_7d
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt
LIMIT 20;

-- =====================================================
-- 19. NTILE — РАЗБИЕНИЕ НА ГРУППЫ
-- =====================================================

-- Разбиение пассажиров на квартили по сумме трат
SELECT
    passenger_name,
    total_spent,
    ntile(4) OVER (ORDER BY total_spent DESC) AS quartile
FROM (
    SELECT
        t.passenger_name,
        sum(s.price) AS total_spent
    FROM tickets t
    JOIN segments s ON t.ticket_no = s.ticket_no
    GROUP BY t.passenger_name
    limit 16
) spending
ORDER BY total_spent DESC
LIMIT 30;

-- Сегментация маршрутов по выручке на 3 группы
SELECT
    departure_airport,
    arrival_airport,
    revenue,
    CASE ntile(3) OVER (ORDER BY revenue DESC)
        WHEN 1 THEN 'Высокодоходные'
        WHEN 2 THEN 'Среднедоходные'
        WHEN 3 THEN 'Низкодоходные'
    END AS segment_name
FROM (
    SELECT
        t.departure_airport,
        t.arrival_airport,
        sum(s.price) AS revenue
    FROM timetable t
    JOIN segments s ON t.flight_id = s.flight_id
    GROUP BY t.departure_airport, t.arrival_airport
    limit 22
) route_revenue
ORDER BY revenue DESC;

-- Децили (10 групп)
SELECT
    departure_airport,
    city,
    flights_count,
    ntile(10) OVER (ORDER BY flights_count DESC) AS decile
FROM (
    SELECT
        a.airport_code AS departure_airport,
        a.city,
        count(*) AS flights_count
    FROM timetable t
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY a.airport_code, a.city
) sub
ORDER BY flights_count DESC;

-- =====================================================
-- 20. PERCENT_RANK И CUME_DIST
-- =====================================================

-- Сравнение PERCENT_RANK и CUME_DIST
SELECT
    departure_airport,
    city,
    flights_count,
    round(percent_rank() OVER (ORDER BY flights_count)::numeric, 4) AS pct_rank,
    round(cume_dist() OVER (ORDER BY flights_count)::numeric, 4) AS cume_dist
FROM (
    SELECT
        a.airport_code AS departure_airport,
        a.city,
        count(*) AS flights_count
    FROM timetable t
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY a.airport_code, a.city
) sub
ORDER BY flights_count DESC
LIMIT 20;

-- =====================================================
-- 21. СЛОЖНЫЕ ПРИМЕРЫ
-- =====================================================

-- Отклонение от скользящего среднего
SELECT
    dt,
    daily_revenue,
    ma_7d,
    daily_revenue - ma_7d AS deviation,
    round(100.0 * (daily_revenue - ma_7d) / ma_7d, 2) AS deviation_pct
FROM (
    SELECT
        dt,
        daily_revenue,
        round(avg(daily_revenue) OVER (
            ORDER BY dt
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS ma_7d
    FROM (
        SELECT
            book_date::date AS dt,
            sum(total_amount) AS daily_revenue
        FROM bookings
        GROUP BY book_date::date
    ) daily
) with_ma
ORDER BY dt
LIMIT 30;

-- Рейсы с большим интервалом до следующего
SELECT
    flight_id,
    departure_airport,
    arrival_airport,
    scheduled_departure,
    next_flight_time,
    hours_to_next
FROM (
    SELECT
        flight_id,
        departure_airport,
        arrival_airport,
        scheduled_departure,
        lead(scheduled_departure) OVER (
            PARTITION BY departure_airport, arrival_airport
            ORDER BY scheduled_departure
        ) AS next_flight_time,
        extract(epoch FROM (
            lead(scheduled_departure) OVER (
                PARTITION BY departure_airport, arrival_airport
                ORDER BY scheduled_departure
            ) - scheduled_departure
        )) / 3600 AS hours_to_next
    FROM timetable
) sub
WHERE hours_to_next > 24
ORDER BY hours_to_next DESC
LIMIT 20;

-- Разница между текущим и лучшим результатом в партиции
SELECT
    departure_airport,
    arrival_airport,
    revenue,
    first_value(revenue) OVER (
        PARTITION BY departure_airport
        ORDER BY revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS best_route_revenue,
    revenue - first_value(revenue) OVER (
        PARTITION BY departure_airport
        ORDER BY revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS diff_from_best
FROM (
    SELECT
        t.departure_airport,
        t.arrival_airport,
        sum(s.price) AS revenue
    FROM timetable t
    JOIN segments s ON t.flight_id = s.flight_id
    GROUP BY t.departure_airport, t.arrival_airport
) route_revenue
ORDER BY departure_airport, revenue DESC
LIMIT 30;

-- =====================================================
-- УПРАЖНЕНИЯ ДЛЯ САМОСТОЯТЕЛЬНОЙ РАБОТЫ
-- =====================================================

-- Упражнение 1: Найти для каждого рейса его порядковый номер
-- в расписании аэропорта отправления

-- Упражнение 2: Вычислить долю каждого класса обслуживания
-- в общей выручке

-- Упражнение 3: Найти топ-3 самых загруженных дня
-- для каждого аэропорта

-- Упражнение 4: Определить, какой рейс принёс больше всего
-- выручки для каждого направления

-- Упражнение 5: Посчитать накопительное количество бронирований
-- по месяцам

-- Упражнение 6: Для каждого дня вычислить отклонение выручки
-- от 7-дневного среднего

-- Упражнение 7: Найти рейсы, у которых следующий рейс
-- по тому же маршруту более чем через 24 часа

-- Упражнение 8: Разбить аэропорты на децили
-- по количеству рейсов

-- =====================================================
-- РЕШЕНИЯ УПРАЖНЕНИЙ
-- =====================================================

-- Решение 1
SELECT
    flight_id,
    departure_airport,
    scheduled_departure,
    row_number() OVER (
        PARTITION BY departure_airport
        ORDER BY scheduled_departure
    ) AS schedule_position
FROM timetable
ORDER BY departure_airport, scheduled_departure
LIMIT 30;

-- Решение 2
SELECT DISTINCT
    fare_conditions,
    sum(price) OVER (PARTITION BY fare_conditions) AS class_revenue,
    sum(price) OVER () AS total_revenue,
    round(100.0 * sum(price) OVER (PARTITION BY fare_conditions) /
          sum(price) OVER (), 2) AS pct_of_total
FROM segments;

-- Решение 3
WITH daily_flights AS (
    SELECT
        departure_airport,
        scheduled_departure::date AS flight_date,
        count(*) AS flights_count,
        row_number() OVER (
            PARTITION BY departure_airport
            ORDER BY count(*) DESC
        ) AS rn
    FROM timetable
    GROUP BY departure_airport, scheduled_departure::date
)
SELECT *
FROM daily_flights
WHERE rn <= 3
ORDER BY departure_airport, rn;

-- Решение 4
WITH flight_revenue AS (
    SELECT
        t.flight_id,
        t.departure_airport,
        t.arrival_airport,
        sum(s.price) AS revenue,
        row_number() OVER (
            PARTITION BY t.departure_airport, t.arrival_airport
            ORDER BY sum(s.price) DESC
        ) AS rn
    FROM timetable t
    JOIN segments s ON t.flight_id = s.flight_id
    GROUP BY t.flight_id, t.departure_airport, t.arrival_airport
)
SELECT
    flight_id,
    departure_airport,
    arrival_airport,
    revenue
FROM flight_revenue
WHERE rn = 1
ORDER BY revenue DESC
LIMIT 20;

-- Решение 5
SELECT
    booking_month,
    monthly_bookings,
    sum(monthly_bookings) OVER (ORDER BY booking_month) AS cumulative_bookings
FROM (
    SELECT
        date_trunc('month', book_date)::date AS booking_month,
        count(*) AS monthly_bookings
    FROM bookings
    GROUP BY date_trunc('month', book_date)
) monthly
ORDER BY booking_month;

-- Решение 6
SELECT
    dt,
    daily_revenue,
    ma_7d,
    daily_revenue - ma_7d AS deviation,
    round(100.0 * (daily_revenue - ma_7d) / ma_7d, 2) AS deviation_pct
FROM (
    SELECT
        book_date::date AS dt,
        sum(total_amount) AS daily_revenue,
        round(avg(sum(total_amount)) OVER (
            ORDER BY book_date::date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS ma_7d
    FROM bookings
    GROUP BY book_date::date
) daily
ORDER BY dt;

-- Решение 7
SELECT
    flight_id,
    departure_airport,
    arrival_airport,
    scheduled_departure,
    next_scheduled,
    hours_gap
FROM (
    SELECT
        flight_id,
        departure_airport,
        arrival_airport,
        scheduled_departure,
        lead(scheduled_departure) OVER (
            PARTITION BY departure_airport, arrival_airport
            ORDER BY scheduled_departure
        ) AS next_scheduled,
        extract(epoch FROM lead(scheduled_departure) OVER (
            PARTITION BY departure_airport, arrival_airport
            ORDER BY scheduled_departure
        ) - scheduled_departure) / 3600 AS hours_gap
    FROM timetable
) sub
WHERE hours_gap > 24
ORDER BY hours_gap DESC;

-- Решение 8
SELECT
    departure_airport,
    city,
    flights_count,
    ntile(10) OVER (ORDER BY flights_count DESC) AS decile
FROM (
    SELECT
        a.airport_code AS departure_airport,
        a.city,
        count(*) AS flights_count
    FROM timetable t
    JOIN airports a ON t.departure_airport = a.airport_code
    GROUP BY a.airport_code, a.city
) airport_stats
ORDER BY decile, flights_count DESC;
