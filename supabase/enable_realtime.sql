-- LỆNH BẬT REALTIME CHO BẢNG TASKS
-- Chạy lệnh này trong mục "SQL Editor" trên Supabase

-- 1. Thêm bảng tasks vào danh sách phát tin realtime
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;

-- 2. (Tùy chọn) Nếu bạn muốn bật cho cả các bảng khác để ứng dụng mượt hơn:
-- ALTER PUBLICATION supabase_realtime ADD TABLE boards;
-- ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
-- ALTER PUBLICATION supabase_realtime ADD TABLE board_members;
