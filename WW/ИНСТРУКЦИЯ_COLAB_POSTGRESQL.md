# Подключение к PostgreSQL из Google Colab через psycopg2

Краткая инструкция по настройке и работе с базой данных PostgreSQL из блокнота Google Colab.

---

## 1. Установка библиотек

В первой ячейке блокнота выполните:

```python
!pip install -q psycopg2-binary pandas sqlalchemy
```

---

## 2. Подключение к базе данных

### Вариант А. Через чистый `psycopg2` (быстро и стандартно)

```python
import psycopg2

# Параметры вашего сервера
DB_HOST = "IP_СЕРВЕРА"      # например: "194.87.x.x"
DB_PORT = 443               # или 5432
DB_NAME = "club_demo"       # имя базы (или club_varXX)
DB_USER = "student_01"      # имя пользователя (или postgres)
DB_PASS = "StudyPass2026_var01"

# Подключение
conn = psycopg2.connect(
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASS
)
conn.autocommit = True  # автоматическое подтверждение изменений (без явного conn.commit())
print("Подключение успешно!")
```

### Вариант Б. Через строку подключения (для SQLAlchemy / pandas)

```python
from sqlalchemy import create_engine

CONN_STR = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(CONN_STR)
```

---

## 3. Выполнение запросов

### Простой запрос через курсор:
```python
cur = conn.cursor()
cur.execute("SELECT version();")
print("Версия СУБД:", cur.fetchone()[0])
cur.close()
```

### Выборка данных в таблицу `pandas` (рекомендуется для аналитики):
```python
import pandas as pd

query = "SELECT * FROM members LIMIT 10;"
df = pd.read_sql(query, conn)
display(df)
```

### Выполнение DDL / DML скрипта (создание таблиц, вставка):
```python
cur = conn.cursor()
cur.execute("""
    INSERT INTO members (nickname, balance, is_verified)
    VALUES ('ColabUser', 1000.00, TRUE)
    RETURNING member_id, nickname, balance;
""")
new_row = cur.fetchone()
print("Добавлена запись:", new_row)
cur.close()
```

---

## 4. Закрытие соединения в конце работы

```python
conn.close()
print("Соединение закрыто.")
```

---

## 5. Частые ошибки и их устранение

| Ошибка | Причина | Что делать |
| :--- | :--- | :--- |
| `connection timeout` | Порт сервера закрыт фаерволом хостинга | Убедиться, что на VPS порт `443` (или `5432`) открыт для входящих соединений (`0.0.0.0/0`). |
| `password authentication failed` | Ошибка в логине/пароле или имени базы данных | Проверить имя пользователя, пароль и название базы. |
| `could not connect to server: Connection refused` | PostgreSQL слушает только localhost | На сервере в `/etc/postgresql/.../postgresql.conf` должно быть `listen_addresses = '*'`. |
| `no pg_hba.conf entry for host` | Нет разрешения на подключение в конфиге | В `/etc/postgresql/.../pg_hba.conf` добавить строку: `host all all 0.0.0.0/0 scram-sha-256`. |
