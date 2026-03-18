-- =====================================================
-- Day 3: PostgreSQL Foundation & Database Basics
-- Database: ecommerce
-- =====================================================

-- =====================================================
-- 1. USERS TABLE - Lưu thông tin người dùng
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. SAMPLE DATA - Insert 5 users
-- =====================================================
INSERT INTO users (email, password_hash, full_name)
VALUES 
    ('user1@example.com', 'hashed_password_1', 'User One'),
    ('user2@example.com', 'hashed_password_2', 'User Two'),
    ('user3@example.com', 'hashed_password_3', 'User Three'),
    ('user4@example.com', 'hashed_password_4', 'User Four'),
    ('user5@example.com', 'hashed_password_5', 'User Five');

-- =====================================================
-- 3. SAMPLE QUERIES - Thực hành SELECT
-- =====================================================

-- Query 1: Lấy tất cả users
SELECT * FROM users;

-- Query 2: Lấy email và full_name, sắp xếp theo created_at
SELECT email, full_name, created_at FROM users ORDER BY created_at DESC;

-- Query 3: Lấy users có full_name không NULL
SELECT id, email, full_name FROM users WHERE full_name IS NOT NULL;

-- =====================================================
-- 4. UPDATE EXAMPLE - Cập nhật full_name
-- =====================================================
-- UPDATE users SET full_name = 'Updated Name' WHERE id = 1;

-- =====================================================
-- 5. DELETE EXAMPLE - Xóa user theo id
-- =====================================================
-- DELETE FROM users WHERE id = 1;