-- SỬA LỖI PHÂN QUYỀN CẬP NHẬT THẺ

DO $$
BEGIN
    -- 1. Xóa các chính sách cũ có khả năng gây xung đột
    DROP POLICY IF EXISTS "Users can update their own tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Members can update tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Members can insert tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Users can insert their own tasks" ON public.tasks;

    -- 2. Chính sách INSERT: Cho phép thành viên bảng tạo thẻ
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Members can insert tasks'
    ) THEN
        CREATE POLICY "Members can insert tasks" 
        ON public.tasks FOR INSERT 
        TO authenticated 
        WITH CHECK (public.check_board_access(board_id));
    END IF;

    -- 3. Chính sách UPDATE: Cho phép thành viên bảng cập nhật thẻ (VD: kéo thả status)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Members can update tasks'
    ) THEN
        CREATE POLICY "Members can update tasks" 
        ON public.tasks FOR UPDATE 
        TO authenticated 
        USING (public.check_board_access(board_id))
        WITH CHECK (public.check_board_access(board_id));
    END IF;

    -- 4. Chính sách SELECT: Cho phép thành viên bảng xem thẻ (Đã có nhưng đảm bảo lại)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Members can select tasks'
    ) THEN
        CREATE POLICY "Members can select tasks" 
        ON public.tasks FOR SELECT 
        TO authenticated 
        USING (public.check_board_access(board_id));
    END IF;

END $$;
