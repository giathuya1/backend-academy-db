-- =====================================================
-- Day 6: JOIN & Query Nghiệp Vụ (Relational Query)
-- =====================================================
-- Tệp này chứa các query JOIN thực tế để giải quyết yêu cầu nghiệp vụ

-- =====================================================
-- 1. QUERY CƠ BẢN - Lấy tất cả orders kèm email user (INNER JOIN)
-- =====================================================
-- Requirement: Liệt kê tất cả đơn hàng với thông tin khách hàng
-- JOIN type: INNER JOIN (chỉ lấy orders có user tồn tại)
SELECT 
    o.id AS order_id,
    u.id AS user_id,
    u.email,
    u.full_name,
    o.total_amount,
    o.created_at
FROM orders o
INNER JOIN users u ON o.user_id = u.id
ORDER BY o.created_at DESC;

-- =====================================================
-- 2. QUERY - Lấy chi tiết 1 đơn hàng (4-table JOIN)
-- =====================================================
-- Requirement: Chi tiết đơn hàng bao gồm sản phẩm và giá
-- Demo cho order_id = 1
SELECT 
    o.id AS order_id,
    u.email AS customer_email,
    u.full_name AS customer_name,
    p.id AS product_id,
    p.name AS product_name,
    oi.quantity,
    oi.price AS unit_price,
    (oi.quantity * oi.price) AS line_total,
    o.total_amount,
    o.created_at
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
WHERE o.id = 1
ORDER BY oi.id;

-- =====================================================
-- 3. QUERY - Tính tổng tiền từng order (GROUP BY + SUM)
-- =====================================================
-- Requirement: Tính lại tổng từ order_items để kiểm tra
-- Giúp kiểm tra data integrity
SELECT 
    o.id AS order_id,
    u.email,
    COUNT(oi.id) AS item_count,
    SUM(oi.quantity * oi.price) AS calculated_total,
    o.total_amount AS recorded_total,
    (o.total_amount - SUM(oi.quantity * oi.price)) AS difference
FROM orders o
INNER JOIN users u ON o.user_id = u.id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, u.email, o.total_amount
ORDER BY o.id;

-- =====================================================
-- 4. QUERY - Top 3 sản phẩm bán nhiều nhất (GROUP BY + ORDER BY LIMIT)
-- =====================================================
-- Requirement: Biết sản phẩm nào hot nhất
SELECT 
    p.id,
    p.name,
    p.price,
    COUNT(oi.id) AS times_sold,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * oi.price) AS revenue
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.price
ORDER BY revenue DESC NULLS LAST
LIMIT 3;

-- =====================================================
-- 5. QUERY - Tổng doanh thu theo user (LEFT JOIN + GROUP BY)
-- =====================================================
-- Requirement: Biết user nào chi tiêu nhiều nhất
-- LEFT JOIN vì muốn hiển thị cả user chưa có order
SELECT 
    u.id,
    u.email,
    u.full_name,
    COUNT(o.id) AS total_orders,
    SUM(o.total_amount) AS total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email, u.full_name
ORDER BY total_spent DESC NULLS LAST;

-- =====================================================
-- 6. QUERY - Lấy tất cả users kể cả chưa có order (LEFT JOIN)
-- =====================================================
-- Requirement: Liệt kê tất cả user, show NULL nếu chưa mua
-- Dùng LEFT JOIN để giữ tất cả users
SELECT 
    u.id,
    u.email,
    u.full_name,
    COUNT(o.id) AS order_count,
    COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email, u.full_name
ORDER BY u.id;

-- =====================================================
-- 7. QUERY - Orders từ user cụ thể (Parameterized Query Pattern)
-- =====================================================
-- Requirement: Lấy tất cả orders của 1 user
-- Ví dụ: user_id = 1
-- Note: Trong production, user_id sẽ là parameter
SELECT 
    o.id AS order_id,
    o.total_amount,
    COUNT(oi.id) AS item_count,
    o.created_at
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.user_id = 1
GROUP BY o.id, o.total_amount, o.created_at
ORDER BY o.created_at DESC;

-- =====================================================
-- 8. QUERY - So sánh INNER JOIN vs LEFT JOIN
-- =====================================================
-- INNER JOIN (chỉ orders có user)
-- Bao gồm: orders với user tồn tại
-- Loại trừ: orders với user_id không hợp lệ (nếu FK không bảo vệ)
SELECT COUNT(*) AS inner_join_count
FROM orders o
INNER JOIN users u ON o.user_id = u.id;

-- LEFT JOIN (tất cả orders, kể cả user không tồn tại)
-- Bao gồm: tất cả orders
-- Hiển thị: NULL nếu user không tồn tại
SELECT COUNT(*) AS left_join_count
FROM orders o
LEFT JOIN users u ON o.user_id = u.id;

-- =====================================================
-- 9. DEMONSTRATION - N+1 Query Problem
-- =====================================================
-- ❌ SAI CÁCH (Sẽ tốt hơn nếu sử dụng 1 JOIN query):
-- Query 1: SELECT * FROM orders;
-- Với MỖI order → Query: SELECT * FROM users WHERE id = user_id;
-- Với MỖI order → Query: SELECT * FROM order_items WHERE order_id = id;
-- Với MỖI order_item → Query: SELECT * FROM products WHERE id = product_id;
-- Total: 1 + N + N + M queries = quá chậm!

-- ✅ ĐÚNG CÁCH (1 query duy nhất):
-- Tất cả dữ liệu lấy trong 1 JOIN query
SELECT 
    o.id AS order_id,
    u.email,
    p.name AS product_name,
    oi.quantity
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id;

-- =====================================================
-- 10. ADVANCED - Subquery với JOIN (tìm orders > $500)
-- =====================================================
SELECT 
    o.id,
    u.email,
    o.total_amount,
    (SELECT COUNT(*) FROM order_items WHERE order_id = o.id) AS item_count
FROM orders o
INNER JOIN users u ON o.user_id = u.id
WHERE o.total_amount > 500
ORDER BY o.total_amount DESC;