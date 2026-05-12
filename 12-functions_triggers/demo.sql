-- =====================================================
-- Пара 14: Функции и триггеры в PostgreSQL
-- Демонстрационные запросы
-- =====================================================

-- Блоки по VIEW и MATERIALIZED VIEW перенесены в урок 08
-- (подзапросы, CTE и VIEW).

-- =====================================================
-- 1. ФУНКЦИИ НА SQL
-- =====================================================

-- Простая функция
CREATE OR REPLACE FUNCTION get_airport_city(p_code CHAR(3))
RETURNS TEXT AS $$
    SELECT city FROM airports WHERE airport_code = p_code;
$$ LANGUAGE SQL STABLE;

-- Использование
SELECT get_airport_city('SVO');
SELECT route_no, get_airport_city(departure_airport) FROM timetable LIMIT 5;

-- Функция с несколькими параметрами
CREATE OR REPLACE FUNCTION format_route(p_dep CHAR(3), p_arr CHAR(3))
RETURNS TEXT AS $$
    SELECT get_airport_city(p_dep) || ' → ' || get_airport_city(p_arr);
$$ LANGUAGE SQL STABLE;

SELECT format_route('SVO', 'LED');

-- =====================================================
-- 2. ФУНКЦИИ PL/pgSQL — БАЗОВЫЕ
-- =====================================================

-- Функция с логикой
CREATE OR REPLACE FUNCTION get_flight_status_description(p_status TEXT)
RETURNS TEXT AS $$
BEGIN
    CASE p_status
        WHEN 'Scheduled' THEN RETURN 'Рейс запланирован';
        WHEN 'On Time' THEN RETURN 'Рейс вовремя';
        WHEN 'Delayed' THEN RETURN 'Рейс задержан';
        WHEN 'Departed' THEN RETURN 'Рейс вылетел';
        WHEN 'Arrived' THEN RETURN 'Рейс прибыл';
        WHEN 'Cancelled' THEN RETURN 'Рейс отменён';
        ELSE RETURN 'Неизвестный статус';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT
    status,
    get_flight_status_description(status) AS description,
    count(*)
FROM flights
GROUP BY status;

-- =====================================================
-- 3. ФУНКЦИИ С ПЕРЕМЕННЫМИ
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_flight_revenue(p_flight_id INTEGER)
RETURNS NUMERIC AS $$
DECLARE
    v_total_revenue NUMERIC;
    v_ticket_count INTEGER;
BEGIN
    -- Получаем общую выручку и количество билетов
    SELECT
        COALESCE(sum(price), 0),
        count(*)
    INTO v_total_revenue, v_ticket_count
    FROM segments
    WHERE flight_id = p_flight_id;

    -- Логирование (для отладки)
    RAISE NOTICE 'Flight %: % tickets, revenue %',
        p_flight_id, v_ticket_count, v_total_revenue;

    RETURN v_total_revenue;
END;
$$ LANGUAGE plpgsql STABLE;

-- Использование
SELECT calculate_flight_revenue(1);

-- В запросе
SELECT
    flight_id,
    route_no,
    calculate_flight_revenue(flight_id) AS revenue
FROM flights
WHERE flight_id <= 10;

-- =====================================================
-- 4. ФУНКЦИИ С УСЛОВИЯМИ
-- =====================================================

CREATE OR REPLACE FUNCTION get_fare_category(p_amount NUMERIC)
RETURNS TEXT AS $$
BEGIN
    IF p_amount IS NULL THEN
        RETURN 'Unknown';
    ELSIF p_amount >= 100000 THEN
        RETURN 'Premium';
    ELSIF p_amount >= 50000 THEN
        RETURN 'Business';
    ELSIF p_amount >= 20000 THEN
        RETURN 'Comfort';
    ELSE
        RETURN 'Economy';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Статистика по категориям
SELECT
    get_fare_category(price) AS category,
    count(*) AS ticket_count,
    round(avg(price), 2) AS avg_amount
FROM segments
GROUP BY get_fare_category(price)
ORDER BY avg_amount DESC;

-- =====================================================
-- 5. ФУНКЦИИ ВОЗВРАЩАЮЩИЕ ТАБЛИЦУ
-- =====================================================

-- RETURNS TABLE
CREATE OR REPLACE FUNCTION get_flights_between_cities(
    p_from_city TEXT,
    p_to_city TEXT
)
RETURNS TABLE (
    route_no        TEXT,
    departure_time  TIMESTAMPTZ,
    arrival_time    TIMESTAMPTZ,
    status          TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.route_no,
        t.scheduled_departure,
        t.scheduled_arrival,
        t.status
    FROM timetable t
    JOIN airports dep ON t.departure_airport = dep.airport_code
    JOIN airports arr ON t.arrival_airport = arr.airport_code
    WHERE dep.city = p_from_city
      AND arr.city = p_to_city
    ORDER BY t.scheduled_departure;
END;
$$ LANGUAGE plpgsql STABLE;

-- Использование
SELECT * FROM get_flights_between_cities('Москва', 'Санкт-Петербург')
LIMIT 10;

-- =====================================================
-- 6. RETURNS SETOF
-- =====================================================

-- Возвращает множество строк существующего типа
CREATE OR REPLACE FUNCTION get_airports_in_city(p_city TEXT)
RETURNS SETOF airports AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM airports
    WHERE city = p_city;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT * FROM get_airports_in_city('Москва');

-- =====================================================
-- 7. OUT ПАРАМЕТРЫ
-- =====================================================

CREATE OR REPLACE FUNCTION get_flight_stats(
    p_flight_id INTEGER,
    OUT o_ticket_count INTEGER,
    OUT o_total_revenue NUMERIC,
    OUT o_avg_price NUMERIC
) AS $$
BEGIN
    SELECT
        count(*),
        sum(price),
        round(avg(price), 2)
    INTO o_ticket_count, o_total_revenue, o_avg_price
    FROM segments
    WHERE flight_id = p_flight_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Использование
SELECT * FROM get_flight_stats(1);

-- Можно обращаться к отдельным полям
SELECT (get_flight_stats(1)).o_total_revenue;

-- =====================================================
-- 8. ПАРАМЕТРЫ ПО УМОЛЧАНИЮ
-- =====================================================

CREATE OR REPLACE FUNCTION search_flights(
    p_from_city TEXT,
    p_to_city TEXT DEFAULT NULL,
    p_date DATE DEFAULT CURRENT_DATE,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    route_no    TEXT,
    from_city   TEXT,
    to_city     TEXT,
    departure   TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.route_no,
        dep.city,
        arr.city,
        t.scheduled_departure
    FROM timetable t
    JOIN airports dep ON t.departure_airport = dep.airport_code
    JOIN airports arr ON t.arrival_airport = arr.airport_code
    WHERE dep.city = p_from_city
      AND (p_to_city IS NULL OR arr.city = p_to_city)
      AND t.scheduled_departure::date = p_date
    ORDER BY t.scheduled_departure
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Разные варианты вызова
SELECT * FROM search_flights('Москва');
SELECT * FROM search_flights('Москва', 'Сочи');
SELECT * FROM search_flights('Москва', NULL, '2017-08-15');
SELECT * FROM search_flights(p_from_city := 'Москва', p_limit := 5);

-- =====================================================
-- 9. ТРИГГЕРЫ — СОЗДАНИЕ
-- =====================================================

-- Таблица для аудита
CREATE TABLE IF NOT EXISTS booking_audit (
    audit_id SERIAL PRIMARY KEY,
    book_ref CHAR(6),
    action TEXT,
    old_amount NUMERIC(10,2),
    new_amount NUMERIC(10,2),
    changed_by TEXT DEFAULT current_user,
    changed_at TIMESTAMP DEFAULT now()
);

-- Функция триггера
CREATE OR REPLACE FUNCTION fn_audit_bookings()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO booking_audit (book_ref, action, new_amount)
        VALUES (NEW.book_ref, 'INSERT', NEW.total_amount);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO booking_audit (book_ref, action, old_amount, new_amount)
        VALUES (NEW.book_ref, 'UPDATE', OLD.total_amount, NEW.total_amount);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO booking_audit (book_ref, action, old_amount)
        VALUES (OLD.book_ref, 'DELETE', OLD.total_amount);
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера
CREATE TRIGGER tr_audit_bookings
AFTER INSERT OR UPDATE OR DELETE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_audit_bookings();

-- =====================================================
-- 10. ТРИГГЕРЫ — ТЕСТИРОВАНИЕ
-- =====================================================

-- Создадим тестовое бронирование
INSERT INTO bookings (book_ref, book_date, total_amount)
VALUES ('TSTAUD', now(), 10000);

-- Обновим
UPDATE bookings SET total_amount = 15000 WHERE book_ref = 'TSTAUD';

-- Проверим аудит
SELECT * FROM booking_audit WHERE book_ref = 'TSTAUD';

-- Удалим
DELETE FROM bookings WHERE book_ref = 'TSTAUD';

-- Проверим аудит снова
SELECT * FROM booking_audit WHERE book_ref = 'TSTAUD';

-- =====================================================
-- 11. ТРИГГЕР BEFORE — ВАЛИДАЦИЯ
-- =====================================================

CREATE OR REPLACE FUNCTION fn_validate_booking()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка суммы
    IF NEW.total_amount < 0 THEN
        RAISE EXCEPTION 'Сумма бронирования не может быть отрицательной';
    END IF;

    -- Автоматическая установка даты
    IF NEW.book_date IS NULL THEN
        NEW.book_date := now();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_validate_booking
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_validate_booking();

-- Тест — это вызовет ошибку
-- INSERT INTO bookings (book_ref, book_date, total_amount)
-- VALUES ('TSTERR', now(), -100);

-- =====================================================
-- 12. УПРАЖНЕНИЯ
-- =====================================================

-- Упражнение 1: Написать функцию подсчёта рейсов между городами

-- Упражнение 2: Написать функцию поиска пересадочных маршрутов

-- =====================================================
-- РЕШЕНИЯ
-- =====================================================

-- Решение 1: Функция подсчёта рейсов
CREATE OR REPLACE FUNCTION count_flights_between(p_city1 TEXT, p_city2 TEXT)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*)
    INTO v_count
    FROM timetable t
    JOIN airports dep ON t.departure_airport = dep.airport_code
    JOIN airports arr ON t.arrival_airport = arr.airport_code
    WHERE (dep.city = p_city1 AND arr.city = p_city2)
       OR (dep.city = p_city2 AND arr.city = p_city1);

    RETURN v_count;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT count_flights_between('Москва', 'Санкт-Петербург');

-- Решение 2: Функция поиска пересадочных маршрутов
CREATE OR REPLACE FUNCTION find_connecting_flights(
    p_from TEXT,
    p_to TEXT,
    p_date DATE
)
RETURNS TABLE (
    flight1_no      TEXT,
    transfer_city   TEXT,
    flight2_no      TEXT,
    total_duration  INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f1.route_no,
        mid.city,
        f2.route_no,
        (f2.scheduled_arrival - f1.scheduled_departure) AS duration
    FROM timetable f1
    JOIN airports dep ON f1.departure_airport = dep.airport_code
    JOIN airports mid ON f1.arrival_airport = mid.airport_code
    JOIN timetable f2 ON f2.departure_airport = f1.arrival_airport
    JOIN airports arr ON f2.arrival_airport = arr.airport_code
    WHERE dep.city = p_from
      AND arr.city = p_to
      AND f1.scheduled_departure::date = p_date
      AND f2.scheduled_departure > f1.scheduled_arrival
      AND f2.scheduled_departure < f1.scheduled_arrival + interval '6 hours'
    ORDER BY duration
    LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT * FROM find_connecting_flights('Москва', 'Владивосток', '2017-08-15');

-- =====================================================
-- ОЧИСТКА (опционально)
-- =====================================================

-- DROP FUNCTION IF EXISTS get_airport_city(CHAR);
-- DROP FUNCTION IF EXISTS format_route(CHAR, CHAR);
-- DROP FUNCTION IF EXISTS get_flight_status_description(TEXT);
-- DROP FUNCTION IF EXISTS calculate_flight_revenue(INTEGER);
-- DROP FUNCTION IF EXISTS get_fare_category(NUMERIC);
-- DROP FUNCTION IF EXISTS get_flights_between_cities(TEXT, TEXT);
-- DROP FUNCTION IF EXISTS get_airports_in_city(TEXT);
-- DROP FUNCTION IF EXISTS get_flight_stats(INTEGER);
-- DROP FUNCTION IF EXISTS search_flights(TEXT, TEXT, DATE, INTEGER);
-- DROP FUNCTION IF EXISTS count_flights_between(TEXT, TEXT);
-- DROP FUNCTION IF EXISTS find_connecting_flights(TEXT, TEXT, DATE);
-- DROP TRIGGER IF EXISTS tr_audit_bookings ON bookings;
-- DROP TRIGGER IF EXISTS tr_validate_booking ON bookings;
-- DROP FUNCTION IF EXISTS fn_audit_bookings();
-- DROP FUNCTION IF EXISTS fn_validate_booking();
-- DROP TABLE IF EXISTS booking_audit;
