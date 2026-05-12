-- =====================================================
-- Пара 11: DDL, DML и временные таблицы
-- Демонстрационные запросы
-- =====================================================

-- =====================================================
-- 1. DDL — DATA DEFINITION LANGUAGE
-- =====================================================

-- DDL управляет структурой объектов базы данных:
-- CREATE, ALTER, DROP, TRUNCATE

-- На время демонстрации используем отдельную таблицу-песочницу
DROP TABLE IF EXISTS public.dml_playground;
CREATE TABLE public.dml_playground (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        text NOT NULL UNIQUE,
    title       text NOT NULL,
    amount      numeric(10, 2) NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);

select * from public.dml_playground;

-- Проверим структуру созданной таблицы
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'dml_playground'
ORDER BY ordinal_position;

-- ALTER TABLE — меняем структуру таблицы
ALTER TABLE public.dml_playground
ADD COLUMN status text NOT NULL DEFAULT 'new';

ALTER TABLE public.dml_playground
ADD COLUMN note text;

-- Проверка после ALTER
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'dml_playground'
ORDER BY ordinal_position;

-- TRUNCATE — быстрая очистка таблицы
TRUNCATE TABLE public.dml_playground;

-- =====================================================
-- 2. DML — DATA MANIPULATION LANGUAGE
-- =====================================================

-- INSERT — вставка одной строки
INSERT INTO public.dml_playground (code, title, amount)
VALUES ('ROW001', 'Первая запись', 1000);

SELECT * FROM public.dml_playground;

-- INSERT — вставка нескольких строк
INSERT INTO public.dml_playground (code, title, amount, status)
VALUES
    ('ROW002', 'Вторая запись', 1500, 'draft'),
    ('ROW003', 'Третья запись', 2200, 'draft'),
    ('ROW004', 'Четвёртая запись', 800, 'approved');

SELECT * FROM public.dml_playground ORDER BY id;

-- INSERT ... SELECT — загрузка данных из запроса
INSERT INTO public.dml_playground (code, title, amount, status, note)
SELECT
    'FLT-' || flight_id,
    route_no,
    0,
    'imported',
    status
FROM flights
ORDER BY flight_id
LIMIT 5;

SELECT * FROM public.dml_playground ORDER BY id;

-- UPDATE — изменение строк
UPDATE public.dml_playground
SET amount = amount * 1.1
WHERE status = 'draft';

-- UPDATE с вычислением и условием
UPDATE public.dml_playground
SET
    status = 'review',
    note = 'Обновлено на демонстрации'
WHERE amount >= 1500
  AND status IN ('draft', 'imported');

SELECT * FROM public.dml_playground ORDER BY id;

-- DELETE — удаление строк
DELETE FROM public.dml_playground
WHERE status = 'new';

SELECT * FROM public.dml_playground ORDER BY id;

-- RETURNING — получаем результат DML сразу
INSERT INTO public.dml_playground (code, title, amount, status)
VALUES ('ROW999', 'Запись с RETURNING', 9999, 'final')
RETURNING id, code, status, amount;

UPDATE public.dml_playground
SET amount = amount + 500
WHERE code = 'ROW999'
RETURNING id, code, amount;

DELETE FROM public.dml_playground
WHERE code = 'ROW999'
RETURNING id, code, status;

-- =====================================================
-- 3. ВРЕМЕННЫЕ ТАБЛИЦЫ
-- =====================================================

-- TEMP TABLE живёт только в рамках текущей сессии
DROP TABLE IF EXISTS temp_route_stats;

CREATE TEMP TABLE temp_route_stats (
    route_no         text,
    flights_count    integer,
    cancelled_count  integer,
    total_revenue    numeric(12, 2)
);

-- Наполняем временную таблицу агрегатами
INSERT INTO temp_route_stats
SELECT
    t.route_no,
    count(*) AS flights_count,
    count(*) FILTER (WHERE t.status = 'Cancelled') AS cancelled_count,
    COALESCE(sum(s.price), 0) AS total_revenue
FROM timetable t
LEFT JOIN segments s ON s.flight_id = t.flight_id
GROUP BY t.route_no
ORDER BY total_revenue DESC
LIMIT 20;

SELECT *
FROM temp_route_stats
ORDER BY total_revenue DESC, route_no;

-- Временная таблица может быть создана сразу из SELECT
DROP TABLE IF EXISTS temp_cancelled_flights;

CREATE TEMP TABLE temp_cancelled_flights AS
SELECT
    t.flight_id,
    t.route_no,
    dep.city AS departure_city,
    arr.city AS arrival_city,
    t.scheduled_departure
FROM timetable t
JOIN airports dep ON dep.airport_code = t.departure_airport
JOIN airports arr ON arr.airport_code = t.arrival_airport
WHERE t.status = 'Cancelled';

SELECT count(*) AS cancelled_flights_count
FROM temp_cancelled_flights;

-- На TEMP TABLE можно создавать индексы
CREATE INDEX ON temp_cancelled_flights (route_no);

-- ON COMMIT DELETE ROWS — структура остаётся, строки очищаются
DROP TABLE IF EXISTS temp_session_buffer;

CREATE TEMP TABLE temp_session_buffer (
    id      integer GENERATED ALWAYS AS IDENTITY,
    payload text
) ON COMMIT DELETE ROWS;

BEGIN;

INSERT INTO temp_session_buffer (payload)
VALUES ('one'), ('two'), ('three');

SELECT count(*) AS rows_inside_tx
FROM temp_session_buffer;

COMMIT;

SELECT count(*) AS rows_after_commit
FROM temp_session_buffer;

-- =====================================================
-- 4. ПРАКТИКА: ПОВТОРЯЕМ DDL И DML НА ВРЕМЕННЫХ ТАБЛИЦАХ
-- =====================================================

-- В практике берём знакомую структуру из учебной БД:
-- bookings -> tickets -> segments

-- Подготовка: создаём временные копии таблиц
DROP TABLE IF EXISTS temp_bookings_work;
DROP TABLE IF EXISTS temp_tickets_work;
DROP TABLE IF EXISTS temp_segments_work;

CREATE TEMP TABLE temp_bookings_work
    (LIKE bookings INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

CREATE TEMP TABLE temp_tickets_work
    (LIKE tickets INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

CREATE TEMP TABLE temp_segments_work
    (LIKE segments INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

select * from temp_bookings_work;

-- Загружаем небольшой набор данных для тренировки
INSERT INTO temp_bookings_work
SELECT *
FROM bookings
ORDER BY book_date DESC
LIMIT 20;



INSERT INTO temp_tickets_work
SELECT t.*
FROM tickets t
JOIN temp_bookings_work b ON b.book_ref = t.book_ref;

INSERT INTO temp_segments_work
SELECT s.*
FROM segments s
JOIN temp_tickets_work t ON t.ticket_no = s.ticket_no;

-- Проверка объёма временного набора
SELECT 'temp_bookings_work' AS table_name, count(*) AS row_count FROM temp_bookings_work
UNION ALL
SELECT 'temp_tickets_work', count(*) FROM temp_tickets_work
UNION ALL
SELECT 'temp_segments_work', count(*) FROM temp_segments_work;

-- -----------------------------------------------------
-- Практика 1. DDL на временной таблице
-- -----------------------------------------------------

ALTER TABLE temp_bookings_work
ADD COLUMN lesson_tag text NOT NULL DEFAULT 'lesson-10';

SELECT book_ref, total_amount, lesson_tag
FROM temp_bookings_work
ORDER BY book_date DESC
LIMIT 5;

-- -----------------------------------------------------
-- Практика 2. INSERT во временную таблицу
-- -----------------------------------------------------

INSERT INTO temp_bookings_work (book_ref, book_date, total_amount, lesson_tag)
VALUES ('TMP001', now(), 12345, 'manual-insert')
RETURNING *;

-- -----------------------------------------------------
-- Практика 3. UPDATE во временной таблице
-- -----------------------------------------------------

UPDATE temp_bookings_work
SET total_amount = total_amount * 1.05
WHERE total_amount < 50000
RETURNING book_ref, total_amount;

-- -----------------------------------------------------
-- Практика 4. DELETE во временной таблице
-- -----------------------------------------------------

DELETE FROM temp_bookings_work
WHERE book_ref = 'TMP001'
RETURNING book_ref, total_amount;

-- -----------------------------------------------------
-- Практика 5. Временная аналитическая таблица
-- -----------------------------------------------------

DROP TABLE IF EXISTS temp_booking_summary;

CREATE TEMP TABLE temp_booking_summary AS
SELECT
    b.book_ref,
    b.book_date,
    b.total_amount,
    count(DISTINCT t.ticket_no) AS tickets_count,
    count(s.flight_id) AS segments_count,
    COALESCE(sum(s.price), 0) AS segments_total
FROM temp_bookings_work b
LEFT JOIN temp_tickets_work t ON t.book_ref = b.book_ref
LEFT JOIN temp_segments_work s ON s.ticket_no = t.ticket_no
GROUP BY b.book_ref, b.book_date, b.total_amount;

SELECT *
FROM temp_booking_summary
ORDER BY segments_total DESC, total_amount DESC
LIMIT 10;

-- -----------------------------------------------------
-- Практика 6. TRUNCATE временной таблицы
-- -----------------------------------------------------

SELECT count(*) AS before_truncate
FROM temp_booking_summary;

TRUNCATE TABLE temp_booking_summary;

SELECT count(*) AS after_truncate
FROM temp_booking_summary;

-- =====================================================
-- ОЧИСТКА ПОСТОЯННОЙ DEMO-ТАБЛИЦЫ
-- =====================================================

DROP TABLE IF EXISTS public.dml_playground;


WITH ranked_segments AS (
    SELECT
        s.ticket_no,
        s.flight_id,
        s.fare_conditions,
        s.price,
        row_number() OVER (
            PARTITION BY s.fare_conditions
            ORDER BY s.price DESC, s.ticket_no
        ) AS price_rank
        --avg(s.price) OVER (PARTITION BY s.fare_conditions) AS class_avg_price
    FROM segments s
    limit 500
)
SELECT
    ticket_no,
    flight_id,
    fare_conditions,
    price,
    price_rank,
    round(class_avg_price, 2) AS class_avg_price,
    round(price - class_avg_price, 2) AS diff_from_class_avg
FROM ranked_segments
WHERE price_rank <= 3
ORDER BY fare_conditions, price_rank;