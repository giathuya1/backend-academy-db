-- =====================================================
-- Day 7: Transaction & Atomicity (Consistency Foundation)
-- =====================================================
-- Tệp này chứa ví dụ transaction và testing atomicity

-- =====================================================
-- 1. SCENARIO - Flow đặt hàng gồm 3 bước
-- =====================================================
-- Step 1: Tạo order
-- Step 2: Tạo order_item (chi tiết sản phẩm)
-- Step 3: Trừ stock
-- 
-- Nếu bước 3 lỗi mà không dùng transaction:
-- → Order đã tạo, Order_item đã tạo, nhưng stock chưa trừ
-- → Dữ liệu KHÔNG nhất quán

-- =====================================================
-- 2. ❌ SAI CÁCH - Không dùng Transaction
-- =====================================================
-- Vấn đề: Nếu bước 3 lỗi, dữ liệu sẽ inconsistent
-- Không nên dùng cách này trong production!

-- Step 1: Tạo order
-- INSERT INTO orders (user_id, total_amount)
-- VALUES (1, 1299.99)
-- RETURNING id;  -- Giả sử trả về order_id = 2

-- Step 2: Tạo order_item
-- INSERT INTO order_items (order_id, product_id, quantity, price)
-- VALUES (2, 1, 1, 1299.99);

-- Step 3: Trừ stock
-- UPDATE products SET stock = stock - 1 WHERE id = 1;
-- -- Nếu lỗi ở đây → order_item vẫn tồn tại, stock không trừ → SAI

-- =====================================================
-- 3. ✅ ĐÚNG CÁCH - Dùng Transaction
-- =====================================================
-- Atomicity: Hoặc toàn bộ commit hoặc toàn bộ rollback
-- Nếu bất kỳ bước nào lỗi → tất cả rollback

BEGIN;

  -- Step 1: Tạo order
  INSERT INTO orders (user_id, total_amount)
  VALUES (1, 1299.99);
  -- Lấy order_id vừa tạo (thường backend sẽ handle này)
  
  -- Step 2: Tạo order_item
  INSERT INTO order_items (order_id, product_id, quantity, price)
  VALUES (1, 1, 1, 1299.99);
  
  -- Step 3: Trừ stock (CHECK stock phải >= quantity trước)
  -- Nếu stock < 1 → sẽ lỗi (oversell protection)
  UPDATE products 
  SET stock = stock - 1 
  WHERE id = 1 AND stock >= 1;
  
  -- Kiểm tra xem có dòng nào được update (kiểm tra oversell)
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock for product 1';
  END IF;

COMMIT;
-- Hoặc nếu có lỗi → ROLLBACK

-- =====================================================
-- 4. Test Transaction - Demonstration
-- =====================================================
-- Đây là ví dụ để hiểu cơ chế, không chạy trực tiếp
-- Vì sẽ thay đổi data

-- Test 1: Normal case (thành công)
-- BEGIN;
--   INSERT INTO orders (user_id, total_amount) VALUES (2, 249.99);
--   INSERT INTO order_items (order_id, product_id, quantity, price) 
--   VALUES (?, 2, 1, 249.99);
--   UPDATE products SET stock = stock - 1 WHERE id = 2;
-- COMMIT;
-- Result: Tất cả thành công → data nhất quán

-- Test 2: Oversell case (stock < 1, sẽ fail)
-- BEGIN;
--   INSERT INTO orders (user_id, total_amount) VALUES (3, 1000.00);
--   INSERT INTO order_items (order_id, product_id, quantity, price) 
--   VALUES (?, 5, 1000, 999.99);
--   UPDATE products SET stock = stock - 1000 WHERE id = 5 AND stock >= 1000;
--   -- Stock không đủ → lỗi → ROLLBACK tất cả
-- COMMIT;
-- Result: Rollback → data nhất quán (không bán quá số lượng)

-- =====================================================
-- 5. SAVEPOINT - Partial Rollback (Nâng cao)
-- =====================================================
-- SAVEPOINT cho phép rollback một phần transaction

BEGIN;
  
  INSERT INTO orders (user_id, total_amount)
  VALUES (4, 500.00);
  -- order_id = 3 (giả sử)
  
  SAVEPOINT sp1;
  
  INSERT INTO order_items (order_id, product_id, quantity, price)
  VALUES (3, 1, 1, 500.00);
  
  SAVEPOINT sp2;
  
  -- Nếu bước này lỗi
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  
  -- Nếu muốn rollback chỉ từ sp2 (không rollback order_item)
  -- ROLLBACK TO sp2;
  
  COMMIT;

-- =====================================================
-- 6. Oversell Problem Demo
-- =====================================================
-- Giả sử: Product id=5 có stock = 2

-- Scenario: 2 user cùng đặt 1 sản phẩm đó
-- Nếu không kiểm soát:
--   User 1: stock = 2 - 1 = 1
--   User 2: stock = 1 - 1 = 0
--   OK (but if concurrent → could sell 3)

-- Cách kiểm soát:
-- 1. Check stock trước: SELECT stock FROM products WHERE id=5 FOR UPDATE;
-- 2. Kiểm tra: stock >= quantity?
-- 3. Trừ stock nếu đủ
-- 4. Transaction đảm bảo atomicity

-- =====================================================
-- 7. READONLY Transaction - Query an toàn
-- =====================================================
-- Dùng khi chỉ query, không sửa dữ liệu
-- Tránh lock conflicts với write transactions

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
  
  SELECT 
    o.id,
    u.email,
    SUM(oi.quantity * oi.price) AS total
  FROM orders o
  JOIN users u ON o.user_id = u.id
  LEFT JOIN order_items oi ON o.id = oi.order_id
  GROUP BY o.id, u.email;
  
COMMIT;

-- =====================================================
-- 8. Transaction Isolation Levels
-- =====================================================
-- READ UNCOMMITTED (không an toàn, ít dùng)
-- READ COMMITTED (mặc định, an toàn)
-- REPEATABLE READ (an toàn hơn)
-- SERIALIZABLE (an toàn nhất, chậm nhất)

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  -- Tất cả queries đều độc lập, không conflict
  -- Nhưng chậm vì lock mạnh
COMMIT;

-- =====================================================
-- 9. Error Handling Pattern (giả lập backend logic)
-- =====================================================
-- Đây là pattern sẽ implement trong Node.js/Express

DO $$
BEGIN
  BEGIN
    INSERT INTO orders (user_id, total_amount)
    VALUES (5, 100.00);
    
    INSERT INTO order_items (order_id, product_id, quantity, price)
    VALUES (4, 1, 1, 100.00);  -- Giả sử order_id = 4
    
    UPDATE products SET stock = stock - 1 WHERE id = 1;
    
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE NOTICE 'Transaction failed: %', SQLERRM;
  END;
END $$;

-- =====================================================
-- 10. Best Practices - Transaction Design
-- =====================================================
-- ✅ DO:
-- - Keep transactions SHORT and FOCUSED
-- - Commit as soon as possible
-- - Put transaction logic in service layer (backend)
-- - Use appropriate isolation level
-- - Handle exceptions with ROLLBACK

-- ❌ DON'T:
-- - Hold transaction for long time
-- - Mix read and write queries unnecessarily
-- - Place transaction logic in controller
-- - Commit half-way through
-- - Ignore error handling