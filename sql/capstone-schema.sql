-- =====================================================
-- Day 10: Mini Capstone - Production-Ready E-commerce Database
-- =====================================================
-- Thiết kế hoàn chỉnh database cho website bán hàng
-- Áp dụng: Constraints, Relationships, Transactions, Indexes, Performance

-- =====================================================
-- DESIGN PRINCIPLES
-- =====================================================
-- 1. Data Integrity First
--    - Constraints: NOT NULL, UNIQUE, CHECK, FK
--    - Types: NUMERIC for money, TIMESTAMP for dates
--
-- 2. Relationships
--    - Foreign Keys with ON DELETE RESTRICT/CASCADE
--    - Referential integrity protection
--
-- 3. Performance
--    - Indexes on FK, WHERE columns, ORDER BY
--    - Strategic indexing for common queries
--
-- 4. Concurrency
--    - Transactions for multi-step operations
--    - SELECT FOR UPDATE to prevent oversell
--    - Lock ordering to avoid deadlock
--
-- 5. Audit
--    - created_at for all tables
--    - updated_at for frequently changing tables

-- =====================================================
-- TABLE 1: USERS
-- =====================================================
-- Purpose: Store user account information
-- Key requirements:
--   - Email must be unique (login key)
--   - Password hashed (never store plaintext)
--   - full_name optional
--   - created_at for audit trail

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- INDEX: Email lookup for login
CREATE INDEX idx_users_email ON users(email);

-- =====================================================
-- TABLE 2: PRODUCTS
-- =====================================================
-- Purpose: Store product catalog
-- Key requirements:
--   - Name required
--   - Price must be positive (NUMERIC for accuracy)
--   - Stock must be non-negative (CHECK)
--   - created_at for when product was added

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- INDEX: Stock search for "in stock" products
CREATE INDEX idx_products_stock_positive 
ON products(id) WHERE stock > 0;

-- =====================================================
-- TABLE 3: ORDERS
-- =====================================================
-- Purpose: Store order headers
-- Key requirements:
--   - user_id FK to users (ON DELETE RESTRICT - never orphan orders)
--   - total_amount non-negative (calculated from items)
--   - created_at for order timestamp
--   - status for tracking (pending, completed, cancelled)
-- 
-- Transaction flow:
--   BEGIN;
--     INSERT orders (user_id, total_amount, status='pending')
--     INSERT order_items
--     UPDATE products stock
--   COMMIT;

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user
        FOREIGN KEY(user_id) 
        REFERENCES users(id)
        ON DELETE RESTRICT  -- Never delete user if orders exist
);

-- INDEX: FK for JOIN queries
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- INDEX: Status filtering (pending orders)
CREATE INDEX idx_orders_status ON orders(status) 
WHERE status = 'pending';

-- INDEX: ORDER BY created_at DESC (recent orders)
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- =====================================================
-- TABLE 4: ORDER_ITEMS
-- =====================================================
-- Purpose: Store individual items within an order
-- Key requirements:
--   - order_id FK to orders (ON DELETE CASCADE - delete items with order)
--   - product_id FK to products (ON DELETE RESTRICT - keep product)
--   - quantity must be positive (CHECK)
--   - price SNAPSHOT at order time (NOT join with products.price)
--     This ensures historical accuracy when product price changes
--   - created_at for audit

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
        ON DELETE CASCADE  -- Delete items when order deleted
    CONSTRAINT fk_order_items_product
        FOREIGN KEY(product_id) 
        REFERENCES products(id)
        ON DELETE RESTRICT  -- Keep product even if item deleted
);

-- INDEX: FK for JOIN queries (order details)
CREATE INDEX idx_order_items_order_id ON orders(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- INDEX: Composite for finding items in order efficiently
CREATE INDEX idx_order_items_order_product 
ON order_items(order_id, product_id);

-- =====================================================
-- SAMPLE DATA - Insert test data
-- =====================================================

-- Insert 3 users
INSERT INTO users (email, password_hash, full_name)
VALUES 
    ('user1@example.com', 'hashed_pw_1', 'User One'),
    ('user2@example.com', 'hashed_pw_2', 'User Two'),
    ('user3@example.com', 'hashed_pw_3', 'User Three');

-- Insert 5 products
INSERT INTO products (name, description, price, stock)
VALUES 
    ('Laptop Dell XPS 13', 'High performance ultrabook', 1299.99, 15),
    ('Apple AirPods Pro', 'Wireless earbuds with ANC', 249.99, 50),
    ('Samsung 27" Monitor', '4K display', 399.99, 8),
    ('Mechanical Keyboard RGB', 'Gaming keyboard', 149.99, 30),
    ('USB-C Hub 7 in 1', 'Port expander', 59.99, 100);

-- =====================================================
-- PRODUCTION QUERIES
-- =====================================================

-- Query 1: List all orders with customer info
SELECT 
    o.id,
    u.email,
    u.full_name,
    o.total_amount,
    o.status,
    o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id
ORDER BY o.created_at DESC;

-- Query 2: Order details (all items in order)
SELECT 
    o.id AS order_id,
    u.email,
    p.name AS product_name,
    oi.quantity,
    oi.price,
    (oi.quantity * oi.price) AS line_total,
    o.total_amount
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.id = 1
ORDER BY oi.id;

-- Query 3: User revenue analysis
SELECT 
    u.id,
    u.email,
    COUNT(o.id) AS total_orders,
    COUNT(CASE WHEN o.status = 'completed' THEN 1 END) AS completed_orders,
    SUM(o.total_amount) AS total_revenue
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email
ORDER BY total_revenue DESC NULLS LAST;

-- Query 4: Products with low stock (< 10)
SELECT 
    id,
    name,
    stock
FROM products
WHERE stock < 10
ORDER BY stock ASC;

-- =====================================================
-- CONSTRAINT TESTS - Verify integrity
-- =====================================================

-- Test 1: Try insert order with non-existent user (should fail)
-- INSERT INTO orders (user_id, total_amount, status)
-- VALUES (9999, 100.00, 'pending');
-- Expected: ERROR - FK constraint violation

-- Test 2: Try insert order_item with non-existent order (should fail)
-- INSERT INTO order_items (order_id, product_id, quantity, price)
-- VALUES (9999, 1, 1, 100.00);
-- Expected: ERROR - FK constraint violation

-- Test 3: Try insert product with negative price (should fail)
-- INSERT INTO products (name, price, stock)
-- VALUES ('Bad Product', -100.00, 10);
-- Expected: ERROR - CHECK constraint violation

-- Test 4: Try insert order_item with quantity = 0 (should fail)
-- INSERT INTO order_items (order_id, product_id, quantity, price)
-- VALUES (1, 1, 0, 100.00);
-- Expected: ERROR - CHECK constraint violation

-- =====================================================
-- TRANSACTION FLOW - Safe order processing
-- =====================================================

-- BEGIN;
--   -- Step 1: Lock product for update (prevent oversell)
--   SELECT stock FROM products WHERE id = 1 FOR UPDATE;
--   
--   -- Step 2: Check stock availability
--   -- (assume logic here in application)
--   
--   -- Step 3: Insert order
--   INSERT INTO orders (user_id, total_amount, status)
--   VALUES (1, 1299.99, 'pending')
--   RETURNING id;
--   -- (assume order_id = 1)
--   
--   -- Step 4: Insert order_item (snapshot price)
--   INSERT INTO order_items (order_id, product_id, quantity, price)
--   VALUES (1, 1, 1, 1299.99);
--   
--   -- Step 5: Deduct stock
--   UPDATE products SET stock = stock - 1 WHERE id = 1;
--   
--   -- Step 6: If all success, commit
-- COMMIT;
-- 
-- -- If any error, ROLLBACK ensures consistency

-- =====================================================
-- PERFORMANCE NOTES
-- =====================================================

-- Index Strategy:
-- 1. idx_users_email
--    - Used for login: WHERE email = ?
--    - Cost without: O(N) full scan
--    - Cost with: O(log N) binary search
--    - Expected speedup: 50-100x for large tables
--
-- 2. idx_orders_user_id
--    - Used for: WHERE user_id = ? OR JOIN users
--    - Essential for FK lookups
--    - Expected speedup: 10-50x
--
-- 3. idx_orders_status
--    - Used for: WHERE status = 'pending'
--    - Partial index (only pending orders)
--    - Saves space, improves performance
--    - Expected speedup: 20-100x
--
-- 4. idx_orders_created_at DESC
--    - Used for: ORDER BY created_at DESC
--    - Eliminates sort step
--    - Expected speedup: 10-30x
--
-- 5. idx_order_items_* (FKs)
--    - Used for: JOIN queries
--    - Essential for query performance
--    - Expected speedup: 10-30x

-- =====================================================
-- SCHEMA SUMMARY
-- =====================================================

-- Tables: 4 (users, products, orders, order_items)
-- Constraints:
--   - PKs: 4 (id on each table)
--   - FKs: 3 (orders.user_id, order_items.order_id, order_items.product_id)
--   - UNIQUEs: 1 (users.email)
--   - CHECKs: 4 (price > 0, stock >= 0, quantity > 0, total_amount >= 0)
--   - NOT NULLs: Strategic on important columns
--
-- Indexes:
--   - Primary: 4 (automatic on PK)
--   - Foreign Key: 3 (users, order_items x2)
--   - Search: 2 (email, status)
--   - Sort: 1 (created_at DESC)
--   - Composite: 1 (order_id, product_id)
--   - Total: ~11 indexes
--
-- Transactions:
--   - Order processing: 5-step atomic transaction
--   - Lock ordering: Always sort by ID ascending
--   - Deadlock prevention: Consistent lock order
--   - Oversell prevention: SELECT FOR UPDATE
--
-- Design Quality:
--   - Data integrity: ✅ (constraints, FKs, types)
--   - Performance: ✅ (strategic indexes)
--   - Concurrency: ✅ (transactions, locks)
--   - Audit trail: ✅ (created_at, updated_at)
--   - Production ready: ✅ (snapshot price, NUMERIC for money)
