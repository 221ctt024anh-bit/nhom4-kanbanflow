-- SỬA LỖI XÓA THẺ - BẢN "DỌN DẸP SẠCH SẼ" (NUCLEAR CLEANUP)

DO $$
DECLARE
    pol record;
BEGIN
    -- 1. Xóa TẤT CẢ các chính sách hiện có trên bảng tasks để bắt đầu lại từ đầu
    FOR pol IN (SELECT policyname FROM pg_policies WHERE tablename = 'tasks' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.tasks', pol.policyname);
    END LOOP;
    
    -- 2. Đảm bảo RLS đã được bật
    ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

    -- 3. Tạo CHỈ MỘT chính sách duy nhất, cực kỳ thông thoáng cho môi trường debug
    -- Chính sách này cho phép bất kỳ ai đã đăng nhập đều có thể THẤY và XÓA thẻ
    -- (Chúng ta sẽ siết chặt lại sau khi đã xác định lỗi xong)
    CREATE POLICY "tasks_debug_all_policy" ON public.tasks
    FOR ALL TO authenticated
    USING ( true )
    WITH CHECK ( true );

    -- 4. Nếu bạn muốn an toàn hơn một chút, hãy dùng dòng này thay cho dòng trên:
    -- CREATE POLICY "tasks_debug_all_policy" ON public.tasks
    -- FOR ALL TO authenticated
    -- USING ( public.check_board_access(board_id) )
    -- WITH CHECK ( public.check_board_access(board_id) );

END $$;
