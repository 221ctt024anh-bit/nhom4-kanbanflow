-- Run this in Supabase SQL Editor to fix the missing columns and RLS issues.

-- 1. Add missing columns to public.tasks table
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS checklist JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS has_attachments BOOLEAN DEFAULT FALSE;

-- 2. Ensure RLS is enabled and policies allow insert/update
-- (Adjust these if your user IDs or logic differs)

-- Check if insert policy exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Users can insert their own tasks'
    ) THEN
        CREATE POLICY "Users can insert their own tasks" 
        ON public.tasks FOR INSERT 
        TO authenticated 
        WITH CHECK (auth.uid() = creator_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tasks' AND policyname = 'Users can update their own tasks'
    ) THEN
        CREATE POLICY "Users can update their own tasks" 
        ON public.tasks FOR UPDATE 
        TO authenticated 
        USING (auth.uid() = creator_id OR auth.uid() = assignee_id)
        WITH CHECK (auth.uid() = creator_id OR auth.uid() = assignee_id);
    END IF;
END $$;
