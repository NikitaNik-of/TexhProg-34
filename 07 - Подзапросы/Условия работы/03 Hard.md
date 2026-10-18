# Практическая работа #7: Уровень 3 (Продвинутый / Hard)

## 1. Описание набора данных
В папке вашего варианта (`hard/variant_XX/`) представлена разветвленная нелинейная база данных киберспортивного клуба из шести связанных CSV-файлов (разделитель — точка с запятой `;`):

* `members.csv` — реестр клиентов клуба (200 клиентов):
  * `member_id`, `nickname`, `city`, `email`, `registered_at`, `loyalty_tier`, `balance`.
* `hardware_pcs.csv` — парк игрового оборудования (40 компьютеров):
  * `pc_id`, `pc_number`, `zone_name`, `hourly_rate`, `gpu`, `cpu`, `ram_gb`, `status`.
* `game_sessions.csv` — журнал игровых сессий (800 сессий):
  * `session_id`, `member_id` (для анонимов `NULL`), `pc_id`, `game_title`, `session_date`, `hours_played`, `discount_promo`, `total_paid`, `client_rating`.
* `bar_orders.csv` — заказы в баре и буфете (500 заказов):
  * `order_id`, `member_id` (для анонимов `NULL`), `item_name`, `category`, `order_date`, `quantity`, `item_price`, `total_amount`.
* `tournaments.csv` — каталог киберспортивных турниров клуба (7 турниров):
  * `tournament_id`, `tournament_name`, `game_title`, `prize_fund`, `entry_fee`, `start_date`, `min_rank`.
* `tournament_entries.csv` — протокол участия клиентов в турнирах (120 записей):
  * `entry_id` — номер записи;
  * `tournament_id` — внешний ключ к `tournaments`;
  * `member_id` — внешний ключ к `members`;
  * `team_name` — название команды;
  * `placement` — занятое итоговое место (1, 2, 3... 16);
  * `prize_won` — сумма выплаченного приза (руб., 0 для мест ниже 3).

---

## 2. Задания к выполнению

### Часть 1. Архитектура схемы и валидация 6 таблиц (CSV → SQLite)
1. Считайте все 6 CSV-файлов в датафреймы Pandas.
2. Создайте файл базы данных `club_hard.db` через `sqlite3.connect()`.
3. Активируйте ссылочную целостность: `conn.execute("PRAGMA foreign_keys = ON;")`.
4. Спроектируйте DDL-схему на 6 таблиц со всеми внешними ключами.
5. Загрузите данные в базу методом `.to_sql(..., if_exists='append', index=False)`.
6. Выполните сводный проверочный SQL-запрос `COUNT(*)` к шести таблицам с контролем длин датафреймов в Pandas.

---

### Часть 2. Скалярные подзапросы в `WHERE`
Все запросы выполняйте через `pd.read_sql_query(query, conn)`.

1. **Рекордные призовые выплаты:**  
   Найдите записи об участии в турнирах (`tournament_entries`), где сумма выигранного приза (`prize_won`) превышает средний призовой фонд по всем турнирам клуба:  
   `WHERE te.prize_won > (SELECT AVG(prize_fund) FROM tournaments)`.  
   Выведите `entry_id`, `tournament_id`, `member_id`, `team_name`, `placement`, `prize_won`.

---

### Часть 3. Множественные подзапросы (`IN` и `NOT IN`)
1. **Упорные турнирные бойцы без призовых мест:**  
   Найдите клиентов клуба, которые принимали участие в турнирах (`member_id IN (SELECT member_id FROM tournament_entries)`), но **ни разу не заняли призовое место (топ-3)**:  
   `WHERE member_id NOT IN (SELECT member_id FROM tournament_entries WHERE placement <= 3 AND member_id IS NOT NULL)`.

---

### Часть 4. Глубокие коррелированные подзапросы
1. **Премиальные сессии внутри конкретной посадочной зоны ПК:**  
   Найдите сессии, длительность которых (`hours_played`) превышает среднюю длительность сессий **внутри той зоны, к которой относится занятый компьютер**:  
   ```sql
   WHERE s1.hours_played > (
       SELECT AVG(s2.hours_played)
       FROM game_sessions s2
       JOIN hardware_pcs p2 ON s2.pc_id = p2.pc_id
       WHERE p2.zone_name = p1.zone_name
   )
   ```
2. **Выдающиеся турнирные выигрыши внутри состязания:**  
   Найдите участников турниров из `tournament_entries`, чей выигрыш (`prize_won`) превышает средний ненулевой выигрыш внутри соответствующего турнира (`WHERE te1.tournament_id = te2.tournament_id AND te2.prize_won > 0`).

---

### Часть 5. Сложная логика предикатов существования (`EXISTS` и `NOT EXISTS`)
1. **Клиенты-«триатлонисты» (тройной `EXISTS`):**  
   Найдите уникальных клиентов клуба, которые приняли участие во всех трех направлениях жизни клуба:
   * сыграли хотя бы одну сессию на ПК (`EXISTS` в `game_sessions`);
   * сделали хотя бы один заказ в баре (`EXISTS` в `bar_orders`);
   * зарегистрировались хотя бы на один турнир (`EXISTS` в `tournament_entries`).  
   Выведите `member_id`, `nickname`, `city`, `loyalty_tier`.
2. **Скрытые чемпионы (`EXISTS` + `NOT EXISTS`):**  
   Найдите клиентов, которые вошли в тройку призеров любого турнира (`placement <= 3`), но при этом **ни разу в жизни ничего не купили в баре клуба** (`NOT EXISTS` в `bar_orders`).

---

### Часть 6. Подзапросы в секции `SELECT` (Полный расчет Net LTV)
1. **Чистая ценность клиента для клуба (Net LTV):**  
   Для каждого клиента из `members` с помощью независимых скалярных подзапросов в `SELECT` вычислите:
   * `game_spend`: сумма оплат за ПК (`(SELECT IFNULL(SUM(total_paid), 0) FROM game_sessions ...)`);
   * `bar_spend`: сумма расходов в баре (`(SELECT IFNULL(SUM(total_amount), 0) FROM bar_orders ...)`);
   * `tournaments_fee`: сумма оплаченных турнирных взносов (`(SELECT IFNULL(SUM(t.entry_fee), 0) FROM tournament_entries te JOIN tournaments t ON te.tournament_id = t.tournament_id WHERE te.member_id = m.member_id)`);
   * `prizes_earned`: сумма выплаченных призовых (`(SELECT IFNULL(SUM(prize_won), 0) FROM tournament_entries ...)`);
   * `net_profit`: чистая прибыль клуба (`game_spend + bar_spend + tournaments_fee - prizes_earned`).  
   Отсортируйте по `net_profit DESC` и выведите топ-15 наиболее прибыльных гостей.

---

### Часть 7. Подзапросы в секции `FROM` (Многомерные производные таблицы)
1. **Дисперсия активности игроков:**  
   С помощью подзапроса в `FROM` вычислите среднее, минимальное и максимальное число сессий на одного активного игрока, а также средний LTV по аренде ПК.
2. **Зоны повышенной доходности:**  
   С помощью производной таблицы в `FROM` найдите средний чек по каждой игровой зоне клуба. Во внешнем запросе оставьте только те зоны, чей средний чек **строго превышает общий средний чек клуба**.

---

### Часть 8. Операции над множествами на 6 таблицах (`UNION ALL`, `INTERSECT`, `EXCEPT`)
1. **Участники турниров без барных трат (`EXCEPT`):**  
   Найдите ID клиентов, которые участвовали в турнирах (`SELECT member_id FROM tournament_entries WHERE member_id IS NOT NULL`), но ни разу не совершали покупок в баре (`EXCEPT SELECT member_id FROM bar_orders WHERE member_id IS NOT NULL`).
2. **Сквозной детальный аудит финансовых потоков (`UNION ALL`):**  
   Объедините все 4 денежных потока клуба в единую ленту аудита (`source_type`, `event_date`, `cash_flow`):
   * доходы от ПК: `'Аренда ПК'`, `session_date`, `total_paid`;
   * доходы от бара: `'Бар клуба'`, `order_date`, `total_amount`;
   * турнирные взносы (приток): `'Взнос в турнир'`, `start_date`, `entry_fee`;
   * призовые выплаты (отток): `'Выплата призовых'`, `start_date`, `-prize_won` (со знаком минус!).  
   Выведите общую сумму сальдо по всем четырем потокам.

---

### Часть 9. Параметризованный срез Net LTV по городам и порогу прибыли
1. Оберните витрину Net LTV (Часть 6) в производную таблицу в `FROM`. Оставьте только клиентов из городов, переданных в кортеже параметров `?` (например, `'Москва'`, `'Санкт-Петербург'`), с чистой прибылью выше порогового значения `?`.

---

### Часть 10. Экспорт аналитической витрины
1. Выгрузите рассчитанную витрину **Net LTV клиентов** (Часть 6) в итоговый CSV-файл `executive_customer_equity.csv` с разделителем `;` (`sep=';'`, `index=False`).
2. Освободите ресурсы и закройте соединение с базой данных `conn.close()`.
