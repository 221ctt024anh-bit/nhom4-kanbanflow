-- 1. Liệt kê tất cả chính sách RLS hiện có cho bảng tasks
SELECT policyname, action, permissive, roles, qual, with_check 
FROM pg_policies 
WHERE tablename = 'tasks';

-- 2. Kiểm tra cấu trúc cột của bảng tasks (đặc biệt là các ID)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'tasks';

-- 3. Kiểm tra xem RLS đã thực sự được bật chưa
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname = 'tasks';

-- 4. Kiểm tra các hàm hỗ trợ
-- SELECT routine_definition 
-- FROM information_schema.routines 
-- WHERE routine_name = 'check_board_access';
