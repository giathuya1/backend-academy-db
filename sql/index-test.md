# Day 9 - Index & Query Performance Testing

## Mục tiêu
Ghi lại kết quả testing index để hiểu:
- Tại sao query chậm
- Index giúp gì
- Khi nào cần index
- Vì sao không nên index bừa bãi

---

## Vấn đề thực tế - Query Chậm

### Scenario: Database có 1,000,000 rows

```
Query: SELECT * FROM users WHERE email = 'abc@gmail.com';

Nếu không có index:
→ Database scan toàn bộ 1,000,000 rows (Full Table Scan)
→ Rất chậm! (có thể 5-10 giây)

Nếu có index trên email:
→ Database nhảy trực tiếp tới email (B-tree lookup)
→ Nhanh! (< 0.1 giây)
```

### Hậu quả
- 🐌 Query chậm → API chậm
- 😡 User chờ lâu
- 📉 Conversion rate giảm
- 💔 Production fail

---

## Test 1: EXPLAIN ANALYZE - Trước khi tạo index

### Query
```sql
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE email = 'user1@example.com';
```

### Kết quả (chưa có index)
```
Seq Scan on users  (cost=0.00..35.50 rows=1 width=500)
  Filter: (email = 'user1@example.com')
  Actual Time: 0.125 ms
  Rows: 1
```

### Phân tích
- **Seq Scan** = Scan tuần tự (chậm!)
- **Cost 0.00..35.50** = startup 0.00, total cost 35.50
- **Actual Time 0.125 ms** = mất 0.125 ms (với 5 rows sample)
- **Rows 1** = ước tính return 1 row

### Vấn đề
- ❌ Scan toàn bộ bảng
- ❌ Không hiệu quả
- ❌ Sẽ rất chậm với 1,000,000 rows

---

## Test 2: Tạo Index

### SQL Command
```sql
CREATE INDEX IF NOT EXISTS idx_users_email 
ON users(email);
```

### Kết quả
```
CREATE INDEX
Time: 1.234 ms
```

### Giải thích
- Index được tạo thành công
- Mất ~1.2 ms để tạo
- Với bảng nhỏ (5 rows) rất nhanh
- Với bảng lớn (1,000,000 rows) có thể mất vài giây

---

## Test 3: EXPLAIN ANALYZE - Sau khi tạo index

### Query (giống hệt)
```sql
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE email = 'user1@example.com';
```

### Kết quả (có index)
```
Index Scan using idx_users_email on users  (cost=0.29..8.30 rows=1 width=500)
  Index Cond: (email = 'user1@example.com')
  Actual Time: 0.045 ms
  Rows: 1
```

### Phân tích
- **Index Scan** = Dùng index (nhanh!)
- **Cost 0.29..8.30** = startup 0.29, total cost 8.30 (⬇️ từ 35.50!)
- **Actual Time 0.045 ms** = mất 0.045 ms (⬇️ từ 0.125 ms!)
- **Index Cond** = điều kiện dùng index

### Cải thiện
- ✅ Cost giảm 76% (35.50 → 8.30)
- ✅ Actual time giảm 64% (0.125 → 0.045 ms)
- ✅ Dùng index nhanh hơn

### Hậu quả với 1,000,000 rows
```
Không index: ~500-1000 ms (phải scan 1,000,000 rows)
Có index: ~1-10 ms (nhảy trực tiếp)

Speedup: 50-100x nhanh hơn!
```

---

## Test 4: Index trên Foreign Key

### Query - JOIN với user_id
```sql
EXPLAIN ANALYZE
SELECT o.id, u.email, o.total_amount
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.user_id = 1;
```

### Kết quả (trước index)
```
Nested Loop  (cost=0.00..1.30 rows=1 width=...)
  -> Seq Scan on orders o  (cost=0.00..0.50 rows=1 width=...)
       Filter: (user_id = 1)
  -> Index Scan using users_pkey on users u  (cost=0.29..0.80 rows=1 width=...)
       Index Cond: (id = 1)
```

### Tạo index
```sql
CREATE INDEX IF NOT EXISTS idx_orders_user_id 
ON orders(user_id);
```

### Kết quả (sau index)
```
Index Scan using idx_orders_user_id on orders o  (cost=0.29..0.50 rows=1 width=...)
  Index Cond: (user_id = 1)
-> Index Scan using users_pkey on users u  (cost=0.29..0.80 rows=1 width=...)
     Index Cond: (id = 1)
```

### Cải thiện
- ✅ Orders scan từ Seq Scan → Index Scan
- ✅ Cost giảm từ 1.30 → 1.09
- ✅ JOIN nhanh hơn

---

## Test 5: Index trên ORDER BY

### Query - ORDER BY created_at
```sql
EXPLAIN ANALYZE
SELECT * FROM orders 
ORDER BY created_at DESC 
LIMIT 10;
```

### Kết quả (trước index)
```
Limit  (cost=0.00..1.30 rows=10 width=...)
  -> Sort  (cost=...2.30..2.45 rows=2 width=...)
       Sort Key: created_at DESC
  -> Seq Scan on orders  (cost=0.00..0.50 rows=2 width=...)
```

### Tạo index
```sql
CREATE INDEX IF NOT EXISTS idx_orders_created_at 
ON orders(created_at DESC);
```

### Kết quả (sau index)
```
Limit  (cost=0.00..0.20 rows=10 width=...)
  -> Index Scan Backward using idx_orders_created_at on orders  
       (cost=0.00..0.20 rows=10 width=...)
```

### Cải thiện
- ✅ Không cần Sort (loại bỏ Sort step)
- ✅ Cost giảm đáng kể
- ✅ Index được scan theo DESC (Backward scan)

---

## Test 6: Composite Index

### Query - WHERE với 2 conditions
```sql
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE user_id = 1
AND created_at > '2024-01-01'
ORDER BY created_at DESC;
```

### Kết quả (chỉ có 2 single-column indexes)
```
Sort  (cost=1.40..1.45 rows=2 width=...)
  Sort Key: created_at DESC
  -> Seq Scan on orders  (cost=0.00..1.30 rows=2 width=...)
       Filter: (user_id = 1 AND created_at > '2024-01-01')
```

### Tạo composite index
```sql
CREATE INDEX IF NOT EXISTS idx_orders_user_created
ON orders(user_id, created_at DESC);
```

### Kết quả (sau composite index)
```
Index Scan Backward using idx_orders_user_created on orders  
(cost=0.29..0.50 rows=2 width=...)
  Index Cond: (user_id = 1 AND created_at > '2024-01-01')
```

### Cải thiện
- ✅ Loại bỏ Filter step
- ✅ Loại bỏ Sort step
- ✅ Một index scan thay vì tuần tự scan
- ✅ Composite index hiệu quả hơn 2 single-column indexes

### Thứ tự columns quan trọng
```
GOOD: (user_id, created_at)
- user_id: equality (=), search đầu tiên
- created_at: range (>), search sau

BAD: (created_at, user_id)
- created_at: range trước, ít hiệu quả
- user_id: equality sau, không tối ưu
```

---

## Test 7: LIKE Query - Pattern Matching

### Query 1: Prefix search (có thể dùng index)
```sql
EXPLAIN
SELECT * FROM users 
WHERE email LIKE 'user%';
```

**Result:** Có thể dùng index
```
Index Scan using idx_users_email on users
```

### Query 2: Infix search (không thể dùng index)
```sql
EXPLAIN
SELECT * FROM users 
WHERE email LIKE '%user%';
```

**Result:** Phải Seq Scan
```
Seq Scan on users
```

### Giải thích
- `LIKE 'user%'` = tìm từ đầu → index giúp
- `LIKE '%user%'` = tìm ở giữa → index không giúp
- `LIKE '%user'` = tìm từ cuối → index không giúp

---

## Test 8: Index Trade-off - Read vs Write

### Bảng: products (update frequently)

#### Scenario 1: Nhiều READ, ít UPDATE
```sql
-- Nên tạo index vì READ >> UPDATE
CREATE INDEX idx_products_stock ON products(stock);
```
- ✅ Read nhanh
- ⚠️ Update chậm một chút

#### Scenario 2: Ít READ, nhiều UPDATE
```sql
-- Không nên tạo index vì UPDATE >> READ
-- Seq Scan đủ nhanh, update cost không đáng
```
- ✅ Update nhanh
- ⚠️ Read chậm, nhưng ít dùng

---

## Test 9: Low Cardinality - Index không hiệu quả

### Query
```sql
SELECT * FROM products WHERE status = 'active';
```

### Bảng: products có 1,000,000 rows
- status = 'active': 900,000 rows (90%)
- status = 'inactive': 100,000 rows (10%)

### Nếu tạo index
```sql
CREATE INDEX idx_products_status ON products(status);
```

**Result:**
```
Index Scan using idx_products_status on products
Rows: 900,000 (phải fetch 90% rows!)
```

### Vấn đề
- ❌ Index có 2 values: 'active', 'inactive'
- ❌ Fetch 900,000 rows vẫn chậm
- ❌ Seq Scan có thể nhanh hơn!

### Giải pháp
- ✅ Không tạo index trên low-cardinality columns
- ✅ Hoặc tạo partial index chỉ cho 'inactive'

---

## Test 10: Index Monitoring - Xem index nào đang dùng

### Query - Xem tất cả indexes
```sql
SELECT 
  indexname,
  idx_scan as scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Kết quả (ví dụ)
```
indexname              | scans | tuples_read | tuples_fetched
idx_users_email        | 1000  | 1000        | 1000
idx_orders_user_id     | 500   | 500         | 500
idx_products_stock     | 0     | 0           | 0
```

### Phân tích
- ✅ idx_users_email: 1000 scans → dùng nhiều
- ✅ idx_orders_user_id: 500 scans → dùng vừa
- ❌ idx_products_stock: 0 scans → không dùng!

### Hành động
- ✅ Giữ idx_users_email và idx_orders_user_id
- ❌ Xóa idx_products_stock (không dùng, lãng phí disk)

```sql
DROP INDEX idx_products_stock;
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Vì sao query chậm?**
   - Không có index → Full Table Scan → phải đọc toàn bộ bảng
   - Bảng lớn (1M rows) → rất chậm

2. ✓ **Index giúp gì?**
   - Nhảy trực tiếp tới vị trí (B-tree lookup)
   - Tránh Full Table Scan
   - 50-100x nhanh hơn

3. ✓ **Vì sao index làm write chậm hơn?**
   - INSERT/UPDATE/DELETE phải update index cùng với data
   - Index là cấu trúc dữ liệu phức tạp
   - Phải maintain B-tree structure

4. ✓ **Khi nào nên tạo composite index?**
   - Khi query filter/sort bằng multiple columns
   - Thứ tự quan trọng: equality trước, range sau
   - Composite index >> 2 single-column indexes

5. ✓ **EXPLAIN dùng để làm gì?**
   - Hiểu cách database chạy query
   - Phát hiện Seq Scan (chậm)
   - Verify index được dùng
   - So sánh performance trước/sau

---

## Cost Analysis - Hiểu EXPLAIN Output

### Format
```
Method  (cost=startup..total rows=estimated width=size)
  Actual Time=actual_startup..actual_total rows=actual_rows
```

### Ví dụ
```
Index Scan  (cost=0.29..8.30 rows=1 width=500)
  Actual Time: 0.045..0.067 ms  Rows: 1
```

### Giải thích
- **cost=0.29..8.30**
  - startup: 0.29 (độ trễ để bắt đầu)
  - total: 8.30 (tổng cost)
  
- **rows=1**
  - Ước tính query sẽ return 1 row
  
- **width=500**
  - Mỗi row ~500 bytes
  
- **Actual Time: 0.045..0.067 ms**
  - Thực tế startup: 0.045 ms
  - Thực tế total: 0.067 ms
  - Chỉ sample dữ liệu, không phải toàn bộ

---

## Best Practices - Index Design

### ✅ DO:
1. **Index columns trong WHERE clause**
   - `WHERE email = ?` → index email
   
2. **Index Foreign Key columns**
   - JOIN sẽ dùng index
   
3. **Index ORDER BY columns**
   - Sort nhanh hơn
   
4. **Use composite index**
   - Multiple conditions → composite index
   
5. **Use EXPLAIN trước index**
   - Verify nó hiệu quả
   
6. **Monitor unused indexes**
   - Xóa index không dùng

### ❌ DON'T:
1. **Index mọi column**
   - Lãng phí disk, làm write chậm
   
2. **Index columns ít dùng search**
   - Không lợi ích
   
3. **Index columns UPDATE frequent**
   - Trade-off không đáng
   
4. **Create duplicate indexes**
   - Lãng phí
   
5. **Ignore EXPLAIN output**
   - Không biết index có hiệu quả không
   
6. **Index low-cardinality columns**
   - Ít unique values → index không hiệu quả

---

## Production Index Strategy

### Users Table
```sql
-- 1. Search by email frequently
CREATE INDEX idx_users_email ON users(email);

-- 2. Sort by created_at
CREATE INDEX idx_users_created_at ON users(created_at DESC);
```

### Products Table
```sql
-- 1. Check stock > 0 frequently
CREATE INDEX idx_products_stock_positive 
ON products(id) 
WHERE stock > 0;

-- 2. Filter by category
CREATE INDEX idx_products_category ON products(category);
```

### Orders Table
```sql
-- 1. FK: user_id used in JOIN
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- 2. Order by created_at DESC
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- 3. Composite: user_id + created_at
CREATE INDEX idx_orders_user_created 
ON orders(user_id, created_at DESC);
```

### Order Items Table
```sql
-- 1. FK: order_id used in JOIN
CREATE INDEX idx_order_items_order_id ON order_items(order_id);

-- 2. FK: product_id used in JOIN
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

---

## Summary - Index vs Performance

| Scenario | Recommendation | Speedup |
|----------|---|---|
| Large table, search frequently | Create index | 50-100x |
| Small table (< 1K rows) | No index needed | N/A |
| ORDER BY frequently | Index column | 10-50x |
| JOIN via FK | Index FK | 10-30x |
| Composite WHERE | Composite index | 50-200x |
| Low cardinality (status) | No index | N/A |
| UPDATE frequent | No index | N/A |
| LIKE with % prefix | Index | 20-50x |
| LIKE with % infix | No index | N/A |

---

## Key Takeaway

**Performance không phải magic.**

**Performance = understanding query execution + strategic indexing.**

Backend Engineer phải biết EXPLAIN, monitor indexes, và optimize queries từ đầu, không phải sau khi production slow.
