# Day 3 - PostgreSQL Foundation & Database Basics

## Những điều đã học

### Database là gì?
- Database = hệ thống lưu trữ dữ liệu bền vững (persistent storage)
- Trong hệ thống bán hàng:
  - User đăng ký → lưu vào database
  - Sản phẩm → lưu vào database
  - Đơn hàng → lưu vào database
- Không có database:
  - Refresh là mất dữ liệu
  - Không lưu được lịch sử
  - Không thể xử lý nhiều người dùng

### PostgreSQL là gì?
- Relational Database Management System (RDBMS)
- Tuân thủ ACID (Atomicity, Consistency, Isolation, Durability)
- Hỗ trợ SQL chuẩn
- Phù hợp hệ thống production
- Lưu dữ liệu theo mô hình: Database → Schema → Table → Row → Column

## Khái niệm nền tảng

### Database
- Một container logic chứa các bảng
- Ví dụ: `ecommerce`, `academy_db`

### Schema
- Nhóm các tables liên quan
- Mặc định: `public`

### Table
- Cấu trúc lưu dữ liệu dạng bảng
- Ví dụ: `users`, `products`, `orders`

### Row
- Một bản ghi cụ thể
- Ví dụ: một user cụ thể

### Column
- Thuộc tính của bản ghi
- Ví dụ: `id`, `email`, `password_hash`, `created_at`

## Data Types quan trọng

### Numeric
- `SERIAL` / `BIGSERIAL` - auto increment integer (cho ID)
- `INTEGER` - số nguyên
- `NUMERIC` / `DECIMAL` - số thập phân (cho tiền, không dùng FLOAT!)

### String
- `VARCHAR(n)` - chuỗi có độ dài tối đa n
- `TEXT` - chuỗi không giới hạn độ dài

### Boolean
- `BOOLEAN` - true/false

### Temporal
- `TIMESTAMP` - ngày giờ đầy đủ
- `DATE` - chỉ ngày
- `TIME` - chỉ giờ

### ⚠️ Lưu ý quan trọng
- ❌ **Không dùng FLOAT cho tiền** → gây sai số
- ✅ **Dùng NUMERIC hoặc DECIMAL** cho tiền

## Constraints quan trọng

### PRIMARY KEY
- Xác định duy nhất một row
- Không được NULL
- Không được trùng
- Nếu không có PK: không thể xác định bản ghi

### UNIQUE
- Giá trị trong column không được trùng
- Ví dụ: email phải unique

### NOT NULL
- Column không được rỗng
- Bắt buộc phải có giá trị

### DEFAULT
- Giá trị mặc định khi không cung cấp
- Ví dụ: `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`

## SQL CRUD cơ bản

### CREATE (INSERT)
```sql
INSERT INTO users (email, password_hash, full_name)
VALUES ('user@example.com', 'hashed_password', 'User Name');
```

### READ (SELECT)
```sql
-- Lấy tất cả
SELECT * FROM users;

-- Lấy cột cụ thể
SELECT id, email, full_name FROM users;

-- Với WHERE condition
SELECT * FROM users WHERE id = 1;

-- Sắp xếp
SELECT * FROM users ORDER BY created_at DESC;
```

### UPDATE
```sql
UPDATE users
SET full_name = 'Updated Name'
WHERE id = 1;
```

⚠️ **Luôn có WHERE khi UPDATE** - nếu không sẽ update tất cả!

### DELETE
```sql
DELETE FROM users
WHERE id = 1;
```

⚠️ **Luôn có WHERE khi DELETE** - nếu không sẽ xóa tất cả!

## Thực hành Commands

### Kết nối vào PostgreSQL
```bash
# Cách 1: Qua Docker container
docker compose exec postgres psql -U student -d ecommerce

# Cách 2: Chạy schema.sql
docker compose exec postgres psql -U student -d ecommerce -f /path/to/schema.sql
```

### Commands trong psql
```bash
\dt              # Liệt kê tất cả tables
\d users         # Xem cấu trúc table users
\l               # Liệt kê tất cả databases
\c ecommerce     # Kết nối vào database ecommerce
\q               # Thoát psql
```

## Lỗi phổ biến & Cách fix

### Lỗi: Duplicate key value violates unique constraint
**Nguyên nhân**: Cố insert email trùng
**Fix**: Kiểm tra email trước insert hoặc cập nhật

### Lỗi: null value in column violates not-null constraint
**Nguyên nhân**: Cố insert NULL vào NOT NULL column
**Fix**: Cung cấp giá trị

### Lỗi: UPDATE tất cả rows vô tình
**Nguyên nhân**: Quên WHERE khi UPDATE
**Fix**: Luôn có WHERE

## Tự kiểm tra hiểu bản chất

1. ✓ Database khác table thế nào?
   - Database = container chứa tables
   - Table = cấu trúc lưu dữ liệu dạng bảng

2. ✓ Vì sao mỗi bảng cần Primary Key?
   - Xác định duy nhất một row
   - Liên kết với bảng khác
   - Tránh duplicate data

3. ✓ Vì sao không dùng FLOAT cho tiền?
   - FLOAT gây sai số trong phép tính
   - Dùng NUMERIC/DECIMAL cho độ chính xác

4. ✓ Nếu không có UNIQUE email thì chuyện gì xảy ra?
   - Có thể tạo nhiều account cùng email
   - Không thể định danh user duy nhất

5. ✓ Tại sao cần NOT NULL cho password_hash?
   - Không được phép user không có password
   - Bảo mật cơ bản
