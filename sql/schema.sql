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

-- =====================================================
-- Day 5: Relationship & Foreign Key (Database Modeling)
-- =====================================================

-- =====================================================
-- 9. ORDERS TABLE - Lưu thông tin đơn hàng
-- =====================================================
-- Constraints:
-- - id: PRIMARY KEY (định danh duy nhất)
-- - user_id: NOT NULL, FOREIGN KEY → users.id (tham chiếu tới user)
-- - total_amount: NUMERIC, CHECK >= 0 (tổng tiền không âm)
-- - created_at: DEFAULT CURRENT_TIMESTAMP
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user
        FOREIGN KEY(user_id)
        REFERENCES users(id)
        ON DELETE RESTRICT
);

-- =====================================================
-- 10. ORDER_ITEMS TABLE - Lưu chi tiết từng sản phẩm trong đơn hàng
-- =====================================================
-- Constraints:
-- - id: PRIMARY KEY
-- - order_id: FK → orders.id (đơn hàng nào)
-- - product_id: FK → products.id (sản phẩm nào)
-- - quantity: INTEGER, CHECK > 0 (số lượng phải dương)
-- - price: NUMERIC, CHECK > 0 (giá tại thời điểm đặt hàng - snapshot)
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_items_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY(product_id)
        REFERENCES products(id)
        ON DELETE RESTRICT
);

-- =====================================================
-- 11. SAMPLE DATA - Insert test data
-- =====================================================

-- Insert 1 order cho user_id = 1
INSERT INTO orders (user_id, total_amount)
VALUES (1, 1549.98);

-- Insert 2 order_items cho order_id = 1
-- Item 1: Laptop (1299.99) x 1
-- Item 2: AirPods (249.99) x 1
INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES 
    (1, 1, 1, 1299.99),
    (1, 2, 1, 249.99);

-- =====================================================
-- 12. QUERIES - Thực hành JOIN queries
-- =====================================================

-- Query 1: Lấy tất cả orders với thông tin user
SELECT 
    o.id,
    o.user_id,
    u.email,
    u.full_name,
    o.total_amount,
    o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id;

-- Query 2: Lấy chi tiết order (order + order_items + products)
SELECT 
    o.id AS order_id,
    u.email,
    p.name AS product_name,
    oi.quantity,
    oi.price,
    (oi.quantity * oi.price) AS line_total
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
ORDER BY o.id, oi.id;

-- Query 3: Lấy tổng doanh thu theo user
SELECT 
    u.id,
    u.email,
    u.full_name,
    COUNT(o.id) AS total_orders,
    SUM(o.total_amount) AS total_revenue
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email, u.full_name
ORDER BY total_revenue DESC NULLS LAST;

-- =====================================================
-- 13. FOREIGN KEY CONSTRAINT TESTING
-- =====================================================

-- Test 1: Thử insert order với user_id không tồn tại (sẽ bị lỗi FK)
-- INSERT INTO orders (user_id, total_amount) VALUES (9999, 1000);

-- Test 2: Thử insert order_item với order_id không tồn tại (sẽ bị lỗi FK)
-- INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (9999, 1, 1, 100);

-- Test 3: Thử insert order_item với product_id không tồn tại (sẽ bị lỗi FK)
-- INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 9999, 1, 100);