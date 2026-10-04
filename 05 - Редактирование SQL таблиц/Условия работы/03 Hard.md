# Практическая работа #5: Уровень 3 (Hard / Продвинутый)

## 1. Ваши исходные файлы
В папке вашего варианта (`hard/variant_XX/`) лежат три CSV-файла с разделителем `;`:
* `hardware_pcs.csv` — компьютеры клуба (`pc_id`, `pc_number`, `zone_name`, `hourly_rate`, `gpu`, `status`).
* `members.csv` — клиенты клуба (`member_id`, `nickname`, `email`, `city`, `balance`, `registered_at`).
* `game_sessions.csv` — игровые сессии (`session_id`, `member_id`, `pc_id`, `game_title`, `start_time`, `duration_hours`, `status`, `client_rating`).

---

## 2. Что нужно сделать

### Задание 1. Проектирование схемы с каскадным удалением (DDL)
1. Подключитесь к файлу `club_hard.db` и включите контроль связей:
   ```python
   conn = sqlite3.connect("club_hard.db")
   conn.execute("PRAGMA foreign_keys = ON;")
   ```
2. Создайте родительские таблицы `hardware_pcs` и `members` со всеми ограничениями (`PRIMARY KEY`, `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`).
3. Создайте таблицу `game_sessions`, настроив **каскадное удаление по клиенту**:
   ```sql
   CREATE TABLE game_sessions (
       session_id     INTEGER PRIMARY KEY,
       member_id      INTEGER,
       pc_id          INTEGER NOT NULL,
       game_title     TEXT NOT NULL,
       start_time     TEXT NOT NULL,
       duration_hours REAL NOT NULL CHECK (duration_hours > 0 AND duration_hours <= 24),
       status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
       client_rating  INTEGER CHECK (client_rating BETWEEN 1 AND 5),
       FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
       FOREIGN KEY (pc_id) REFERENCES hardware_pcs(pc_id)
   );
   ```

### Задание 2. Импорт данных из CSV
1. Прочитайте CSV-файлы через `pd.read_csv("...", sep=";")`.
2. Загрузите данные в таблицы через `.to_sql(..., if_exists="append", index=False)` в правильном порядке зависимостей (родители -> дочерняя).
3. Зафиксируйте сохранение: `conn.commit()`.

### Задание 3. Двухшаговая транзакция с расчетом по тарифу (COMMIT и ROLLBACK)
Завершение сессии и списание платы должны происходить как единая атомарная операция.
Стоимость сессии рассчитывается по тарифу компьютера: `стоимость = duration_hours * hourly_rate`.

1. **Успешная транзакция (COMMIT):**
   * Выберите активную сессию клиента, у которого на балансе достаточно средств.
   * Получите часовой тариф используемого ПК и рассчитайте общую стоимость.
   * В блоке транзакции выполните:
     1. Перевод сессии в статус `'completed'` (`UPDATE game_sessions ...`).
     2. Списание расчетной стоимости с баланса (`UPDATE members ...`).
     3. Фиксацию изменений: `conn.commit()`.
   * Выведите строки через `SELECT`, подтвердив оплату.
2. **Аварийный откат (ROLLBACK):**
   * Смоделируйте завершение сессии для клиента, у которого баланс меньше требуемой суммы.
   * В блоке `try ... except` выполните шаги транзакции. При нарушении `CHECK (balance >= 0)` база вызовет ошибку.
   * Перехватите исключение и вызовите `conn.rollback()`.
   * С помощью `SELECT` докажите, что статус сессии остался активным, а баланс не изменился.

### Задание 4. Проверка автоматического каскадного удаления (ON DELETE CASCADE)
1. Найдите клиента (`member_id`), у которого в базе есть несколько сессий в `game_sessions`.
2. Посчитайте число его сессий:
   ```sql
   SELECT COUNT(*) FROM game_sessions WHERE member_id = ?;
   ```
3. Удалите самого клиента из таблицы `members`:
   ```sql
   DELETE FROM members WHERE member_id = ?;
   ```
4. Зафиксируйте транзакцию: `conn.commit()`.
5. Повторно запросите количество сессий этого клиента. Убедитесь, что все зависимые сессии были автоматически удалены самой СУБД благодаря правилу `ON DELETE CASCADE`.

### Задание 5. Аналитический UPDATE со вложенным условием
1. Клуб начисляет **200 бонусных рублей** на депозит активным игрокам из городов `'Москва'` и `'Санкт-Петербург'`, завершившим хотя бы одну сессию:
   ```sql
   UPDATE members
   SET balance = balance + 200
   WHERE city IN ('Москва', 'Санкт-Петербург')
     AND member_id IN (
         SELECT DISTINCT member_id 
         FROM game_sessions 
         WHERE status = 'completed' AND member_id IS NOT NULL
     );
   ```
2. Выведите количество фактически измененных строк (`cur.rowcount`).
3. Зафиксируйте сохранение `conn.commit()` и закройте соединение `conn.close()`.
