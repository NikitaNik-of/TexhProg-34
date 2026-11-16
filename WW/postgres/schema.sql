-- ============================================================
-- Эталонный проект: Онлайн-курсы (LMS)
-- Файл: schema.sql (версия для PostgreSQL)
-- Назначение: создание таблиц
-- ============================================================

-- ------------------------------------------------------------
-- Таблица students
-- ------------------------------------------------------------
CREATE TABLE students (
    student_id     SERIAL PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    registered_at  DATE NOT NULL
);

-- ------------------------------------------------------------
-- Таблица courses
-- ------------------------------------------------------------
CREATE TABLE courses (
    course_id      SERIAL PRIMARY KEY,
    title          VARCHAR(200) NOT NULL,
    description    TEXT,
    price          NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    duration_hours INTEGER NOT NULL CHECK (duration_hours > 0),
    level          VARCHAR(20) NOT NULL CHECK (level IN ('beginner','intermediate','advanced')),
    created_at     DATE NOT NULL
);

-- ------------------------------------------------------------
-- Таблица lessons
-- ------------------------------------------------------------
CREATE TABLE lessons (
    lesson_id    SERIAL PRIMARY KEY,
    course_id    INTEGER NOT NULL,
    title        VARCHAR(200) NOT NULL,
    order_num    INTEGER NOT NULL,
    duration_min INTEGER NOT NULL CHECK (duration_min > 0),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);

-- ------------------------------------------------------------
-- Таблица enrollments
-- ------------------------------------------------------------
CREATE TABLE enrollments (
    enrollment_id    SERIAL PRIMARY KEY,
    student_id       INTEGER NOT NULL,
    course_id        INTEGER NOT NULL,
    enrolled_at      DATE NOT NULL,
    status           VARCHAR(20) NOT NULL CHECK (status IN ('active','completed','cancelled')),
    progress_percent INTEGER NOT NULL CHECK (progress_percent BETWEEN 0 AND 100),
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id)  REFERENCES courses(course_id),
    UNIQUE (student_id, course_id)
);

-- ------------------------------------------------------------
-- Таблица reviews
-- ------------------------------------------------------------
CREATE TABLE reviews (
    review_id  SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id  INTEGER NOT NULL,
    rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at DATE NOT NULL,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id)  REFERENCES courses(course_id)
);