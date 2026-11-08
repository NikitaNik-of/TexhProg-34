# Уровень 01 — Easy (5 таблиц)

> **Оценка:** до «3».
> **Исходные файлы:** шаблон `easy/sqlite_schema_easy.sql` и папка `easy/variant_XX/` (5 CSV-файлов, где `XX` — номер варианта `01`..`20`).
> **База на сервере:** `club_varXX` (логин `student_XX`, пароль `StudyPass2026_varXX`).

---

## Задание

Перенести схему из 5 таблиц (`tariffs`, `members`, `pcs`, `sessions`, `bar_orders`) из формата SQLite в PostgreSQL, загрузить данные своего варианта и выполнить 4 однотабличных запроса в DBeaver.

---

## Шаг 1. Перевод схемы из SQLite в PostgreSQL

Откройте файл `easy/sqlite_schema_easy.sql` и переведите таблицы на синтаксис PostgreSQL в редакторе SQL (`F3`):

| Таблица | Поля и типы в PostgreSQL | Ограничения (`Constraints`) |
| :--- | :--- | :--- |
| **1. `tariffs`** | `tariff_id SERIAL PRIMARY KEY`,<br>`zone_name VARCHAR(20) NOT NULL UNIQUE`,<br>`hourly_rate NUMERIC(8, 2) NOT NULL`,<br>`is_vip BOOLEAN NOT NULL DEFAULT FALSE` | `CHECK (hourly_rate > 0)` |
| **2. `members`** | `member_id SERIAL PRIMARY KEY`,<br>`nickname VARCHAR(30) NOT NULL UNIQUE`,<br>`balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00`,<br>`is_verified BOOLEAN NOT NULL DEFAULT FALSE`,<br>`reg_date DATE NOT NULL DEFAULT CURRENT_DATE` | `CHECK (balance >= 0)` |
| **3. `pcs`** | `pc_id SERIAL PRIMARY KEY`,<br>`pc_code VARCHAR(10) NOT NULL UNIQUE`,<br>`tariff_id INTEGER NOT NULL`,<br>`ram_gb SMALLINT NOT NULL`,<br>`is_active BOOLEAN NOT NULL DEFAULT TRUE` | `REFERENCES tariffs(tariff_id)`,<br>`CHECK (ram_gb IN (16, 32, 64))` |
| **4. `sessions`** | `session_id SERIAL PRIMARY KEY`,<br>`member_id INTEGER`,<br>`pc_id INTEGER NOT NULL`,<br>`hours SMALLINT NOT NULL`,<br>`session_date DATE NOT NULL DEFAULT CURRENT_DATE` | `REFERENCES members(member_id)`,<br>`REFERENCES pcs(pc_id)`,<br>`CHECK (hours BETWEEN 1 AND 24)` |
| **5. `bar_orders`** | `order_id SERIAL PRIMARY KEY`,<br>`session_id INTEGER NOT NULL`,<br>`item_name VARCHAR(40) NOT NULL`,<br>`price NUMERIC(8, 2) NOT NULL`,<br>`is_delivered BOOLEAN NOT NULL DEFAULT FALSE` | `REFERENCES sessions(session_id)`,<br>`CHECK (price > 0)` |

1. Создайте первые 4 таблицы через SQL-скрипт (`Alt + X`).
2. **Работа в интерфейсе DBeaver:** создайте 5-ю таблицу `bar_orders` (или добавьте в неё ограничение `CHECK`) через визуальный конструктор:
   * Правый клик на `Таблицы` $\to$ **Создать Новую Таблицу** $\to$ добавьте колонки и внешний ключ $\to$ нажмите `Ctrl + S`.
   * В окне **Persist Changes** скопируйте сгенерированный код `CREATE TABLE` в свой SQL-скрипт и нажмите **Persist**.
3. Обновите схему `public` (`F5`) и откройте вкладку **ER-диаграмма**. Проверьте, что все 5 таблиц связаны между собой.

---

## Шаг 2. Загрузка данных и работа во вкладке «Данные»

1. Импортируйте 5 CSV-файлов из папки `easy/variant_XX/` в порядке от родительских таблиц к дочерним:
   `tariffs` $\to$ `members` $\to$ `pcs` $\to$ `sessions` $\to$ `bar_orders` (через правый клик по таблице $\to$ **Импорт данных из CSV** или через Python-скрипт из `00 Общее задание.md`).
2. Синхронизируйте счетчик `SERIAL` для таблицы `members`:
   ```sql
   SELECT setval(pg_get_serial_sequence('members', 'member_id'), COALESCE(MAX(member_id), 1)) FROM members;
   ```
3. **Работа в интерфейсе DBeaver:**
   * Откройте таблицу `members` $\to$ вкладка **Данные**.
   * Нажмите **`+` (Добавить новую строку)** внизу, введите свой никнейм, баланс `500.00`, поставьте галочку в `is_verified`, выберите дату в календаре `reg_date` и нажмите **`Ctrl + S`**.

---

## Шаг 3. Запросы в DBeaver (отличия PostgreSQL от SQLite)

Напишите в SQL-редакторе 4 простых запроса к одиночным таблицам:

1. **Кавычки (`'...'` против `"..."`):**
   * Выполните запрос с двойными кавычками: `SELECT * FROM tariffs WHERE zone_name = "VIP";`
   * Закомментируйте его (`--`) с кратким пояснением ошибки и ниже напишите рабочий запрос с одинарными кавычками `'VIP'`.
2. **Регистр символов (`LIKE` против `ILIKE`):**
   * Сравните запросы к таблице `bar_orders`:
     ```sql
     SELECT * FROM bar_orders WHERE item_name LIKE '%cola%';
     SELECT * FROM bar_orders WHERE item_name ILIKE '%cola%';
     ```
3. **Фильтр по `BOOLEAN`:**
   * Выберите из таблицы `pcs` все активные компьютеры (`is_active = TRUE`) с объемом ОЗУ от 32 ГБ (`ram_gb >= 32`), отсортировав по убыванию `ram_gb`.
4. **Проверка ограничений `VARCHAR(10)` и `CHECK`:**
   * Попробуйте вставить через `INSERT` в таблицу `pcs` строку с `pc_code` длиннее 10 символов или с `ram_gb = 24`.
   * Оставьте запрос закомментированным в скрипте вместе с текстом ошибки PostgreSQL.

---

## Что сдать
1. Открытую вкладку **ER-диаграмма** в DBeaver (5 связанных таблиц).
2. Добавленную вручную строку во вкладке **Данные** таблицы `members`.
3. Файл `easy_solution.sql` с созданием таблиц и 4 запросами.
