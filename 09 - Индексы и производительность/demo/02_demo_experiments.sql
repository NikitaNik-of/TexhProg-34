-- ============================================================================
-- ПРАКТИЧЕСКАЯ РАБОТА №9: ИНДЕКСЫ И ПРОИЗВОДИТЕЛЬНОСТЬ В POSTGRESQL
-- ДЕМОНСТРАЦИЯ ПРЕПОДАВАТЕЛЯ (База: club_demo)
-- Скрипт №2: Пошаговые эксперименты в DBeaver (запускайте через Ctrl+Enter)
-- ============================================================================
-- Подсказка для DBeaver: поставьте курсор на любой SELECT и нажмите Ctrl+Shift+E,
-- чтобы открыть графическую диаграмму плана выполнения (Explain Execution Plan).

-- ============================================================================
-- ВВОДНЫЙ ЭКСПЕРИМЕНТ: Почему на 100 строках индекс не используется
-- ============================================================================
-- Если в таблице всего 100 строк, она помещается в 1 страницу диска (8 КБ).
-- Планировщик видит, что быстрее прочитать всю таблицу целиком (Seq Scan),
-- чем сначала читать страницу индекса, а потом переходить в таблицу.

DROP TABLE IF EXISTS tiny_test;
CREATE TABLE tiny_test (id SERIAL PRIMARY KEY, code INTEGER);
INSERT INTO tiny_test (code) SELECT gs FROM generate_series(1, 100) AS gs;
CREATE INDEX idx_tiny_code ON tiny_test(code);
ANALYZE tiny_test;

EXPLAIN ANALYZE
SELECT * FROM tiny_test WHERE code = 42;
-- В плане будет Seq Scan (несмотря на наличие индекса idx_tiny_code)!

DROP TABLE IF EXISTS tiny_test;


-- ============================================================================
-- ЭКСПЕРИМЕНТ 1: Точечный поиск на 200 000 строк (Seq Scan -> Index Scan)
-- ============================================================================

-- 1.1. Замер ДО создания индекса (ожидаем Seq Scan, ~20-40 мс):
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 500;

-- 1.2. Создаем B-Tree индекс на столбец user_id:
CREATE INDEX idx_orders_user_id ON orders(user_id);
ANALYZE orders;

-- 1.3. Замер ПОСЛЕ создания индекса (ожидаем Bitmap Index Scan / Index Scan, ~0.1-0.3 мс):
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 500;


-- ============================================================================
-- ЭКСПЕРИМЕНТ 2: Сортировка и пагинация (Убираем узел Sort)
-- ============================================================================

-- 2.1. Запрос с сортировкой при одном индексе idx_orders_user_id:
-- Обратите внимание на узел "Sort (Sort Method: top-N heapsort)" в плане!
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE user_id = 500
ORDER BY order_date DESC
LIMIT 5;

-- 2.2. Создаем составной индекс под фильтр + порядок сортировки:
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date DESC);
ANALYZE orders;

-- 2.3. Повторяем запрос — узел Sort исчез из плана!
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE user_id = 500
ORDER BY order_date DESC
LIMIT 5;


-- ============================================================================
-- ЭКСПЕРИМЕНТ 3: Цена индексов — замедление операции INSERT
-- ============================================================================

-- 3.1. Создаем две пустые копии таблицы: без индексов и с 3 индексами:
DROP TABLE IF EXISTS bench_no_idx;
DROP TABLE IF EXISTS bench_with_idx;

CREATE TABLE bench_no_idx AS SELECT * FROM orders WITH NO DATA;
CREATE TABLE bench_with_idx AS SELECT * FROM orders WITH NO DATA;

CREATE INDEX idx_b_user   ON bench_with_idx(user_id);
CREATE INDEX idx_b_date   ON bench_with_idx(order_date);
CREATE INDEX idx_b_status ON bench_with_idx(status);

-- 3.2. Вставка 50 000 строк БЕЗ индексов:
EXPLAIN ANALYZE
INSERT INTO bench_no_idx SELECT * FROM orders LIMIT 50000;

-- 3.3. Вставка 50 000 строк С 3 индексами (будет в 3-5 раз медленнее!):
EXPLAIN ANALYZE
INSERT INTO bench_with_idx SELECT * FROM orders LIMIT 50000;

-- 3.4. Очистка временных таблиц:
DROP TABLE IF EXISTS bench_no_idx;
DROP TABLE IF EXISTS bench_with_idx;


-- ============================================================================
-- ЭКСПЕРИМЕНТ 4: Частичный индекс (Partial Index) и замер размера на диске
-- ============================================================================

-- 4.1. Создаем индекс только по отмененным заказам (5% от всей таблицы):
CREATE INDEX idx_orders_cancelled ON orders(user_id) WHERE status = 'cancelled';
ANALYZE orders;

-- 4.2. Сравниваем размер полного и частичного индексов:
SELECT
    pg_size_pretty(pg_relation_size('idx_orders_user_id'))   AS "Полный индекс (user_id)",
    pg_size_pretty(pg_relation_size('idx_orders_user_date')) AS "Составной (user_id, date)",
    pg_size_pretty(pg_relation_size('idx_orders_cancelled')) AS "Частичный (cancelled)";

-- 4.3. Убеждаемся, что при поиске отмен планировщик берет именно частичный индекс:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 500 AND status = 'cancelled';
