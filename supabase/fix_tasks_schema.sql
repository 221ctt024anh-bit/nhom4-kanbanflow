-- Run this in Supabase SQL Editor to fix the missing columns and RLS issues.

-- 1. Add missing columns to public.tasks table
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS checklist JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS has_attachments BOOLEAN DEFAULT FALSE;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS task_type TEXT DEFAULT 'text';

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Ensure RLS is enabled and policies allow insert/update
-- (Adjust these if your user IDs or logic differs)

-- Check if insert policy exists, if not create it
DO $$
BEGIN
    -- Chính sách INSERT: Cho phép thành viên bảng tạo thẻ
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Members can insert tasks'
    ) THEN
        CREATE POLICY "Members can insert tasks" 
        ON public.tasks FOR INSERT 
        TO authenticated 
        WITH CHECK (public.check_board_access(board_id));
    END IF;

    -- Chính sách UPDATE: Cho phép thành viên bảng cập nhật thẻ (để kéo thả)
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

    -- Chính sách SELECT: Cho phép thành viên bảng xem thẻ
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Members can select tasks'
    ) THEN
        CREATE POLICY "Members can select tasks" 
        ON public.tasks FOR SELECT 
        TO authenticated 
        USING (public.check_board_access(board_id));
    END IF;

    -- Chính sách cho bảng task_assignees
    -- Cho phép xem phân công của bảng mình tham gia
    DROP POLICY IF EXISTS "Members can select task_assignees" ON public.task_assignees;
    CREATE POLICY "Members can select task_assignees" 
    ON public.task_assignees FOR SELECT 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.tasks t
            WHERE t.id = task_id AND public.check_board_access(t.board_id)
        )
    );

    -- Xóa các chính sách cũ nếu tồn tại để tránh xung đột
    DROP POLICY IF EXISTS "Users can insert their own tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Users can update their own tasks" ON public.tasks;
    DROP POLICY IF EXISTS "Users can view task assignees" ON public.task_assignees;
END $$;
