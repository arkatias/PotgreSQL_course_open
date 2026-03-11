-- ============================================================================
-- ПАРА 3: Типы данных в PostgreSQL
-- Демонстрационный скрипт для slides_data_types.md
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Числовые типы
-- ============================================================================

SELECT pg_typeof(1) AS t_int, pg_typeof(1.0) AS t_numeric;

-- Точность numeric vs float
SELECT
    0.1::numeric + 0.2::numeric AS numeric_sum,
    0.1::double precision + 0.2::double precision AS float_sum;

-- ============================================================================
-- ЧАСТЬ 2: Символьные типы
-- ============================================================================

SELECT
    'abc'::char(5) = 'abc  ' AS char_eq_with_spaces,
    'abc'::text = 'abc  ' AS text_eq_with_spaces;

SELECT
    length('Hello') AS len,
    upper('hello') AS upper_val,
    trim('  hello  ') AS trimmed,
    substring('PostgreSQL', 1, 4) AS sub,
    replace('foo bar', 'bar', 'baz') AS replaced;

-- ============================================================================
-- ЧАСТЬ 3: BOOLEAN
-- ============================================================================

CREATE TEMP TABLE dt_features (
    feature_name text NOT NULL,
    is_enabled boolean NOT NULL DEFAULT false
);

INSERT INTO dt_features (feature_name, is_enabled) VALUES
('new_ui', true),
('beta_api', false);

SELECT * FROM dt_features WHERE is_enabled;
SELECT * FROM dt_features WHERE NOT is_enabled;

-- ============================================================================
-- ЧАСТЬ 4: Дата и время
-- ============================================================================

SELECT
    CURRENT_DATE AS current_date,
    NOW() AS now_ts,
    DATE_TRUNC('month', NOW()) AS month_start,
    NOW() + INTERVAL '1 day 3 hours' AS plus_interval;

SET TIME ZONE 'Europe/Moscow';
SELECT '2024-08-15 12:00:00+03'::timestamptz AS moscow_time;
SET TIME ZONE 'UTC';
SELECT '2024-08-15 12:00:00+03'::timestamptz AS utc_repr_same_moment;

-- ============================================================================
-- ЧАСТЬ 5: BYTEA
-- ============================================================================

SELECT '\xDEADBEEF'::bytea AS raw_bytes;
SELECT encode('\x48656c6c6f'::bytea, 'escape') AS decoded_text;
SELECT octet_length('\x48656c6c6f'::bytea) AS bytes_len;

-- ============================================================================
-- ЧАСТЬ 6: UUID
-- ============================================================================

-- Литерал UUID без расширений
SELECT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid AS sample_uuid;

-- Опционально: генерация UUID (нужен pgcrypto)
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- SELECT gen_random_uuid();

-- ============================================================================
-- ЧАСТЬ 7: JSONB
-- ============================================================================

CREATE TEMP TABLE dt_events (
    id serial PRIMARY KEY,
    data jsonb NOT NULL
);

INSERT INTO dt_events (data) VALUES
('{"user_id": 42, "action": "login", "tags": ["web", "mobile"]}'),
('{"user_id": 42, "action": "purchase", "amount": 1990, "tags": ["web"]}'),
('{"user_id": 7, "action": "login", "tags": ["mobile"]}');

SELECT data -> 'user_id' AS user_id_json FROM dt_events;
SELECT data ->> 'action' AS action_text FROM dt_events;
SELECT * FROM dt_events WHERE data ? 'amount';
SELECT * FROM dt_events WHERE data @> '{"action":"login"}';

UPDATE dt_events
SET data = data || '{"status":"ok"}'
WHERE data ->> 'action' = 'login';

SELECT
    data ->> 'action' AS action,
    count(*) AS cnt
FROM dt_events
GROUP BY data ->> 'action'
ORDER BY cnt DESC;

-- ============================================================================
-- ЧАСТЬ 8: ARRAY
-- ============================================================================

CREATE TEMP TABLE dt_products (
    product_id serial PRIMARY KEY,
    name text NOT NULL,
    tags text[],
    scores integer[]
);

INSERT INTO dt_products (name, tags, scores) VALUES
('Widget', ARRAY['sale', 'new', 'hot'], ARRAY[5,4,5]),
('Gadget', ARRAY['tech', 'new'], ARRAY[4,4,5]);

SELECT tags[1] AS first_tag FROM dt_products WHERE name = 'Widget';
SELECT * FROM dt_products WHERE 'new' = ANY(tags);
SELECT * FROM dt_products WHERE tags @> ARRAY['sale'];
SELECT array_length(tags, 1) AS tags_count FROM dt_products;
SELECT unnest(tags) AS tag FROM dt_products WHERE name = 'Widget';

SELECT
    departure_airport,
    array_agg(DISTINCT arrival_airport ORDER BY arrival_airport) AS destinations
FROM routes
GROUP BY departure_airport
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 9: ENUM
-- ============================================================================

DROP TYPE IF EXISTS dt_employee_status;
CREATE TYPE dt_employee_status AS ENUM ('intern', 'active', 'vacation', 'fired');

CREATE TEMP TABLE dt_employees_enum (
    emp_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    status dt_employee_status NOT NULL DEFAULT 'active'
);

INSERT INTO dt_employees_enum (full_name, status) VALUES
('Ivan Ivanov', 'active'),
('Petr Petrov', 'intern');

SELECT full_name, status
FROM dt_employees_enum
ORDER BY status;

-- ============================================================================
-- ЧАСТЬ 10: DOMAIN
-- ============================================================================

DROP DOMAIN IF EXISTS dt_email;
CREATE DOMAIN dt_email AS text
CHECK (VALUE ~ '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

CREATE TEMP TABLE dt_customers (
    customer_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email dt_email NOT NULL
);

INSERT INTO dt_customers (email) VALUES ('user@example.com');

-- Пример ошибки валидации домена (раскомментировать для демонстрации)
-- INSERT INTO dt_customers (email) VALUES ('not_an_email');

-- ============================================================================
-- ЧАСТЬ 11: Составной тип
-- ============================================================================

DROP TYPE IF EXISTS dt_address;
CREATE TYPE dt_address AS (
    street text,
    city text,
    zip char(6)
);

CREATE TEMP TABLE dt_employees_composite (
    emp_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    home_addr dt_address
);

INSERT INTO dt_employees_composite (full_name, home_addr) VALUES
('Anna Smirnova', ROW('Lenina 1', 'Moscow', '101000'));

SELECT (home_addr).city AS city FROM dt_employees_composite;

-- ============================================================================
-- ЧАСТЬ 12: Сетевые/геометрические/full-text типы
-- ============================================================================

SELECT '192.168.1.100'::inet << '192.168.1.0/24'::cidr AS in_network;
SELECT point(0,0) <-> point(3,4) AS distance_3_4_5;
SELECT to_tsvector('russian', 'Самолёт вылетел из Москвы') @@ to_tsquery('russian', 'Москва') AS fts_match;

-- ============================================================================
-- ЧАСТЬ 13: Касты и индексы
-- ============================================================================

SELECT '42'::integer AS cast_colon;
SELECT CAST('2024-01-01' AS date) AS cast_func;
SELECT pg_typeof(1 + 1.5) AS implicit_cast_result_type;

-- ============================================================================
-- ПРАКТИЧЕСКИЙ БЛОК (по слайду 29)
-- ============================================================================

DROP DOMAIN IF EXISTS dt_email2;
CREATE DOMAIN dt_email2 AS text
CHECK (VALUE ~ '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

DROP TYPE IF EXISTS dt_emp_status;
CREATE TYPE dt_emp_status AS ENUM ('junior', 'middle', 'senior');

CREATE TEMP TABLE dt_employees_practice (
    employee_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    email dt_email2 NOT NULL,
    salary numeric(12,2) NOT NULL CHECK (salary >= 0),
    hired_at date NOT NULL DEFAULT CURRENT_DATE,
    skills text[] NOT NULL DEFAULT '{}',
    profile jsonb NOT NULL DEFAULT '{}'::jsonb,
    status dt_emp_status NOT NULL DEFAULT 'junior'
);

INSERT INTO dt_employees_practice (full_name, email, salary, skills, profile, status) VALUES
('Alex Kim', 'alex@example.com', 120000, ARRAY['SQL', 'Python'], '{"team":"analytics","city":"Moscow"}', 'middle'),
('Maria Lee', 'maria@example.com', 90000, ARRAY['Excel', 'SQL'], '{"team":"finance","city":"SPb"}', 'junior');

-- 1) сотрудники с навыком SQL
SELECT full_name, skills
FROM dt_employees_practice
WHERE 'SQL' = ANY(skills);

-- 2) агрегировать по ключу из jsonb
SELECT
    profile ->> 'team' AS team,
    count(*) AS employees
FROM dt_employees_practice
GROUP BY profile ->> 'team'
ORDER BY employees DESC;

-- 3) проверка DOMAIN (раскомментировать)
-- INSERT INTO dt_employees_practice (full_name, email, salary)
-- VALUES ('Bad Email', 'oops', 1);
