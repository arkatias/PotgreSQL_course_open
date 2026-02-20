-- ============================================================================
-- ПАРА 2: Основы SELECT и порядок выполнения запроса
-- Демонстрационный скрипт
-- ============================================================================

-- ============================================================================
-- ЧАСТЬ 1: Порядок выполнения запроса
-- ============================================================================

-- Логический порядок выполнения:
-- 1. FROM    - определяем источник данных
-- 2. WHERE   - фильтруем строки
-- 3. GROUP BY - группируем (если нужно)
-- 4. HAVING  - фильтруем группы
-- 5. SELECT  - выбираем колонки
-- 6. ORDER BY - сортируем
-- 7. LIMIT   - ограничиваем количество

-- Демонстрация: почему алиасы не работают в WHERE
-- Этот запрос вызовет ошибку:
SELECT route_no, departure_airport AS dep
FROM routes
WHERE dep = 'SVO'
LIMIT 5;-- ❌ column "dep" does not exist

-- Правильный вариант:
SELECT route_no, departure_airport AS dep
FROM routes
WHERE departure_airport = 'SVO'
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 2: Базовый SELECT
-- ============================================================================

-- Выбор всех колонок
SELECT * FROM airports LIMIT 5;

-- Выбор конкретных колонок
SELECT airport_code, airport_name, city
FROM airports
LIMIT 5;

-- Подсчёт количества строк
SELECT count(*) FROM airports;
SELECT count(*) FROM flights;

-- ============================================================================
-- ЧАСТЬ 3: Псевдонимы (AS)
-- ============================================================================

-- Псевдонимы для колонок
SELECT
    airport_code AS code,
    airport_name AS name,
    city
FROM airports
LIMIT 5;

-- Псевдонимы с пробелами (в двойных кавычках)
SELECT
    airport_code AS "Код",
    airport_name AS "Название аэропорта",
    city AS "Город"
FROM airports
LIMIT 5;

-- Псевдоним без AS (работает, но менее читаемо)
SELECT
    airport_code code,
    airport_name name
FROM airports
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 4: Вычисления и выражения в SELECT
-- ============================================================================

-- Арифметические выражения
SELECT
    book_ref,
    total_amount,
    total_amount * 0.2 AS vat_amount,          -- НДС 20%
    total_amount * 1.2 AS total_with_vat       -- Сумма с НДС
FROM bookings
LIMIT 5;

-- Работа с датами
SELECT
    route_no,
    scheduled_departure,
    scheduled_arrival,
    scheduled_arrival - scheduled_departure AS flight_duration
FROM flights
LIMIT 5;

-- Конкатенация строк
SELECT
    airport_code || ' - ' || airport_name AS airport_info
FROM airports
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 5: Фильтрация с WHERE
-- ============================================================================

-- Простое условие равенства
SELECT route_no, status
FROM flights
WHERE status = 'Cancelled'
LIMIT 10;

-- Условие неравенства
SELECT route_no, status
FROM flights
WHERE status != 'Cancelled'
LIMIT 10;

-- Альтернативный синтаксис неравенства
SELECT route_no, status
FROM flights
WHERE status <> 'Cancelled'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 6: Операторы сравнения
-- ============================================================================

-- Рейсы на определённую дату (больше или равно)
SELECT route_no, scheduled_departure
FROM flights
WHERE scheduled_departure >= '2025-10-01'
  AND scheduled_departure < '2025-10-02'
LIMIT 10;

-- Бронирования дороже 100 000 рублей
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount > 100000
LIMIT 10;

-- Бронирования от 50 000 до 100 000 рублей
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount >= 50000
  AND total_amount <= 100000
LIMIT 10;

-- Самолёты с дальностью полёта более 5000 км
SELECT airplane_code, model, range
FROM airplanes
WHERE range > 5000
limit 10;

-- ============================================================================
-- ЧАСТЬ 7: Логический оператор AND
-- ============================================================================

-- Маршруты из SVO в LED
SELECT
    route_no,
    departure_airport,
    arrival_airport
FROM routes
WHERE departure_airport = 'SVO'
  AND arrival_airport = 'LED'
LIMIT 1000;

-- Рейсы со статусом Arrived за определённый период
SELECT
    route_no,
    status,
    scheduled_departure
FROM flights
WHERE status = 'Arrived'
  AND scheduled_departure >= '2025-11-01'
LIMIT 10;

-- Несколько условий с AND (маршруты определённого самолёта)
SELECT
    route_no,
    departure_airport,
    arrival_airport,
    airplane_code
FROM routes
WHERE departure_airport = 'SVO'
  AND arrival_airport = 'LED'
  AND airplane_code = '77W'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 8: Логический оператор OR
-- ============================================================================

-- Рейсы со статусом Cancelled ИЛИ Delayed
SELECT route_no, status
FROM flights
WHERE status = 'Cancelled'
   OR status = 'Delayed'
LIMIT 1000;

-- Маршруты из московских аэропортов (SVO, DME, VKO)
SELECT
    route_no,
    departure_airport,
    arrival_airport
FROM routes
WHERE departure_airport = 'SVO'
   OR departure_airport = 'DME'
   OR departure_airport = 'VKO'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 9: Логический оператор NOT
-- ============================================================================

-- Рейсы, которые НЕ отменены
SELECT route_no, status
FROM flights
WHERE NOT status = 'Cancelled'
LIMIT 10;

-- Эквивалентно:
SELECT route_no, status
FROM flights
WHERE status != 'Cancelled'
LIMIT 10;

-- NOT с более сложным условием
SELECT route_no, status, scheduled_departure
FROM flights
WHERE NOT (status = 'Cancelled' OR status = 'Delayed')
LIMIT 1000;

-- ============================================================================
-- ЧАСТЬ 10: Приоритет операторов и скобки
-- ============================================================================

-- ⚠️ ВНИМАНИЕ: AND имеет приоритет над OR!

-- Это может быть НЕ тем, что вы хотели:
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE departure_airport = 'SVO' OR departure_airport = 'DME'
  AND arrival_airport = 'LED'
LIMIT 10;

-- Выполнится как:
-- WHERE departure_airport = 'SVO' OR (departure_airport = 'DME' AND arrival_airport = 'LED')

-- Если нужно "из SVO или DME в LED":
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE (departure_airport = 'SVO' OR departure_airport = 'DME')
  AND arrival_airport = 'LED'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 11: Комплексные условия
-- ============================================================================

-- Маршруты из Москвы (SVO или DME) в Санкт-Петербург (LED)
SELECT
    route_no,
    departure_airport AS "Откуда",
    arrival_airport AS "Куда",
    airplane_code AS "Самолёт"
FROM routes
WHERE (departure_airport = 'SVO' OR departure_airport = 'DME')
  AND arrival_airport = 'LED'
LIMIT 15;

-- Рейсы: прибывшие или вылетевшие за период
SELECT route_no, status, scheduled_departure
FROM flights
WHERE (status = 'Arrived' OR status = 'Departed')
  AND scheduled_departure >= '2025-11-01'
LIMIT 15;

-- Бронирования: дорогие (>100000) ИЛИ недавние
SELECT book_ref, book_date, total_amount
FROM bookings
WHERE total_amount > 100000
   OR book_date >= '2025-11-01'
LIMIT 10;

-- ============================================================================
-- ЧАСТЬ 12: Псевдонимы таблиц
-- ============================================================================

-- Длинные имена таблиц можно сокращать
SELECT
    f.route_no,
    f.status,
    f.scheduled_departure
FROM flights AS f
WHERE f.status = 'Departed'
LIMIT 5;

-- AS можно опустить
SELECT
    r.route_no,
    r.departure_airport
FROM routes r
WHERE r.departure_airport = 'SVO'
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 13: Исследование данных
-- ============================================================================

-- Какие статусы существуют в таблице flights?
SELECT DISTINCT status
FROM flights;

-- Какие аэропорты отправления есть?
SELECT DISTINCT departure_airport
FROM routes
ORDER BY departure_airport
LIMIT 20;

-- Сколько рейсов в каждом статусе?
SELECT status, count(*) AS count
FROM flights
GROUP BY status
ORDER BY count DESC;

-- Топ-10 направлений по количеству маршрутов
SELECT
    departure_airport,
    arrival_airport,
    count(*) AS routes_count
FROM routes
GROUP BY departure_airport, arrival_airport
ORDER BY routes_count DESC
LIMIT 1000;

-- ============================================================================
-- ПРАКТИЧЕСКИЕ ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Вывести все аэропорты города Москва
-- Подсказка: используйте WHERE city = ...

-- Задание 2: Найти все рейсы маршрута PG0404
-- Подсказка: используйте таблицу flights и колонку route_no

-- Задание 3: Вывести маршруты из Шереметьево (SVO) в Пулково (LED)

-- Задание 4: Найти бронирования дороже 200 000 рублей

-- Задание 5: Вывести маршруты из SVO или DME

-- ============================================================================
-- ОТВЕТЫ НА ЗАДАНИЯ
-- ============================================================================

-- Задание 1: Аэропорты Москвы
SELECT *
FROM airports
WHERE city = 'Moscow';
--выборка из вьюхи

-- Задание 2: Рейсы маршрута PG0404
SELECT *
FROM flights
WHERE route_no = 'PG0404'
LIMIT 10;

-- Задание 3: Маршруты из SVO в LED
SELECT *
FROM routes
WHERE departure_airport = 'SVO'
  AND arrival_airport = 'LED';

-- Задание 4: Бронирования дороже 200 000
SELECT book_ref, book_date, total_amount
FROM bookings
WHERE total_amount > 200000
LIMIT 10;

-- Задание 5: Маршруты из SVO или DME
SELECT route_no, departure_airport, arrival_airport
FROM routes
WHERE departure_airport = 'SVO' OR departure_airport = 'DME'
LIMIT 15;

-- ============================================================================
-- ДОМАШНИЕ ЗАДАНИЯ
-- ============================================================================

-- ДЗ 1: Вывести все рейсы самолёта Boeing 737 MAX 7 (airplane_code = '7M7')
SELECT route_no, airplane_code, departure_airport, arrival_airport
FROM routes
WHERE airplane_code = '7M7'
LIMIT 20;

-- ДЗ 2: Найти бронирования от 50 000 до 150 000 рублей
SELECT book_ref, total_amount
FROM bookings
WHERE total_amount >= 50000
  AND total_amount <= 150000
LIMIT 20;

-- ДЗ 3: Вывести рейсы, которые НЕ прибыли (статус не Arrived)
SELECT route_no, status
FROM flights
WHERE status != 'Arrived'
LIMIT 20;

-- ДЗ 4: Найти все аэропорты не в Москве
SELECT airport_code, airport_name, city
FROM airports
WHERE city != 'Moscow';
