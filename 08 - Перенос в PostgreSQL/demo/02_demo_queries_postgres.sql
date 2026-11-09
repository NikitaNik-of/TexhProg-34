-- ============================================================================
-- ПРАКТИЧЕСКАЯ РАБОТА №8: ПЕРЕНОС ИЗ SQLite В POSTGRESQL И РАБОТА В DBEAVER
-- ДЕМОНСТРАЦИОННЫЙ ВАРИАНТ ПРЕПОДАВАТЕЛЯ (База: club_demo / Схема: public)
-- Скрипт №2: Наглядные однотабличные эксперименты (Отличия PostgreSQL от SQLite)
-- ============================================================================
-- В DBeaver: ставьте курсор на нужную команду и нажимайте Ctrl+Enter!

-- ============================================================================
-- ШАГ 1. СИНХРОНИЗАЦИЯ СЧЕТЧИКОВ SERIAL ПОСЛЕ ИМПОРТА ГОТОВЫХ ID ИЗ CSV
-- ============================================================================
-- Когда мы переносим строки со старыми ID (1..25) из SQLite/CSV в PostgreSQL,
-- внутренний счетчик SERIAL остается на 1. Подтянем его к максимальному ID:
SELECT setval(pg_get_serial_sequence('tariffs', 'tariff_id'), COALESCE(MAX(tariff_id), 1)) FROM tariffs;
SELECT setval(pg_get_serial_sequence('members', 'member_id'), COALESCE(MAX(member_id), 1)) FROM members;
SELECT setval(pg_get_serial_sequence('pcs', 'pc_id'), COALESCE(MAX(pc_id), 1)) FROM pcs;
SELECT setval(pg_get_serial_sequence('sessions', 'session_id'), COALESCE(MAX(session_id), 1)) FROM sessions;
SELECT setval(pg_get_serial_sequence('bar_orders', 'order_id'), COALESCE(MAX(order_id), 1)) FROM bar_orders;
SELECT setval(pg_get_serial_sequence('tournament_entries', 'entry_id'), COALESCE(MAX(entry_id), 1)) FROM tournament_entries;


-- ============================================================================
-- ШАГ 2. ЧЕТЫРЕ КРАШ-ТЕСТА: ЧТО ПРОЩАЛ SQLite, НО БЛОКИРУЕТ POSTGRESQL
-- ============================================================================

-- [ТЕСТ 1] Строгий контроль длины VARCHAR(10) в таблице pcs:
-- В SQLite строка из 25 символов спокойно вставлялась в VARCHAR(10).
-- В PostgreSQL получаем: ERROR: value too long for type character varying(10)
/*
INSERT INTO pcs (pc_code, tariff_id, ram_gb, is_active)
VALUES ('PC-SUPER-LONG-CODE-99999', 1, 16, TRUE);
*/

-- [ТЕСТ 2] Именованное ограничение CHECK (chk_pc_ram):
-- Попытка вставить компьютер с нестандартным объемом ОЗУ (24 ГБ вместо 16, 32, 64):
-- В PostgreSQL получаем: ERROR: new row for relation "pcs" violates check constraint "chk_pc_ram"
/*
INSERT INTO pcs (pc_code, tariff_id, ram_gb, is_active)
VALUES ('VIP-99', 3, 24, TRUE);
*/

-- [ТЕСТ 3] Кавычки в фильтрах: одинарные ('VIP') против двойных ("VIP"):
-- В SQLite двойные кавычки "VIP" воспринимались как строка.
-- В PostgreSQL двойные кавычки означают ИМЯ СТОЛБЦА!
-- Запрос ниже выдаст: ERROR: column "VIP" does not exist
/*
SELECT * FROM tariffs WHERE zone_name = "VIP";
*/

-- А вот так правильно в PostgreSQL (строки — строго в одинарных кавычках!):
SELECT tariff_id, zone_name AS "Название зоны", hourly_rate AS "Тариф (руб/ч)", is_vip
FROM tariffs
WHERE zone_name = 'VIP';


-- ============================================================================
-- ШАГ 3. ПРОСТЫЕ ОДНОТАБЛИЧНЫЕ ЗАПРОСЫ В POSTGRESQL (БЕЗ JOIN!)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.1. Регистрозависимый LIKE против регистронезависимого ILIKE
-- ----------------------------------------------------------------------------
-- В таблице bar_orders записано 'Coca-Cola Zero 0.5' с заглавных букв.
-- Обычный LIKE '%cola%' в PostgreSQL вернет 0 строк (пустую таблицу!):
SELECT * FROM bar_orders WHERE item_name LIKE '%cola%';

-- А оператор PostgreSQL ILIKE '%cola%' ищет без учета регистра:
SELECT order_id, session_id, item_name, price, is_delivered
FROM bar_orders
WHERE item_name ILIKE '%cola%';


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.2. Работа с настоящим типом BOOLEAN (TRUE / FALSE вместо 1 / 0)
-- ----------------------------------------------------------------------------
-- Выберем только активные ПК с объемом памяти от 32 ГБ:
SELECT pc_id, pc_code, tariff_id, ram_gb, is_active
FROM pcs
WHERE is_active = TRUE
  AND ram_gb >= 32
ORDER BY ram_gb DESC, pc_code;


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.3. Замена NULL через COALESCE (в PostgreSQL нет функции IFNULL!)
-- ----------------------------------------------------------------------------
-- В таблице tournament_entries у части игроков prize равен NULL (не заняли призовое место).
-- Заменим NULL на 0.00 с помощью стандартной функции COALESCE:
SELECT
    entry_id,
    member_id,
    game_title,
    prize                  AS "Приз (исходный с NULL)",
    COALESCE(prize, 0.00)  AS "Приз (через COALESCE)"
FROM tournament_entries
ORDER BY COALESCE(prize, 0.00) DESC
LIMIT 12;


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.4. Нативная арифметика дат (тип DATE вместо строк TEXT в SQLite)
-- ----------------------------------------------------------------------------
-- В PostgreSQL вычитание двух дат (CURRENT_DATE - reg_date) сразу дает целое число дней!
SELECT
    member_id,
    nickname,
    reg_date,
    CURRENT_DATE - reg_date AS "Дней в клубе",
    balance
FROM members
WHERE is_verified = TRUE
ORDER BY reg_date ASC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.5. Вставка строки с мгновенным возвратом результата (RETURNING)
-- ----------------------------------------------------------------------------
-- Вместо того чтобы делать INSERT, а потом отдельно искать новую строку через SELECT,
-- в PostgreSQL пишем RETURNING — и сразу видим присвоенный member_id и reg_date!
INSERT INTO members (nickname, balance, is_verified)
VALUES ('CyberAdmin_Demo', 2500.00, TRUE)
ON CONFLICT (nickname) DO UPDATE
    SET balance = members.balance + 500.00
RETURNING member_id, nickname, balance, is_verified, reg_date;


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.6. Лаконичный фильтр внутри агрегации FILTER (WHERE ...) на 1 таблице
-- ----------------------------------------------------------------------------
-- Посчитаем по одной таблице pcs статистику оборудования без громоздких CASE WHEN:
SELECT
    COUNT(*)                                      AS "Всего ПК в клубе",
    COUNT(*) FILTER (WHERE is_active = TRUE)      AS "Активных ПК",
    COUNT(*) FILTER (WHERE is_active = FALSE)     AS "На ремонте (неактивных)",
    COUNT(*) FILTER (WHERE ram_gb = 64)           AS "Топовых ПК (64 ГБ ОЗУ)"
FROM pcs;


-- ----------------------------------------------------------------------------
-- ПРИМЕР 3.7. Безопасная проверка каскадных правил (BEGIN ... ROLLBACK)
-- ----------------------------------------------------------------------------
-- Проверим, как работают ON DELETE SET NULL (в sessions) и ON DELETE CASCADE (в tournament_entries)
-- при удалении игрока member_id = 1, а затем отменим удаление командой ROLLBACK!
BEGIN;

DELETE FROM members WHERE member_id = 1;

-- В таблице sessions сами записи о сессиях сохранились, а member_id стал NULL:
SELECT session_id, member_id, pc_id, hours, session_date
FROM sessions
WHERE member_id IS NULL;

-- В таблице tournament_entries все заявки игрока 1 удалились автоматически:
SELECT COUNT(*) AS "Осталось заявок игрока №1"
FROM tournament_entries
WHERE member_id = 1;

-- Откатываем транзакцию — игрок №1 и все его связи мгновенно возвращаются на место!
ROLLBACK;
