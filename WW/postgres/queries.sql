-- ============================================================
-- Эталонный проект: Онлайн-курсы (LMS)
-- Файл: queries.sql
-- Назначение: запросы к базе данных
--
-- Разделы:
--   1. Фильтрация и сортировка
--   2. Агрегаты по всей таблице
--   3. GROUP BY: агрегаты по группам
--   4. HAVING: фильтрация групп
--   5. Комбинирование WHERE + GROUP BY + HAVING + ORDER BY + LIMIT
--   6. JOIN: соединение таблиц
--   7. Подзапросы
--   8. Операции над множествами
--   9. Аналитические отчеты (JOIN + GROUP BY + HAVING)
-- ============================================================


-- ============================================================
-- 1. Фильтрация и сортировка
-- ============================================================

-- 1.1. Все курсы с ценой от 5000 до 12000, отсортированные по цене.
SELECT course_id, title, price, level
FROM courses
WHERE price BETWEEN 5000 AND 12000
ORDER BY price;


-- 1.2. Студенты с email, зарегистрированные в первой половине 2026, отсортированные по дате регистрации (strftime('%d.%m.%Y', registered_at) заменено на TO_CHAR(registered_at, 'DD.MM.YYYY')).
SELECT student_id,
       name,
       email,
       TO_CHAR(registered_at, 'DD.MM.YYYY') AS registered_at_ru
FROM students
WHERE email IS NOT NULL
  AND registered_at BETWEEN '2026-01-01' AND '2026-06-30'
ORDER BY registered_at;


-- 1.3. Курсы уровня beginner или advanced, топ-3 по цене.
SELECT title, price, level
FROM courses
WHERE level IN ('beginner', 'advanced')
ORDER BY price DESC
LIMIT 3;


-- 1.4. Студенты, у которых в фамилии есть «ов» или «ев».
SELECT student_id, name
FROM students
WHERE name LIKE '%ов%'
   OR name LIKE '%ев%'
ORDER BY name;


-- ============================================================
-- 2. Агрегаты по всей таблице
-- ============================================================

-- 2.1. Всего студентов.
SELECT COUNT(*) AS total_students
FROM students;


-- 2.2. Количество студентов с заполненным email.
SELECT COUNT(email) AS students_with_email
FROM students;


-- 2.3. Средняя, минимальная и максимальная цена курса.
SELECT ROUND(AVG(price), 2) AS avg_price,
       MIN(price) AS min_price,
       MAX(price) AS max_price
FROM courses;


-- 2.4. Количество отзывов с оценкой 5.
SELECT COUNT(*) AS five_star_reviews
FROM reviews
WHERE rating = 5;


-- ============================================================
-- 3. GROUP BY: агрегаты по группам
-- ============================================================

-- 3.1. Количество записей на каждый курс.
SELECT course_id,
       COUNT(*) AS total
FROM enrollments
GROUP BY course_id
ORDER BY course_id;


-- 3.2. Средний прогресс по каждому курсу.
SELECT course_id,
       ROUND(AVG(progress_percent), 1) AS avg_progress
FROM enrollments
GROUP BY course_id
ORDER BY avg_progress DESC;


-- 3.3. Количество отзывов по каждой оценке.
SELECT rating,
       COUNT(*) AS total
FROM reviews
GROUP BY rating
ORDER BY rating DESC;


-- 3.4. Средняя цена курса по уровням.
SELECT level,
       ROUND(AVG(price), 2) AS avg_price
FROM courses
GROUP BY level
ORDER BY avg_price DESC;


-- ============================================================
-- 4. HAVING: фильтрация групп
-- ============================================================

-- 4.1. Курсы, на которые записалось больше 5 студентов.
SELECT course_id,
       COUNT(*) AS total
FROM enrollments
GROUP BY course_id
HAVING COUNT(*) > 5
ORDER BY total DESC;


-- 4.2. Курсы со средней оценкой выше 4.
SELECT course_id,
       ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
GROUP BY course_id
HAVING ROUND(AVG(rating), 2) > 4
ORDER BY avg_rating DESC;


-- 4.3. Уровни, где средняя цена курса выше 8000.
SELECT level,
       ROUND(AVG(price), 2) AS avg_price
FROM courses
GROUP BY level
HAVING ROUND(AVG(price), 2) > 8000
ORDER BY avg_price DESC;


-- ============================================================
-- 5. Комбинирование WHERE + GROUP BY + HAVING + ORDER BY + LIMIT
-- ============================================================

-- 5.1. Курсы, где больше 2 завершённых записей.
SELECT course_id,
       COUNT(*) AS completed
FROM enrollments
WHERE status = 'completed'
GROUP BY course_id
HAVING COUNT(*) > 2
ORDER BY completed DESC;


-- 5.2. Курсы со средней оценкой выше 4, учитывая только оценки 3+.
SELECT course_id,
       ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
WHERE rating >= 3
GROUP BY course_id
HAVING ROUND(AVG(rating), 2) > 4
ORDER BY avg_rating DESC;


-- 5.3. Активные месяцы 2026 (первое полугодие), где больше 3 записей (strftime('%Y-%m', enrolled_at) заменено на TO_CHAR(enrolled_at, 'YYYY-MM')).
SELECT TO_CHAR(enrolled_at, 'YYYY-MM') AS month,
       COUNT(*)                       AS total
FROM enrollments
WHERE enrolled_at < '2026-07-01'
GROUP BY month
HAVING COUNT(*) > 3
ORDER BY month;


-- 5.4. Топ-3 курса по количеству завершённых записей.
SELECT course_id,
       COUNT(*) AS completed
FROM enrollments
WHERE status = 'completed'
GROUP BY course_id
ORDER BY completed DESC
LIMIT 3;


-- ============================================================
-- 6. JOIN: соединение таблиц
-- ============================================================

-- 6.1. Студенты и их записи на курсы — имя, статус, прогресс.
SELECT s.name, e.status, e.progress_percent
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
ORDER BY s.name;


-- 6.2. Отзывы с именами студентов.
SELECT s.name, r.rating, r.comment
FROM reviews r
JOIN students s ON s.student_id = r.student_id
ORDER BY r.created_at DESC;


-- 6.3. Записи с названиями курсов.
SELECT c.title, e.status, e.progress_percent
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
ORDER BY c.title;


-- 6.4. Три таблицы: студент + курс + статус.
SELECT s.name, c.title, e.status
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses c  ON c.course_id  = e.course_id
ORDER BY s.name, c.title;


-- 6.5. Все студенты и их записи (включая тех, у кого записей нет) — LEFT JOIN.
SELECT s.student_id, s.name, e.enrollment_id
FROM students s
LEFT JOIN enrollments e ON e.student_id = s.student_id
ORDER BY s.student_id;


-- 6.6. Студенты без записей — LEFT JOIN + IS NULL.
SELECT s.student_id, s.name
FROM students s
LEFT JOIN enrollments e ON e.student_id = s.student_id
WHERE e.enrollment_id IS NULL;


-- 6.7. Курсы: количество записей и средний прогресс — JOIN + GROUP BY.
SELECT c.title,
       COUNT(e.enrollment_id)            AS total,
       ROUND(AVG(e.progress_percent), 1) AS avg_progress
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.course_id
GROUP BY c.course_id, c.title
ORDER BY total DESC;


-- 6.8. Студенты с более чем 2 записями — JOIN + GROUP BY + HAVING.
SELECT s.name, COUNT(e.enrollment_id) AS total
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.name
HAVING COUNT(e.enrollment_id) > 2
ORDER BY total DESC;

-- ============================================================
-- 7. Подзапросы
-- ============================================================

-- 7.1. Студенты, записанные на курс «SQL и базы данных» — подзапрос в WHERE.
SELECT name FROM students
WHERE student_id IN (
    SELECT e.student_id
    FROM enrollments e
    JOIN courses c ON c.course_id = e.course_id
    WHERE c.title = 'SQL и базы данных'
);


-- 7.2. Студенты, завершившие хотя бы один курс — подзапрос в WHERE.
SELECT name FROM students
WHERE student_id IN (
    SELECT student_id FROM enrollments WHERE status = 'completed'
);


-- 7.3. Курсы без записей — NOT IN.
SELECT title FROM courses
WHERE course_id NOT IN (
    SELECT DISTINCT course_id FROM enrollments
);


-- 7.4. Средний прогресс среди студентов с более чем 2 записями — подзапрос в FROM.
SELECT ROUND(AVG(avg_progress), 1) AS overall_avg
FROM (
    SELECT student_id, ROUND(AVG(progress_percent), 2) AS avg_progress
    FROM enrollments
    GROUP BY student_id
    HAVING COUNT(*) > 2
);


-- 7.5. Курсы, на которые есть хотя бы одна запись — EXISTS.
SELECT c.title
FROM courses c
WHERE EXISTS (
    SELECT 1 FROM enrollments e WHERE e.course_id = c.course_id
);


-- 7.6. Студенты без отзывов — NOT EXISTS.
SELECT s.name
FROM students s
WHERE NOT EXISTS (
    SELECT 1 FROM reviews r WHERE r.student_id = s.student_id
);


-- ============================================================
-- 8. Операции над множествами
-- ============================================================

-- 8.1. Студенты, завершившие курс или оставившие отзыв — UNION.
SELECT student_id FROM enrollments WHERE status = 'completed'
UNION
SELECT student_id FROM reviews;


-- 8.2. То же с дубликатами — UNION ALL.
SELECT student_id FROM enrollments WHERE status = 'completed'
UNION ALL
SELECT student_id FROM reviews;


-- 8.3. Студенты с записями, но без отзывов — EXCEPT.
SELECT student_id FROM enrollments
EXCEPT
SELECT student_id FROM reviews;

-- ============================================================
-- 9. Аналитические отчёты (JOIN + GROUP BY + HAVING)
-- ============================================================

-- 9.1. Топ-3 курса по средней оценке (учитываются только курсы с 3+ отзывами).
SELECT c.title,
       COUNT(r.review_id)      AS total_reviews,
       ROUND(AVG(r.rating), 2) AS avg_rating
FROM courses c
JOIN reviews r ON r.course_id = c.course_id
GROUP BY c.course_id, c.title
HAVING COUNT(r.review_id) >= 3
ORDER BY avg_rating DESC
LIMIT 3;


-- 9.2. Студенты, записанные на 2 и более курсов, со средней ценой этих курсов.
SELECT s.name,
       COUNT(e.course_id)       AS courses_count,
       ROUND(AVG(c.price), 0)   AS avg_course_price
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
JOIN courses c     ON c.course_id  = e.course_id
GROUP BY s.student_id, s.name
HAVING COUNT(e.course_id) >= 2
ORDER BY courses_count DESC, avg_course_price DESC;