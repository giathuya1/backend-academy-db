# Day 2 - Docker Fundamentals & Environment Discipline

## Những điều đã học

### Docker là gì?
- Docker là nền tảng containerization
- Container = môi trường chạy ứng dụng cô lập, nhẹ, độc lập
- Giải quyết vấn đề "chạy được trên máy em nhưng không chạy trên máy anh"

### Container khác VM thế nào?
- **Virtual Machine**: Có full OS, nặng, tốn tài nguyên
- **Container**: Chia sẻ kernel OS, nhẹ, khởi động nhanh, phù hợp microservice

### Thành phần Docker chính
- **Image**: Bản thiết kế/bản mẫu (giống class)
- **Container**: Instance đang chạy từ image (giống object)
- **Volume**: Nơi lưu dữ liệu bền vững (dữ liệu tồn tại dù container bị xóa)
- **Port mapping**: Kết nối container với máy local (5432:5432)

## Docker Commands

### Kiểm tra Docker
```bash
docker --version
docker ps                    # Liệt kê container đang chạy
docker ps -a                 # Liệt kê tất cả container (bao gồm dừng)
docker images                # Liệt kê images
```

### Docker Compose
```bash
docker compose up -d         # Khởi động services ở background
docker compose down          # Dừng và xóa containers
docker compose logs          # Xem logs
docker compose logs -f       # Xem logs realtime
docker compose ps            # Xem status containers
```

### Kiểm tra database
```bash
# Kết nối vào PostgreSQL container
docker compose exec postgres psql -U student -d ecommerce

# Hoặc dùng GUI tool như pgAdmin
```

## Cấu trúc docker-compose.yml

```yaml
version: '3.8'  # Version của Docker Compose

services:
  postgres:     # Tên service
    image: postgres:16-alpine    # Image sử dụng
    container_name: academy-postgres  # Tên container
    environment:   # Biến môi trường
      POSTGRES_USER: student
      POSTGRES_PASSWORD: 123456
      POSTGRES_DB: ecommerce
    ports:         # Port mapping (máy local:container)
      - "5432:5432"
    volumes:       # Mount volume
      - pgdata:/var/lib/postgresql/data
    healthcheck:   # Kiểm tra health
      test: ["CMD-SHELL", "pg_isready -U student"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:        # Volume định nghĩa
```

## Điều quan trọng

### Volume - Tại sao cần?
- Nếu không dùng volume: Tắt container → mất dữ liệu
- Với volume: Dữ liệu tồn tại dù container bị xóa
- `pgdata:/var/lib/postgresql/data` = map thư mục trên máy → trong container

### Port Mapping - Làm sao kết nối?
- `5432:5432` = máy local port 5432 → container port 5432
- Nếu port 5432 bị chiếm, có thể dùng `5433:5432`

### Healthcheck - Kiểm tra sức khỏe
- Docker sẽ kiểm tra mỗi 10s xem PostgreSQL có sẵn sàng không
- Nếu lỗi 5 lần liên tiếp, container bị đánh dấu unhealthy

## Lỗi phổ biến & Cách fix

### Lỗi: Port 5432 đã bị chiếm
```bash
# Kiểm tra process dùng port
netstat -ano | findstr :5432  # Windows
lsof -i :5432                 # Mac/Linux

# Fix: Thay port khác trong docker-compose.yml
ports:
  - "5433:5432"
```

### Lỗi: Mất dữ liệu sau khi xóa container
**Nguyên nhân**: Không dùng volume
**Fix**: Thêm volumes section

### Lỗi: Container không khởi động
```bash
# Xem logs chi tiết
docker compose logs postgres

# Rebuild và khởi động lại
docker compose down
docker compose up -d
```

## Self-Check Questions

1. ✓ Docker khác VM thế nào?
2. ✓ Image khác container thế nào?
3. ✓ Nếu xóa container mà không có volume thì chuyện gì xảy ra?
4. ✓ Vì sao backend production nên dùng Docker?
5. ✓ Port mapping `5432:5432` có nghĩa gì?

