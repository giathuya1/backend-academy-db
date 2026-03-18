# Day 8 - Isolation Level & Concurrency Testing

## Mục tiêu
Ghi lại kết quả testing concurrency để hiểu:
- Isolation level ảnh hưởng như thế nào
- Khi nào cần lock dữ liệu
- Vì sao hệ thống thực tế phải xử lý concurrency

---

## Vấn đề thực tế - Race Condition

### Scenario: 2 users đặt hàng cùng lúc

```
Product: AirPods (id=2, stock=50)

REQUEST 1 (User A):          REQUEST 2 (User B):
SELECT stock = 50      →     SELECT stock = 50
UPDATE stock = 50-1=49 ←     UPDATE stock = 50-1=49 ❌

Expected: stock = 48
Actual: stock = 49
Lost update!
```

### Hậu quả
- 📦 Tồn kho sai
- 💰 Doanh thu record sai (chỉ bán 1 nhưng thực tế bán 2)
- 🐛 Khó debug: "Tại sao stock lỗi?"
- 😡 Customer angry: "Tôi mua nhưng hết hàng"

---

## Test 1: READ COMMITTED (Mặc định) - Non-repeatable Read

### Chuẩn bị

**Trước test:**
```sql
SELECT price FROM products WHERE id = 2;
-- Result: $249.99
SELECT stock FROM products WHERE id = 2;
-- Result: 50
```

### Execution - 2 Sessions

**SESSION 1:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT price FROM products WHERE id = 2;
-- Read: $249.99 (snapshot tại thời điểm này)

-- Giả sử có processing logic ở đây...
-- SELECT * FROM order_items;
-- ...

SELECT price FROM products WHERE id = 2;
-- Đọc lại
COMMIT;
```

**SESSION 2 (Parallel with SESSION 1):**
```sql
BEGIN;
UPDATE products SET price = 199.99 WHERE id = 2;
COMMIT;
```

### Kết quả - Non-repeatable Read

```
SESSION 1 - Read 1: $249.99
SESSION 2: UPDATE price to $199.99 + COMMIT
SESSION 1 - Read 2: $199.99 ❌ (khác!)

Result: NON-REPEATABLE READ
- Session 1 đọc 2 lần, kết quả khác nhau
- Xảy ra ở READ COMMITTED
```

### Hậu quả
- ❌ Dữ liệu không consistent trong transaction
- ❌ Tính toán có thể sai nếu dựa vào giá cũ
- ✅ Nhưng không có dirty read (chỉ đọc committed data)

---

## Test 2: REPEATABLE READ - Protected from Non-repeatable Read

### Execution - 2 Sessions

**SESSION 1:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT price FROM products WHERE id = 2;
-- Read: $249.99 (snapshot at BEGIN)

-- Giả sử có processing logic...

SELECT price FROM products WHERE id = 2;
-- Đọc lại
COMMIT;
```

**SESSION 2 (Parallel with SESSION 1):**
```sql
BEGIN;
UPDATE products SET price = 199.99 WHERE id = 2;
COMMIT;
```

### Kết quả - Snapshot Isolation

```
SESSION 1 - Read 1: $249.99 (snapshot)
SESSION 2: UPDATE price to $199.99 + COMMIT
SESSION 1 - Read 2: $249.99 ✅ (giống!)

Result: REPEATABLE READ
- Session 1 đọc 2 lần, kết quả như nhau
- Dữ liệu consistent trong transaction
```

### Hậu quả
- ✅ Dữ liệu consistent trong transaction
- ✅ Tính toán dựa vào snapshot cũ là an toàn
- ⚠️ Nhưng có thể gặp phantom read (INSERT mới rows)
- ⚠️ Chậm hơn READ COMMITTED (do snapshot overhead)

---

## Test 3: SELECT FOR UPDATE - Lock để tránh Oversell

### Scenario

```
Product: Laptop (id=1, stock=2)

REQUEST 1 (User A):
BEGIN;
  SELECT stock FROM products WHERE id=1 FOR UPDATE;
  -- Row bị lock!

REQUEST 2 (User B): (cùng lúc)
BEGIN;
  SELECT stock FROM products WHERE id=1 FOR UPDATE;
  -- CHỜ! Row đang bị lock bởi Session 1
  
REQUEST 1:
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  COMMIT;
  -- Lock được release
  
REQUEST 2:
  -- Bây giờ mới có thể acquire lock
  SELECT stock FROM products WHERE id=1 FOR UPDATE;
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  COMMIT;
```

### Kết quả - Safe Locking

```
Initial stock: 2

REQUEST 1: Acquires lock, deducts 1 → stock = 1, releases lock
REQUEST 2: Acquires lock, deducts 1 → stock = 0, releases lock

Final stock: 0 ✅ (Correct!)
```

### Hậu quả
- ✅ Không oversell
- ✅ Serial execution tại database level
- ✅ Concurrency-safe
- ⚠️ Request 2 phải chờ Request 1 (trade-off: safety vs speed)

---

## Test 4: PHANTOM READ - Xuất hiện row mới

### Scenario

```
Query: SELECT COUNT(*) FROM products WHERE stock < 5

Before: 1 product (USB-C Hub: stock=2)
```

### Execution - 2 Sessions

**SESSION 1:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM products WHERE stock < 5;
-- Result: 1

-- Processing...

SELECT COUNT(*) FROM products WHERE stock < 5;
-- Đọc lại
COMMIT;
```

**SESSION 2 (Parallel):**
```sql
BEGIN;
INSERT INTO products (name, price, stock) VALUES ('New Item', 30, 3);
COMMIT;
```

### Kết quả - Phantom Read

```
SESSION 1 - Read 1: COUNT = 1 (USB-C Hub)
SESSION 2: INSERT new product with stock=3
SESSION 1 - Read 2: COUNT = 2 ❌ (xuất hiện row "ma"!)

Result: PHANTOM READ
- Session 1 đọc 2 lần, row mới xuất hiện
- Xảy ra ở READ COMMITTED và REPEATABLE READ
```

### Hậu quả
- ❌ Dữ liệu không consistent (row mới xuất hiện)
- ❌ Aggregation queries có thể sai
- ✅ Chỉ xảy ra với range queries (WHERE clause)

---

## Test 5: DEADLOCK - Khi 2 transactions chờ lẫn nhau

### Scenario - Lock theo thứ tự không nhất quán

**SESSION 1:**
```sql
BEGIN;
SELECT * FROM products WHERE id = 1 FOR UPDATE;
-- Lock product 1

-- Simulate delay...
-- SLEEP(1000);  (nếu có)

SELECT * FROM products WHERE id = 2 FOR UPDATE;
-- Chờ! Session 2 đang hold lock trên product 2
COMMIT;
```

**SESSION 2:**
```sql
BEGIN;
SELECT * FROM products WHERE id = 2 FOR UPDATE;
-- Lock product 2

-- Simulate delay...

SELECT * FROM products WHERE id = 1 FOR UPDATE;
-- Chờ! Session 1 đang hold lock trên product 1
-- DEADLOCK! Cả 2 đang chờ nhau
COMMIT;
```

### Kết quả - DEADLOCK ERROR

```
ERROR: deadlock detected
DETAIL: Process 123 waits for ShareLock on transaction 456; blocked by process 456.
Process 456 waits for ShareLock on transaction 123; blocked by process 123.
HINT: See server log for query details.
```

### Hậu quả
- ❌ Transaction thất bại
- ❌ Client nhận error
- ✅ PostgreSQL tự detect và abort 1 transaction
- ✅ Application nên retry

---

## Comparison - Isolation Levels

| Issue | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|-------|---|---|---|
| Dirty Read | ✅ No | ✅ No | ✅ No |
| Non-repeatable Read | ❌ Yes | ✅ No | ✅ No |
| Phantom Read | ❌ Yes | ❌ Yes | ✅ No |
| Performance | ✅ Fast | ⚠️ Medium | ❌ Slow |
| Concurrency | ✅ High | ⚠️ Medium | ❌ Low |
| Use Case | ✅ Most cases | ⚠️ High consistency needs | ❌ Critical transactions |

---

## Locking Strategies

### Strategy 1: No Lock (Không Lock) - ❌ Unsafe
```sql
BEGIN;
  SELECT stock FROM products WHERE id = 1;  -- stock = 10
  -- Nếu khác transaction update → tính toán sai
  UPDATE products SET stock = stock - 5 WHERE id = 1;
COMMIT;
```
**Result:** Race condition possible

### Strategy 2: FOR UPDATE (Exclusive Lock) - ✅ Safe
```sql
BEGIN;
  SELECT stock FROM products WHERE id = 1 FOR UPDATE;  -- Row locked
  -- Khác transaction phải chờ
  UPDATE products SET stock = stock - 5 WHERE id = 1;
COMMIT;
```
**Result:** Serialized, safe nhưng chậm

### Strategy 3: FOR UPDATE NOWAIT - ⚠️ Aggressive
```sql
BEGIN;
  SELECT stock FROM products WHERE id = 1 FOR UPDATE NOWAIT;
  -- Nếu row lock → ERROR ngay, không chờ
COMMIT;
```
**Result:** Fast fail, nhưng client phải retry

### Strategy 4: FOR UPDATE SKIP LOCKED - ✅ Flexible
```sql
BEGIN;
  SELECT stock FROM products WHERE id IN (1,2,3) 
  FOR UPDATE SKIP LOCKED;
  -- Nếu row 1 locked → bỏ qua, lock row 2,3
COMMIT;
```
**Result:** Always succeed, nhưng kết quả có thể incomplete

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Concurrency problem là gì?**
   - Khi nhiều transaction truy cập data cùng lúc
   - Có thể gây race condition, lost update

2. ✓ **Dirty read xảy ra khi nào?**
   - Transaction đọc uncommitted data từ transaction khác
   - Xảy ra ở READ UNCOMMITTED (PostgreSQL không support)

3. ✓ **Isolation level cao hơn có lợi và hại gì?**
   - Lợi: Dữ liệu consistent, không có anomalies
   - Hại: Chậm hơn, lock nhiều hơn, deadlock risk cao

4. ✓ **Vì sao SELECT FOR UPDATE quan trọng?**
   - Đảm bảo exclusive access đến row
   - Tránh race condition trong transaction
   - Essential cho multi-step operations (order processing)

5. ✓ **Deadlock là gì?**
   - Khi 2+ transactions chờ lẫn nhau's locks
   - PostgreSQL detect và abort 1 transaction
   - Giải pháp: Lock theo thứ tự nhất quán

---

## Best Practices - Concurrency Design

### ✅ DO:
1. **Keep transactions SHORT** - Giảm lock time
2. **Lock only what you need** - FOR UPDATE khi cần
3. **Lock in consistent order** - Tránh deadlock (id1 before id2)
4. **Use READ COMMITTED** - Mặc định, đủ cho hầu hết
5. **Handle retry logic** - Khi deadlock xảy ra
6. **Monitor locks** - Check pg_locks khi có issue

### ❌ DON'T:
1. **Hold locks for long time** - Chặn resources
2. **Lock everything** - Chỉ lock cần thiết
3. **Lock in random order** - Gây deadlock
4. **Use SERIALIZABLE everywhere** - Quá chậm
5. **Ignore deadlock errors** - Phải retry
6. **Trust "ít user nên không sao"** - Production có concurrent users

---

## Production Patterns - Safe Order Processing

### Pattern 1: Lock-First Check

```javascript
async function createOrder(userId, items) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Lock products in consistent order
    const productIds = items.map(i => i.productId).sort();
    
    for (const productId of productIds) {
      // Step 1: Lock product
      const result = await client.query(
        'SELECT id, stock FROM products WHERE id = $1 FOR UPDATE',
        [productId]
      );
      
      if (result.rows.length === 0) {
        throw new Error('Product not found');
      }
      
      // Step 2: Check stock
      const product = result.rows[0];
      const item = items.find(i => i.productId === productId);
      
      if (product.stock < item.quantity) {
        throw new Error('Insufficient stock');
      }
    }
    
    // Step 3: Create order (after all locks acquired)
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, total_amount) VALUES ($1, $2) RETURNING id',
      [userId, totalAmount]
    );
    const orderId = orderResult.rows[0].id;
    
    // Step 4: Create items and deduct stock
    for (const item of items) {
      await client.query(
        'INSERT INTO order_items (...) VALUES (...)'
      );
      
      await client.query(
        'UPDATE products SET stock = stock - $1 WHERE id = $2',
        [item.quantity, item.productId]
      );
    }
    
    await client.query('COMMIT');
    return orderId;
    
  } catch (error) {
    await client.query('ROLLBACK');
    
    // Handle deadlock retry
    if (error.code === '40P01') {  // Deadlock detected
      // Retry logic
      throw new Error('Deadlock - please retry');
    }
    
    throw error;
  } finally {
    client.release();
  }
}
```

### Pattern 2: With Retry

```javascript
async function createOrderWithRetry(userId, items, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await createOrder(userId, items);
    } catch (error) {
      if (error.code === '40P01' && attempt < maxRetries) {
        // Deadlock - retry with exponential backoff
        await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 100));
        continue;
      }
      throw error;
    }
  }
}
```

---

## Summary - Concurrency Reality

**Backend Engineer phải hiểu:**

1. ✅ Production systems = nhiều concurrent users
2. ✅ Concurrent access = potential data corruption
3. ✅ Isolation levels = trade-off giữa safety và performance
4. ✅ Locks = protective mechanism
5. ✅ Deadlocks = inevitable, phải handle

**Nếu bạn viết code mà không nghĩ về concurrency:**
- ❌ Race condition
- ❌ Lost update
- ❌ Oversell
- ❌ Data corruption
- ❌ Production fail

→ **Bạn chưa sẵn sàng cho production.**
