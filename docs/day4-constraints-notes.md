# Day 4 - Data Integrity, Constraints & Database Discipline

## Những điều đã học

### Data Integrity là gì?
- Database không chỉ để lưu dữ liệu
- Database phải **bảo vệ** dữ liệu
- Database phải:
  - Ngăn dữ liệu sai
  - Ngăn dữ liệu trùng
  - Ngăn dữ liệu vô nghĩa
  - Ngăn dữ liệu gây lỗi production

### Tại sao không chỉ validate ở frontend?
- User có thể bypass bằng **Postman**
- Hacker có thể gửi request trực tiếp
- Dữ liệu rác sẽ vào hệ thống
- **Backend phải validate. Database phải enforce.**

### 3-Layer Validation
```
Frontend (UX)
    ↓
Backend (Business Logic)
    ↓
Database (Last Defense)
```

- **Frontend**: Tốt cho UX, nhưng dễ bypass
- **Backend**: Kiểm tra logic, nhưng code có thể có bug
- **Database**: Lớp phòng thủ cuối cùng, không thể bypass

---

## Constraint là gì?

**Constraint** = luật bảo vệ dữ liệu ở mức database.

Database sẽ **từ chối** dữ liệu vi phạm luật.

---

## Các loại Constraint quan trọng

### 1. NOT NULL
Không cho phép giá trị NULL.

```sql
email VARCHAR(255) NOT NULL
```

**Nếu không có NOT NULL:**
- Email có thể rỗng
- Không xác định được user
- Hệ thống bị lỗi

### 2. UNIQUE
Đảm bảo không trùng lặp.

```sql
email VARCHAR(255) UNIQUE NOT NULL
```

**Nếu không có UNIQUE:**
- Có 2 user cùng email
- Login sai người
- Lỗi nghiệp vụ

### 3. CHECK
Đảm bảo giá trị hợp lệ.

```sql
price NUMERIC(10,2) CHECK (price > 0)
stock INTEGER CHECK (stock >= 0)
```

**Nếu không có CHECK:**
- Giá âm → doanh thu sai
- Tồn kho âm → logic sai
- Production fail

### 4. PRIMARY KEY
Định danh duy nhất.

```sql
id SERIAL PRIMARY KEY
```

**Nếu không có PK:**
- Không join được
- Không reference được
- Không đảm bảo duy nhất

### 5. DEFAULT
Giá trị mặc định khi không cung cấp.

```sql
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
```

---

## Bảng Products - Chuẩn Production

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Constraints giải thích:
- **id SERIAL PRIMARY KEY**: Tự động tăng, định danh duy nhất
- **name VARCHAR(255) NOT NULL**: Tên bắt buộc, max 255 ký tự
- **price NUMERIC(10,2) NOT NULL CHECK (price > 0)**: 
  - Giá phải có (NOT NULL)
  - Giá phải dương (CHECK > 0)
  - NUMERIC(10,2) = 10 chữ số, 2 chữ số thập phân
- **stock INTEGER NOT NULL CHECK (stock >= 0)**:
  - Tồn kho phải có (NOT NULL)
  - Tồn kho >= 0 (CHECK)
- **created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP**:
  - Tự động ghi ngày giờ tạo

---

## Lỗi khi vi phạm Constraint

### Test 1: Insert giá âm
```sql
INSERT INTO products (name, price, stock) 
VALUES ('Invalid', -100, 10);
```

**Lỗi:** `ERROR: violates check constraint "products_price_check"`

**Vì sao?** `-100` vi phạm `price > 0`

### Test 2: Insert stock âm
```sql
INSERT INTO products (name, price, stock) 
VALUES ('Invalid', 50, -5);
```

**Lỗi:** `ERROR: violates check constraint "products_stock_check"`

**Vì sao?** `-5` vi phạm `stock >= 0`

### Test 3: Insert name NULL
```sql
INSERT INTO products (name, price, stock) 
VALUES (NULL, 50, 10);
```

**Lỗi:** `ERROR: null value in column "name" violates not-null constraint`

**Vì sao?** Không thể insert NULL vào NOT NULL column

---

## Vì sao Constraint phải ở Database?

### Scenario: Backend có bug
```
Backend gửi: price = -100

Nếu không có CHECK:
  ❌ Dữ liệu rác lưu vĩnh viễn
  ❌ Phải cleanup thủ công
  ❌ Có thể mất tiền thật

Nếu có CHECK:
  ✅ Database từ chối ngay
  ✅ Lỗi được phát hiện
  ✅ Hệ thống ổn định
```

**Database = lớp phòng thủ cuối cùng.**

---

## Production Mindset

Một backend engineer phải tự hỏi:

1. **Nếu request bị chỉnh sửa thì sao?**
   - Constraint giúp chặn request sai

2. **Nếu client bypass UI thì sao?**
   - Constraint ở database vẫn chặn

3. **Nếu hệ thống có bug thì sao?**
   - Constraint giữ data integrity

4. **Nếu hacker gửi request sai thì sao?**
   - Constraint phòng thủ

---

## Tự kiểm tra hiểu bản chất

1. ✓ **Vì sao constraint phải ở database?**
   - Vì backend code có thể có bug
   - Constraint là lớp phòng thủ cuối cùng
   - Nếu không có constraint → dữ liệu rác sẽ lưu vĩnh viễn

2. ✓ **Nếu không có UNIQUE email thì hậu quả?**
   - Có thể tạo 2 user cùng email
   - Login system bị lỗi
   - Report doanh thu sai

3. ✓ **CHECK khác validation backend thế nào?**
   - CHECK: Database enforce, **không thể bypass**
   - Backend validation: Có thể bypass bằng Postman/curl

4. ✓ **Database có nên tin backend không?**
   - **Không**, database phải tự bảo vệ dữ liệu
   - Assume backend code có thể có bug

---

## Summary: Constraints

| Constraint | Ví dụ | Mục đích |
|-----------|-------|---------|
| PRIMARY KEY | `id SERIAL PRIMARY KEY` | Định danh duy nhất |
| UNIQUE | `email VARCHAR(255) UNIQUE` | Không trùng lặp |
| NOT NULL | `name VARCHAR(255) NOT NULL` | Bắt buộc có giá trị |
| CHECK | `price NUMERIC(10,2) CHECK (price > 0)` | Giá trị hợp lệ |
| DEFAULT | `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP` | Giá trị mặc định |

---

## Key Takeaway

**Backend Engineer** không phải chỉ viết code chạy được.

**Backend Engineer** phải viết code **an toàn** và **bảo vệ dữ liệu**.

Database constraints là phần không thể thiếu của bảo mật hệ thống.
