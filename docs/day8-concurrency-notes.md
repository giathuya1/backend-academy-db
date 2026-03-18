# Day 8 - Isolation Level & Concurrency Basics

## Những điều đã học

### Backend không chạy tuần tự
Production systems = nhiều users truy cập cùng lúc = **Concurrency**

### Vấn đề thực tế - Race Condition
```
Stock = 10

User A: SELECT stock = 10, UPDATE stock = 9
User B: SELECT stock = 10, UPDATE stock = 9 ❌ (nên là 8!)

Result: Lost update
```

---

## Concurrency là gì?

**Concurrency** = Nhiều transaction chạy cùng lúc.

### Thực tế:
- ✅ Hệ thống 1 user = không có concurrency problem
- ✅ Hệ thống thực tế = luôn có concurrency
- ❌ Không xử lý concurrency = production fail

---

## Isolation trong ACID

**Isolation** đảm bảo transaction này không bị ảnh hưởng bởi transaction khác.

### Nhưng mức độ isolation khác nhau sẽ cho hành vi khác nhau:
- READ COMMITTED (mặc định, an toàn vừa đủ)
- REPEATABLE READ (an toàn cao hơn)
- SERIALIZABLE (an toàn nhất, chậm nhất)

---

## 3 Vấn đề khi Isolation thấp

### 1. Dirty Read - Đọc dữ liệu chưa commit
```sql
-- SESSION 1
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT stock FROM products WHERE id = 1;  -- Reads: -100 (uncommitted!)

-- SESSION 2 (Parallel)
BEGIN;
UPDATE products SET stock = -100 WHERE id = 1;
ROLLBACK;  -- Rollback! Dữ liệu -100 không bao giờ tồn tại

-- SESSION 1 đã đọc dữ liệu "ma"
```

**Hậu quả:**
- ❌ Đọc dữ liệu không tồn tại
- ❌ Tính toán sai

**PostgreSQL protection:** PostgreSQL không hỗ trợ dirty read (mặc định)

### 2. Non-repeatable Read - Dữ liệu thay đổi trong transaction
```sql
-- SESSION 1 (READ COMMITTED)
BEGIN;
SELECT price FROM products WHERE id = 1;  -- $1299.99

-- SESSION 2 (Parallel)
BEGIN;
UPDATE products SET price = 999.99 WHERE id = 1;
COMMIT;

-- SESSION 1
SELECT price FROM products WHERE id = 1;  -- $999.99 (khác!)
COMMIT;
```

**Hậu quả:**
- ❌ Dữ liệu không consistent trong transaction
- ❌ Tính toán dựa vào giá cũ là sai

**PostgreSQL behavior:** Xảy ra ở READ COMMITTED

### 3. Phantom Read - Xuất hiện row mới trong transaction
```sql
-- SESSION 1 (READ COMMITTED)
BEGIN;
SELECT COUNT(*) FROM products WHERE stock < 5;  -- 1

-- SESSION 2 (Parallel)
BEGIN;
INSERT INTO products (name, price, stock) VALUES ('New', 50, 2);
COMMIT;

-- SESSION 1
SELECT COUNT(*) FROM products WHERE stock < 5;  -- 2 (phantom!)
COMMIT;
```

**Hậu quả:**
- ❌ Aggregation queries sai
- ❌ Row xuất hiện từ không có

**PostgreSQL behavior:** Xảy ra ở READ COMMITTED và REPEATABLE READ

---

## Isolation Levels trong PostgreSQL

### READ COMMITTED (Mặc định ⭐)
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

**Hành vi:**
- ✅ Không dirty read
- ❌ Có non-repeatable read
- ❌ Có phantom read
- ✅ Nhanh
- ✅ Phù hợp hầu hết cases

### REPEATABLE READ (An toàn cao)
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

**Hành vi:**
- ✅ Không dirty read
- ✅ Không non-repeatable read
- ⚠️ Có phantom read (rare, complex queries)
- ⚠️ Chậm hơn READ COMMITTED
- ✅ Dữ liệu consistent trong transaction

### SERIALIZABLE (An toàn tuyệt đối)
```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

**Hành vi:**
- ✅ Không dirty read
- ✅ Không non-repeatable read
- ✅ Không phantom read
- ❌ Chậm nhất (lock mạnh)
- ❌ Deadlock risk cao
- ✅ Mô phỏng tuần tự execution

---

## Lock là gì?

**Lock** = Cơ chế bảo vệ dữ liệu khỏi concurrent modifications.

### SELECT FOR UPDATE - Exclusive Lock
```sql
BEGIN;
  SELECT stock FROM products WHERE id = 1 FOR UPDATE;
  -- Row bị lock exclusive
  -- Session khác không thể UPDATE row này cho đến khi COMMIT
  
  -- Kiểm tra stock
  -- Update stock
COMMIT;
-- Row được unlock tại đây
```

**Hậu quả:**
- ✅ Concurrent transactions phải chờ
- ✅ Đảm bảo dữ liệu nhất quán
- ⚠️ Performance hit: serial execution tại database level

### SELECT FOR SHARE - Shared Lock
```sql
BEGIN;
  SELECT stock FROM products WHERE id = 1 FOR SHARE;
  -- Row bị lock shared
  -- Multiple transactions có thể READ, nhưng không thể UPDATE
COMMIT;
```

---

## Oversell Problem - Vấn đề thực tế

### Scenario: 2 users đặt hàng cùng lúc
```
Product: Laptop (stock = 2)

REQUEST 1:
SELECT stock = 2
UPDATE stock = 2 - 1 = 1

REQUEST 2:
SELECT stock = 2 ❌ (nên là 1)
UPDATE stock = 2 - 1 = 1 ❌

Final: stock = 1, nhưng bán 2 sản phẩm!
```

### Giải pháp: SELECT FOR UPDATE
```sql
BEGIN;
  -- Lock row trước khi đọc
  SELECT stock FROM products WHERE id = 1 FOR UPDATE;
  
  IF (SELECT stock FROM products WHERE id = 1) >= 1 THEN
    UPDATE products SET stock = stock - 1 WHERE id = 1;
  ELSE
    RAISE EXCEPTION 'Insufficient stock';
  END IF;
COMMIT;
```

**Result:**
- ✅ Request 1: Acquires lock, stock = 1
- ✅ Request 2: Waits for Request 1 to commit
- ✅ Request 2: Acquires lock, stock = 0
- ✅ Không oversell!

---

## FOR UPDATE Strategies

### Strategy 1: FOR UPDATE (Wait forever)
```sql
SELECT * FROM products WHERE id = 1 FOR UPDATE;
```
- ✅ Safe, guaranteed success
- ❌ Chậm (phải chờ nếu row đang lock)

### Strategy 2: FOR UPDATE NOWAIT (Fast fail)
```sql
SELECT * FROM products WHERE id = 1 FOR UPDATE NOWAIT;
```
- ✅ Nhanh, fail ngay nếu row lock
- ⚠️ Client phải retry
- ⚠️ Có thể fail nhiều lần

### Strategy 3: FOR UPDATE SKIP LOCKED (Flexible)
```sql
SELECT * FROM products WHERE id IN (1,2,3,4,5) 
FOR UPDATE SKIP LOCKED;
```
- ✅ Always succeed
- ✅ Nhanh
- ⚠️ Kết quả có thể incomplete

---

## DEADLOCK - Khi 2 transactions chờ lẫn nhau

### Scenario - Lock theo thứ tự không nhất quán

**SESSION 1:**
```sql
BEGIN;
  SELECT * FROM products WHERE id = 1 FOR UPDATE;
  -- Lock product 1
  
  -- ... processing ...
  
  SELECT * FROM products WHERE id = 2 FOR UPDATE;
  -- Chờ! Session 2 đang lock product 2
```

**SESSION 2:**
```sql
BEGIN;
  SELECT * FROM products WHERE id = 2 FOR UPDATE;
  -- Lock product 2
  
  -- ... processing ...
  
  SELECT * FROM products WHERE id = 1 FOR UPDATE;
  -- Chờ! Session 1 đang lock product 1
  -- DEADLOCK! Cả 2 đang chờ nhau
```

### Kết quả
```
ERROR: deadlock detected
DETAIL: Process 123 waits for lock, Process 456 waits for lock
HINT: See server log for query details
```

### Giải pháp: Lock theo thứ tự nhất quán
```sql
BEGIN;
  -- Luôn lock theo thứ tự id tăng dần
  SELECT * FROM products WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
  
  -- Giờ cả Session 1 và Session 2 lock theo thứ tự:
  -- 1 trước 2 → không deadlock
COMMIT;
```

---

## Comparison - Isolation Levels

| Vấn đề | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|-------|---|---|---|
| Dirty Read | ✅ No | ✅ No | ✅ No |
| Non-repeatable Read | ❌ Yes | ✅ No | ✅ No |
| Phantom Read | ❌ Yes | ❌ Yes | ✅ No |
| Performance | ✅ Fast | ⚠️ Medium | ❌ Slow |
| Concurrency | ✅ High | ⚠️ Medium | ❌ Low |
| Use Case | ✅ Most | ⚠️ Critical logic | ❌ Rare |

---

## Production Pattern - Safe Order Processing

### Đúng cách: Lock-First Check
```javascript
async function createOrder(userId, items) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Step 1: Lock ALL products in consistent order
    const productIds = items.map(i => i.productId).sort();
    
    for (const productId of productIds) {
      const result = await client.query(
        'SELECT id, stock FROM products WHERE id = $1 FOR UPDATE',
        [productId]
      );
      
      // Step 2: Check stock
      const product = result.rows[0];
      const item = items.find(i => i.productId === productId);
      
      if (product.stock < item.quantity) {
        throw new Error('Insufficient stock');
      }
    }
    
    // Step 3: Create order (after all locks acquired)
    const order = await client.query(
      'INSERT INTO orders (user_id, total_amount) VALUES ($1, $2) RETURNING id',
      [userId, totalAmount]
    );
    
    // Step 4: Create items and deduct stock
    for (const item of items) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)',
        [order.rows[0].id, item.productId, item.quantity, item.price]
      );
      
      await client.query(
        'UPDATE products SET stock = stock - $1 WHERE id = $2',
        [item.quantity, item.productId]
      );
    }
    
    await client.query('COMMIT');
    return order.rows[0];
    
  } catch (error) {
    await client.query('ROLLBACK');
    
    // Handle deadlock retry
    if (error.code === '40P01') {  // Deadlock detected
      throw new Error('Deadlock - retry');
    }
    
    throw error;
  } finally {
    client.release();
  }
}

// Caller code with retry
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

## Tự kiểm tra hiểu bản chất

1. ✓ **Concurrency problem là gì?**
   - Khi nhiều transaction truy cập data cùng lúc
   - Gây race condition, lost update, oversell

2. ✓ **Dirty read xảy ra khi nào?**
   - Transaction đọc uncommitted data từ transaction khác
   - PostgreSQL không support (mặc định)

3. ✓ **Isolation level cao hơn có lợi và hại gì?**
   - Lợi: Dữ liệu consistent, không anomalies
   - Hại: Chậm hơn, lock nhiều, deadlock risk

4. ✓ **Vì sao SELECT FOR UPDATE quan trọng?**
   - Đảm bảo exclusive access
   - Tránh race condition
   - Essential cho oversell prevention

5. ✓ **Deadlock là gì?**
   - 2+ transactions chờ lẫn nhau's locks
   - PostgreSQL detect và abort 1 transaction
   - Giải pháp: Lock consistent order

---

## Best Practices - Concurrency Design

### ✅ DO:
1. **Keep transactions SHORT** - Giảm lock time
2. **Lock in consistent order** - Tránh deadlock
3. **Use READ COMMITTED** - Mặc định, đủ
4. **Handle deadlock retry** - Khi lỗi 40P01
5. **Test with concurrent load** - Trước production
6. **Monitor locks** - SELECT * FROM pg_locks;

### ❌ DON'T:
1. **Assume 1-user behavior** - Production có concurrent users
2. **Hold locks for long** - Chặn resources
3. **Use SERIALIZABLE everywhere** - Quá chậm
4. **Ignore deadlock errors** - Phải retry
5. **Trust "ít user nên không sao"** - Sai, sẽ scale lên
6. **Lock in random order** - Gây deadlock

---

## Production Mindset

**Backend Engineer phải hiểu:**

1. ✅ Production = concurrent users (many!)
2. ✅ Concurrent access = data corruption risk
3. ✅ Isolation levels = trade-off: safety vs speed
4. ✅ Locks = protective mechanism
5. ✅ Deadlocks = inevitable, phải handle gracefully

**Nếu bạn viết code mà không nghĩ concurrency:**
- ❌ Race condition
- ❌ Lost update
- ❌ Oversell
- ❌ Data corruption
- ❌ Production nightmare

→ **Bạn chưa sẵn sàng cho production.**

---

## Key Takeaway

**Concurrency không phải edge case.**

**Concurrency là thực tế của production systems.**

Backend Engineer phải thiết kế hệ thống với concurrency trong đầu từ ngày đầu.
