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

-- =====================================================
-- Day 4: Data Integrity, Constraints & Database Discipline
-- =====================================================

-- =====================================================
-- 6. PRODUCTS TABLE - Lưu thông tin sản phẩm
-- =====================================================
-- Constraints:
-- - id: PRIMARY KEY (định danh duy nhất)
-- - name: NOT NULL (bắt buộc có tên)
-- - price: NUMERIC, CHECK > 0 (giá phải dương, tránh giá âm)
-- - stock: INTEGER, CHECK >= 0 (tồn kho không âm)
-- - created_at: DEFAULT CURRENT_TIMESTAMP (tự động ghi ngày tạo)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 7. PRODUCTS SAMPLE DATA - Insert 5 products
-- =====================================================
INSERT INTO products (name, price, stock)
VALUES 
    ('Laptop Dell XPS 13', 1299.99, 15),
    ('Apple AirPods Pro', 249.99, 50),
    ('Samsung 27" Monitor', 399.99, 8),
    ('Mechanical Keyboard RGB', 149.99, 30),
    ('USB-C Hub 7 in 1', 59.99, 100);

-- =====================================================
-- 8. CONSTRAINT TESTING - Thử vi phạm constraints
-- =====================================================

-- Test 1: Thử insert giá âm (sẽ bị lỗi CHECK)
-- INSERT INTO products (name, price, stock) VALUES ('Invalid Product', -100, 10);

-- Test 2: Thử insert stock âm (sẽ bị lỗi CHECK)
-- INSERT INTO products (name, price, stock) VALUES ('Invalid Stock', 50, -5);

-- Test 3: Thử insert name NULL (sẽ bị lỗi NOT NULL)
-- INSERT INTO products (name, price, stock) VALUES (NULL, 50, 10);

-- Test 4: Xem tất cả products
SELECT * FROM products;

-- Test 5: Xem products có giá cao nhất
SELECT * FROM products ORDER BY price DESC LIMIT 1;

-- Test 6: Xem sản phẩm với tồn kho ít hơn 10
SELECT name, stock FROM products WHERE stock < 10;