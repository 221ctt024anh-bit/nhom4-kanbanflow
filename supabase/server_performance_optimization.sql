-- Professional server-side optimization script for Supabase/Postgres.
-- Run this in Supabase SQL Editor after the base schema is in place.
-- Focus:
-- 1. Support frequent filters/order by with covering indexes.
-- 2. Reduce RLS/trigger overhead caused by repeated membership checks.
-- 3. Keep changes idempotent and safe to re-run.

begin;

create index if not exists idx_boards_owner_id_created_at
  on public.boards(owner_id, created_at desc);

create index if not exists idx_board_members_user_board
  on public.board_members(user_id, board_id);

create index if not exists idx_board_members_board_user
  on public.board_members(board_id, user_id);

create index if not exists idx_board_members_board_role
  on public.board_members(board_id, role);

create index if not exists idx_tasks_board_created_at
  on public.tasks(board_id, created_at desc);

create index if not exists idx_tasks_board_status_created_at
  on public.tasks(board_id, status, created_at desc);

create index if not exists idx_tasks_creator_created_at
  on public.tasks(creator_id, created_at desc);

create index if not exists idx_tasks_due_at
  on public.tasks(due_at)
  where due_at is not null;

create index if not exists idx_task_comments_task_created_at
  on public.task_comments(task_id, created_at asc);

create index if not exists idx_task_attachments_task_created_at
  on public.task_attachments(task_id, created_at desc);

create index if not exists idx_task_ratings_task_user
  on public.task_ratings(task_id, user_id);

create index if not exists idx_user_notifications_user_unread_created_at
  on public.user_notifications(user_id, is_read, created_at desc);

create index if not exists idx_friend_requests_sender_recipient_status
  on public.friend_requests(sender_id, recipient_id, status);

create index if not exists idx_friend_requests_recipient_status_created_at
  on public.friend_requests(recipient_id, status, created_at desc);

create index if not exists idx_friendships_user_friend
  on public.friendships(user_id, friend_id);

create index if not exists idx_direct_messages_conversation_created_desc
  on public.direct_messages(conversation_id, created_at desc);

create index if not exists idx_direct_messages_recipient_read_created
  on public.direct_messages(recipient_id, is_read, created_at desc);

create index if not exists idx_profiles_email
  on public.profiles(email);

create or replace function public.check_board_access_fast(p_board_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.boards b
    where b.id = p_board_id
      and b.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.board_members bm
    where bm.board_id = p_board_id
      and bm.user_id = auth.uid()
  );
$$;

create or replace function public.check_board_access(p_board_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.check_board_access_fast(p_board_id);
$$;

commit;

-- Recommended manual verification after execution:
-- explain analyze
-- select id, board_id, title, status, created_at
-- from public.tasks
-- where board_id = '<board_uuid>' and status = 'todo'
-- order by created_at desc
-- limit 50;
