-- =====================================================
-- Day 9: Index & Query Performance Foundation
-- =====================================================
-- Tệp này chứa ví dụ về index, EXPLAIN queries, và performance analysis

-- =====================================================
-- 1. PROBLEM - Query chậm vì không có index
-- =====================================================
-- Giả sử: users table có 1,000,000 rows
-- 
-- Query tìm user theo email:
-- SELECT * FROM users WHERE email = 'abc@gmail.com';
-- 
-- Nếu không có index:
-- → Database phải scan toàn bộ 1,000,000 rows (Full Table Scan)
-- → Rất chậm!
-- 
-- Nếu có index trên email:
-- → Database nhảy trực tiếp tới email = 'abc@gmail.com'
-- → Nhanh!

-- =====================================================
-- 2. INDEX là gì?
-- =====================================================
-- Index = Cấu trúc dữ liệu đặc biệt để tìm kiếm nhanh
-- Giống như mục lục trong sách:
-- 
-- Không có index: Phải đọc trang 1-500 để tìm từ X
-- Có index: Nhảy trực tiếp tới trang 123
-- 
-- Trade-off:
-- ✅ Đọc nhanh hơn
-- ❌ Ghi chậm hơn (phải update index)

-- =====================================================
-- 3. PRIMARY KEY tự động có INDEX
-- =====================================================
-- 
-- CREATE TABLE users (
--   id SERIAL PRIMARY KEY,  -- Tự động có index!
--   email VARCHAR(255),
--   ...
-- );
-- 
-- PostgreSQL tự tạo index trên id
-- Đó là lý do SELECT * FROM users WHERE id = 1 nhanh

-- =====================================================
-- 4. EXPLAIN - Hiểu cách database chạy query
-- =====================================================
-- 
-- EXPLAIN:
-- SELECT * FROM users WHERE email = 'user1@example.com';
-- 
-- Result sẽ cho thấy:
-- - Seq Scan (scan tuần tự) → chậm
-- - Index Scan (dùng index) → nhanh
-- - Cost, rows, execution time

-- Demo Query 1: Tìm user theo email (SAI - không có index)
EXPLAIN
SELECT * FROM users 
WHERE email = 'user1@example.com';

-- Expected result:
-- Seq Scan on users → scan tuần tự (chậm!)

-- =====================================================
-- 5. TẠO INDEX - Index trên email column
-- =====================================================
-- 
-- Cú pháp:
-- CREATE INDEX idx_name ON table_name(column_name);

CREATE INDEX IF NOT EXISTS idx_users_email 
ON users(email);

-- Lúc này, query tìm user theo email sẽ nhanh hơn

-- =====================================================
-- 6. TEST sau khi tạo INDEX
-- =====================================================
-- Chạy lại query EXPLAIN:

EXPLAIN
SELECT * FROM users 
WHERE email = 'user1@example.com';

-- Expected result:
-- Index Scan using idx_users_email on users → dùng index (nhanh!)

-- =====================================================
-- 7. INDEX trên FOREIGN KEY
-- =====================================================
-- 
-- Foreign Key columns thường xuyên được dùng trong:
-- - JOIN
-- - WHERE clause
-- 
-- Nên tạo index trên FK

CREATE INDEX IF NOT EXISTS idx_orders_user_id 
ON orders(user_id);

-- Demo Query: JOIN với user_id
EXPLAIN
SELECT o.id, u.email, o.total_amount
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.user_id = 1;

-- Expected: Index Scan on idx_orders_user_id

-- =====================================================
-- 8. INDEX trên ORDER BY column
-- =====================================================
-- 
-- Nếu thường xuyên ORDER BY một column:
-- SELECT * FROM orders ORDER BY created_at DESC;
-- 
-- Tạo index sẽ giúp sort nhanh hơn

CREATE INDEX IF NOT EXISTS idx_orders_created_at 
ON orders(created_at DESC);

-- Demo Query:
EXPLAIN
SELECT * FROM orders 
ORDER BY created_at DESC 
LIMIT 10;

-- Expected: Index Scan (sort nhanh)

-- =====================================================
-- 9. COMPOSITE INDEX - Index trên nhiều columns
-- =====================================================
-- 
-- Nếu query với nhiều WHERE conditions:
-- SELECT * FROM orders
-- WHERE user_id = 1
-- AND created_at > '2024-01-01';
-- 
-- Tạo composite index:

CREATE INDEX IF NOT EXISTS idx_orders_user_created
ON orders(user_id, created_at);

-- Thứ tự columns quan trọng!
-- - Columns thường xuyên search first
-- - Columns range search last

-- Demo Query:
EXPLAIN
SELECT * FROM orders
WHERE user_id = 1
AND created_at > '2024-01-01'
ORDER BY created_at DESC;

-- Expected: Index Scan using idx_orders_user_created

-- =====================================================
-- 10. PARTIAL INDEX - Index cho dữ liệu cụ thể
-- =====================================================
-- 
-- Nếu query thường xuyên filter theo condition:
-- SELECT * FROM products WHERE stock > 0;
-- 
-- Tạo partial index chỉ cho active products:

CREATE INDEX IF NOT EXISTS idx_products_stock_positive
ON products(id) 
WHERE stock > 0;

-- Partial index nhỏ hơn, nhanh hơn
-- Tiết kiệm disk space

-- =====================================================
-- 11. COST ANALYSIS - Hiểu EXPLAIN output
-- =====================================================
-- 
-- EXPLAIN output:
-- cost=0.00..35.50 rows=1 width=500
-- 
-- cost=X..Y
-- - X: startup cost (để bắt đầu)
-- - Y: total cost (toàn bộ)
-- 
-- rows=1: ước tính 1 row sẽ return
-- width=500: mỗi row ~500 bytes

-- =====================================================
-- 12. FULL TABLE SCAN vs INDEX SCAN
-- =====================================================

-- Scenario 1: Query nhỏ (ít rows match)
EXPLAIN
SELECT * FROM products WHERE id = 1;
-- Result: Index Scan (nhanh!)

-- Scenario 2: Query lớn (nhiều rows match)
EXPLAIN
SELECT * FROM products WHERE price > 100;
-- Result: có thể là Seq Scan (nếu > 10% rows)
-- → Database quyết định scan toàn bộ nhanh hơn

-- =====================================================
-- 13. WHEN NOT TO INDEX
-- =====================================================
-- 
-- ❌ Bảng nhỏ (< 1000 rows)
-- Seq Scan đủ nhanh
-- 
-- ❌ Cột ít dùng search
-- Index không lợi ích
-- 
-- ❌ Cột thường xuyên UPDATE
-- Index làm write chậm
-- 
-- ❌ Cột có low cardinality
-- Ví dụ: status (chỉ 'pending', 'completed')
-- Index không hiệu quả

-- =====================================================
-- 14. INDEX MAINTENANCE - Kiểm tra index
-- =====================================================
-- 
-- Xem tất cả index trên table:
-- SELECT * FROM pg_indexes WHERE tablename = 'users';
-- 
-- Xem index không được dùng:
-- SELECT * FROM pg_stat_user_indexes 
-- WHERE idx_scan = 0;
-- 
-- Xem unused index:
-- SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE idx_scan = 0
-- ORDER BY pg_relation_size(indexrelid) DESC;

-- =====================================================
-- 15. BEST PRACTICES - Index Design
-- =====================================================
-- 
-- ✅ DO:
-- - Index columns thường dùng trong WHERE
-- - Index Foreign Key columns
-- - Index ORDER BY columns nếu frequent
-- - Use composite index nếu query kết hợp multiple columns
-- - Use EXPLAIN để verify index usage
-- - Monitor unused indexes
-- 
-- ❌ DON'T:
-- - Index mọi column
-- - Index columns ít dùng
-- - Index columns thường UPDATE
-- - Create duplicate indexes
-- - Ignore EXPLAIN output
-- - Leave unused indexes (clean up!)

-- =====================================================
-- 16. REAL-WORLD EXAMPLE - E-commerce Index Strategy
-- =====================================================
-- 
-- users table:
-- - Index email (thường search)
-- - Index created_at (thường sort)
-- 
-- products table:
-- - Index stock (thường check stock > 0)
-- - Index category (thường filter by category)
-- - Composite: (category, price) nếu filter keduanya
-- 
-- orders table:
-- - Index user_id (FK, JOIN)
-- - Index created_at (ORDER BY)
-- - Composite: (user_id, created_at) nếu query keduanya
-- 
-- order_items table:
-- - Index order_id (FK, JOIN)
-- - Index product_id (FK, JOIN)

-- =====================================================
-- 17. PERFORMANCE TIPS - Query Optimization
-- =====================================================
-- 
-- Tip 1: Always use EXPLAIN before optimization
-- EXPLAIN ANALYZE SELECT ...;
-- 
-- Tip 2: Index on columns in WHERE clause
-- SELECT * FROM users WHERE email = ?;  → index email
-- 
-- Tip 3: Index on columns in JOIN condition
-- JOIN users ON orders.user_id = users.id → index user_id
-- 
-- Tip 4: Watch out for implicit conversions
-- WHERE id = '123';  → '123' converted to int → may skip index
-- 
-- Tip 5: Use LIKE carefully
-- WHERE email LIKE 'abc%';  → can use index
-- WHERE email LIKE '%abc%';  → cannot use index (scan all)

-- =====================================================
-- 18. MONITORING - Track index usage
-- =====================================================
-- 
-- List all indexes and their stats:
-- SELECT 
--   indexname,
--   idx_scan as scans,
--   idx_tup_read as tuples_read,
--   idx_tup_fetch as tuples_fetched
-- FROM pg_stat_user_indexes
-- ORDER BY idx_scan DESC;
-- 
-- Find slow queries:
-- SELECT query, calls, total_time, mean_time
-- FROM pg_stat_statements
-- ORDER BY mean_time DESC
-- LIMIT 10;
