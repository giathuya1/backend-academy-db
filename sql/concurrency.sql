-- =====================================================
-- Day 8: Isolation Level & Concurrency Basics
-- =====================================================
-- Tệp này chứa ví dụ về isolation levels, concurrency issues, và locking

-- =====================================================
-- 1. CONCURRENCY PROBLEM - Vấn đề thực tế
-- =====================================================
-- Giả sử: Stock = 10
-- 2 users đặt hàng cùng lúc
-- 
-- Nếu hệ thống không kiểm soát:
-- User 1: SELECT stock = 10, UPDATE stock = 10 - 1 = 9
-- User 2: SELECT stock = 10, UPDATE stock = 10 - 1 = 9 ❌ (nên là 8!)
-- 
-- Đây là vấn đề Race Condition / Concurrency Problem

-- =====================================================
-- 2. READ COMMITTED - Isolation Level mặc định
-- =====================================================
-- Hành vi:
-- ✅ Không đọc uncommitted data (không dirty read)
-- ⚠️ Có thể gặp non-repeatable read
-- ⚠️ Có thể gặp phantom read
-- ✅ Nhanh, phù hợp hầu hết cases

-- Demo với 2 sessions:
-- 
-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT stock FROM products WHERE id = 1;  -- Giả sử: 15
-- 
-- SESSION 2 (Parallel):
-- BEGIN;
-- UPDATE products SET stock = stock - 5 WHERE id = 1;
-- COMMIT;  -- Stock = 10
-- 
-- SESSION 1:
-- SELECT stock FROM products WHERE id = 1;  -- Result: 10 (non-repeatable read!)
-- COMMIT;

-- =====================================================
-- 3. REPEATABLE READ - Isolation Level an toàn cao hơn
-- =====================================================
-- Hành vi:
-- ✅ Không dirty read
-- ✅ Không non-repeatable read
-- ⚠️ Có thể gặp phantom read
-- ⚠️ Chậm hơn READ COMMITTED

-- Demo với 2 sessions:
-- 
-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- SELECT stock FROM products WHERE id = 1;  -- Giả sử: 15
-- 
-- SESSION 2 (Parallel):
-- BEGIN;
-- UPDATE products SET stock = stock - 5 WHERE id = 1;
-- COMMIT;  -- Stock = 10
-- 
-- SESSION 1:
-- SELECT stock FROM products WHERE id = 1;  -- Result: 15 (snapshot at BEGIN)
-- COMMIT;

-- =====================================================
-- 4. SERIALIZABLE - Isolation Level an toàn nhất
-- =====================================================
-- Hành vi:
-- ✅ Không dirty read
-- ✅ Không non-repeatable read
-- ✅ Không phantom read
-- ❌ Chậm nhất, lock mạnh

-- Demo:
-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- SELECT * FROM products WHERE id = 1;
-- 
-- SESSION 2 sẽ chờ SESSION 1 commit trước khi được update

-- =====================================================
-- 5. DIRTY READ - Đọc uncommitted data (READ UNCOMMITTED)
-- =====================================================
-- ⚠️ PostgreSQL không hỗ trợ DIRTY READ mặc định
-- Nhưng nếu có database khác như MySQL, điều này có thể xảy ra

-- Scenario:
-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- SELECT stock FROM products WHERE id = 1;
-- 
-- SESSION 2:
-- BEGIN;
-- UPDATE products SET stock = -100 WHERE id = 1;  -- Invalid!
-- -- Session 1 đã đọc -100 (uncommitted)
-- ROLLBACK;  -- Rollback vì constraint CHECK
-- 
-- SESSION 1 đã đọc dữ liệu "ma" (dirty read)

-- =====================================================
-- 6. NON-REPEATABLE READ - Dữ liệu thay đổi trong transaction
-- =====================================================
-- Xảy ra ở READ COMMITTED

-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT price FROM products WHERE id = 1;  -- $1299.99
-- 
-- SESSION 2:
-- BEGIN;
-- UPDATE products SET price = 999.99 WHERE id = 1;
-- COMMIT;
-- 
-- SESSION 1:
-- SELECT price FROM products WHERE id = 1;  -- $999.99 (khác!)
-- COMMIT;

-- =====================================================
-- 7. PHANTOM READ - Xuất hiện row mới trong transaction
-- =====================================================
-- Xảy ra ở READ COMMITTED và REPEATABLE READ

-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT COUNT(*) FROM products WHERE stock < 5;  -- Count: 1
-- 
-- SESSION 2:
-- BEGIN;
-- INSERT INTO products (name, price, stock) VALUES ('New Product', 50, 2);
-- COMMIT;
-- 
-- SESSION 1:
-- SELECT COUNT(*) FROM products WHERE stock < 5;  -- Count: 2 (phantom!)
-- COMMIT;

-- =====================================================
-- 8. SELECT FOR UPDATE - Lock row để tránh oversell
-- =====================================================
-- Cách giải quyết vấn đề concurrency

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
  
  -- Lock row trước khi đọc
  SELECT stock FROM products 
  WHERE id = 1 
  FOR UPDATE;  -- Row bị lock đến khi COMMIT
  
  -- Kiểm tra stock
  IF (SELECT stock FROM products WHERE id = 1) >= 1 THEN
    -- Trừ stock
    UPDATE products SET stock = stock - 1 WHERE id = 1;
  ELSE
    RAISE EXCEPTION 'Insufficient stock';
  END IF;

COMMIT;

-- Tại thời điểm này, row được unlock
-- Session khác có thể lock + update

-- =====================================================
-- 9. NOWAIT vs SKIP LOCKED - Lock strategies
-- =====================================================

-- NOWAIT - Không chờ, trả về error ngay
-- SELECT stock FROM products WHERE id = 1 FOR UPDATE NOWAIT;
-- Nếu row đang bị lock → ERROR

-- SKIP LOCKED - Bỏ qua row đang bị lock
-- SELECT stock FROM products WHERE id = 1 FOR UPDATE SKIP LOCKED;
-- Nếu row đang bị lock → bỏ qua, trả về 0 rows

-- =====================================================
-- 10. LOCK TYPES - Các loại lock trong PostgreSQL
-- =====================================================

-- ACCESS SHARE - Share lock, cho phép read
-- SELECT ... FOR SHARE;  -- Multiple transactions có thể share lock

-- EXCLUSIVE - Exclusive lock, chỉ 1 transaction
-- SELECT ... FOR UPDATE;  -- Chỉ 1 transaction lock

-- =====================================================
-- 11. DEADLOCK - Khi 2 transactions chờ lẫn nhau
-- =====================================================
-- Scenario:
-- 
-- SESSION 1:
-- BEGIN;
-- SELECT * FROM products WHERE id = 1 FOR UPDATE;
-- SELECT * FROM products WHERE id = 2 FOR UPDATE;  -- Chờ Session 2 release lock
-- 
-- SESSION 2:
-- BEGIN;
-- SELECT * FROM products WHERE id = 2 FOR UPDATE;
-- SELECT * FROM products WHERE id = 1 FOR UPDATE;  -- Chờ Session 1 release lock
-- 
-- Cả 2 đang chờ nhau → DEADLOCK!
-- PostgreSQL sẽ detect và raise exception
-- 
-- Giải pháp: Lock theo thứ tự nhất quán (id1 trước id2)

-- =====================================================
-- 12. DEMONSTRATION - Non-repeatable Read (READ COMMITTED)
-- =====================================================
-- Đây là pattern để hiểu vấn đề

-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT price FROM products WHERE id = 2;  -- $249.99
-- SAVEPOINT sp1;
-- 
-- SESSION 2:
-- UPDATE products SET price = 199.99 WHERE id = 2;
-- 
-- SESSION 1:
-- SELECT price FROM products WHERE id = 2;  -- $199.99 (NON-REPEATABLE!)
-- ROLLBACK TO sp1;  -- Rollback to snapshot

-- =====================================================
-- 13. DEMONSTRATION - Repeatable Read Protection
-- =====================================================
-- 
-- SESSION 1:
-- BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- SELECT price FROM products WHERE id = 2;  -- $249.99 (snapshot)
-- 
-- SESSION 2:
-- UPDATE products SET price = 199.99 WHERE id = 2;
-- 
-- SESSION 1:
-- SELECT price FROM products WHERE id = 2;  -- $249.99 (still snapshot!)
-- COMMIT;

-- =====================================================
-- 14. BEST PRACTICES - Concurrency Design
-- =====================================================
-- 
-- ✅ DO:
-- - Giữ transaction ngắn
-- - Lock dữ liệu cần thiết (FOR UPDATE)
-- - Lock theo thứ tự nhất quán (tránh deadlock)
-- - Xử lý exception khi deadlock xảy ra
-- - Sử dụng READ COMMITTED cho hầu hết cases
-- 
-- ❌ DON'T:
-- - Giữ transaction lâu
-- - Lock toàn bộ dữ liệu không cần thiết
-- - Lock theo thứ tự ngẫu nhiên
-- - Không xử lý retry khi deadlock
-- - Dùng SERIALIZABLE ở mọi nơi (quá chậm)

-- =====================================================
-- 15. Production Pattern - Safe Order Processing
-- =====================================================

-- Safe procedure để xử lý order với concurrency control:
-- 
-- BEGIN;
--   -- Step 1: Lock product for update
--   SELECT id, stock FROM products WHERE id = 1 FOR UPDATE;
--   
--   -- Step 2: Check stock
--   IF (SELECT stock FROM products WHERE id = 1) < 1 THEN
--     RAISE EXCEPTION 'Stock unavailable';
--   END IF;
--   
--   -- Step 3: Create order (không cần lock, FK sẽ handle)
--   INSERT INTO orders (user_id, total_amount) VALUES (1, 1299.99);
--   
--   -- Step 4: Create order item
--   INSERT INTO order_items (order_id, product_id, quantity, price)
--   VALUES (?, 1, 1, 1299.99);
--   
--   -- Step 5: Deduct stock (row đã locked ở Step 1)
--   UPDATE products SET stock = stock - 1 WHERE id = 1;
--   
-- COMMIT;
-- -- Row được unlock tại đây

-- =====================================================
-- 16. Monitoring Locks - Xem lock nào đang active
-- =====================================================
-- 
-- Để xem transaction nào đang hold lock:
-- SELECT * FROM pg_locks WHERE NOT granted;
-- 
-- Để xem transaction details:
-- SELECT pid, usename, state, query FROM pg_stat_activity;
-- 
-- Để kill transaction (if deadlock):
-- SELECT pg_terminate_backend(pid);
