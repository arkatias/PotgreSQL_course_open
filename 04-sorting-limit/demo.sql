-- ============================================================================
-- ПАРА 4: Сортировка и ограничение результатов
-- Демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: ORDER BY — основы
-- ============================================================================

-- Без ORDER BY порядок строк не гарантирован!
SELECT route_no, scheduled_departure
FROM flights
LIMIT 5;

-- Выполните несколько раз — результат может быть разным

-- С ORDER BY — предсказуемый результат
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 2: ASC и DESC
-- ============================================================================

-- ASC — по возрастанию (значение по умолчанию)
SELECT book_ref, total_amount
FROM bookings
ORDER BY total_amount ASC
LIMIT 10;

-- Можно не писать ASC
SELECT book_ref, total_amount
FROM bookings
ORDER BY total_amount
LIMIT 10;

-- DESC — по убыванию
SELECT book_ref, total_amount
FROM bookings
ORDER BY total_amount DESC
LIMIT 10;

-- Сортировка дат
-- Самые ранние рейсы
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure ASC
LIMIT 10;

-- Самые поздние рейсы
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 3: Сортировка строк
-- ============================================================================

-- Алфавитный порядок
SELECT DISTINCT city
FROM airports
ORDER BY city ASC;

-- Обратный алфавитный порядок
SELECT DISTINCT city
FROM airports
ORDER BY city DESC;

-- Сортировка кодов аэропортов
SELECT airport_code, airport_name
FROM airports
ORDER BY airport_code;

-- ============================================================================
-- ЧАСТЬ 4: Сортировка по нескольким колонкам
-- ============================================================================

-- Сначала по городу, потом по названию аэропорта
SELECT city, airport_code, airport_name
FROM airports
ORDER BY city, airport_name
LIMIT 100;

-- Город по возрастанию, название по убыванию
SELECT city, airport_code, airport_name
FROM airports
ORDER BY city ASC, airport_name DESC
LIMIT 100;

-- Маршруты: сначала по аэропорту вылета, потом по аэропорту прилёта
SELECT
    departure_airport,
    arrival_airport,
    airplane_code
FROM routes
ORDER BY departure_airport ASC, arrival_airport ASC
LIMIT 20;

-- Три уровня сортировки
SELECT
    departure_airport,
    arrival_airport,
    airplane_code
FROM routes
ORDER BY departure_airport, arrival_airport, airplane_code
LIMIT 20;

-- ============================================================================
-- ЧАСТЬ 5: NULL в сортировке
-- ============================================================================

-- По умолчанию NULL = наибольшее значение в PostgreSQL

-- ASC: NULL в конце
SELECT route_no, actual_departure
FROM flights
ORDER BY actual_departure ASC
LIMIT 100;

-- DESC: NULL в начале
SELECT route_no, actual_departure
FROM flights
ORDER BY actual_departure DESC
LIMIT 10;

-- NULLS FIRST — NULL в начале
SELECT route_no, actual_departure
FROM flights
ORDER BY actual_departure ASC NULLS FIRST
LIMIT 10;

-- NULLS LAST — NULL в конце
SELECT route_no, actual_departure
FROM flights
ORDER BY actual_departure DESC NULLS LAST
LIMIT 10;

-- Комбинация с несколькими колонками
SELECT route_no, status, actual_departure
FROM flights
ORDER BY status, actual_departure NULLS LAST
LIMIT 20;


-- ============================================================================
-- ЧАСТЬ 6: Сортировка по номеру колонки и алиасу
-- ============================================================================

-- По номеру колонки (не рекомендуется!)
SELECT route_no, departure_airport, arrival_airport
FROM routes
ORDER BY 2, 3
LIMIT 10;

-- По псевдониму (алиасу) — рекомендуется
SELECT
    departure_airport AS dep,
    arrival_airport AS arr,
    count(*) AS cnt
FROM routes
GROUP BY departure_airport, arrival_airport
ORDER BY cnt DESC
LIMIT 10;

-- Сортировка по выражению
SELECT
    route_no,
    scheduled_departure,
    scheduled_arrival,
    scheduled_arrival - scheduled_departure AS duration
FROM flights
ORDER BY scheduled_arrival - scheduled_departure DESC
LIMIT 10;

-- Или по алиасу выражения
SELECT
    route_no,
    scheduled_arrival - scheduled_departure AS duration
FROM flights
ORDER BY duration DESC
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 7: LIMIT
-- ============================================================================

-- Ограничение количества строк
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 10;

-- Топ-5 самых дорогих бронирований
SELECT book_ref, total_amount
FROM bookings
ORDER BY total_amount DESC
LIMIT 5;

-- Топ-3 самых загруженных аэропортов (по количеству маршрутов)
SELECT
    departure_airport,
    count(*) AS routes_count
FROM routes
GROUP BY departure_airport
ORDER BY routes_count DESC
LIMIT 3;

-- ⚠️ LIMIT без ORDER BY — непредсказуемый результат
SELECT * FROM flights LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 8: OFFSET — пагинация
-- ============================================================================

-- Страница 1 (первые 10)
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 10 OFFSET 0;

-- Страница 2 (пропустить 10, взять 10)
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 10 OFFSET 10;

-- Страница 3
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 10 OFFSET 20;

-- Формула: OFFSET = (page_number - 1) * page_size
-- Страница 5 при page_size = 15
SELECT route_no, scheduled_departure
FROM flights
ORDER BY scheduled_departure
LIMIT 15 OFFSET 60;  -- (5-1) * 15 = 60

-- ============================================================================
-- ЧАСТЬ 9: Пагинация — практический пример
-- ============================================================================

-- Список аэропортов с пагинацией (по 5 на страницу)

-- Страница 1
SELECT airport_code, airport_name, city
FROM airports
ORDER BY city, airport_name
LIMIT 5 OFFSET 0;

-- Страница 2
SELECT airport_code, airport_name, city
FROM airports
ORDER BY city, airport_name
LIMIT 5 OFFSET 5;

-- Страница 3
SELECT airport_code, airport_name, city
FROM airports
ORDER BY city, airport_name
LIMIT 5 OFFSET 10;

-- Общее количество страниц
SELECT
    count(*) AS total_records,
    ceil(count(*)::numeric / 5) AS total_pages
FROM airports;

-- ============================================================================
-- ЧАСТЬ 10: Keyset Pagination (лучший способ)
-- ============================================================================

-- Проблема OFFSET: для OFFSET 1000000 нужно прочитать миллион строк

-- Keyset pagination — используем последний известный ключ
-- Первая страница
SELECT flight_id, route_no, scheduled_departure
FROM flights
ORDER BY flight_id
LIMIT 10;

-- Следующая страница (предположим, последний flight_id был 10)
SELECT flight_id, route_no, scheduled_departure
FROM flights
WHERE flight_id > 10
ORDER BY flight_id
LIMIT 10;

-- Следующая страница (последний flight_id был 20)
SELECT flight_id, route_no, scheduled_departure
FROM flights
WHERE flight_id > 20
ORDER BY flight_id
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 11: DISTINCT — уникальные значения
-- ============================================================================

-- Все уникальные города
SELECT DISTINCT city
FROM airports
ORDER BY city;

-- Количество уникальных городов
SELECT count(DISTINCT city) AS unique_cities
FROM airports;

-- Все уникальные статусы рейсов
SELECT DISTINCT status
FROM flights;

-- Уникальные модели самолётов
SELECT DISTINCT model
FROM airplanes
ORDER BY model;

-- ============================================================================
-- ЧАСТЬ 12: DISTINCT по нескольким колонкам
-- ============================================================================

-- Уникальные комбинации город + код аэропорта
SELECT DISTINCT city, airport_code
FROM airports
ORDER BY city, airport_code;

-- Уникальные направления (откуда → куда)
SELECT DISTINCT departure_airport, arrival_airport
FROM routes
ORDER BY departure_airport, arrival_airport
LIMIT 20;

-- Сколько уникальных направлений?
SELECT count(DISTINCT (departure_airport, arrival_airport)) AS directions
FROM routes;

-- ============================================================================
-- ЧАСТЬ 13: DISTINCT vs GROUP BY
-- ============================================================================

-- DISTINCT для уникальных значений
SELECT DISTINCT status
FROM flights
ORDER BY status;

-- GROUP BY — эквивалентно для уникальных значений
SELECT status
FROM flights
GROUP BY status
ORDER BY status;

-- Но GROUP BY позволяет агрегацию:
SELECT status, count(*) AS cnt
FROM flights
GROUP BY status
ORDER BY cnt DESC;

-- ============================================================================
-- ЧАСТЬ 14: DISTINCT ON (специфика PostgreSQL)
-- ============================================================================

-- DISTINCT ON — первая строка из каждой группы

-- Первый рейс каждого маршрута (по времени вылета)
SELECT DISTINCT ON (route_no)
    route_no,
    scheduled_departure,
    status
FROM flights
ORDER BY route_no, scheduled_departure
LIMIT 15;

-- ⚠️ ORDER BY должен начинаться с колонок из DISTINCT ON

-- Последний рейс каждого маршрута
SELECT DISTINCT ON (route_no)
    route_no,
    scheduled_departure,
    status
FROM flights
ORDER BY route_no, scheduled_departure DESC
LIMIT 15;

-- Для каждого аэропорта отправления — первый маршрут по алфавиту
SELECT DISTINCT ON (departure_airport)
    departure_airport,
    arrival_airport,
    route_no,
    airplane_code
FROM routes
ORDER BY departure_airport, route_no
LIMIT 15;

-- ============================================================================
-- ЧАСТЬ 15: DISTINCT ON — сложные примеры
-- ============================================================================

-- Самое раннее бронирование каждого дня
SELECT DISTINCT ON (book_date::date)
    book_date::date AS booking_day,
    book_ref,
    book_date,
    total_amount
FROM bookings
ORDER BY book_date::date, book_date
LIMIT 10;

-- Самое дорогое бронирование каждого дня
SELECT DISTINCT ON (book_date::date)
    book_date::date AS booking_day,
    book_ref,
    total_amount
FROM bookings
ORDER BY book_date::date, total_amount DESC
LIMIT 10;

-- Первый маршрут каждой авиакомпании (по первым 4 символам route_no)
SELECT DISTINCT ON (substring(route_no, 1, 4))
    substring(route_no, 1, 3) AS airline,
    route_no,
    departure_airport,
    arrival_airport
FROM routes
ORDER BY substring(route_no, 1, 4), route_no
LIMIT 10;

-- ============================================================================
-- ПРАКТИЧЕСКИЕ ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Топ-10 самых дорогих бронирований

-- Задание 2: 5 самых ранних рейсов августа 2026

-- Задание 3: Уникальные модели самолётов
-- (пишем как запрос к таблице airplanes, поле содержащее модель самолета - model)

-- Задание 4: Страница 3 списка аэропортов (по 5 на страницу)
-- (пишем как запрос к таблице airports, поля для вывода - airport_code, airport_name, city)

-- Задание 5: Самые ранние планируемые прилеты в каждый аэропорт (DISTINCT ON)

-- ============================================================================
-- ОТВЕТЫ НА ЗАДАНИЯ
-- ============================================================================

-- Задание 1
SELECT book_ref, book_date, total_amount
FROM bookings
ORDER BY total_amount DESC
LIMIT 10;

-- Задание 2
SELECT route_no, scheduled_departure
FROM flights
WHERE scheduled_departure >= '2026-08-01'
  AND scheduled_departure < '2026-09-01'
ORDER BY scheduled_departure ASC
LIMIT 5;

-- Задание 3
SELECT DISTINCT model
FROM airplanes
ORDER BY model;

-- Альтернатива при работе, но нужен JSON
SELECT DISTINCT jsonb_extract_path_text(model, 'en') AS unique_model_en,
               jsonb_extract_path_text(model, 'ru') AS unique_model_ru
FROM airplanes_data;

-- Задание 4
SELECT airport_code, airport_name, city
FROM airports
ORDER BY airport_name
LIMIT 5 OFFSET 10;  -- (3-1) * 5 = 10

-- Задание 5
SELECT DISTINCT ON (arrival_airport)
    arrival_airport,
    departure_airport,
    route_no,
    scheduled_time + duration as arrival_time
FROM routes
ORDER BY arrival_airport, scheduled_time + duration;
