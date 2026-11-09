-- ============================================================================
-- ПРАКТИЧЕСКАЯ РАБОТА №8: ПЕРЕНОС ИЗ SQLite В POSTGRESQL И РАБОТА В DBEAVER
-- ДЕМОНСТРАЦИОННЫЙ ВАРИАНТ ПРЕПОДАВАТЕЛЯ (База: club_demo / Схема: public)
-- Скрипт №1: Компактная схема из 6 таблиц (по 4–5 колонок) на диалекте PostgreSQL
-- ============================================================================
-- Сравните этот скрипт с файлом 00_sqlite_legacy_schema.sql!
-- В DBeaver: нажмите Alt+X (Выполнить весь скрипт), затем нажмите F5 на схеме public
-- и откройте вкладку "ER-диаграмма".

DROP TABLE IF EXISTS tournament_entries CASCADE;
DROP TABLE IF EXISTS bar_orders CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS pcs CASCADE;
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS tariffs CASCADE;

-- ============================================================================
-- 1. Таблица tariffs (Тарифные зоны клуба — 4 колонки)
-- ============================================================================
-- ПЕРЕВОД ИЗ SQLite В POSTGRESQL:
-- * INTEGER PRIMARY KEY AUTOINCREMENT  -->  SERIAL PRIMARY KEY
-- * TEXT                               -->  VARCHAR(20) (строгий лимит 20 символов!)
-- * REAL                               -->  NUMERIC(8, 2) (точная цена без потери копеек)
-- * INTEGER DEFAULT 0                  -->  BOOLEAN DEFAULT FALSE (настоящий булев тип)
CREATE TABLE tariffs (
    tariff_id   SERIAL        PRIMARY KEY,
    zone_name   VARCHAR(20)   NOT NULL UNIQUE,
    hourly_rate NUMERIC(8, 2) NOT NULL CONSTRAINT chk_tariff_rate CHECK (hourly_rate > 0),
    is_vip      BOOLEAN       NOT NULL DEFAULT FALSE
);

-- ============================================================================
-- 2. Таблица members (Игроки клуба — 5 колонок)
-- ============================================================================
-- ПЕРЕВОД ИЗ SQLite В POSTGRESQL:
-- * TEXT (для даты 'YYYY-MM-DD')       -->  DATE (настоящий календарный тип!)
-- * Именованное ограничение CONSTRAINT chk_member_balance CHECK (balance >= 0)
CREATE TABLE members (
    member_id   SERIAL         PRIMARY KEY,
    nickname    VARCHAR(30)    NOT NULL UNIQUE,
    balance     NUMERIC(10, 2) NOT NULL DEFAULT 0.00
                CONSTRAINT chk_member_balance CHECK (balance >= 0),
    is_verified BOOLEAN        NOT NULL DEFAULT FALSE,
    reg_date    DATE           NOT NULL DEFAULT CURRENT_DATE
);

-- ============================================================================
-- 3. Таблица pcs (Компьютеры — 5 колонок)
-- ============================================================================
-- ПЕРЕВОД ИЗ SQLite В POSTGRESQL:
-- * INTEGER (для малых чисел ОЗУ)      -->  SMALLINT (2 байта вместо 4)
-- * Внешний ключ REFERENCES tariffs(tariff_id) работает ВСЕГДА (без PRAGMA!)
CREATE TABLE pcs (
    pc_id     SERIAL      PRIMARY KEY,
    pc_code   VARCHAR(10) NOT NULL UNIQUE,
    tariff_id INTEGER     NOT NULL REFERENCES tariffs(tariff_id) ON DELETE RESTRICT,
    ram_gb    SMALLINT    NOT NULL CONSTRAINT chk_pc_ram CHECK (ram_gb IN (16, 32, 64)),
    is_active BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ============================================================================
-- 4. Таблица sessions (Игровые сессии — 5 колонок)
-- ============================================================================
-- ПЕРЕВОД ИЗ SQLite В POSTGRESQL:
-- * ON DELETE SET NULL: если игрока удалят из members, запись о сессии останется,
--   а поле member_id станет NULL.
-- * ON DELETE RESTRICT: нельзя удалить ПК из таблицы pcs, если на нем были сессии.
CREATE TABLE sessions (
    session_id   SERIAL   PRIMARY KEY,
    member_id    INTEGER  REFERENCES members(member_id) ON DELETE SET NULL,
    pc_id        INTEGER  NOT NULL REFERENCES pcs(pc_id) ON DELETE RESTRICT,
    hours        SMALLINT NOT NULL CONSTRAINT chk_session_hours CHECK (hours BETWEEN 1 AND 24),
    session_date DATE     NOT NULL DEFAULT CURRENT_DATE
);

-- ============================================================================
-- 5. Таблица bar_orders (Заказы в кибер-баре к игровому месту — 5 колонок)
-- ============================================================================
CREATE TABLE bar_orders (
    order_id     SERIAL        PRIMARY KEY,
    session_id   INTEGER       NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    item_name    VARCHAR(40)   NOT NULL,
    price        NUMERIC(8, 2) NOT NULL CONSTRAINT chk_bar_price CHECK (price > 0),
    is_delivered BOOLEAN       NOT NULL DEFAULT FALSE
);

-- ============================================================================
-- 6. Таблица tournament_entries (Заявки на турниры — 5 колонок, Medium/Hard)
--    [Замыкает кольцо связей между members и pcs на ER-диаграмме!]
-- ============================================================================
-- ПЕРЕВОД ИЗ SQLite В POSTGRESQL:
-- * Составное ограничение CONSTRAINT uq_member_game UNIQUE (member_id, game_title)
-- * ON DELETE CASCADE: при удалении игрока все его турнирные заявки удаляются сами.
CREATE TABLE tournament_entries (
    entry_id   SERIAL         PRIMARY KEY,
    member_id  INTEGER        NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    pc_id      INTEGER        NOT NULL REFERENCES pcs(pc_id) ON DELETE RESTRICT,
    game_title VARCHAR(40)    NOT NULL,
    prize      NUMERIC(10, 2) CONSTRAINT chk_entry_prize CHECK (prize IS NULL OR prize >= 0),
    CONSTRAINT uq_member_game UNIQUE (member_id, game_title)
);
