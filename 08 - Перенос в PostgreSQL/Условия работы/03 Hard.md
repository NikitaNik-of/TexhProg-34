# Уровень 03 — Hard (6 таблиц, правила `ON DELETE`, транзакции, `UPSERT` и `FILTER`)

> **Оценка:** до «5».
> **Исходные файлы:** шаблон `hard/sqlite_schema_hard.sql` и папка `hard/variant_XX/` (6 CSV-файлов, где `XX` — номер варианта `01`..`20`).
> **База на сервере:** `club_varXX` (логин `student_XX`, пароль `StudyPass2026_varXX`).

---

## Задание

Перенести в PostgreSQL схему из 6 таблиц с правилами внешних ключей `ON DELETE RESTRICT / SET NULL / CASCADE`, проверить работу каскадного удаления внутри транзакции с откатом `ROLLBACK`, а также выполнить запросы с `ON CONFLICT DO UPDATE` (UPSERT) и условной агрегацией `FILTER (WHERE ...)`.

---

## Шаг 1. Перевод 6 таблиц с правилами `ON DELETE`

Откройте шаблон `hard/sqlite_schema_hard.sql` и переведите все 6 таблиц на синтаксис PostgreSQL в редакторе SQL (`F3`), добавив именованные ограничения `CONSTRAINT` и правила удаления для внешних ключей:

| Поле внешнего ключа | Куда ссылается (`REFERENCES`) | Правило `ON DELETE` | Назначение |
| :--- | :--- | :--- | :--- |
| `pcs.tariff_id` | `tariffs(tariff_id)` | **`ON DELETE RESTRICT`** | Запрещает удалять тариф, пока к нему привязаны ПК. |
| `sessions.member_id` | `members(member_id)` | **`ON DELETE SET NULL`** | При удалении игрока запись о сессии остается, а `member_id` становится `NULL`. |
| `sessions.pc_id` | `pcs(pc_id)` | **`ON DELETE RESTRICT`** | Запрещает удалять ПК, если по нему есть история сессий. |
| `bar_orders.session_id` | `sessions(session_id)` | **`ON DELETE CASCADE`** | При удалении сессии заказы бара этой сессии удаляются автоматически. |
| `tournament_entries.member_id` | `members(member_id)` | **`ON DELETE CASCADE`** | При удалении игрока его заявки на турниры удаляются автоматически. |
| `tournament_entries.pc_id` | `pcs(pc_id)` | **`ON DELETE RESTRICT`** | Запрещает удалять ПК, задействованный в турнире. |

Выполните скрипт (`Alt + X`), обновите схему `public` (`F5`) и сохраните **ER-диаграмму** 6 таблиц в файл `er_diagram_hard_varXX.png`.

---

## Шаг 2. Загрузка данных и синхронизация счетчиков `SERIAL`

1. Импортируйте 6 CSV-файлов из папки `hard/variant_XX/` в таблицы PostgreSQL (через импорт CSV в DBeaver или через Python с `if_exists="append"`).
2. Синхронизируйте счетчики `SERIAL` для всех 6 таблиц с помощью `SELECT setval(pg_get_serial_sequence(...))`.

---

## Шаг 3. Проверка правил `ON DELETE` внутри транзакции (`BEGIN ... ROLLBACK`)

1. **Проверка `ON DELETE RESTRICT`:**
   Попробуйте удалить тариф №1 (`DELETE FROM tariffs WHERE tariff_id = 1;`). Зафиксируйте ошибку внешнего ключа в комментарии.
2. **Проверка `ON DELETE SET NULL` и `ON DELETE CASCADE` с откатом `ROLLBACK`:**
   Выполните в DBeaver по шагам (`Ctrl + Enter`):
   ```sql
   BEGIN;

   -- Удаляем игрока №1:
   DELETE FROM members WHERE member_id = 1;

   -- В sessions строки остались, а member_id стал NULL (ON DELETE SET NULL):
   SELECT session_id, member_id, pc_id, hours, session_date
   FROM sessions
   WHERE member_id IS NULL;

   -- В tournament_entries заявки игрока №1 удалились (ON DELETE CASCADE):
   SELECT COUNT(*) AS remaining_entries
   FROM tournament_entries
   WHERE member_id = 1;

   -- Отменяем удаление — возвращаем данные в исходное состояние:
   ROLLBACK;

   -- Проверяем, что игрок №1 вернулся на место:
   SELECT * FROM members WHERE member_id = 1;
   ```

---

## Шаг 4. Четыре однотабличных запроса в DBeaver и экспорт в CSV

1. **Вставка с обновлением при дубликате (`UPSERT ... RETURNING`):**
   Добавьте в `members` игрока `'CyberChampion'` с балансом `1000.00`. Если такой `nickname` уже есть — увеличьте его баланс на `1000.00`:
   ```sql
   INSERT INTO members (nickname, balance, is_verified)
   VALUES ('CyberChampion', 1000.00, TRUE)
   ON CONFLICT (nickname) DO UPDATE
       SET balance = members.balance + 1000.00,
           is_verified = TRUE
   RETURNING member_id, nickname, balance, is_verified, reg_date;
   ```
   Выполните запрос дважды подряд и убедитесь, что при втором запуске баланс вырос до `2000.00`.
2. **Условная агрегация `FILTER (WHERE ...)` по таблице `pcs`:**
   В одном запросе к таблице `pcs` выведите:
   * Общее число ПК (`COUNT(*)`);
   * Число активных ПК (`COUNT(*) FILTER (WHERE is_active = TRUE)`);
   * Число неактивных ПК (`COUNT(*) FILTER (WHERE is_active = FALSE)`);
   * Число ПК с памятью 32 ГБ (`COUNT(*) FILTER (WHERE ram_gb = 32)`) и 64 ГБ (`COUNT(*) FILTER (WHERE ram_gb = 64)`).
3. **Условная агрегация `FILTER (WHERE ...)` по таблице `bar_orders`:**
   В одном запросе к таблице `bar_orders` посчитайте: общее число заказов, общую сумму `SUM(price)`, сумму доставленных заказов (`SUM(price) FILTER (WHERE is_delivered = TRUE)`) и сумму заказов колы и энергетиков (`SUM(price) FILTER (WHERE item_name ILIKE '%cola%' OR item_name ILIKE '%red bull%' OR item_name ILIKE '%monster%')`).
4. **Статистика по турнирным дисциплинам (`COALESCE` + экспорт через GUI DBeaver):**
   Сгруппируйте `tournament_entries` по полю `game_title` и выведите:
   * Число заявок (`COUNT(*)`);
   * Число призеров (`COUNT(prize)`);
   * Сумму призовых (`COALESCE(SUM(prize), 0.00)`);
   * Средний приз с учетом `NULL` (`ROUND(AVG(COALESCE(prize, 0.00)), 2)`).
   * **Работа в интерфейсе DBeaver:** в панели результатов этого запроса нажмите **Экспорт данных** $\to$ **CSV** и сохраните результат в файл `hard_tournaments_varXX.csv`.

---

## Что сдать
1. Схему `er_diagram_hard_varXX.png` из 6 таблиц.
2. Показ работы блока `BEGIN ... DELETE ... ROLLBACK` и повторного запуска `UPSERT` в DBeaver.
3. Файл `hard_solution.sql` и выгруженный отчет `hard_tournaments_varXX.csv`.
