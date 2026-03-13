-- Thêm cột task_type vào bảng tasks để phân loại thẻ chính xác
ALTER TABLE tasks ADD COLUMN task_type TEXT DEFAULT 'text';

-- Cập nhật dữ liệu cũ nếu cần (Dựa trên checklist hoặc attachments)
UPDATE tasks SET task_type = 'checklist' WHERE checklist IS NOT NULL AND checklist != '[]';
-- Không thể phân biệt chính xác image/audio cho dữ liệu cũ chỉ bằng has_attachments
-- nên ta để mặc định là 'text' cho dữ liệu cũ có attachments.
