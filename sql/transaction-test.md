# Day 7 - Transaction & Atomicity Testing

## Mục tiêu
Ghi lại kết quả testing transaction để hiểu rõ:
- Khi nào cần transaction
- Vì sao atomicity quan trọng
- Hậu quả của oversell

---

## Vấn đề thực tế - Order Flow

### Flow đặt hàng gồm 3 bước:
1. **Step 1**: Tạo order record
2. **Step 2**: Tạo order_item (chi tiết sản phẩm)
3. **Step 3**: Trừ stock sản phẩm

### ⚠️ Vấn đề nếu bước 3 lỗi mà không dùng transaction:
```
Step 1: INSERT INTO orders → SUCCESS ✅
Step 2: INSERT INTO order_items → SUCCESS ✅
Step 3: UPDATE products SET stock = stock - 1 → FAIL ❌

Result: Dữ liệu KHÔNG nhất quán!
- Order tồn tại
- Order_item tồn tại
- Nhưng stock KHÔNG được trừ
- → Doanh thu record sai, tồn kho sai
```

---

## Test Scenario 1: ❌ SAI CÁCH (Không dùng Transaction)

### Code (không nên dùng):
```sql
INSERT INTO orders (user_id, total_amount) VALUES (1, 1299.99);
-- order_id = 2 (giả sử)

INSERT INTO order_items (order_id, product_id, quantity, price) 
VALUES (2, 1, 1, 1299.99);

UPDATE products SET stock = stock - 1 WHERE id = 1;
-- Nếu lỗi ở đây...
```

### Kết quả nếu UPDATE lỗi:
```
Orders table: INSERT thành công → order_id 2 tồn tại
Order_items table: INSERT thành công → item tồn tại
Products table: UPDATE thất bại → stock KHÔNG đổi

❌ Dữ liệu KHÔNG nhất quán!
- System tính doanh thu: +1299.99
- Nhưng stock: không thay đổi
- Lỗi: Có order nhưng product không được lấy ra
```

### Hậu quả:
- 📊 Report doanh thu sai
- 📦 Tồn kho sai
- 🐛 Khó debug
- 💔 Customer phàn nàn (không nhận hàng)

---

## Test Scenario 2: ✅ ĐÚNG CÁCH (Dùng Transaction)

### Code:
```sql
BEGIN;

  INSERT INTO orders (user_id, total_amount) 
  VALUES (1, 1299.99);
  
  INSERT INTO order_items (order_id, product_id, quantity, price) 
  VALUES (?, 1, 1, 1299.99);
  
  UPDATE products 
  SET stock = stock - 1 
  WHERE id = 1 AND stock >= 1;
  
  -- Nếu stock không đủ → UPDATE ảnh hưởng 0 rows → ROLLBACK

COMMIT;
```

### Kết quả nếu bất kỳ bước lỗi:
```
BEGIN; → Transaction mở
  INSERT orders → SUCCESS
  INSERT order_items → SUCCESS
  UPDATE products → FAIL (stock không đủ)
ROLLBACK; → Tất cả bước quay lại

❌ Không có order được tạo
❌ Không có item được tạo
✅ Stock không thay đổi
✅ Dữ liệu nhất quán!
```

### Hậu quả:
- ✅ Hoặc toàn bộ commit hoặc toàn bộ rollback
- ✅ Dữ liệu LUÔN nhất quán
- ✅ Không có orphan orders
- ✅ Stock chính xác

---

## Oversell Problem - Bán quá số lượng tồn

### Scenario:
```
Product: Laptop (id=1)
Current stock: 1

2 customers tại cùng thời điểm:
- Customer 1: Order 1 laptop
- Customer 2: Order 1 laptop

Nếu không kiểm soát → cả 2 đều thành công?
- Stock: 1 - 1 = 0 (Customer 1)
- Stock: 0 - 1 = -1 (Customer 2) ❌ OVERSELL!
```

### Giải pháp cơ bản:

**Step 1: Check stock trước khi trừ**
```sql
BEGIN;
  -- Check xem có đủ stock không
  SELECT stock FROM products 
  WHERE id = 1 AND stock >= 1 
  FOR UPDATE;  -- Lock row để tránh concurrent issues
  
  IF NOT FOUND THEN
    ROLLBACK;
    RAISE EXCEPTION 'Stock not available';
  END IF;
  
  -- Tạo order
  INSERT INTO orders ...;
  INSERT INTO order_items ...;
  
  -- Trừ stock
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  
COMMIT;
```

**Result:**
- ✅ Customer 1: Thành công (stock = 0)
- ❌ Customer 2: Lỗi (stock không đủ)
- ✅ Không oversell

---

## ACID Properties - Ứng dụng thực tế

### A - Atomicity (Nguyên tử)
```
❌ Sai: Order tạo nhưng stock không trừ
✅ Đúng: Hoặc tất cả hoặc không có gì
```

### C - Consistency (Nhất quán)
```
❌ Sai: Dữ liệu order_item không khớp với order
✅ Đúng: Mọi thứ đều nhất quán theo constraint
```

### I - Isolation (Cô lập)
```
❌ Sai: Transaction A thấy uncommitted data từ Transaction B
✅ Đúng: Mỗi transaction độc lập, không thấy uncommitted data
```

### D - Durability (Tính bền vững)
```
❌ Sai: Commit xong nhưng database crash → data mất
✅ Đúng: Commit = dữ liệu được lưu vĩnh viễn
```

---

## Transaction Isolation Levels

### READ UNCOMMITTED (Nguy hiểm)
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- Có thể thấy uncommitted data từ transaction khác
-- ❌ Không an toàn
-- ✅ Nhanh nhất
```

### READ COMMITTED (Mặc định, An toàn)
```sql
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- Chỉ thấy committed data
-- ✅ An toàn
-- ✅ Nhanh
-- Recommended cho hầu hết cases
```

### REPEATABLE READ (An toàn hơn)
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Nếu query dữ liệu lại, result giống như lần đầu
-- ✅ An toàn cao
-- ⚠️ Chậm hơn
```

### SERIALIZABLE (An toàn nhất)
```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Transactions chạy tuần tự, không concurrent
-- ✅ An toàn tuyệt đối
-- ❌ Chậm nhất
-- Chỉ dùng khi cần tuyệt đối consistency
```

---

## Backend Implementation Pattern

### ❌ Sai cách (Transaction ở controller)
```javascript
app.post('/orders', (req, res) => {
  // Transaction logic mix với HTTP handling
  db.query('BEGIN');
  db.query('INSERT INTO orders ...');
  db.query('INSERT INTO order_items ...');
  db.query('UPDATE products ...');
  db.query('COMMIT');
  res.json(...);
});
```

### ✅ Đúng cách (Transaction ở service layer)
```javascript
// Service layer - xử lý business logic
async function createOrder(userId, items) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Step 1: Tạo order
    const order = await client.query(
      'INSERT INTO orders (user_id, total_amount) VALUES ($1, $2) RETURNING id',
      [userId, totalAmount]
    );
    
    // Step 2-3: Tạo items, trừ stock
    for (const item of items) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ...'
      );
      
      await client.query(
        'UPDATE products SET stock = stock - $1 WHERE id = $2 AND stock >= $1',
        [item.quantity, item.productId]
      );
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

// Controller - chỉ handle HTTP
app.post('/orders', async (req, res) => {
  try {
    const order = await createOrder(req.user.id, req.body.items);
    res.json(order);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
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

4. ✓ **Vì sao transaction nên đặt ở service layer?**
   - Controller = HTTP handling
   - Service = Business logic
   - Transaction = Là business logic, không HTTP logic

5. ✓ **Oversell xảy ra khi nào?**
   - Khi 2+ concurrent requests cùng check stock
   - Cả 2 đều thấy stock = 1
   - Cả 2 đều bán → stock = -1

---

## Best Practices - Transaction Design

### ✅ DO:
1. **Keep transactions SHORT** - Mở vừa, commit sớm
2. **Only include necessary queries** - Không lôi thêm queries vô
3. **Put transaction in service layer** - Không ở controller
4. **Handle exceptions with ROLLBACK** - Catch error → rollback
5. **Use appropriate isolation level** - READ COMMITTED cho hầu hết

### ❌ DON'T:
1. **Hold transaction for long time** - Chặn resources
2. **Mix read and write unnecessarily** - Tránh lock conflicts
3. **Commit half-way through** - Hoặc toàn bộ hoặc không
4. **Ignore error handling** - Luôn try-catch
5. **Use SERIALIZABLE everywhere** - Chỉ khi thực sự cần

---

## Production Mindset

**Backend Engineer không viết code "chạy được".**

**Backend Engineer viết code "an toàn".**

Transaction là một phần quan trọng của safety guarantee.

Nếu bạn tưởng "ít user nên không sao" → bạn chưa sẵn sàng cho production.

---

## Summary

| Aspect | Không Transaction | Có Transaction |
|--------|------------------|-----------------|
| Multi-step logic | ❌ Dữ liệu rác | ✅ Atomicity |
| Error handling | ❌ Inconsistent | ✅ Rollback |
| Oversell | ❌ Bán quá số | ✅ Kiểm soát |
| Data integrity | ❌ Sai | ✅ Đảm bảo |
| Production ready | ❌ Không | ✅ Có |
