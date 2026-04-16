-- =====================================================
-- Пара 9: Строковые и JSON функции
-- Демонстрационные запросы
-- =====================================================

-- =====================================================
-- 1. КОНКАТЕНАЦИЯ СТРОК
-- =====================================================

-- Оператор ||
SELECT
    'Hello' || ' ' || 'World' AS concat_operator,
    departure_airport || ' -> ' || arrival_airport AS route
FROM timetable
LIMIT 5;

-- Функция CONCAT
SELECT
    CONCAT('Hello', ' ', 'World') AS concat_func,
    CONCAT(departure_airport, ' -> ', arrival_airport) AS route
FROM timetable
LIMIT 5;

-- CONCAT_WS (with separator)
SELECT
    CONCAT_WS(', ', 'a', 'b', 'c', 'd') AS concat_ws_result,
    CONCAT_WS(' - ', departure_airport, arrival_airport) AS route
FROM timetable
LIMIT 5;

-- Разница с NULL
SELECT
    'Hello' || NULL AS op_with_null,         -- NULL
    CONCAT('Hello', NULL) AS concat_with_null, -- Hello
    CONCAT_WS(', ', 'a', null, 'b') AS ws_with_null; -- a, b

-- =====================================================
-- 2. ДЛИНА СТРОКИ
-- =====================================================

SELECT
    'Привет' AS str,
    LENGTH('Привет') AS char_length,        -- 6 символов
    OCTET_LENGTH('Привет') AS byte_length,  -- 12 байт (UTF-8)
    BIT_LENGTH('Привет') AS bit_length;     -- 96 бит

-- Длина названий городов
SELECT
    city,
    LENGTH(city) AS city_length
FROM airports
ORDER BY LENGTH(city) DESC
LIMIT 10;

-- =====================================================
-- 3. ИЗМЕНЕНИЕ РЕГИСТРА
-- =====================================================

SELECT
    'Hello World' AS original,
    LOWER('Hello World') AS lower_case,
    UPPER('Hello World') AS upper_case,
    INITCAP('hello world') AS init_cap;

-- Поиск без учёта регистра
SELECT *
FROM airports
WHERE LOWER(city) = 'moscow';

-- =====================================================
-- 4. TRIM — УДАЛЕНИЕ СИМВОЛОВ
-- =====================================================

SELECT
    '  hello  ' AS original,
    TRIM('  hello  ') AS trimmed,
    LTRIM('  hello  ') AS left_trimmed,
    RTRIM('  hello  ') AS right_trimmed;

-- Удаление конкретных символов
SELECT
    TRIM(BOTH '-' FROM '---hello---') AS trim_dash,
    TRIM(LEADING '0' FROM '00042') AS trim_zeros;

-- =====================================================
-- 5. SUBSTRING — ИЗВЛЕЧЕНИЕ ПОДСТРОКИ
-- =====================================================

SELECT
    'PostgreSQL' AS original,
    SUBSTRING('PostgreSQL' FROM 1 FOR 8) AS sub1,  -- Postgres
    SUBSTRING('PostgreSQL' FROM 8) AS sub2,         -- SQL
    SUBSTRING('PostgreSQL', 1, 8) AS sub3,          -- Postgres
    SUBSTR('PostgreSQL', 8) AS substr_func;         -- SQL

-- Извлечение года из строковой даты
SELECT
    '2017-08-15' AS date_str,
    SUBSTRING('2017-08-15' FROM 1 FOR 4) AS year,
    SUBSTRING('2017-08-15' FROM 6 FOR 2) AS month,
    SUBSTRING('2017-08-15' FROM 9 FOR 2) AS day;

-- =====================================================
-- 6. POSITION и STRPOS — ПОИСК ПОДСТРОКИ
-- =====================================================

SELECT
    'PostgreSQL' AS str,
    POSITION('SQL' IN 'PostgreSQL') AS position_result,  -- 8
    STRPOS('PostgreSQL', 'SQL') AS strpos_result,        -- 8
    POSITION('MySQL' IN 'PostgreSQL') AS not_found;      -- 0

-- Поиск в реальных данных
SELECT
    city,
    POSITION('mos' IN city) AS sk_position
FROM airports
WHERE city ILIKE '%mos%'
LIMIT 10;

-- =====================================================
-- 7. REPLACE — ЗАМЕНА ПОДСТРОКИ
-- =====================================================

SELECT
    'Hello World' AS original,
    REPLACE('Hello World', 'World', 'PostgreSQL') AS replaced;

-- Удаление символов
SELECT REPLACE('a-b-c-d', '-', '') AS no_dashes;

-- Замена в данных
SELECT
    passenger_name,
    lower(REPLACE(passenger_name, ' ', '_')) AS name_with_underscores
FROM tickets
LIMIT 5;

-- =====================================================
-- 8. TRANSLATE — ЗАМЕНА СИМВОЛОВ
-- =====================================================

SELECT
    'Hello' AS original,
    TRANSLATE('Hello', 'elo', '310') AS translated;
-- H3110: e→3, l→1, o→0

-- Транслитерация (упрощённая)
SELECT TRANSLATE('АБВ', 'АБВ', 'ABV');

-- =====================================================
-- 9. LEFT и RIGHT
-- =====================================================

SELECT
    'PostgreSQL' AS str,
    LEFT('PostgreSQL', 8) AS left_8,     -- Postgres
    RIGHT('PostgreSQL', 3) AS right_3;   -- SQL

-- Отрицательные значения
SELECT
    LEFT('PostgreSQL', -3) AS left_neg,   -- Postgre (без последних 3)
    RIGHT('PostgreSQL', -8) AS right_neg; -- QL (без первых 8)

-- Первые буквы названий городов
SELECT 
    LEFT(city, 1) AS first_letter,
    count(*) AS city_count
FROM airports
GROUP BY LEFT(city, 1)
ORDER BY first_letter;

-- =====================================================
-- 10. LPAD и RPAD — ДОПОЛНЕНИЕ
-- =====================================================

SELECT
    LPAD('42', 5, '0') AS lpad_zeros,    -- 00042
    RPAD('Hello', 10, '.') AS rpad_dots, -- Hello.....
    LPAD('X', 10, '-') AS lpad_dashes;   -- ---------X

-- Форматирование ID рейсов
SELECT
    flight_id,
    LPAD(flight_id::text, 6, '0') AS formatted_id
FROM flights
LIMIT 5;

-- =====================================================
-- 11. SPLIT_PART — РАЗБИЕНИЕ СТРОКИ
-- =====================================================

SELECT
    'a,b,c,d' AS str,
    SPLIT_PART('a,b,c,d', ',', 1) AS part1,  -- a
    SPLIT_PART('a,b,c,d', ',', 2) AS part2,  -- b
    SPLIT_PART('a,b,c,d', ',', 3) AS part3;  -- c

SELECT
  SPLIT_PART('user@example.com', '@', 2) AS domain;  
    
-- Извлечение частей имени
SELECT
    passenger_name,
    SPLIT_PART(passenger_name, ' ', 1) AS last_name,
    SPLIT_PART(passenger_name, ' ', 2) AS first_name
FROM tickets
LIMIT 10;

-- =====================================================
-- 12. STRING_TO_ARRAY и UNNEST
-- =====================================================

-- Преобразование строки в массив
SELECT STRING_TO_ARRAY('a,b,c,d', ',') AS arr;

-- Разбиение на строки
SELECT UNNEST(STRING_TO_ARRAY('a,b,c,d', ',')) AS element;

-- Подсчёт слов в именах
SELECT
    passenger_name,
    array_length(STRING_TO_ARRAY(passenger_name, ' '), 1) AS word_count
FROM tickets
order by word_count desc
LIMIT 10;

-- =====================================================
-- 13. ARRAY_TO_STRING
-- =====================================================

SELECT
    ARRAY_TO_STRING(ARRAY['a', 'b', 'c'], ', ') AS joined,
    ARRAY_TO_STRING(ARRAY['a', NULL, 'c'], ', ') AS with_null,
    ARRAY_TO_STRING(ARRAY['a', NULL, 'c'], ', ', 'N/A') AS null_replaced;

-- =====================================================
-- 14. STRING_AGG — АГРЕГАЦИЯ СТРОК
-- =====================================================

-- Простая агрегация
SELECT STRING_AGG(city, ', ')
FROM airports
WHERE city LIKE 'Mos%';

-- Агрегация с группировкой
SELECT
    city,
    STRING_AGG(airport_code, ', ' ORDER BY airport_code) AS airports,
    count(*) AS airport_count
FROM airports
GROUP BY city
HAVING count(*) > 1
ORDER BY airport_count DESC;

-- Список направлений из аэропорта (через timetable — имеет departure/arrival_airport)
SELECT
    departure_airport,
    STRING_AGG(DISTINCT arrival_airport, ', ' ORDER BY arrival_airport) AS destinations
FROM timetable
GROUP BY departure_airport
LIMIT 5;

-- =====================================================
-- 15. РЕГУЛЯРНЫЕ ВЫРАЖЕНИЯ — LIKE
-- =====================================================

-- Города, начинающиеся с М
SELECT * FROM airports WHERE city LIKE 'M%';

-- Города, заканчивающиеся на 'ск'
SELECT * FROM airports WHERE city LIKE '%ow';

-- Города, содержащие 'оск'
SELECT * FROM airports WHERE city LIKE '%osc%';

-- ILIKE — без учёта регистра
SELECT * FROM airports WHERE city ILIKE 'm%';

-- =====================================================
-- 16. SIMILAR TO И ~ (POSIX РЕГУЛЯРКИ)
-- =====================================================

-- SIMILAR TO
SELECT * FROM airports
WHERE city SIMILAR TO '(Moscow|Berlin)';

-- ~ (POSIX regex, с учётом регистра)
SELECT * FROM airports
WHERE city ~ '^M.*w$';  -- начинается с М, заканчивается на w

-- ~* (без учёта регистра)
SELECT * FROM airports
WHERE city ~* '^M';

-- !~ (не соответствует)
SELECT * FROM airports
WHERE city !~ '\d';  -- не содержит цифр

-- =====================================================
-- 17. REGEXP_REPLACE
-- =====================================================

-- Замена по регулярному выражению
SELECT
    REGEXP_REPLACE('Hello 123 World 456', '\d+', 'X', 'g') AS replaced_all,
    REGEXP_REPLACE('Hello 123 World', '\d+', 'X') AS replaced_first;

-- Извлечение только цифр
SELECT REGEXP_REPLACE('abc123def456', '[^0-9]', '', 'g') AS only_digits;

SELECT REGEXP_REPLACE('+7-(913)-888/[77]_66', '[^0-9]', '', 'g') AS only_digits;

-- Нормализация пробелов
SELECT REGEXP_REPLACE('Hello    World', '\s+', ' ', 'g') AS normalized;

-- =====================================================
-- 18. REGEXP_MATCHES
-- =====================================================

-- Поиск всех совпадений
SELECT REGEXP_MATCHES('abc123def456ghi789', '\d+', 'g');

-- Группы захвата
SELECT REGEXP_MATCHES('John Smith', '(\w+)\s+(\w+)');
-- Результат: {John,Smith}

-- =====================================================
-- 19. JSON И JSONB
-- =====================================================

-- Создание JSON
SELECT
    '{"name": "John", "age": 30}'::json AS json_literal,
    '{"name": "John", "age": 30}'::jsonb AS jsonb_literal;

-- Функции создания JSON
SELECT
    json_build_object('name', 'John', 'age', 30) AS json_build,
    jsonb_build_object('name', 'John', 'age', 30) AS jsonb_build;

-- JSON массив
SELECT
    json_build_array(1, 2, 3) AS json_array,
    jsonb_build_array('a', 'b', 'c') AS jsonb_array;

-- =====================================================
-- 20. ОПЕРАТОРЫ ИЗВЛЕЧЕНИЯ
-- =====================================================

-- -> возвращает JSON
-- ->> возвращает TEXT
SELECT
    '{"name": "John", "age": 30}'::jsonb -> 'name' AS json_value,
    '{"name": "John", "age": 30}'::jsonb ->> 'name' AS text_value,
    pg_typeof('{"name": "John"}'::jsonb -> 'name') AS json_type,
    pg_typeof('{"name": "John"}'::jsonb ->> 'name') AS text_type;

-- Для массивов
SELECT
    '[1, 2, 3]'::jsonb -> 0 AS first_element,
    '[1, 2, 3]'::jsonb -> -1 AS last_element,
    '[1, 2, 3]'::jsonb ->> 1 AS second_as_text;

-- =====================================================
-- 21. ПУТЬ В JSON (#> и #>>)
-- =====================================================

SELECT
    '{"a": {"b": {"c": 1}}}'::jsonb #> '{a,b,c}' AS deep_json,
    '{"a": {"b": {"c": 1}}}'::jsonb #>> '{a,b,c}' AS deep_text;

-- Работа с вложенными массивами
SELECT
    '{"items": [{"id": 1}, {"id": 2}]}'::jsonb #> '{items,0,id}' AS first_id;

-- =====================================================
-- 22. ОПЕРАТОРЫ ПРОВЕРКИ
-- =====================================================

SELECT
    '{"a": 1, "b": 2}'::jsonb ? 'a' AS has_key_a,       -- true
    '{"a": 1, "b": 2}'::jsonb ? 'c' AS has_key_c,       -- false
    '{"a": 1}'::jsonb ?| array['a', 'b'] AS has_any,    -- true (есть хотя бы один)
    '{"a": 1, "b": 2}'::jsonb ?& array['a', 'b'] AS has_all; -- true (есть все)

-- =====================================================
-- 23. ОПЕРАТОР @> (СОДЕРЖИТ)
-- =====================================================

SELECT
    '{"a": 1, "b": 2}'::jsonb @> '{"a": 1}'::jsonb AS contains,
    '{"a": 1}'::jsonb <@ '{"a": 1, "b": 2}'::jsonb AS contained_by;

-- Поиск самолётов определённой модели (model — JSONB в airplanes_data)
SELECT *
FROM airplanes_data
WHERE model @> '{"ru": "Боинг 767-300F"}'::jsonb
LIMIT 5;

-- =====================================================
-- 24. ФУНКЦИИ РАБОТЫ С JSON
-- =====================================================

-- Тип JSON значения
SELECT
    jsonb_typeof('{"a": 1}'::jsonb) AS obj_type,
    jsonb_typeof('[1, 2, 3]'::jsonb) AS arr_type,
    jsonb_typeof('123'::jsonb) AS num_type,
    jsonb_typeof('"text"'::jsonb) AS str_type,
    jsonb_typeof('true'::jsonb) AS bool_type,
    jsonb_typeof('null'::jsonb) AS null_type;

-- Количество элементов
SELECT
    jsonb_array_length('[1, 2, 3, 4, 5]'::jsonb) AS arr_length,
    jsonb_object_keys('{"a": 1, "b": 2}'::jsonb);

-- =====================================================
-- 25. JSONB_EACH И JSONB_ARRAY_ELEMENTS
-- =====================================================

-- Разбор объекта на пары ключ-значение
SELECT * FROM jsonb_each('{"a": 1, "b": 2, "c": 3}'::jsonb);

-- С текстовыми значениями
SELECT * FROM jsonb_each_text('{"a": 1, "b": 2}'::jsonb);

-- Разбор массива на элементы
SELECT * FROM jsonb_array_elements('[1, 2, 3]'::jsonb);
SELECT * FROM jsonb_array_elements_text('["a", "b", "c"]'::jsonb);

-- =====================================================
-- 26. РАБОТА С JSONB: МОДЕЛИ САМОЛЁТОВ
-- Таблица airplanes_data содержит поле model типа JSONB
-- с переводами: {"en": "...", "ru": "..."}
-- =====================================================

-- Структура model в airplanes_data
SELECT
    airplane_code,
    model
FROM airplanes_data
LIMIT 5;

-- Извлечение модели на русском и английском
SELECT
    airplane_code,
    model ->> 'ru' AS model_ru,
    model ->> 'en' AS model_en
FROM airplanes_data
WHERE model ? 'ru';

-- Подсчёт по наличию переводов
SELECT
    CASE
        WHEN model ? 'ru' AND model ? 'en' THEN 'Оба языка'
        WHEN model ? 'ru' THEN 'Только русский'
        WHEN model ? 'en' THEN 'Только английский'
        ELSE 'Нет переводов'
    END AS translation_type,
    count(*) AS cnt
FROM airplanes_data
GROUP BY 1
ORDER BY cnt DESC;

-- =====================================================
-- 27. МОДИФИКАЦИЯ JSON
-- =====================================================

-- Добавление ключа
SELECT
    '{"a": 1}'::jsonb || '{"b": 2}'::jsonb AS merged,
    jsonb_set('{"a": 1}'::jsonb, '{b}', '2') AS with_new_key;

-- Удаление ключа
SELECT
    '{"a": 1, "b": 2}'::jsonb - 'a' AS without_a,
    '{"a": 1, "b": 2}'::jsonb - '{a,b}'::text[] AS without_ab;

-- =====================================================
-- 28. СОЗДАНИЕ JSON ОТЧЁТОВ
-- =====================================================

-- JSON-отчёт по аэропортам
SELECT
    jsonb_build_object(
        'airport_code', airport_code,
        'city', city,
        'airport_name', airport_name
    ) AS airport_json
FROM airports
LIMIT 5;

-- Агрегация в JSON массив
SELECT
    city,
    jsonb_agg(jsonb_build_object(
        'code', airport_code,
        'name', airport_name
    )) AS airports
FROM airports
GROUP BY city
HAVING count(*) > 1;

-- =====================================================
-- 29. УПРАЖНЕНИЯ ДЛЯ САМОСТОЯТЕЛЬНОЙ РАБОТЫ
-- =====================================================

-- Упражнение 1: Найти всех пассажиров с фамилией из 5+ букв

-- Упражнение 2: Создать список маршрутов в формате "ГОРОД1 - ГОРОД2"

-- Упражнение 3: Извлечь модели самолётов на русском из airplanes_data

-- Упражнение 4: Построить JSON-отчёт с вложенной статистикой

-- Упражнение 5: Найти самолёты, модель которых содержит слово 'Боинг'

-- =====================================================
-- РЕШЕНИЯ УПРАЖНЕНИЙ
-- =====================================================

-- Решение 1
SELECT
    passenger_name,
    SPLIT_PART(passenger_name, ' ', 1) AS last_name,
    LENGTH(SPLIT_PART(passenger_name, ' ', 1)) AS last_name_length
FROM tickets
WHERE LENGTH(SPLIT_PART(passenger_name, ' ', 1)) >= 5
LIMIT 20;

select passenger_name, SPLIT_PART(t.passenger_name, ' ', 2) as surname
from tickets t
where length(SPLIT_PART(t.passenger_name, ' ', 2)) >= 5
limit 20;



-- Решение 2
SELECT DISTINCT
    dep.city || ' - ' || arr.city AS route
FROM timetable t
JOIN airports dep ON t.departure_airport = dep.airport_code
JOIN airports arr ON t.arrival_airport = arr.airport_code
ORDER BY route
LIMIT 20;

SELECT DISTINCT CONCAT_WS(' - ', dep.city, arr.city) AS unique_routes
FROM airports dep
JOIN timetable t ON dep.airport_code = t.departure_airport
JOIN airports arr ON arr.airport_code = t.arrival_airport
ORDER BY unique_routes;

SELECT ARRAY(
SELECT DISTINCT CONCAT(a1.city, ' - ', a2.city)
FROM timetable t
JOIN airports a1 ON t.departure_airport = a1.airport_code
JOIN airports a2 ON t.arrival_airport = a2.airport_code
ORDER BY 1
) AS routes_array;


SELECT DISTINCT CONCAT(a1.city, ' - ', a2.city)
FROM timetable t
JOIN airports a1 ON t.departure_airport = a1.airport_code
JOIN airports a2 ON t.arrival_airport = a2.airport_code
ORDER BY 1;

-- Решение 3
select city, city ->> 'ru' as city_ru
from airports_data ad 
where ad.country ->> 'en' = 'Mexico'
order by city ->> 'en';

select city ->> 'ru' as rus_city
from airports_data ad
where country ->> 'ru' = 'Мексика'
order by city ->> 'en'

SELECT
country,
city ->> 'ru' AS city_in_russian,
city ->> 'en' as city_in_english
FROM airports_data
WHERE country::jsonb @> '{"en": "Mexico"}'
ORDER BY city_in_english;

-- Решение 4
SELECT
    jsonb_build_object(
        'total_bookings', (SELECT count(*) FROM bookings),
        'total_revenue', (SELECT sum(total_amount) FROM bookings),
        'avg_booking', (SELECT round(avg(total_amount), 2) FROM bookings)        
    ) AS report;



select
jsonb_build_object(
'total_revenue', ROUND(SUM(total_amount),2),
'total_bookings', COUNT(*),
'avg_booking', ROUND(AVG(total_amount),2)
)
from bookings;


-- Решение 5
SELECT
    airplane_code,
    model ->> 'ru' AS model_ru
FROM airplanes_data
WHERE model ->> 'ru' LIKE '%Боинг%'
LIMIT 20;

-- =====================================================
-- XML ФУНКЦИИ
-- =====================================================

-- Базовое создание XML
SELECT XMLELEMENT(
    NAME flight,
    XMLATTRIBUTES(t.flight_id AS id, t.route_no AS route),
    XMLELEMENT(NAME departure, t.departure_airport),
    XMLELEMENT(NAME arrival, t.arrival_airport)
)
FROM timetable t
LIMIT 3;

-- XMLFOREST — несколько элементов из колонок
SELECT XMLELEMENT(
    NAME airport,
    XMLFOREST(
        airport_code AS code,
        city AS city,
        airport_name AS name
    )
)
FROM airports
WHERE city = 'Москва';

-- XMLAGG — агрегация элементов в один XML
SELECT XMLELEMENT(
    NAME airports,
    XMLAGG(
        XMLELEMENT(
            NAME airport,
            XMLATTRIBUTES(airport_code AS code),
            city
        )
        ORDER BY city
    )
)
FROM airports
WHERE city LIKE 'М%';

-- XPATH — извлечение данных из XML
SELECT XPATH(
    '/airports/airport/@code',
    XMLPARSE(DOCUMENT
        '<airports>
            <airport code="SVO">Шереметьево</airport>
            <airport code="LED">Пулково</airport>
            <airport code="DME">Домодедово</airport>
        </airports>'
    )
);

-- XPATH текстовый контент
SELECT (XPATH('/root/city/text()',
    '<root><city>Москва</city></root>'::xml
))[1]::text AS city_name;

-- XMLTABLE — XML как реляционная таблица
SELECT t.*
FROM XMLTABLE(
    '/airports/airport'
    PASSING XMLPARSE(DOCUMENT
        '<airports>
            <airport code="SVO" city="Москва">Шереметьево</airport>
            <airport code="LED" city="Санкт-Петербург">Пулково</airport>
            <airport code="AER" city="Сочи">Адлер</airport>
        </airports>'
    )
    COLUMNS
        code    text PATH '@code',
        city    text PATH '@city',
        name    text PATH '.'
) AS t;

-- Генерация XML из реальных данных и разбор через XMLTABLE
WITH flights_xml AS (
    SELECT XMLELEMENT(
        NAME flights,
        XMLAGG(
            XMLELEMENT(
                NAME flight,
                XMLATTRIBUTES(
                    t.flight_id AS id,
                    t.route_no AS route,
                    t.status AS status
                ),
                XMLELEMENT(NAME departure, dep.city),
                XMLELEMENT(NAME arrival, arr.city)
            )
        )
    ) AS xml_doc
    FROM timetable t
    JOIN airports dep ON t.departure_airport = dep.airport_code
    JOIN airports arr ON t.arrival_airport = arr.airport_code
    WHERE t.status = 'Cancelled'
    LIMIT 10
)
SELECT t.*
FROM flights_xml,
XMLTABLE(
    '/flights/flight'
    PASSING xml_doc
    COLUMNS
        id          int     PATH '@id',
        route       text    PATH '@route',
        status      text    PATH '@status',
        departure   text    PATH 'departure',
        arrival     text    PATH 'arrival'
) AS t;

-- XMLSERIALIZE — преобразование XML в текст
SELECT XMLSERIALIZE(
    DOCUMENT XMLELEMENT(
        NAME report,
        XMLATTRIBUTES(now()::text AS generated_at),
        XMLELEMENT(NAME total_flights, count(*))
    ) AS text
)
FROM flights;




