# Day 6 - JOIN & Query Nghiệp Vụ (Relational Query Foundation)

## Những điều đã học

### Database không phải lưu trữ tĩnh
Database phải **xử lý quan hệ** giữa các bảng để trả lời các câu hỏi nghiệp vụ:
- Lấy danh sách đơn hàng kèm tên user
- Lấy chi tiết đơn hàng kèm sản phẩm
- Tính tổng tiền một đơn
- Lấy top sản phẩm bán chạy

**Nếu không dùng JOIN:**
- Phải query từng bảng riêng
- Tốn tài nguyên (N+1 query problem)
- Gây lỗi khi data thay đổi giữa queries

**JOIN giúp database xử lý quan hệ ngay tại tầng dữ liệu.**

---

## Bản chất của JOIN

**JOIN** = Kết hợp dữ liệu từ nhiều bảng dựa trên mối quan hệ.

Database thực hiện:
1. Tìm các row trong bảng thứ nhất
2. Tìm các row tương ứng trong bảng thứ hai (theo điều kiện ON)
3. Ghép chúng lại thành kết quả

---

## INNER JOIN - Dữ liệu chắc chắn tồn tại ở cả 2 bảng

### Syntax
```sql
SELECT o.id, u.email, o.total_amount
FROM orders o
INNER JOIN users u ON o.user_id = u.id;
```

### Hành vi
- ✅ Hiển thị: Orders có user tồn tại
- ❌ Loại trừ: Orders có user_id không tồn tại

### Khi nào dùng
- Khi bạn **chắc chắn** cả 2 bảng phải có dữ liệu
- Ví dụ: Lấy orders kèm user (vì FK RESTRICT bảo vệ)

### Diagram
```
Orders          Users
   1              1
   2              2
   3              X (không tồn tại)
   
INNER JOIN → chỉ hiển thị 1, 2
```

---

## LEFT JOIN - Giữ tất cả dữ liệu từ bảng trái

### Syntax
```sql
SELECT u.id, u.email, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email;
```

### Hành vi
- ✅ Hiển thị: Tất cả users
- ℹ️ NULL: Nếu user chưa có order

### Khi nào dùng
- Khi bạn muốn giữ tất cả record từ bảng trái
- Ví dụ: Liệt kê tất cả users, kể cả chưa mua gì

### Diagram
```
Users          Orders
   1    ←→       1
   2    ←→       2
   3             (NULL - không có order)
   
LEFT JOIN → hiển thị 1, 2, 3 (3 có NULL)
```

---

## JOIN Nhiều Bảng - 4-Table JOIN

### Câu hỏi: Chi tiết đơn hàng gồm user, sản phẩm, giá?

```sql
SELECT 
    o.id AS order_id,
    u.email,
    p.name AS product_name,
    oi.quantity,
    oi.price
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id;
```

### Quy trình
1. Bắt đầu từ `orders` (o)
2. JOIN với `users` (u) qua `o.user_id = u.id`
3. JOIN với `order_items` (oi) qua `o.id = oi.order_id`
4. JOIN với `products` (p) qua `oi.product_id = p.id`

### Kết quả: 1 row = 1 order-item combo

---

## GROUP BY & Aggregate Functions

### Aggregate Functions
- `COUNT(*)` - đếm số rows
- `SUM(column)` - tổng cộng
- `AVG(column)` - trung bình
- `MAX(column)` / `MIN(column)` - max/min

### GROUP BY - Nhóm dữ liệu

**Câu hỏi: Tổng doanh thu theo user?**

```sql
SELECT 
    u.email,
    COUNT(o.id) AS total_orders,
    SUM(o.total_amount) AS total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.email;
```

**Cơ chế:**
1. LEFT JOIN users với orders
2. GROUP BY u.email → nhóm tất cả rows cùng email
3. COUNT(o.id) → đếm số orders trong mỗi nhóm
4. SUM(o.total_amount) → tổng tiền trong mỗi nhóm

**Kết quả:**
```
email          total_orders   total_spent
user1@...      2              1549.98
user2@...      0              NULL
```

---

## N+1 Query Problem - Hiểu Vấn đề

### ❌ SAI CÁCH (N+1 queries)

```python
# Query 1: Lấy tất cả orders
orders = db.query("SELECT * FROM orders");  # 1 query

# Query N+M: Với mỗi order, lấy user, order_items, products
for order in orders:
    user = db.query("SELECT * FROM users WHERE id = ?", order.user_id);  # N queries
    items = db.query("SELECT * FROM order_items WHERE order_id = ?", order.id);  # N queries
    
    for item in items:
        product = db.query("SELECT * FROM products WHERE id = ?", item.product_id);  # M queries
```

**Tổng queries: 1 + N + N + M = quá chậm!**

### ✅ ĐÚNG CÁCH (1 query duy nhất)

```sql
SELECT 
    o.id, u.email, p.name, oi.quantity
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id;
```

**Tổng queries: 1 query duy nhất** 🎉

### Hậu quả của N+1
- ❌ CPU cao
- ❌ I/O cao
- ❌ Network chậm
- ❌ Production fail

---

## INNER JOIN vs LEFT JOIN - So sánh

| Tiêu chí | INNER JOIN | LEFT JOIN |
|---------|-----------|-----------|
| Dữ liệu từ trái | ✅ Có | ✅ Tất cả |
| Dữ liệu từ phải | ✅ Có | ℹ️ Có hoặc NULL |
| Chỉ lấy khớp? | ✅ Có | ❌ Không |
| Khi dùng | Chắc chắn tồn tại | Có thể thiếu |

### Ví dụ

**INNER JOIN (chỉ users có order):**
```sql
SELECT u.email, COUNT(o.id)
FROM users u
INNER JOIN orders o ON u.id = o.user_id
GROUP BY u.email;
```
Result: Chỉ user1 (vì user2, 3, 4, 5 chưa có order)

**LEFT JOIN (tất cả users):**
```sql
SELECT u.email, COUNT(o.id)
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.email;
```
Result: user1, user2, user3, user4, user5 (user2-5 có count = 0)

---

## Alias - Làm code dễ đọc

### ❌ Không dùng alias (khó đọc)
```sql
SELECT 
    orders.id,
    users.email,
    orders.total_amount
FROM orders
INNER JOIN users ON orders.user_id = users.id;
```

### ✅ Dùng alias (dễ đọc)
```sql
SELECT 
    o.id,
    u.email,
    o.total_amount
FROM orders o
INNER JOIN users u ON o.user_id = u.id;
```

---

## Những lỗi phổ biến

### ❌ Sai 1: Quên điều kiện ON
```sql
SELECT * FROM orders o
INNER JOIN users u;  -- Quên ON → Cartesian product (sai!)
```

### ❌ Sai 2: GROUP BY thiếu cột
```sql
SELECT u.email, COUNT(o.id)
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id;  -- Thiếu u.email → lỗi!
```

### ❌ Sai 3: Nhầm INNER vs LEFT
```sql
SELECT u.email
FROM users u
INNER JOIN orders o ON u.id = o.user_id;  -- Không hiển thị users chưa mua
-- Nên dùng LEFT JOIN
```

### ❌ Sai 4: Không hiểu dữ liệu trước
```sql
SELECT p.name
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id;
-- Không group by → hiển thị nhiều rows cùng product
-- Nên thêm: GROUP BY p.id, p.name
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **JOIN thực chất làm gì?**
   - Kết hợp dữ liệu từ nhiều bảng dựa trên điều kiện ON

2. ✓ **INNER JOIN khác LEFT JOIN thế nào?**
   - INNER: Chỉ hiển thị rows khớp ở cả 2 bảng
   - LEFT: Hiển thị tất cả từ bảng trái, NULL nếu không khớp

3. ✓ **Vì sao JOIN giúp giảm số query?**
   - Xử lý quan hệ ngay tại database, không cần múu query rời rạc

4. ✓ **Khi nào cần GROUP BY?**
   - Khi muốn nhóm dữ liệu và sử dụng aggregate functions

5. ✓ **N+1 query problem là gì?**
   - 1 query chính + N queries lặp = quá chậm
   - Giải pháp: Dùng 1 JOIN query thay vì multiple queries

---

## Query Performance Tips

1. ✅ **Luôn JOIN thay vì multiple queries**
2. ✅ **Dùng INNER JOIN khi chắc chắn dữ liệu tồn tại**
3. ✅ **Dùng LEFT JOIN khi cần giữ tất cả record**
4. ✅ **Luôn dùng alias cho clarity**
5. ✅ **GROUP BY khi dùng aggregate functions**
6. ✅ **Test query trước khi đưa vào production**

---

## Key Takeaway

**JOIN không phải optional.**

**JOIN là cách chuẩn để xử lý quan hệ trong database.**

Một backend engineer phải viết query tối ưu từ đầu, không phải sửa sau khi bị slow production.
