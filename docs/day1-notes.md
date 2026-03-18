# Day 1 - Git Discipline & Version Control Fundamentals

## Những điều đã học

### Git lưu gì?
- Git không lưu từng file riên lẻ
- Git lưu snapshot (ảnh chụp toàn bộ trạng thái project tại thời điểm commit)
- Mỗi commit = một trạng thái hoàn chỉnh của hệ thống

### Commit là gì?
- Commit không phải hành động "lưu cho có"
- Commit là một đơn vị thay đổi logic độc lập
- Một commit tốt phải:
  - Chỉ chứa một thay đổi có ý nghĩa
  - Có message rõ ràng
  - Có thể rollback mà không phá hệ thống

### Vì sao commit nhỏ quan trọng?
- Dễ xác định nguyên nhân bug
- Dễ rollback
- Dễ review code
- Commit nhỏ = kiểm soát rủi ro

### Vì sao không làm việc trên main?
- Main đại diện cho code ổn định, có thể deploy production
- Nếu mọi người commit trực tiếp vào main:
  - Không có review
  - Không kiểm soát chất lượng
  - Có thể phá hệ thống đang chạy

## Workflow làm việc chuẩn công nghiệp

### Quy trình chuẩn
1. Tạo branch: `git checkout -b feature/name`
2. Làm việc & commit: `git add .` → `git commit -m "..."`
3. Push: `git push origin feature/name`
4. Tạo Pull Request
5. Review & Merge

### Branch là gì?
- Branch là một dòng phát triển độc lập
- main = đường chính
- feature branch = nhánh phụ phát triển tính năng
- Sau khi hoàn tất và được review → merge vào main

## Chuẩn Commit Message (Conventional Commits)

### Format
```
<type>(optional-scope): short description
```

### Types được sử dụng
- `feat` - Tính năng mới
- `fix` - Sửa bug
- `refactor` - Cải thiện code
- `docs` - Cập nhật tài liệu
- `chore` - Công việc hành chính
- `test` - Thêm test
- `perf` - Tối ưu hiệu năng

### Ví dụ
```
feat(db): create users table
fix(order): rollback transaction on failure
docs: add git discipline note
```

### Yêu cầu
- Viết tiếng Anh
- Ngắn gọn
- Không viết mơ hồ

## Tự kiểm tra hiểu bản chất

1. ✓ Git lưu file hay lưu snapshot?
   - Git lưu snapshot

2. ✓ Vì sao commit nhỏ giúp debug?
   - Dễ xác định phần nào gây lỗi

3. ✓ Nếu main bị lỗi do merge sai thì chuyện gì xảy ra?
   - Production gặp lỗi, cần rollback ngay

4. ✓ Git giúp gì khi rollback production bug?
   - Có thể quay lại commit trước đó nhanh chóng

5. ✓ Tại sao không làm việc trực tiếp trên main?
   - Vì main là code ổn định cho production
