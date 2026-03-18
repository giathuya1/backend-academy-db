# Day 7 - Transaction & Atomicity (Consistency Foundation)

## Những điều đã học

### Database không phải chỉ lưu dữ liệu
Database phải **đảm bảo dữ liệu nhất quán** ngay cả khi xảy ra lỗi.

### Vấn đề thực tế - Order Flow
```
Step 1: Tạo order
Step 2: Tạo order_item
Step 3: Trừ stock

Nếu Step 3 lỗi mà không có transaction:
❌ Order tồn tại
❌ Order_item tồn tại
❌ Stock KHÔNG trừ
❌ Dữ liệu KHÔNG nhất quán
```

---

## Transaction là gì?

**Transaction** = Một nhóm thao tác được thực thi như một đơn vị duy nhất.

### Đặc điểm:
- ✅ Hoặc **toàn bộ thành công** (COMMIT)
- ✅ Hoặc **toàn bộ thất bại** (ROLLBACK)
- ❌ **Không có trạng thái "nửa vời"**

### Syntax cơ bản
```sql
BEGIN;
  -- Tất cả SQL queries ở đây
  INSERT INTO orders ...;
  INSERT INTO order_items ...;
  UPDATE products ...;
COMMIT;  -- Hoặc ROLLBACK nếu có lỗi
```

---

## ACID - Tính chất của Transaction

### A - Atomicity (Nguyên tử)
```
❌ Sai: Order tạo nhưng stock không trừ (nửa vời)
✅ Đúng: Hoặc tất cả hoặc không có gì
```
- Hoặc commit toàn bộ
- Hoặc rollback toàn bộ
- Không có "nửa commit"

### C - Consistency (Nhất quán)
```
❌ Sai: Order_item không khớp với order
✅ Đúng: Mọi thứ đều hợp lệ theo constraint
```
- Dữ liệu phải tuân thủ tất cả constraints
- FK, PK, CHECK constraints đều phải hợp lệ
- Sau transaction, database ở trạng thái valid

### I - Isolation (Cô lập)
```
❌ Sai: Transaction A thấy uncommitted data từ B
✅ Đúng: Mỗi transaction độc lập
```
- Các transaction không ảnh hưởng lẫn nhau
- Không thấy uncommitted data từ transaction khác
- Có nhiều isolation levels tùy nhu cầu

### D - Durability (Tính bền vững)
```
❌ Sai: Commit xong nhưng database crash → data mất
✅ Đúng: Commit = dữ liệu lưu vĩnh viễn
```
- Sau COMMIT, dữ liệu được lưu bền vững
- Kể cả khi hệ thống crash
- Dữ liệu không bao giờ mất

---

## ❌ Sai Cách - Không dùng Transaction

### Code
```sql
INSERT INTO orders (user_id, total_amount) VALUES (1, 1299.99);
INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 1, 1, 1299.99);
UPDATE products SET stock = stock - 1 WHERE id = 1;
-- Nếu UPDATE lỗi → order vẫn tồn tại
```

### Vấn đề nếu UPDATE lỗi
```
✅ Orders table: order_id 1 tồn tại
✅ Order_items table: item tồn tại
❌ Products table: stock KHÔNG đổi

Result: Dữ liệu KHÔNG nhất quán!
- System: "Doanh thu +1299.99"
- Reality: "Stock không thay đổi"
- Lỗi: Có order nhưng product không được lấy ra
```

### Hậu quả
- 📊 Report doanh thu sai
- 📦 Tồn kho sai
- 🐛 Khó debug: "Làm sao order này tạo được?"
- 💔 Customer phàn nàn: "Tôi đặt hàng nhưng không nhận được"

---

## ✅ Đúng Cách - Dùng Transaction

### Code
```sql
BEGIN;
  INSERT INTO orders (user_id, total_amount) VALUES (1, 1299.99);
  INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 1, 1, 1299.99);
  UPDATE products SET stock = stock - 1 WHERE id = 1 AND stock >= 1;
COMMIT;
```

### Nếu bất kỳ bước lỗi
```
BEGIN; → Mở transaction
  INSERT orders → SUCCESS
  INSERT order_items → SUCCESS
  UPDATE products → FAIL (stock không đủ)
ROLLBACK; → Tất cả bước quay lại

Result:
❌ Không có order được tạo
❌ Không có item được tạo
✅ Stock không thay đổi
✅ Dữ liệu LUÔN nhất quán!
```

### Hậu quả
- ✅ Hoặc toàn bộ commit hoặc toàn bộ rollback
- ✅ Dữ liệu LUÔN nhất quán
- ✅ Không có orphan orders
- ✅ Stock chính xác
- ✅ Production ready

---

## Oversell Problem - Bán quá số lượng tồn

### Scenario - 2 customers cùng đặt hàng
```
Product: Laptop (stock = 1)

Request 1: Customer mua 1 laptop
Request 2: Customer mua 1 laptop (cùng lúc)

Nếu không kiểm soát:
Customer 1: stock = 1 - 1 = 0 ✅
Customer 2: stock = 0 - 1 = -1 ❌ OVERSELL!
```

### Giải pháp cơ bản

**Step 1: Lock và check stock**
```sql
BEGIN;
  -- Lock row để tránh concurrent issues
  SELECT stock FROM products 
  WHERE id = 1 AND stock >= 1 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    ROLLBACK;
    RAISE EXCEPTION 'Stock not available';
  END IF;
  
  INSERT INTO orders ...;
  INSERT INTO order_items ...;
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  
COMMIT;
```

**Result:**
- ✅ Customer 1: Thành công (stock = 0)
- ❌ Customer 2: Lỗi (stock không đủ)
- ✅ Không oversell!

---

## Transaction Isolation Levels

### READ UNCOMMITTED (Nguy hiểm ⚠️)
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- Có thể thấy uncommitted data từ transaction khác
-- ❌ Không an toàn
-- ✅ Nhanh nhất
-- Không dùng trong production
```

### READ COMMITTED (Mặc định ⭐)
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- Chỉ thấy committed data
-- ✅ An toàn
-- ✅ Nhanh
-- Recommended cho hầu hết cases
```

### REPEATABLE READ (An toàn cao)
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Nếu query lại, result giống như lần đầu
-- ✅ An toàn cao
-- ⚠️ Chậm hơn
-- Dùng khi cần consistency cao
```

### SERIALIZABLE (An toàn tuyệt đối)
```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Transactions chạy tuần tự, không concurrent
-- ✅ An toàn tuyệt đối
-- ❌ Chậm nhất (lock mạnh)
-- Chỉ dùng khi cần tuyệt đối consistency
```

---

## Backend Implementation - Service Layer Pattern

### ❌ Sai Cách (Transaction ở Controller)
```javascript
app.post('/orders', (req, res) => {
  db.query('BEGIN');
  db.query('INSERT INTO orders ...');
  db.query('INSERT INTO order_items ...');
  db.query('UPDATE products ...');
  db.query('COMMIT');
  res.json(...);
});
// ❌ Mix business logic + HTTP handling
```

### ✅ Đúng Cách (Transaction ở Service Layer)
```javascript
// Service layer = Business logic
async function createOrder(userId, items) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Step 1: Tạo order
    const order = await client.query(
      'INSERT INTO orders (user_id, total_amount) VALUES ($1, $2) RETURNING id',
      [userId, totalAmount]
    );
    const orderId = order.rows[0].id;
    
    // Step 2-3: Tạo items, trừ stock
    for (const item of items) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)',
        [orderId, item.productId, item.quantity, item.price]
      );
      
      const result = await client.query(
        'UPDATE products SET stock = stock - $1 WHERE id = $2 AND stock >= $1',
        [item.quantity, item.productId]
      );
      
      // Check oversell
      if (result.rowCount === 0) {
        throw new Error('Insufficient stock');
      }
    }
    
    await client.query('COMMIT');
    return order.rows[0];
    
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Controller = HTTP handling
app.post('/orders', async (req, res) => {
  try {
    const order = await createOrder(req.user.id, req.body.items);
    res.json({ success: true, order });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
// ✅ Clean separation: service = logic, controller = HTTP
```

---

## SAVEPOINT - Partial Rollback (Nâng cao)

### Khi nào dùng
Khi muốn rollback một phần transaction, không rollback toàn bộ.

### Example
```sql
BEGIN;
  
  INSERT INTO orders (user_id, total_amount) VALUES (1, 100);
  SAVEPOINT sp1;
  
  INSERT INTO order_items (...) VALUES (...);
  SAVEPOINT sp2;
  
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  
  -- Nếu muốn undo chỉ từ sp2
  ROLLBACK TO sp2;
  -- → order_items bị undo, nhưng order vẫn tồn tại
  
  -- Hoặc commit tất cả
  COMMIT;
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Transaction giải quyết vấn đề gì?**
   - Atomicity: Hoặc tất cả commit hoặc tất cả rollback
   - Ngăn dữ liệu half-committed (nửa vời)

2. ✓ **Atomicity nghĩa là gì?**
   - Một nhóm thao tác được thực thi như 1 đơn vị
   - Không có trạng thái "nửa vời"

3. ✓ **Nếu không rollback thì chuyện gì xảy ra?**
   - Dữ liệu rác tích lũy
   - System inconsistency
   - Khó debug, khó fix
   - Production fail

4. ✓ **Vì sao transaction nên đặt ở service layer?**
   - Controller = HTTP handling
   - Service = Business logic
   - Transaction = là business logic, không HTTP logic
   - Clean separation of concerns

5. ✓ **Oversell xảy ra khi nào?**
   - Khi 2+ concurrent requests cùng check stock
   - Cả 2 đều thấy stock >= 1
   - Cả 2 đều update → stock = -1 (oversell!)

---

## Best Practices - Transaction Design

### ✅ DO:
1. **Keep transactions SHORT** - Mở vừa, commit sớm
2. **Only include necessary queries** - Không lôi thêm queries vô
3. **Put transaction in service layer** - Không ở controller
4. **Handle exceptions with ROLLBACK** - Try-catch → rollback
5. **Use appropriate isolation level** - READ COMMITTED cho hầu hết

### ❌ DON'T:
1. **Hold transaction for long time** - Chặn resources
2. **Mix read and write unnecessarily** - Tránh lock conflicts
3. **Commit half-way through** - Hoặc toàn bộ hoặc không
4. **Ignore error handling** - Luôn try-catch-finally
5. **Use SERIALIZABLE everywhere** - Chỉ khi thực sự cần

---

## Production Mindset

**Backend Engineer không viết code "chạy được".**

**Backend Engineer viết code "an toàn".**

Transaction là một phần **không thể thiếu** của safety guarantee.

Nếu bạn tưởng:
- "Ít user nên không sao" → ❌ Chỉ là vấn đề thời gian
- "Lỡ sảy ra lỗi em sẽ fix sau" → ❌ Không thể recover dữ liệu inconsistent
- "Database sẽ tự xử lý" → ❌ Database chỉ tuân thủ constraint, không thể fix business logic lỗi

→ **Bạn chưa sẵn sàng cho production.**

---

## Key Takeaway

**ACID properties không phải lý thuyết.**

**ACID properties là yêu cầu bắt buộc cho hệ thống production.**

Transaction là cách Backend Engineer đảm bảo dữ liệu nhất quán và hệ thống không fail khi có lỗi.
