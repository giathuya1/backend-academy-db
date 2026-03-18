# Day 5 - Relationship & Foreign Key (Database Modeling Foundation)

## Những điều đã học

### Database không phải tập hợp bảng rời rạc
Một hệ thống bán hàng có:
- `users` - người dùng
- `products` - sản phẩm
- `orders` - đơn hàng
- `order_items` - chi tiết từng sản phẩm trong đơn hàng

**Các bảng này KHÔNG độc lập.** Chúng liên kết logic với nhau.

### Ví dụ quan hệ:
- 1 user → nhiều orders (One-to-Many)
- 1 order → nhiều order_items (One-to-Many)
- 1 product → nhiều order_items (One-to-Many)

---

## Các loại quan hệ cơ bản

### 1. One-to-One (1–1)
```
users ← → user_profiles
1 user = 1 profile
```
**Ít dùng** trong giai đoạn đầu.

### 2. One-to-Many (1–N) ⭐ Phổ biến nhất
```
users (1) ← → (N) orders
1 user có nhiều orders

orders (1) ← → (N) order_items
1 order có nhiều items
```
**Đây là loại quan hệ phổ biến nhất trong backend.**

### 3. Many-to-Many (N–N)
```
products (N) ← → (N) categories
Sản phẩm có nhiều danh mục
Danh mục có nhiều sản phẩm
→ Phải dùng bảng trung gian (junction table)
```

---

## Foreign Key là gì?

**Foreign Key (FK)** = cột tham chiếu tới Primary Key của bảng khác.

### FK đảm bảo:
- ✅ Không thể tạo order nếu user không tồn tại
- ✅ Không thể tạo order_item nếu order không tồn tại
- ✅ Không thể tạo order_item nếu product không tồn tại

### Syntax:
```sql
CONSTRAINT fk_orders_user
    FOREIGN KEY(user_id)
    REFERENCES users(id)
```

---

## Bảng Orders - One-to-Many với Users

### Schema
```sql
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
```

### Giải thích:
- **user_id**: Tham chiếu tới `users.id`
- **NOT NULL**: Mỗi order phải thuộc một user
- **CHECK (total_amount >= 0)**: Tổng tiền không được âm
- **ON DELETE RESTRICT**: Không cho xóa user nếu user có order

---

## Bảng Order_Items - Two Foreign Keys

### Schema
```sql
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
```

### Giải thích:
- **order_id FK → orders.id**: Item thuộc order nào
- **product_id FK → products.id**: Sản phẩm nào trong order
- **quantity CHECK (quantity > 0)**: Số lượng phải dương
- **price**: Snapshot giá tại thời điểm đặt (không phải lấy từ products.price)
- **ON DELETE CASCADE**: Xóa order → xóa tất cả order_items
- **ON DELETE RESTRICT**: Không thể xóa product nếu đang trong order

---

## Vì sao lưu price riêng ở order_items?

**Snapshot Price Pattern** - Rất quan trọng!

### Sai (❌):
```sql
-- Nếu chỉ lưu product_id
SELECT oi.*, p.price FROM order_items oi
JOIN products p ON oi.product_id = p.id;
-- Nếu product.price thay đổi → tính toán lại order cũ → SAI
```

### Đúng (✅):
```sql
-- Lưu price riêng tại thời điểm đặt hàng
INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES (1, 1, 1, 1299.99);
-- Sau này product price thay đổi thành 999.99
-- order_items vẫn lưu giá 1299.99 → tính toán lịch sử đúng
```

---

## Referential Integrity - Bản chất

### Nếu không có FK (❌):
- Có thể tạo order cho user không tồn tại
- Có thể có order_item không thuộc order nào
- Dữ liệu rác tích lũy → khó cleanup

### Nếu có FK (✅):
- Database chặn order với user_id không tồn tại
- Database chặn order_item với order_id không tồn tại
- Tính nhất quán dữ liệu được bảo vệ
- Không có "orphan records" (bản ghi mồ côi)

---

## ON DELETE - Hai lựa chọn

### 1. ON DELETE RESTRICT (mặc định, an toàn)
```sql
FOREIGN KEY(user_id) REFERENCES users(id)
ON DELETE RESTRICT
```

**Hành vi:**
```sql
DELETE FROM users WHERE id = 1;
-- ERROR: Cannot delete user because orders exist
-- ❌ Xóa thất bại - data vẫn an toàn
```

**Khi dùng:** Dữ liệu không nên xóa tự động

### 2. ON DELETE CASCADE (xóa liên tầng)
```sql
FOREIGN KEY(order_id) REFERENCES orders(id)
ON DELETE CASCADE
```

**Hành vi:**
```sql
DELETE FROM orders WHERE id = 1;
-- ✅ Order bị xóa
-- ✅ Tất cả order_items của order này cũng bị xóa tự động
```

**Khi dùng:** Child records phụ thuộc vào parent

**⚠️ Cần cân nhắc kỹ** - CASCADE có thể xóa dữ liệu lớn!

---

## JOIN Queries - Truy vấn dữ liệu từ nhiều bảng

### Query 1: Orders với User Info
```sql
SELECT 
    o.id,
    u.email,
    u.full_name,
    o.total_amount,
    o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id;
```

### Query 2: Order Details (4-table JOIN)
```sql
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
JOIN products p ON oi.product_id = p.id;
```

### Query 3: Revenue per User
```sql
SELECT 
    u.id,
    u.email,
    COUNT(o.id) AS total_orders,
    SUM(o.total_amount) AS total_revenue
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email
ORDER BY total_revenue DESC;
```

---

## Foreign Key Constraint Testing

### Test 1: Insert order với user_id không tồn tại
```sql
INSERT INTO orders (user_id, total_amount) 
VALUES (9999, 1000);
```

**Expected Error:**
```
ERROR:  insert or update on table "orders" violates foreign key constraint "fk_orders_user"
DETAIL:  Key (user_id)=(9999) is not present in table "users".
```

### Test 2: Insert order_item với order_id không tồn tại
```sql
INSERT INTO order_items (order_id, product_id, quantity, price) 
VALUES (9999, 1, 1, 100);
```

**Expected Error:**
```
ERROR:  insert or update on table "order_items" violates foreign key constraint "fk_order_items_order"
```

### Test 3: Insert order_item với product_id không tồn tại
```sql
INSERT INTO order_items (order_id, product_id, quantity, price) 
VALUES (1, 9999, 1, 100);
```

**Expected Error:**
```
ERROR:  insert or update on table "order_items" violates foreign key constraint "fk_order_items_product"
```

---

## Những sai lầm phổ biến

### ❌ Sai 1: Không dùng FK
```sql
-- "Cho nhanh" - không dùng FK
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,  -- Không FK, không ràng buộc
    total_amount NUMERIC(12,2)
);
```
**Hậu quả:** Orphan data, không có referential integrity

### ❌ Sai 2: Không lưu snapshot price
```sql
-- Chỉ lưu product_id
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER
    -- Quên lưu price → tính toán sai khi price thay đổi
);
```

### ❌ Sai 3: Xóa dữ liệu tùy tiện
```sql
-- Xóa user mà không kiểm tra order
DELETE FROM users WHERE id = 1;
-- Nếu không có FK RESTRICT → orphan orders tồn tại
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Vì sao cần Foreign Key?**
   - FK bảo vệ referential integrity
   - Ngăn tạo dữ liệu không hợp lệ
   - Ngăn orphan records

2. ✓ **Nếu không có FK thì hậu quả gì?**
   - Có thể tạo order cho user không tồn tại
   - Dữ liệu rác tích lũy
   - Khó cleanup, khó debug

3. ✓ **Khi nào nên dùng ON DELETE CASCADE?**
   - Khi child record phụ thuộc vào parent
   - Ví dụ: Xóa order → xóa order_items
   - ⚠️ Cần cân nhắc, có thể xóa dữ liệu lớn

4. ✓ **Order_item có nên lưu price riêng không? Vì sao?**
   - ✅ CÓ, lưu snapshot price
   - Vì product price có thể thay đổi
   - Cần giữ lịch sử giá tại thời điểm đặt hàng

---

## Database Modeling Best Practices

1. ✅ **Luôn dùng Primary Key** - định danh duy nhất
2. ✅ **Luôn dùng Foreign Key** - bảo vệ referential integrity
3. ✅ **Lưu snapshot dữ liệu** - không phụ thuộc vào record khác thay đổi
4. ✅ **Cân nhắc ON DELETE** - RESTRICT an toàn hơn CASCADE
5. ✅ **Sử dụng JOIN** - truy vấn dữ liệu từ nhiều bảng
6. ✅ **Test constraint** - cố gắng vi phạm để chắc chắn FK hoạt động

---

## Diagram - Ecommerce Database Relationships

```
┌─────────────┐
│    users    │
│─────────────│
│ id (PK)     │
│ email       │
│ password    │
│ full_name   │
└──────┬──────┘
       │ 1
       │
       │ N
       ▼
┌─────────────┐         ┌──────────────┐
│   orders    │─────────│  order_items │
│─────────────│    1    │──────────────│
│ id (PK)     │         │ id (PK)      │
│ user_id(FK) │    N    │ order_id(FK) │
│ total_amt   │         │ product_id.. │
└─────────────┘         │ quantity     │
                        │ price        │
                        └──────┬───────┘
                               │
                               │ N
                               │
                               │ 1
                        ┌──────▼──────┐
                        │  products   │
                        │─────────────│
                        │ id (PK)     │
                        │ name        │
                        │ price       │
                        │ stock       │
                        └─────────────┘
```

---

## Key Takeaway

**Database modeling** không phải chỉ tạo bảng.

**Database modeling** là thiết kế **quan hệ** giữa các bảng để phản ánh **logic nghiệp vụ**.

Foreign Key + Constraints = Bảo vệ data integrity từ database level.
