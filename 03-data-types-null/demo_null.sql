-- ============================================================================
-- ПАРА 3: Работа с NULL и специальные операторы
-- Демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Понятие NULL
-- ============================================================================

-- NULL — это отсутствие значения, а не пустая строка или ноль
SELECT NULL;
SELECT '';
SELECT 0;

-- Все три значения выше — разные!

-- В таблице flights есть NULL в колонке actual_departure
-- (рейсы, которые ещё не вылетели)
SELECT route_no, scheduled_departure, actual_departure
FROM flights
WHERE actual_departure IS NULL
LIMIT 5;

SELECT route_no, scheduled_departure, actual_departure
FROM flights
WHERE actual_departure IS NOT NULL
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 2: Трёхзначная логика
-- ============================================================================

-- Любое сравнение с NULL даёт NULL
SELECT NULL = NULL;      -- NULL (не TRUE!)
SELECT NULL != NULL;     -- NULL (не FALSE!)
SELECT NULL > 5;         -- NULL
SELECT 5 = NULL;         -- NULL
SELECT 'text' = NULL;    -- NULL

-- Демонстрация таблицы истинности
SELECT
    TRUE AND TRUE AS "T AND T",
    TRUE AND FALSE AS "T AND F",
    TRUE AND NULL AS "T AND NULL",
    FALSE AND NULL AS "F AND NULL",
    NULL AND NULL AS "NULL AND NULL";

SELECT
    TRUE OR FALSE AS "T OR F",
    FALSE OR FALSE AS "F OR F",
    TRUE OR NULL AS "T OR NULL",
    FALSE OR NULL AS "F OR NULL",
    NULL OR NULL AS "NULL OR NULL";

SELECT
    NOT TRUE AS "NOT T",
    NOT FALSE AS "NOT F",
    NOT NULL AS "NOT NULL";

-- ============================================================================
-- ЧАСТЬ 3: IS NULL и IS NOT NULL
-- ============================================================================

-- ❌ НЕПРАВИЛЬНО — это не найдёт ничего!
SELECT route_no, actual_departure
FROM flights
WHERE actual_departure = NULL
LIMIT 5;

-- ✅ ПРАВИЛЬНО — используйте IS NULL
SELECT route_no, actual_departure
FROM flights
WHERE actual_departure IS NULL
LIMIT 5;

-- Рейсы, которые уже прибыли (actual_arrival заполнен)
SELECT route_no, actual_arrival
FROM flights
WHERE actual_arrival IS NOT NULL
LIMIT 10;

-- Сколько рейсов ещё не вылетело?
SELECT count(*) AS not_departed
FROM flights
WHERE actual_departure IS NULL;

-- Сколько рейсов уже вылетело?
SELECT count(*) AS departed
FROM flights
WHERE actual_departure IS NOT NULL;

-- ============================================================================
-- ЧАСТЬ 4: COALESCE — замена NULL
-- ============================================================================

-- COALESCE возвращает первое не-NULL значение
SELECT COALESCE(NULL, 'default');
SELECT COALESCE('value', 'default');
SELECT COALESCE(NULL, NULL, 'third');
SELECT COALESCE(NULL, 'second', 'third');

-- Практический пример: показать фактическое или плановое время
SELECT
    route_no,
    scheduled_departure,
    actual_departure,
    COALESCE(actual_departure, scheduled_departure) AS real_departure
FROM flights
LIMIT 10;

-- Заменить NULL на текст "Ещё не вылетел"
SELECT
    route_no,
    scheduled_departure,
    COALESCE(actual_departure::text, 'Ещё не вылетел') AS departure_status
FROM flights
LIMIT 10;

-- Использование с числами
SELECT
    book_ref,
    total_amount,
    COALESCE(total_amount, 0) AS safe_amount
FROM bookings
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 5: NULLIF — создание NULL
-- ============================================================================

-- NULLIF возвращает NULL, если аргументы равны
SELECT NULLIF(5, 5);       -- NULL
SELECT NULLIF(5, 3);       -- 5
SELECT NULLIF('a', 'a');   -- NULL
SELECT NULLIF('a', 'b');   -- 'a'

-- Защита от деления на ноль
SELECT 100 / 2;            -- 50
-- SELECT 100 / 0;         -- Ошибка!
SELECT 100 / NULLIF(0, 0); -- NULL (безопасно)

-- Практический пример: заменить пустую строку на NULL
SELECT NULLIF('', '');     -- NULL
SELECT NULLIF('text', ''); -- 'text'

-- ============================================================================
-- ЧАСТЬ 6: Оператор BETWEEN
-- ============================================================================

-- BETWEEN включает границы (>=  AND <=)
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount BETWEEN 50000 AND 100000
ORDER BY total_amount
LIMIT 10;

-- Эквивалентная запись
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount >= 50000 AND total_amount <= 100000
ORDER BY total_amount
LIMIT 10;

-- BETWEEN с датами
SELECT route_no, scheduled_departure
FROM flights
WHERE scheduled_departure BETWEEN '2017-08-15' AND '2017-08-15 23:59:59'
ORDER BY scheduled_departure
LIMIT 10;

-- Лучший способ для дат — >= и < (не включая верхнюю границу)
SELECT route_no, scheduled_departure
FROM flights
WHERE scheduled_departure >= '2017-08-15'
  AND scheduled_departure < '2017-08-16'
ORDER BY scheduled_departure
LIMIT 10;

-- NOT BETWEEN
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount NOT BETWEEN 50000 AND 100000
ORDER BY total_amount
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 7: Оператор IN
-- ============================================================================

-- IN — проверка на вхождение в список
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE departure_airport IN ('SVO', 'DME', 'VKO')
LIMIT 10;

-- Эквивалентно, но длиннее
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE departure_airport = 'SVO'
   OR departure_airport = 'DME'
   OR departure_airport = 'VKO'
LIMIT 10;

-- IN со статусами
SELECT route_no, status
FROM flights
WHERE status IN ('Cancelled', 'Delayed')
LIMIT 10;

-- NOT IN
SELECT route_no, departure_airport
FROM routes
WHERE departure_airport NOT IN ('SVO', 'DME', 'VKO')
LIMIT 10;

-- ⚠️ Осторожно с NULL в NOT IN!
-- Это вернёт строки:
SELECT 1 WHERE 1 IN (1, 2, NULL);      -- TRUE

-- А это не вернёт ничего!
SELECT 1 WHERE 3 NOT IN (1, 2, NULL);  -- NULL, не TRUE

-- IN с подзапросом (превью пары 9)
SELECT route_no, arrival_airport
FROM routes
WHERE arrival_airport IN (
    SELECT airport_code
    FROM airports
    WHERE city = 'Москва'
)
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 8: Оператор LIKE
-- ============================================================================

-- LIKE использует шаблоны:
-- % — любое количество символов (включая 0)
-- _ — ровно один символ

-- Аэропорты, начинающиеся на "Ш"
SELECT airport_code, airport_name, city
FROM airports
WHERE airport_name LIKE 'Ш%';

-- Аэропорты, заканчивающиеся на "во"
SELECT airport_code, airport_name, city
FROM airports
WHERE airport_name LIKE '%во';

-- Аэропорты, содержащие "между" (международный)
SELECT airport_code, airport_name, city
FROM airports
WHERE airport_name LIKE '%ународ%';

-- Маршруты, номер которых начинается на "PG"
SELECT DISTINCT route_no
FROM routes
WHERE route_no LIKE 'PG%'
LIMIT 10;

-- Маршруты с номером из 6 символов
SELECT DISTINCT route_no
FROM routes
WHERE route_no LIKE '______'
LIMIT 10;

-- Маршруты, где второй символ — цифра
SELECT DISTINCT route_no
FROM routes
WHERE route_no LIKE '_[0-9]%'  -- Не работает! LIKE не поддерживает []
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 9: Оператор ILIKE (регистронезависимый)
-- ============================================================================

-- ILIKE — расширение PostgreSQL для регистронезависимого поиска
SELECT airport_code, city
FROM airports
WHERE city ILIKE 'москва';

-- Сравните с LIKE:
SELECT airport_code, city
FROM airports
WHERE city LIKE 'москва';  -- Не найдёт "Москва"!

-- Города, содержащие "пет" в любом регистре
SELECT airport_code, city
FROM airports
WHERE city ILIKE '%пет%';

-- ============================================================================
-- ЧАСТЬ 10: NOT LIKE
-- ============================================================================

-- Аэропорты, НЕ начинающиеся на "М"
SELECT airport_code, airport_name, city
FROM airports
WHERE airport_name NOT LIKE 'М%';

-- Маршруты не авиакомпании "PG"
SELECT DISTINCT route_no
FROM routes
WHERE route_no NOT LIKE 'PG%'
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 11: Регулярные выражения
-- ============================================================================

-- ~ — соответствует регулярному выражению (регистрозависимо)
-- ~* — регистронезависимо
-- !~ — не соответствует
-- !~* — не соответствует (регистронезависимо)

-- Города, начинающиеся на гласную (русскую)
SELECT city
FROM airports
WHERE city ~ '^[АЕЁИОУЫЭЮЯаеёиоуыэюя]'
ORDER BY city;

-- Номера маршрутов: 2 буквы + цифры
SELECT DISTINCT route_no
FROM routes
WHERE route_no ~ '^[A-Z]{2}[0-9]+$'
LIMIT 15;

-- Пассажиры с именем из двух слов
SELECT passenger_name
FROM tickets
WHERE passenger_name ~ '^[A-Z]+ [A-Z]+$'
LIMIT 10;

-- Регистронезависимый поиск
SELECT city
FROM airports
WHERE city ~* 'москва';

-- ============================================================================
-- ЧАСТЬ 12: SIMILAR TO
-- ============================================================================

-- SIMILAR TO — SQL-стандарт, гибрид LIKE и regex
-- Использует % и _ как LIKE, но поддерживает | для альтернатив

-- Маршруты авиакомпаний PG или SU
SELECT DISTINCT route_no
FROM routes
WHERE route_no SIMILAR TO '(PG|SU)%'
LIMIT 15;

-- Сравните с регулярным выражением:
SELECT DISTINCT route_no
FROM routes
WHERE route_no ~ '^(PG|SU)'
LIMIT 15;

-- ============================================================================
-- ПРАКТИЧЕСКИЕ ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Найти рейсы без фактического времени прибытия

-- Задание 2: Вывести аэропорты Санкт-Петербурга (город содержит "Санкт")

-- Задание 3: Найти бронирования от 100 000 до 200 000 рублей

-- Задание 4: Вывести маршруты авиакомпаний SU, S7, U6 (по route_no)

-- Задание 5: Найти пассажиров с именем, начинающимся на "IVAN"

-- ============================================================================
-- ОТВЕТЫ НА ЗАДАНИЯ
-- ============================================================================

-- Задание 1
SELECT route_no, scheduled_arrival, actual_arrival
FROM flights
WHERE actual_arrival IS NULL
LIMIT 15;

-- Задание 2
SELECT airport_code, airport_name, city
FROM airports
WHERE city LIKE '%Санкт%';

-- или регистронезависимо
SELECT airport_code, airport_name, city
FROM airports
WHERE city ILIKE '%санкт%';

-- Задание 3
SELECT book_ref, book_date, total_amount
FROM bookings
WHERE total_amount BETWEEN 100000 AND 200000
ORDER BY total_amount
LIMIT 15;

-- Задание 4
SELECT DISTINCT route_no
FROM routes
WHERE route_no LIKE 'SU%'
   OR route_no LIKE 'S7%'
   OR route_no LIKE 'U6%'
ORDER BY route_no
LIMIT 20;

-- Или с IN и подстрокой:
SELECT DISTINCT route_no
FROM routes
WHERE substring(route_no, 1, 2) IN ('SU', 'S7', 'U6')
ORDER BY route_no
LIMIT 20;

-- Задание 5
SELECT ticket_no, passenger_name
FROM tickets
WHERE passenger_name LIKE 'IVAN %'
LIMIT 15;

-- ============================================================================
-- ДОМАШНИЕ ЗАДАНИЯ
-- ============================================================================

-- ДЗ 1: Рейсы, которые вылетели, но ещё не прибыли
SELECT route_no, actual_departure, actual_arrival, status
FROM flights
WHERE actual_departure IS NOT NULL
  AND actual_arrival IS NULL
LIMIT 20;

-- ДЗ 2: Аэропорты с "International" в названии
SELECT airport_code, airport_name, city
FROM airports
WHERE airport_name ILIKE '%international%';

-- ДЗ 3: Бронирования НЕ в диапазоне 10 000 - 50 000
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount NOT BETWEEN 10000 AND 50000
ORDER BY total_amount
LIMIT 20;

-- ДЗ 4: Города, заканчивающиеся на "ск"
SELECT DISTINCT city
FROM airports
WHERE city LIKE '%ск'
ORDER BY city;

-- ДЗ 5: Фактическое или плановое время прибытия
SELECT
    route_no,
    scheduled_arrival,
    actual_arrival,
    COALESCE(actual_arrival, scheduled_arrival) AS arrival_time,
    CASE
        WHEN actual_arrival IS NOT NULL THEN 'Факт'
        ELSE 'План'
    END AS arrival_type
FROM flights
LIMIT 15;
