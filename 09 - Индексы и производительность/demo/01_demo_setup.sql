-- ============================================================================
-- ПРАКТИЧЕСКАЯ РАБОТА №9: ИНДЕКСЫ И ПРОИЗВОДИТЕЛЬНОСТЬ В POSTGRESQL
-- ДЕМОНСТРАЦИЯ ПРЕПОДАВАТЕЛЯ (База: club_demo)
-- Скрипт №1: Подготовка таблицы-полигона orders на 200 000 строк
-- ============================================================================
-- В DBeaver: выделите весь скрипт (Ctrl+A) и выполните через Alt+X.

DROP TABLE IF EXISTS bench_with_idx CASCADE;
DROP TABLE IF EXISTS bench_no_idx CASCADE;
DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL,
    order_date  TIMESTAMP NOT NULL,
    status      VARCHAR(20) NOT NULL,
    amount      NUMERIC(10, 2) NOT NULL
);

-- Генерация 200 000 строк встроенной функцией generate_series() за 1-2 секунды:
-- user_id от 1 до 2000 (~100 заказов на одного пользователя)
-- 85% 'delivered', 10% 'paid', 5% 'cancelled'
INSERT INTO orders (user_id, order_date, status, amount)
SELECT
    (floor(random() * 2000) + 1)::INTEGER,
    NOW() - (random() * 365) * INTERVAL '1 day',
    CASE
        WHEN gs % 20 = 0 THEN 'cancelled'
        WHEN gs % 10 = 1 THEN 'paid'
        ELSE 'delivered'
    END,
    ROUND((random() * 4900 + 100)::NUMERIC, 2)
FROM generate_series(1, 200000) AS gs;

-- Обновляем статистику таблицы для оптимизатора запросов
ANALYZE orders;

-- Контрольная проверка:
SELECT status, COUNT(*) AS rows_cnt
FROM orders
GROUP BY status
ORDER BY rows_cnt DESC;
