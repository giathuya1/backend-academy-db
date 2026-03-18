# Day 10 - Mini Capstone: Production-Ready Database Design

## Executive Summary

Đây là design hoàn chỉnh cho e-commerce database áp dụng tất cả kiến thức từ Day 1-9:
- ✅ Data integrity (constraints, types)
- ✅ Relationships (foreign keys)
- ✅ Performance (strategic indexes)
- ✅ Concurrency (transactions, locks)
- ✅ Audit trail (created_at, updated_at)

---

## 1. Schema Overview

### Bảng chính:
```
users (3 records)
├── id: Primary Key
├── email: UNIQUE (login identifier)
├── password_hash: Hashed password
└── created_at, updated_at: Audit trail

products (5 records)
├── id: Primary Key
├── name: Product name
├── price: NUMERIC(10,2) - NOT FLOAT!
├── stock: Non-negative integer
└── created_at, updated_at: Audit trail

orders
├── id: Primary Key
├── user_id: FK → users (ON DELETE RESTRICT)
├── total_amount: NUMERIC(12,2)
├── status: 'pending', 'completed', 'cancelled'
└── created_at, updated_at: Audit trail

order_items
├── id: Primary Key
├── order_id: FK → orders (ON DELETE CASCADE)
├── product_id: FK → products (ON DELETE RESTRICT)
├── quantity: Positive integer (CHECK quantity > 0)
├── price: SNAPSHOT at order time (NOT current product price!)
└── created_at: Audit trail
```

---

## 2. Key Design Decisions & Rationale

### Decision 1: Foreign Keys with ON DELETE Policy

**Question:** Vì sao dùng Foreign Key?

**Answer:**
```
Foreign Key = Database-level referential integrity

Nếu không dùng FK:
❌ user_id = 9999 (user không tồn tại)
❌ order_id = 9999 (order không tồn tại)
❌ Dữ liệu orphan (không có parent)
❌ Backend phải check lại (lỗi dễ xảy ra)

Nếu dùng FK:
✅ Database tự reject invalid references
✅ Dữ liệu luôn consistent
✅ Backend không cần check (database bảo vệ)
✅ Production safe
```

**ON DELETE RESTRICT vs CASCADE:**

```sql
-- orders.user_id FK
ON DELETE RESTRICT
-- Không cho delete user nếu còn orders
-- Hợp lý: Giữ lịch sử order của user

-- order_items.order_id FK
ON DELETE CASCADE
-- Auto delete order_items khi order deleted
-- Hợp lý: Items là một phần của order

-- order_items.product_id FK
ON DELETE RESTRICT
-- Không cho delete product nếu có order_items
-- Hợp lý: Giữ lịch sử sản phẩm
```

### Decision 2: Snapshot Price trong order_items

**Question:** Vì sao order_items lưu price riêng?

**Answer:**
```
Scenario: Product price thay đổi

Product:
- Hôm nay: $100
- Tuần sau: $80 (sale)

Order được đặt hôm nay với price $100
Tuần sau query order → product price $80

Nếu KHÔNG snapshot (join trực tiếp):
SELECT (oi.quantity * p.price) AS total
FROM order_items oi
JOIN products p ON oi.product_id = p.id

Problem:
- Tuần sau query lại order → total = $80 (sai!)
- Không khớp với recorded order total
- Tính toán revenue sai

Nếu snapshot (lưu price trong order_items):
SELECT (oi.quantity * oi.price) AS total
FROM order_items oi

Benefit:
- Luôn consistent dù product price đổi
- Historical accuracy (biết giá lúc order)
- Revenue calculation chính xác
```

### Decision 3: NUMERIC thay vì FLOAT cho tiền

**Question:** Tại sao NUMERIC(10,2) không phải FLOAT?

**Answer:**
```
FLOAT = Floating point (không chính xác)
NUMERIC = Fixed precision (chính xác tuyệt đối)

Example:
0.1 + 0.2 = ?

FLOAT:
0.1 + 0.2 = 0.30000000000000004 ❌ (sai!)

NUMERIC(10,2):
0.1 + 0.2 = 0.30 ✅ (chính xác)

Production impact:
- FLOAT: Mất $0.00000000000000004 x 1,000,000 orders
- = Mất tiền! Ngân hàng fail
- NUMERIC: Luôn chính xác

Trong e-commerce: NUMERIC là bắt buộc!
```

### Decision 4: Constraints (CHECK) cho business logic

**Question:** Vì sao cần CHECK price > 0?

**Answer:**
```
Scenario: Backend bug hoặc hacker bypass

Nếu KHÔNG có CHECK:
INSERT INTO products (name, price, stock)
VALUES ('Hacked Product', -999.99, 100);

Result:
- Sản phẩm có giá âm (free + money back!)
- Hacker kiếm lợi
- Database accept (không protect)

Nếu có CHECK:
INSERT INTO products (name, price, stock)
VALUES ('Hacked Product', -999.99, 100);

Result:
ERROR: CHECK constraint violation
- Database tự bảo vệ
- Dù backend bug, database vẫn safe
- Production protected at multiple layers
```

### Decision 5: UNIQUE constraint trên email

**Question:** Vì sao email phải UNIQUE?

**Answer:**
```
Email = Login identifier

Nếu KHÔNG UNIQUE:
- User A: user1@gmail.com
- User B: user1@gmail.com (duplicate!)
- Login lỡ vào tài khoản sai
- Data chaos

Nếu UNIQUE:
- Database reject duplicate email
- 1 email = 1 account
- Login an toàn

Production must-have!
```

---

## 3. Transaction Flow - Order Processing

### Safe Order Processing (Concurrency-safe)

```sql
BEGIN;
  -- Step 1: Lock product (prevent oversell)
  SELECT stock FROM products WHERE id = 1 FOR UPDATE;
  -- Row bị lock exclusive → khác transaction phải chờ
  
  -- Step 2: Check stock (in application)
  -- if stock < quantity → RAISE EXCEPTION
  
  -- Step 3: Create order
  INSERT INTO orders (user_id, total_amount, status)
  VALUES (1, 1299.99, 'pending')
  RETURNING id;
  
  -- Step 4: Create order_items (snapshot price)
  INSERT INTO order_items (order_id, product_id, quantity, price)
  VALUES (1, 1, 1, 1299.99);
  -- price = snapshot at order time
  
  -- Step 5: Deduct stock (row đã lock ở Step 1)
  UPDATE products SET stock = stock - 1 WHERE id = 1;
  
COMMIT;
-- Tất cả success → commit
-- Bất kỳ step fail → ROLLBACK tất cả
```

### Concurrency Scenario - 2 users đặt hàng cùng lúc

```
Stock: Laptop = 1

REQUEST 1 (User A):          REQUEST 2 (User B):
BEGIN;                       BEGIN;
SELECT stock FOR UPDATE;     (chờ...)
-- stock = 1
-- lock acquired

                             SELECT stock FOR UPDATE;
                             (chờ! A đang lock)

INSERT order ...;
INSERT order_item ...;
UPDATE stock = 0;
COMMIT;
-- lock released

                             (bây giờ được lock)
                             SELECT stock = 0;
                             -- không đủ stock!
                             RAISE EXCEPTION;
                             ROLLBACK;

Result:
✅ User A: Bán được 1 laptop
❌ User B: Hết hàng (oversell prevented!)
✅ Stock = 0 (correct!)
```

### Why Oversell Prevention is Critical

```
Nếu KHÔNG có transaction + lock:
- 2 users thấy stock = 1
- Cả 2 đều UPDATE stock = 0
- System bán 2 nhưng chỉ có 1
- Stock = 0, nhưng -1 từ backend
- Hacker có thể abuse (free products)

Nếu có transaction + lock:
- User 1 lock → stock = 1 - 1 = 0
- User 2 phải chờ → stock = 0 - 1 = -1 (fail!)
- ✅ Không oversell
- ✅ Database enforce quantity integrity
```

---

## 4. Data Integrity Protection

### Constraint Summary

```
TABLE users:
  ✅ id: PRIMARY KEY (unique, not null, auto-increment)
  ✅ email: UNIQUE (one account per email)
  ✅ email: NOT NULL (required)
  ✅ password_hash: NOT NULL (required)
  ✅ full_name: NULLABLE (optional)

TABLE products:
  ✅ id: PRIMARY KEY
  ✅ name: NOT NULL (required)
  ✅ price: NUMERIC(10,2) NOT NULL CHECK (price > 0)
  ✅ stock: INTEGER NOT NULL CHECK (stock >= 0)
  ✅ description: NULLABLE (optional)

TABLE orders:
  ✅ id: PRIMARY KEY
  ✅ user_id: NOT NULL, FK → users(ON DELETE RESTRICT)
  ✅ total_amount: NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0)
  ✅ status: VARCHAR NOT NULL DEFAULT 'pending'

TABLE order_items:
  ✅ id: PRIMARY KEY
  ✅ order_id: NOT NULL, FK → orders(ON DELETE CASCADE)
  ✅ product_id: NOT NULL, FK → products(ON DELETE RESTRICT)
  ✅ quantity: INTEGER NOT NULL CHECK (quantity > 0)
  ✅ price: NUMERIC(10,2) NOT NULL CHECK (price > 0)
```

### What Happens if Constraints Missing?

```
Scenario 1: No FK on orders.user_id
Problem:
  - Can insert order_id = 9999 (user doesn't exist)
  - Orphan orders in database
  - Report revenue from non-existent users
  - Backend confusion

Scenario 2: No CHECK price > 0
Problem:
  - Can insert price = -100
  - Free products + money back
  - Hacker exploit
  - Business loss

Scenario 3: No UNIQUE email
Problem:
  - Can insert duplicate emails
  - Login confusion
  - Account compromise
  - Security breach

Scenario 4: No CHECK stock >= 0
Problem:
  - Can insert stock = -100
  - Report false negative stock
  - Oversell
  - Inventory chaos

Scenario 5: No snapshot price in order_items
Problem:
  - Order total changes when product price changes
  - Historical records inconsistent
  - Revenue reporting wrong
  - Accounting nightmare
```

---

## 5. Performance Index Strategy

### Index Selection Rationale

```
1. idx_users_email
   Query: SELECT * FROM users WHERE email = 'abc@gmail.com'
   Without index: Full table scan O(N)
   With index: Binary search O(log N)
   Speedup: 50-100x for 1M users
   Essential for: Login, uniqueness check

2. idx_orders_user_id
   Query: SELECT * FROM orders WHERE user_id = 1
   Query: JOIN users u ON o.user_id = u.id
   Without index: Full table scan O(N)
   With index: Direct lookup O(log N)
   Speedup: 10-50x
   Essential for: User dashboard, FK lookup

3. idx_orders_status (PARTIAL)
   Query: SELECT * FROM orders WHERE status = 'pending'
   Partial: Only index pending orders (~10% of table)
   Without index: Full table scan O(N)
   With index: Scan only pending O(log N)
   Speedup: 20-100x
   Space saving: 90% smaller than full index
   Essential for: Admin dashboard

4. idx_orders_created_at DESC
   Query: SELECT * FROM orders ORDER BY created_at DESC LIMIT 10
   Without index: Full table scan + sort O(N log N)
   With index: Index scan backward O(log N)
   Speedup: 10-30x (eliminates sort)
   Essential for: Recent orders, feed

5. idx_order_items_* (Foreign Keys)
   Query: JOIN order_items oi ON o.id = oi.order_id
   Without index: Full table scan O(N)
   With index: Direct lookup O(log N)
   Speedup: 10-30x
   Essential for: Order details, revenue calculation

6. idx_order_items_order_product (Composite)
   Query: WHERE order_id = 1 AND product_id = 2
   Composite vs 2 single indexes: Better query plan
   Speedup: 2-5x over separate indexes
   Essential for: Finding specific item in order
```

### What if No Indexes?

```
Query: SELECT * FROM orders WHERE user_id = 1 (1M orders table)
Without index: Scan 1,000,000 rows → ~500-1000ms
With index: Lookup → ~1-10ms
Performance: 50-100x slower

User experience:
- Without: Chờ 1 giây → frustration
- With: Response < 10ms → happy

Scale impact:
- Without: 100 concurrent users = 100 seconds query time = timeout
- With: 100 concurrent users = 10ms per user = happy

Production requirement: Indexes are MANDATORY
```

---

## 6. Self-Review Checklist (Production Readiness)

### Architecture Decisions

- [x] **Primary Keys**
  - All 4 tables have ID PK
  - Auto-increment (SERIAL)
  - Immutable

- [x] **Foreign Keys**
  - orders.user_id → users(id)
  - order_items.order_id → orders(id)
  - order_items.product_id → products(id)
  - All with appropriate ON DELETE policies

- [x] **Data Types**
  - Money: NUMERIC(10,2) ✅ (not FLOAT)
  - Timestamps: TIMESTAMP ✅
  - IDs: SERIAL (auto-increment) ✅
  - Text: VARCHAR with reasonable length ✅

- [x] **Constraints**
  - NOT NULL: Strategic placement ✅
  - UNIQUE: email ✅
  - CHECK: price > 0, stock >= 0, quantity > 0 ✅
  - FK: All present with policies ✅

- [x] **Audit Trail**
  - created_at: All tables ✅
  - updated_at: users, products, orders ✅

- [x] **Indexes**
  - FK indexes (3): user_id, order_id, product_id ✅
  - Search indexes (2): email, status ✅
  - Sort indexes (1): created_at ✅
  - Composite indexes (1): order_id + product_id ✅

- [x] **Concurrency**
  - Transactions: Order processing ✅
  - Locks: SELECT FOR UPDATE ✅
  - Oversell prevention: Stock check + update ✅

- [x] **Historical Accuracy**
  - Snapshot price in order_items ✅
  - Never join to current product price for history ✅

### Edge Cases Handled

- [x] **1000 concurrent orders?**
  - Solution: SELECT FOR UPDATE locks → serial execution → safe
  
- [x] **Hacker bypass frontend?**
  - Solution: DB constraints check price > 0, quantity > 0
  
- [x] **Backend bug inserts invalid data?**
  - Solution: FK constraints, CHECK constraints reject
  
- [x] **Product price changes?**
  - Solution: Snapshot price in order_items → history accurate
  
- [x] **Delete user?**
  - Solution: ON DELETE RESTRICT → cannot delete if orders exist
  
- [x] **Query performance for 1M rows?**
  - Solution: Strategic indexes → 50-100x speedup

---

## 7. Production Mindset Summary

### How This Design Reflects Production Thinking

```
❌ Junior Developer thinking:
- "Let me just INSERT data and see if it works"
- No constraints → "I'll check in backend"
- No indexes → "It's fast enough now"
- No transactions → "Rarely happens concurrently"
- FLOAT for money → "Good enough for now"

✅ Production Engineer thinking:
- "What constraints prevent bad data?"
  → NOT NULL, UNIQUE, CHECK, FK
  
- "What happens if 1000 users hit at once?"
  → SELECT FOR UPDATE, transactions
  
- "What if product price changes?"
  → Snapshot price in order_items
  
- "What if backend bug or hacker bypass?"
  → Database constraints enforce integrity
  
- "What if query is slow?"
  → Strategic indexes on FK, WHERE, ORDER BY
  
- "How do I know the order total is correct?"
  → Snapshot price, NUMERIC precision
```

### Key Principles Applied

1. **Defense in Depth**
   - Frontend validation
   - Backend validation
   - Database constraints (last line of defense)
   - Layers protect each other

2. **Fail Safe**
   - Cannot insert invalid data
   - Cannot delete if references exist
   - Cannot oversell
   - Safe by design

3. **Data Integrity First**
   - Consistency > Performance
   - ACID properties guaranteed
   - Referential integrity enforced
   - Historical accuracy maintained

4. **Performance Intentional**
   - Indexes chosen strategically
   - Not added randomly
   - Based on actual query patterns
   - Monitored and maintained

5. **Audit Trail**
   - created_at on all tables
   - Track who changed what when
   - Legal/compliance requirement
   - Debugging aid

---

## 8. Next Steps - Integration with Backend

### When building API in Phase 2:

1. **Service Layer Transactions**
   ```javascript
   async function createOrder(userId, items) {
     const client = await pool.connect();
     try {
       await client.query('BEGIN');
       
       // Step 1-5: (as described above)
       
       await client.query('COMMIT');
     } catch (error) {
       await client.query('ROLLBACK');
       throw error;
     }
   }
   ```

2. **Deadlock Retry Logic**
   ```javascript
   for (let attempt = 1; attempt <= 3; attempt++) {
     try {
       return await createOrder(userId, items);
     } catch (error) {
       if (error.code === '40P01' && attempt < 3) {
         // Deadlock - retry with backoff
         await delay(Math.pow(2, attempt) * 100);
       } else {
         throw error;
       }
     }
   }
   ```

3. **Input Validation**
   ```javascript
   // Validate before transaction
   if (!userId || !items || items.length === 0) {
     throw new Error('Invalid request');
   }
   for (const item of items) {
     if (item.quantity <= 0) {
       throw new Error('Quantity must be positive');
     }
   }
   ```

4. **EXPLAIN Analysis**
   ```sql
   EXPLAIN ANALYZE
   SELECT * FROM orders WHERE user_id = 1;
   -- Verify index is used
   ```

---

## Summary - Production-Ready Database

**This database design:**
- ✅ Enforces data integrity at DB level
- ✅ Prevents oversell with transactions + locks
- ✅ Maintains historical accuracy with snapshots
- ✅ Handles concurrency safely
- ✅ Performs well with strategic indexes
- ✅ Passes audit trail requirements
- ✅ Ready for production deployment

**By Day 10, you understand:**
- Data integrity is non-negotiable
- Constraints are protection, not overhead
- Transactions are essential, not optional
- Concurrency is reality, not edge case
- Performance requires strategy, not magic
- Production requires thinking ahead
