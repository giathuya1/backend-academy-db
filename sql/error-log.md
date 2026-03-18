# Day 4 - Constraint Testing & Error Log

## Mục tiêu
Ghi lại những lỗi khi vi phạm constraints để chứng minh database đang bảo vệ dữ liệu.

## Constraint Testing Results

### Test 1: Thử insert giá âm (CHECK constraint)
```sql
INSERT INTO products (name, price, stock) VALUES ('Invalid Product', -100, 10);
```

**Expected Error:**
```
ERROR:  new row for relation "products" violates check constraint "products_price_check"
DETAIL:  Failing row contains (6, Invalid Product, -100, 10, 2026-03-18 11:30:00).
```

**Why this error?**
- Constraint: `price NUMERIC(10,2) NOT NULL CHECK (price > 0)`
- Giá `-100` vi phạm điều kiện `price > 0`
- Database từ chối insert này
- **Production mindset**: Nếu backend có bug và gửi giá âm, database sẽ chặn

---

### Test 2: Thử insert stock âm (CHECK constraint)
```sql
INSERT INTO products (name, price, stock) VALUES ('Invalid Stock', 50, -5);
```

**Expected Error:**
```
ERROR:  new row for relation "products" violates check constraint "products_stock_check"
DETAIL:  Failing row contains (7, Invalid Stock, 50, -5, 2026-03-18 11:30:00).
```

**Why this error?**
- Constraint: `stock INTEGER NOT NULL CHECK (stock >= 0)`
- Stock `-5` vi phạm điều kiện `stock >= 0`
- Database từ chối insert này
- **Production mindset**: Không thể có tồn kho âm trong hệ thống

---

### Test 3: Thử insert name NULL (NOT NULL constraint)
```sql
INSERT INTO products (name, price, stock) VALUES (NULL, 50, 10);
```

**Expected Error:**
```
ERROR:  null value in column "name" violates not-null constraint
DETAIL:  Failing row contains (8, null, 50, 10, 2026-03-18 11:30:00).
```

**Why this error?**
- Constraint: `name VARCHAR(255) NOT NULL`
- Không thể có product mà không có tên
- Database từ chối insert này
- **Production mindset**: Tên sản phẩm là thông tin bắt buộc

---

## Successful Inserts

### 5 Products hợp lệ đã insert thành công:
```sql
INSERT INTO products (name, price, stock)
VALUES 
    ('Laptop Dell XPS 13', 1299.99, 15),
    ('Apple AirPods Pro', 249.99, 50),
    ('Samsung 27" Monitor', 399.99, 8),
    ('Mechanical Keyboard RGB', 149.99, 30),
    ('USB-C Hub 7 in 1', 59.99, 100);
```

**Result:** `INSERT 0 5` ✅

---

## Key Learnings

### 1. Vì sao constraint phải ở database?
- **Frontend validation** có thể bị bypass bằng Postman
- **Backend code** có thể có bug
- **Database constraints** = lớp phòng thủ cuối cùng
- Nếu không có constraint → dữ liệu rác sẽ lưu vĩnh viễn

### 2. CHECK vs Frontend Validation
| Aspect | Frontend | Backend | Database |
|--------|----------|---------|----------|
| Dễ bypass? | ✅ Có (DevTools) | ⚠️ Có (nếu code sai) | ❌ Không |
| User experience | Nhanh | Nhanh | Hơi chậm |
| Production safety | ❌ Không | ⚠️ Có thể | ✅ Có |
| Dữ liệu integrity | ❌ Không | ⚠️ Có thể | ✅ Có |

**Kết luận**: Cả 3 cấp độ đều cần, nhưng database constraints là quan trọng nhất.

### 3. Ví dụ hậu quả nếu không có CHECK (price > 0)
```
Scenario: Backend có bug gửi price = -100
- Nếu không có constraint: Dữ liệu rác lưu vĩnh viễn
- Nếu có constraint: Database từ chối ngay
- Hậu quả: Phải cleanup dữ liệu, mất thời gian
- Chi phí: Có thể mất tiền thật nếu là hệ thống bán hàng
```

### 4. Ví dụ hậu quả nếu không có UNIQUE (email)
```
Scenario: Không có UNIQUE constraint trên email
- Có thể tạo 2 user cùng email
- Login system bị lỗi (lấy cái nào?)
- Report doanh thu sai
- Khó cleanup vì có thể có dữ liệu phụ thuộc
```

### 5. Ví dụ hậu quả nếu không có NOT NULL (name)
```
Scenario: Cho phép product name = NULL
- Không hiển thị được tên sản phẩm
- Frontend lỗi
- User bối rối
- Phải cleanup dữ liệu
```

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Vì sao constraint phải ở database?**
   - Vì backend code có thể có bug, và constraint là lớp phòng thủ cuối cùng

2. ✓ **Nếu không có UNIQUE email thì hậu quả?**
   - Có thể nhiều user cùng email, login bị lỗi, doanh thu report sai

3. ✓ **CHECK khác validation backend thế nào?**
   - CHECK: Database enforce, không thể bypass
   - Backend validation: Có thể bypass bằng Postman

4. ✓ **Database có nên tin backend không?**
   - Không, database phải tự bảo vệ dữ liệu

---

## Constraints Summary

| Constraint | Ví dụ | Mục đích |
|-----------|-------|---------|
| PRIMARY KEY | `id SERIAL PRIMARY KEY` | Định danh duy nhất |
| UNIQUE | `email VARCHAR(255) UNIQUE` | Không trùng lặp |
| NOT NULL | `name VARCHAR(255) NOT NULL` | Bắt buộc có giá trị |
| CHECK | `price NUMERIC(10,2) CHECK (price > 0)` | Giá trị hợp lệ |
| DEFAULT | `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP` | Giá trị mặc định |

---

## Production Mindset Checklist

- ✅ Không tin hoàn toàn vào frontend validation
- ✅ Không tin hoàn toàn vào backend code
- ✅ Luôn đặt constraint ở database
- ✅ Test constraint bằng cách cố vi phạm nó
- ✅ Xem database là lớp phòng thủ cuối cùng
- ✅ Hỏi "Nếu backend có bug thì sao?"
