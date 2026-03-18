# Day 9 - Index & Query Performance Foundation

## Những điều đã học

### Database không phải lúc nào cũng nhanh
- Bảng nhỏ (1000 rows) → nhanh
- Bảng lớn (1,000,000 rows) → chậm
- Vì sao? **Không có index → Full Table Scan**

### Vấn đề thực tế
```
Query: SELECT * FROM users WHERE email = 'abc@gmail.com';

Không index:
→ Scan toàn bộ 1,000,000 rows
→ ~500-1000 ms (rất chậm!)

Có index:
→ Nhảy trực tiếp tới email
→ ~1-10 ms (nhanh!)

Speedup: 50-100x!
```

---

## Index là gì?

**Index** = Cấu trúc dữ liệu đặc biệt để tìm kiếm nhanh.

### Analogy: Mục lục trong sách
```
Không có index (mục lục):
→ Phải đọc trang 1-500 để tìm từ X
→ Chậm

Có index (mục lục):
→ Nhảy trực tiếp tới trang 123
→ Nhanh
```

### Trade-off
- ✅ Đọc nhanh hơn (SELECT)
- ❌ Ghi chậm hơn (INSERT/UPDATE/DELETE)

---

## B-Tree Index - Cơ chế hoạt động

### PostgreSQL sử dụng B-tree (mặc định)

```
Bảng: users (1,000,000 rows)
Index trên email:

Root Node
├── 'a' - 'h'
├── 'i' - 'p'
└── 'q' - 'z'

Query: email = 'bob@gmail.com'
→ Đi vào 'a' - 'h' branch
→ Đi vào leaf node
→ Tìm thấy trong ~10-20 comparisons (log N)
→ Thay vì scan 1,000,000 rows (linear scan)
```

### Độ phức tạp
- **Full Table Scan**: O(N) - scan toàn bộ N rows
- **Index Scan**: O(log N) - binary search

---

## PRIMARY KEY tự động có INDEX

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,  -- Tự động có index!
  email VARCHAR(255),
  ...
);
```

**PostgreSQL tự tạo index trên id**

Đó là lý do:
```sql
SELECT * FROM users WHERE id = 1;
```
**Rất nhanh** (dùng index trên PK)

---

## Khi nào cần INDEX?

### 1. WHERE Clause - Tìm kiếm theo column
```sql
SELECT * FROM users WHERE email = 'abc@gmail.com';
-- Nên index email
CREATE INDEX idx_users_email ON users(email);
```

### 2. JOIN - Foreign Key
```sql
SELECT * FROM orders
JOIN users ON orders.user_id = users.id
WHERE orders.user_id = 1;
-- Nên index orders.user_id
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

### 3. ORDER BY - Sort thường xuyên
```sql
SELECT * FROM orders 
ORDER BY created_at DESC;
-- Nên index created_at nếu query này thường xuyên
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

### 4. Range Query - Range search
```sql
SELECT * FROM orders 
WHERE created_at > '2024-01-01' 
AND created_at < '2024-12-31';
-- Index giúp range search
CREATE INDEX idx_orders_date ON orders(created_at);
```

---

## EXPLAIN - Hiểu cách database chạy query

### Syntax
```sql
EXPLAIN SELECT ...;           -- Chỉ plan
EXPLAIN ANALYZE SELECT ...;   -- Plan + actual execution
```

### Output format
```
Method  (cost=startup..total rows=estimated width=size)
  Actual Time: startup..total rows=actual_rows
```

### Example: Trước tạo index
```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user1@example.com';

-- Seq Scan on users  (cost=0.00..35.50 rows=1 width=500)
--   Filter: (email = 'user1@example.com')
--   Actual Time: 0.125 ms  Rows: 1
```

**Phân tích:**
- ❌ **Seq Scan** = Scan tuần tự (chậm!)
- ❌ **Cost 35.50** = tổng cost (cao!)
- ❌ **Actual Time 0.125 ms** = thực tế mất thời gian

### Example: Sau tạo index
```sql
CREATE INDEX idx_users_email ON users(email);

EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user1@example.com';

-- Index Scan using idx_users_email on users  
--   (cost=0.29..8.30 rows=1 width=500)
--   Index Cond: (email = 'user1@example.com')
--   Actual Time: 0.045 ms  Rows: 1
```

**Phân tích:**
- ✅ **Index Scan** = Dùng index (nhanh!)
- ✅ **Cost 8.30** = tổng cost (thấp! 76% giảm)
- ✅ **Actual Time 0.045 ms** = nhanh hơn (64% giảm)

---

## Composite Index - Index trên nhiều columns

### Khi nào dùng?
```sql
SELECT * FROM orders
WHERE user_id = 1
AND created_at > '2024-01-01'
ORDER BY created_at DESC;
```

Query này filter theo **2 columns**: user_id AND created_at

### Composite Index
```sql
CREATE INDEX idx_orders_user_created
ON orders(user_id, created_at DESC);
```

### Thứ tự columns quan trọng!
```
GOOD: (user_id, created_at)
- user_id: equality (=), search đầu tiên
- created_at: range (>), search sau
→ Index tree được organize tốt

BAD: (created_at, user_id)
- created_at: range (>), search đầu tiên
- user_id: equality (=), search sau
→ Index tree không tối ưu
```

### Quy tắc
1. **Equality columns first** (=, IN)
2. **Range columns after** (>, <, BETWEEN)
3. **ORDER BY columns last** (DESC/ASC)

---

## PARTIAL INDEX - Index cho dữ liệu cụ thể

### Khi nào dùng?
```sql
-- Thường xuyên query products với stock > 0
SELECT * FROM products WHERE stock > 0;
```

### Partial Index - chỉ index active rows
```sql
CREATE INDEX idx_products_stock_positive
ON products(id) WHERE stock > 0;
```

### Lợi ích
- ✅ Index nhỏ hơn (chỉ ~10% rows)
- ✅ Nhanh hơn
- ✅ Tiết kiệm disk space
- ✅ UPDATE các products với stock=0 không ảnh hưởng index

---

## EXPLAIN Output - Hiểu Cost

### Format
```
cost=startup..total
```

- **startup**: Độ trễ để bắt đầu (phụ thuộc method)
- **total**: Tổng cost để hoàn thành

### Cost interpretation
```
cost=0.00..35.50 < 1000?       → Nhỏ
cost=1000..5000?                → Vừa
cost=10000..100000?             → Lớn
cost=100000..1000000?           → Rất lớn (Full table scan!)
```

### Khi nào lo lắng?
- ✅ cost < 100: Tốt
- ⚠️ cost 100-1000: Bình thường
- ❌ cost > 1000: Cần optimize (thêm index)

---

## LIKE Query - Pattern Matching

### Prefix Search (CÓ thể dùng index)
```sql
WHERE email LIKE 'user%';     -- Tìm từ đầu
```
✅ Index có thể giúp

### Infix/Suffix Search (KHÔNG thể dùng index)
```sql
WHERE email LIKE '%user%';    -- Tìm ở giữa
WHERE email LIKE '%user';     -- Tìm từ cuối
```
❌ Phải Seq Scan

---

## Khi KHÔNG nên tạo INDEX

### ❌ 1. Bảng nhỏ (< 1000 rows)
```sql
-- Seq Scan đủ nhanh, không cần index
CREATE TABLE small_table (
  id INT PRIMARY KEY,
  name VARCHAR(255)
);  -- 100 rows → Seq Scan OK
```

### ❌ 2. Cột ít dùng search
```sql
-- Cột notes ít dùng trong WHERE
-- Không tạo index
CREATE INDEX idx_orders_notes ON orders(notes);  -- Lãng phí
```

### ❌ 3. Cột thường xuyên UPDATE
```sql
-- Cột page_views UPDATE liên tục
-- Không tạo index (index update cost cao)
CREATE INDEX idx_products_page_views 
ON products(page_views);  -- ❌ Lãng phí
```

### ❌ 4. Low Cardinality (ít unique values)
```sql
-- Cột status chỉ có 2 values: 'active', 'inactive'
-- 900,000 rows = 'active', 100,000 rows = 'inactive'
-- Index fetch 900,000 rows vẫn chậm
-- Seq Scan có thể nhanh hơn!

CREATE INDEX idx_products_status 
ON products(status);  -- ❌ Không hiệu quả
```

---

## Index Monitoring - Xem index nào dùng

### Query - Xem tất cả indexes
```sql
SELECT 
  indexname,
  idx_scan as scans,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Phát hiện unused indexes
```sql
SELECT 
  indexname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Hành động
- ✅ 0 scans → Xóa unused index
```sql
DROP INDEX idx_products_stock;
```

---

## Real-World E-commerce Index Strategy

### Users table
```sql
-- 1. Search by email
CREATE INDEX idx_users_email ON users(email);

-- 2. Sort by created_at
CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

### Products table
```sql
-- 1. Partial index for active products
CREATE INDEX idx_products_stock_positive 
ON products(id) WHERE stock > 0;

-- 2. Filter by category
CREATE INDEX idx_products_category ON products(category);
```

### Orders table
```sql
-- 1. FK JOIN
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- 2. Sort by created_at
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- 3. Composite for user_id + created_at query
CREATE INDEX idx_orders_user_created 
ON orders(user_id, created_at DESC);
```

### Order_items table
```sql
-- 1. FK JOIN to orders
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- 2. FK JOIN to products
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Vì sao query chậm?**
   - Không có index → Full Table Scan
   - Phải đọc toàn bộ bảng (O(N))
   - Bảng lớn → rất chậm

2. ✓ **Index giúp gì?**
   - Nhảy trực tiếp tới vị trí (B-tree O(log N))
   - Tránh Full Table Scan
   - 50-100x nhanh hơn

3. ✓ **Vì sao index làm write chậm hơn?**
   - INSERT/UPDATE/DELETE phải update index
   - Index là cấu trúc B-tree phức tạp
   - Phải maintain order + balance

4. ✓ **Khi nào nên tạo composite index?**
   - Khi query filter + sort bằng multiple columns
   - Thứ tự: equality → range → order by
   - Composite index > 2 single-column indexes

5. ✓ **EXPLAIN dùng để làm gì?**
   - Xem query plan database sẽ dùng
   - Phát hiện Seq Scan (chậm)
   - Verify index có hiệu quả
   - So sánh trước/sau optimization

---

## Best Practices - Index Design

### ✅ DO:
1. **Use EXPLAIN trước khi tạo index**
   - Verify index thực sự hiệu quả

2. **Index columns trong WHERE clause**
   - WHERE email = ? → index email

3. **Index Foreign Key columns**
   - JOIN sẽ dùng index

4. **Index ORDER BY columns**
   - Sort nhanh hơn

5. **Use composite index cho multiple conditions**
   - WHERE user_id = 1 AND created_at > ? → composite index

6. **Monitor unused indexes**
   - Xóa index không dùng

### ❌ DON'T:
1. **Index mọi column**
   - Lãng phí disk, làm write chậm

2. **Index columns ít dùng search**
   - Không lợi ích

3. **Index columns UPDATE frequently**
   - Trade-off không đáng

4. **Create duplicate indexes**
   - SELECT * FROM pg_indexes để check

5. **Ignore EXPLAIN output**
   - Phải verify index có dùng

6. **Index low-cardinality columns**
   - Ít unique values → index không hiệu quả

---

## Production Mindset

**Backend Engineer phải tư duy performance từ đầu.**

### Workflow
1. ✅ Write query
2. ✅ Run EXPLAIN ANALYZE
3. ✅ Nếu Seq Scan → tạo index
4. ✅ Run EXPLAIN lại → verify
5. ✅ Deploy

### Anti-pattern (❌ không làm)
1. ❌ Write query without EXPLAIN
2. ❌ Deploy without testing
3. ❌ Wait for production to be slow
4. ❌ "Ít users nên không sao"

---

## Performance Summary

| Scenario | Before | After | Speedup |
|----------|--------|-------|---------|
| Search by email (1M rows) | 500ms | 5ms | 100x |
| JOIN via FK | 100ms | 10ms | 10x |
| ORDER BY (1M rows) | 2000ms | 100ms | 20x |
| Composite query | 200ms | 20ms | 10x |

---

## Key Takeaway

**Performance ≠ Magic**

**Performance = Understanding query execution + Strategic indexing**

Backend Engineer không viết query và chờ nó chạy.

Backend Engineer viết query, run EXPLAIN, understand result, optimize nếu cần.

Đó là sự khác biệt giữa **junior** và **professional** backend engineer.
