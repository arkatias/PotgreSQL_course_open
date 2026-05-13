-- =====================================================
-- Пара 16: Хранимые процедуры в PostgreSQL
-- Демонстрационные запросы
-- =====================================================

-- =====================================================
-- 0. ПОДГОТОВКА
-- =====================================================
drop table if exists procedure_log;
CREATE TABLE IF NOT EXISTS procedure_log (
    log_id     SERIAL PRIMARY KEY,
    proc_name  TEXT        NOT NULL,
    status     TEXT        NOT NULL,  -- 'OK' | 'ERROR'
    message    TEXT,
    started_at TIMESTAMP   DEFAULT now()
);

-- =====================================================
-- 1. DO BLOCK — АНОНИМНЫЙ БЛОК КОДА
-- =====================================================

-- DO выполняется один раз и не создает объект в БД.
DO $$
DECLARE
    v_cnt INTEGER;
BEGIN
    SELECT count(*) INTO v_cnt FROM flights;
    RAISE NOTICE 'Всего рейсов: %', v_cnt;
END;
$$;

-- Пример: условная логика в разовом тех. скрипте
DO $$
DECLARE
    v_has_delayed BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM flights WHERE status = 'Delayed'
    ) INTO v_has_delayed;

    IF v_has_delayed THEN
        RAISE NOTICE 'Есть задержанные рейсы, можно запускать обработку';
    ELSE
        RAISE NOTICE 'Задержанных рейсов нет';
    END IF;
END;
$$;

-- =====================================================
-- 2. ПРОЦЕДУРА vs ФУНКЦИЯ — БАЗОВОЕ ОТЛИЧИЕ
-- =====================================================

-- Функция — возвращает значение, вызывается в SELECT
CREATE OR REPLACE FUNCTION fn_count_flights(p_status TEXT)
RETURNS BIGINT AS $$
    SELECT count(*) FROM flights WHERE status = p_status;
$$ LANGUAGE SQL STABLE;

SELECT fn_count_flights('Scheduled');

-- Процедура — не возвращает значение, вызывается через CALL
CREATE OR REPLACE PROCEDURE pr_log_event(
    p_proc_name TEXT,
    p_status    TEXT,
    p_message   TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO procedure_log (proc_name, status, message)
    VALUES (p_proc_name, p_status, p_message);
END;
$$;

CALL pr_log_event('demo', 'OK', 'Тест процедуры');
SELECT * FROM procedure_log ORDER BY log_id DESC LIMIT 5;

-- =====================================================
-- 3. IN / OUT / INOUT ПАРАМЕТРЫ
-- =====================================================

CREATE OR REPLACE PROCEDURE pr_calc_bonus(
    IN p_amount NUMERIC,
    IN p_percent NUMERIC,
    OUT p_bonus NUMERIC,
    INOUT p_comment TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    p_bonus := round(p_amount * p_percent / 100.0, 2);
    p_comment := coalesce(p_comment, '') || ' | bonus calculated';
END;
$$;

-- OUT/INOUT возвращаются как результат CALL
CALL pr_calc_bonus(15000, 12.5, NULL, 'monthly payout');

-- Используем OUT/INOUT дальше в коде (внутри PL/pgSQL-блока)
DO $$
DECLARE
    v_bonus NUMERIC;
    v_comment TEXT := 'quarterly payout';
BEGIN
    CALL pr_calc_bonus(20000, 10, v_bonus, v_comment);

    INSERT INTO procedure_log (proc_name, status, message)
    VALUES (
        'pr_calc_bonus',
        CASE WHEN v_bonus >= 1500 THEN 'OK' ELSE 'CHECK' END,
        format('bonus=%s, comment=%s', v_bonus, v_comment)
    );

    RAISE NOTICE 'Использовали OUT/INOUT: bonus=%, comment=%',
        v_bonus, v_comment;
END;
$$;

SELECT * FROM procedure_log
WHERE proc_name = 'pr_calc_bonus'
ORDER BY log_id DESC
LIMIT 5;

-- =====================================================
-- 4. ОБРАБОТКА ИСКЛЮЧЕНИЙ
-- =====================================================

-- Таблица для тестирования ошибок (unique_violation)
drop table if exists test_bookings;
CREATE TABLE IF NOT EXISTS test_bookings (
    book_ref    CHAR(6) PRIMARY KEY,
    total_amount NUMERIC(10,2) CHECK (total_amount >= 0)
);

CREATE OR REPLACE PROCEDURE pr_safe_insert(
    p_book_ref   CHAR(6),
    p_amount     NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO test_bookings (book_ref, total_amount)
    VALUES (p_book_ref, p_amount);

    RAISE NOTICE 'Запись % добавлена', p_book_ref;

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Запись % уже существует — пропускаем', p_book_ref;

    WHEN check_violation THEN
        RAISE EXCEPTION 'Нарушение CHECK: сумма % недопустима', p_amount;

    WHEN OTHERS THEN
        RAISE WARNING '[%] Неожиданная ошибка: %', SQLSTATE, SQLERRM;
END;
$$;

CALL pr_safe_insert('TST001', 10000);
CALL pr_safe_insert('TST001', 10000);  -- unique_violation
CALL pr_safe_insert('TST002', -500);   -- check_violation

SELECT * FROM test_bookings;

-- =====================================================
-- 5. УПРАВЛЕНИЕ ТРАНЗАКЦИЯМИ ВНУТРИ ПРОЦЕДУРЫ
-- =====================================================
-- Процедура пакетного обновления с COMMIT внутри
-- (имитируем "устаревшие" рейсы)
CREATE OR REPLACE PROCEDURE pr_batch_update_status(
    p_from_status TEXT,
    p_to_status   TEXT,
    p_batch_size  INTEGER DEFAULT 100
)
LANGUAGE plpgsql AS $$
DECLARE
    v_total     INTEGER := 0;
    v_rows      INTEGER;
BEGIN
    LOOP
        UPDATE flights
        SET status = p_to_status
        WHERE flight_id IN (
            SELECT flight_id FROM flights
            WHERE status = p_from_status
            LIMIT p_batch_size
        );

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        EXIT WHEN v_rows = 0;

        v_total := v_total + v_rows;
        RAISE NOTICE 'Пакет: %, итого: %', v_rows, v_total;

        COMMIT;  -- освобождаем блокировки после каждого пакета
    END LOOP;

    RAISE NOTICE 'Завершено. Обновлено всего: % рейсов', v_total;
END;
$$;

-- Смотрим текущее распределение статусов
SELECT status, count(*) FROM flights GROUP BY status ORDER BY count DESC;

-- =====================================================
-- 6. ОГРАНИЧЕНИЯ ТРАНЗАКЦИЙ ПРИ CALL
-- =====================================================

-- Важно: COMMIT/ROLLBACK внутри процедуры используйте при top-level CALL.
-- Типовой безопасный сценарий: вызываем CALL как отдельную команду.
-- Если процедура нужна как часть SELECT-логики, обычно нужна функция.

-- =====================================================
-- 7. ПРОЦЕДУРА С ЛОГИРОВАНИЕМ ОШИБОК
-- =====================================================

CREATE OR REPLACE PROCEDURE pr_update_arrived_flights()
LANGUAGE plpgsql AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Помечаем улетевшие рейсы как прилетевшие (если время вышло)
    UPDATE flights
    SET status = 'Arrived'
    WHERE status = 'Departed'
      AND scheduled_arrival < now() - interval '1 hour';

    GET DIAGNOSTICS v_count = ROW_COUNT;

    INSERT INTO procedure_log (proc_name, status, message)
    VALUES (
        'pr_update_arrived_flights',
        'OK',
        format('Обновлено %s рейсов', v_count)
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Логируем ошибку и пробрасываем дальше
        INSERT INTO procedure_log (proc_name, status, message)
        VALUES (
            'pr_update_arrived_flights',
            'ERROR',
            format('[%s] %s', SQLSTATE, SQLERRM)
        );
        COMMIT;  -- лог нужно закоммитить даже при ошибке
        RAISE;
END;
$$;

CALL pr_update_arrived_flights();
SELECT * FROM procedure_log ORDER BY log_id DESC LIMIT 5;

-- =====================================================
-- 8. SECURITY DEFINER И БЕЗОПАСНЫЙ search_path
-- =====================================================

CREATE SCHEMA IF NOT EXISTS admin;

CREATE TABLE IF NOT EXISTS admin.maintenance_log (
    id         SERIAL PRIMARY KEY,
    action     TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE PROCEDURE admin.pr_write_maintenance_log(p_action TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = admin, pg_temp
AS $$
BEGIN
    INSERT INTO admin.maintenance_log(action) VALUES (p_action);
END;
$$;

CALL admin.pr_write_maintenance_log('nightly maintenance');
SELECT * FROM admin.maintenance_log ORDER BY id DESC LIMIT 5;

-- =====================================================
-- 9. DDL И АДМИНИСТРИРОВАНИЕ ПРОЦЕДУР
-- =====================================================

COMMENT ON PROCEDURE pr_batch_update_status(TEXT, TEXT, INTEGER)
IS 'Пакетное обновление статусов рейсов';

-- Пример смены владельца (выполнять при наличии роли):
-- ALTER PROCEDURE pr_batch_update_status(TEXT, TEXT, INTEGER) OWNER TO app_owner;

-- =====================================================
-- 10. КУРСОР — ЯВНЫЙ
-- =====================================================

-- Явный курсор с параметром
CREATE OR REPLACE PROCEDURE pr_print_flights_by_airport(p_airport CHAR(3))
LANGUAGE plpgsql AS $$
DECLARE
    cur CURSOR (p_dep CHAR(3)) FOR
        SELECT flight_no, status, scheduled_departure
        FROM flights
        WHERE departure_airport = p_dep
        ORDER BY scheduled_departure
        LIMIT 10;

    v_rec RECORD;
    v_count INTEGER := 0;
BEGIN
    OPEN cur(p_airport);

    LOOP
        FETCH cur INTO v_rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE '% | % | %',
            v_rec.flight_no,
            v_rec.status,
            v_rec.scheduled_departure;

        v_count := v_count + 1;
    END LOOP;

    CLOSE cur;
    RAISE NOTICE 'Выведено рейсов: %', v_count;
END;
$$;

CALL pr_print_flights_by_airport('SVO');

-- =====================================================
-- 11. FOR LOOP — ЧАЩЕ ЛУЧШЕ КУРСОРА
-- =====================================================

CREATE OR REPLACE PROCEDURE pr_summary_by_status()
LANGUAGE plpgsql AS $$
DECLARE
    v_rec RECORD;
BEGIN
    FOR v_rec IN
        SELECT status, count(*) AS cnt, round(avg(
            EXTRACT(EPOCH FROM (scheduled_arrival - scheduled_departure)) / 60
        ), 0) AS avg_duration_min
        FROM flights
        GROUP BY status
        ORDER BY cnt DESC
    LOOP
        RAISE NOTICE 'Статус: %-15s | Кол-во: % | Средн. длит.: % мин',
            v_rec.status, v_rec.cnt, v_rec.avg_duration_min;
    END LOOP;
END;
$$;

CALL pr_summary_by_status();

-- =====================================================
-- 12. GET DIAGNOSTICS
-- =====================================================

DO $$
DECLARE
    v_rows INTEGER;
BEGIN
    -- Пример использования GET DIAGNOSTICS
    UPDATE flights SET status = status  -- обновление "вхолостую" для демо
    WHERE departure_airport = 'SVO' AND status = 'Scheduled';

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RAISE NOTICE 'Затронуто строк: %', v_rows;
END;
$$;

-- =====================================================
-- 13. УПРАЖНЕНИЯ
-- =====================================================

-- Упражнение 1:
-- Написать процедуру pr_cancel_flight(p_flight_id INTEGER):
-- - Установить статус рейса в 'Cancelled'
-- - Логировать результат в procedure_log
-- - Обработать случай, если рейс не найден (RAISE NOTICE)

-- Упражнение 2:
-- Написать процедуру pr_recalculate_booking_totals(),
-- которая обновляет total_amount в bookings
-- как сумму amount из ticket_flights.
-- Коммитить каждые 500 записей.

-- =====================================================
-- РЕШЕНИЯ
-- =====================================================

-- Решение 1
