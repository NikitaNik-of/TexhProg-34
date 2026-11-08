# Уровень 02 — Medium (6 таблиц)

> **Оценка:** до «4».
> **Исходные файлы:** шаблон `medium/sqlite_schema_medium.sql` и папка `medium/variant_XX/` (6 CSV-файлов, где `XX` — номер варианта `01`..`20`).
> **База на сервере:** `club_varXX` (логин `student_XX`, пароль `StudyPass2026_varXX`).

---

## Задание

Перенести в PostgreSQL схему из 6 таблиц (включая таблицу турнирных заявок `tournament_entries`) с именованными ограничениями `CONSTRAINT` и составным `UNIQUE`, загрузить данные, синхронизировать счетчики `SERIAL` и выполнить 5 однотабличных запросов в DBeaver.

---

## Шаг 1. Перевод 6 таблиц из SQLite в PostgreSQL

Откройте шаблон `medium/sqlite_schema_medium.sql` и переведите его на синтаксис PostgreSQL в редакторе SQL (`F3`):

1. Переведите первые 5 таблиц (`tariffs`, `members`, `pcs`, `sessions`, `bar_orders`), заменив типы данных и задав **имена всем ограничениям `CHECK`**:
   * `tariffs`: `CONSTRAINT chk_tariff_rate CHECK (hourly_rate > 0)`
   * `members`: `CONSTRAINT chk_member_balance CHECK (balance >= 0)`
   * `pcs`: `CONSTRAINT chk_pc_ram CHECK (ram_gb IN (16, 32, 64))`
   * `sessions`: `CONSTRAINT chk_session_hours CHECK (hours BETWEEN 1 AND 24)`
   * `bar_orders`: `CONSTRAINT chk_bar_price CHECK (price > 0)`
2. Добавьте 6-ю таблицу **`tournament_entries`** (связывает `members` и `pcs` и запрещает одному игроку дважды регистрироваться на одну игру):
   ```sql
   CREATE TABLE tournament_entries (
       entry_id   SERIAL         PRIMARY KEY,
       member_id  INTEGER        NOT NULL REFERENCES members(member_id),
       pc_id      INTEGER        NOT NULL REFERENCES pcs(pc_id),
       game_title VARCHAR(40)    NOT NULL,
       prize      NUMERIC(10, 2) CONSTRAINT chk_entry_prize CHECK (prize IS NULL OR prize >= 0),
       CONSTRAINT uq_member_game UNIQUE (member_id, game_title)
   );
   ```
3. **Работа в интерфейсе DBeaver:**
   * Откройте таблицу `tournament_entries` $\to$ вкладка **Свойства** $\to$ проверьте разделы **Ограничения** и **Внешние ключи**.
   * Откройте схему `public` $\to$ вкладка **ER-диаграмма** и сохраните схему из 6 таблиц в файл `er_diagram_varXX.png` (иконка дискеты на панели диаграммы).

---

## Шаг 2. Загрузка данных, синхронизация `SERIAL` и справочник внешних ключей

1. Загрузите 6 CSV-файлов из папки `medium/variant_XX/` в порядке:
   `tariffs` $\to$ `members` $\to$ `pcs` $\to$ `sessions` $\to$ `bar_orders` $\to$ `tournament_entries` (через импорт CSV в DBeaver или через Python с `if_exists="append"`).
2. Синхронизируйте счетчики `SERIAL` для всех 6 таблиц:
   ```sql
   SELECT setval(pg_get_serial_sequence('tariffs', 'tariff_id'), COALESCE(MAX(tariff_id), 1)) FROM tariffs;
   SELECT setval(pg_get_serial_sequence('members', 'member_id'), COALESCE(MAX(member_id), 1)) FROM members;
   SELECT setval(pg_get_serial_sequence('pcs', 'pc_id'), COALESCE(MAX(pc_id), 1)) FROM pcs;
   SELECT setval(pg_get_serial_sequence('sessions', 'session_id'), COALESCE(MAX(session_id), 1)) FROM sessions;
   SELECT setval(pg_get_serial_sequence('bar_orders', 'order_id'), COALESCE(MAX(order_id), 1)) FROM bar_orders;
   SELECT setval(pg_get_serial_sequence('tournament_entries', 'entry_id'), COALESCE(MAX(entry_id), 1)) FROM tournament_entries;
   ```
3. **Работа в интерфейсе DBeaver (Справочник внешнего ключа):**
   * Откройте таблицу `sessions` $\to$ вкладка **Данные** $\to$ нажмите **`+` (Добавить строку)**.
   * Кликните на ячейку `member_id` или `pc_id` и выберите значение из открывшегося справа списка (**Словарь / Dictionary**), укажите `hours = 3` и нажмите **`Ctrl + S`**.

---

## Шаг 3. Пять однотабличных запросов в DBeaver

1. **Поиск без учета регистра (`ILIKE`):**
   Выберите из таблицы `bar_orders` все заказы, где в `item_name` встречается `'energy'` или `'cola'` в любом регистре (`ILIKE`), отсортировав по убыванию `price`.
2. **Замена `NULL` через `COALESCE`:**
   В таблице `tournament_entries` выведите `entry_id`, `member_id`, `game_title`, `prize` и столбец `COALESCE(prize, 0.00) AS prize_clean` (в PostgreSQL нет функции `IFNULL`).
3. **Вычитание дат (`DATE`):**
   Выведите из таблицы `members` верифицированных игроков (`is_verified = TRUE`) и рассчитайте, сколько дней каждый зарегистрирован в клубе:
   ```sql
   SELECT member_id, nickname, reg_date, (CURRENT_DATE - reg_date) AS days_in_club, balance
   FROM members
   WHERE is_verified = TRUE
   ORDER BY days_in_club DESC;
   ```
4. **Вставка с возвратом строки (`RETURNING`):**
   Добавьте нового игрока в `members` без указания `member_id` и `reg_date`, завершив запрос конструкцией `RETURNING member_id, nickname, balance, reg_date;`.
5. **Проверка именованного `CHECK` и составного `UNIQUE`:**
   * Попробуйте вставить в `pcs` строку с `ram_gb = 48` (проверка `chk_pc_ram`).
   * Попробуйте повторно вставить в `tournament_entries` уже существующую пару `(member_id, game_title)` (проверка `uq_member_game`).
   * Оставьте оба запроса закомментированными с текстом ошибки PostgreSQL.

---

## Что сдать
1. Схему `er_diagram_varXX.png` из 6 таблиц.
2. Файл `medium_solution.sql` (DDL 6 таблиц с именованными `CONSTRAINT`, `setval` и 5 запросов).
