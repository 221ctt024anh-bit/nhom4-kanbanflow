-- Run this script in Supabase SQL Editor.
-- It creates tables and storage policies for task comments and attachments.

create table if not exists public.task_assignees (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(task_id, user_id)
);

create index if not exists idx_task_assignees_task_id on public.task_assignees(task_id);
create index if not exists idx_task_assignees_user_id on public.task_assignees(user_id);

alter table public.task_assignees enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_assignees'
      and policyname = 'task_assignees_select_member'
  ) then
    create policy task_assignees_select_member
      on public.task_assignees
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_assignees.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_assignees.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_assignees'
      and policyname = 'task_assignees_insert_member'
  ) then
    create policy task_assignees_insert_member
      on public.task_assignees
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_assignees.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_assignees.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_assignees'
      and policyname = 'task_assignees_delete_member'
  ) then
    create policy task_assignees_delete_member
      on public.task_assignees
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_assignees.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_assignees.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;
end $$;

-- Migrate existing data
insert into public.task_assignees (task_id, user_id)
select id, assignee_id from public.tasks
where assignee_id is not null
on conflict do nothing;

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_task_comments_task_id on public.task_comments(task_id);
create index if not exists idx_task_comments_created_at on public.task_comments(created_at);

alter table public.task_comments enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_comments'
      and policyname = 'task_comments_select_member'
  ) then
    create policy task_comments_select_member
      on public.task_comments
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_comments.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_comments.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_comments'
      and policyname = 'task_comments_insert_member'
  ) then
    create policy task_comments_insert_member
      on public.task_comments
      for insert
      to authenticated
      with check (
        user_id = auth.uid()
        and (
          exists (
            select 1
            from public.tasks t
            join public.board_members bm on bm.board_id = t.board_id
            where t.id = task_comments.task_id
              and bm.user_id = auth.uid()
          )
          or exists (
            select 1
            from public.tasks t
            join public.boards b on b.id = t.board_id
            where t.id = task_comments.task_id
              and b.owner_id = auth.uid()
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_comments'
      and policyname = 'task_comments_update_owner'
  ) then
    create policy task_comments_update_owner
      on public.task_comments
      for update
      to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_comments'
      and policyname = 'task_comments_delete_owner'
  ) then
    create policy task_comments_delete_owner
      on public.task_comments
      for delete
      to authenticated
      using (user_id = auth.uid());
  end if;
end $$;

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  task_id uuid references public.tasks(id) on delete cascade,
  comment_id uuid references public.task_comments(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_notifications_user_id on public.user_notifications(user_id);
create index if not exists idx_user_notifications_created_at on public.user_notifications(created_at);

alter table public.user_notifications enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notifications'
      and policyname = 'user_notifications_select_own'
  ) then
    create policy user_notifications_select_own
      on public.user_notifications
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_notifications'
      and policyname = 'user_notifications_update_own'
  ) then
    create policy user_notifications_update_own
      on public.user_notifications
      for update
      to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

-- Ensure authenticated users can select and update profiles.
do $$
begin
  -- Update policy
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own
      on public.profiles
      for update
      to authenticated
      using (id = auth.uid())
      with check (id = auth.uid());
  end if;

  -- Select policy (Crucial for finding friends)
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_select_auth'
  ) then
    create policy profiles_select_auth
      on public.profiles
      for select
      to authenticated
      using (true);
  end if;
end $$;

alter table public.profiles
  add column if not exists is_online boolean not null default false;

alter table public.profiles
  add column if not exists last_seen_at timestamptz;

alter table public.profiles
  add column if not exists bio text;

alter table public.tasks
  add column if not exists due_at timestamptz;

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  in_app_notifications boolean not null default true,
  email_notifications boolean not null default true,
  theme_mode text not null default 'system' check (theme_mode in ('system', 'light', 'dark')),
  language_code text not null default 'vi',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_settings_updated_at on public.user_settings(updated_at);

alter table public.user_settings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_select_own'
  ) then
    create policy user_settings_select_own
      on public.user_settings
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_insert_own'
  ) then
    create policy user_settings_insert_own
      on public.user_settings
      for insert
      to authenticated
      with check (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_update_own'
  ) then
    create policy user_settings_update_own
      on public.user_settings
      for update
      to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

create or replace function public.set_user_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
before update on public.user_settings
for each row
execute function public.set_user_settings_updated_at();

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_id <> recipient_id)
);

create index if not exists idx_friend_requests_sender on public.friend_requests(sender_id, status);
create index if not exists idx_friend_requests_recipient on public.friend_requests(recipient_id, status);

alter table public.friend_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friend_requests'
      and policyname = 'friend_requests_select_related'
  ) then
    create policy friend_requests_select_related
      on public.friend_requests
      for select
      to authenticated
      using (sender_id = auth.uid() or recipient_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friend_requests'
      and policyname = 'friend_requests_insert_sender'
  ) then
    create policy friend_requests_insert_sender
      on public.friend_requests
      for insert
      to authenticated
      with check (
        sender_id = auth.uid()
        and status = 'pending'
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friend_requests'
      and policyname = 'friend_requests_update_related'
  ) then
    create policy friend_requests_update_related
      on public.friend_requests
      for update
      to authenticated
      using (sender_id = auth.uid() or recipient_id = auth.uid())
      with check (sender_id = auth.uid() or recipient_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friend_requests'
      and policyname = 'friend_requests_delete_related'
  ) then
    create policy friend_requests_delete_related
      on public.friend_requests
      for delete
      to authenticated
      using (sender_id = auth.uid() or recipient_id = auth.uid());
  end if;
end $$;

create table if not exists public.friendships (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create index if not exists idx_friendships_user on public.friendships(user_id);
create index if not exists idx_friendships_friend on public.friendships(friend_id);

alter table public.friendships enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friendships'
      and policyname = 'friendships_select_own'
  ) then
    create policy friendships_select_own
      on public.friendships
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friendships'
      and policyname = 'friendships_insert_own'
  ) then
    create policy friendships_insert_own
      on public.friendships
      for insert
      to authenticated
      with check (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'friendships'
      and policyname = 'friendships_delete_related'
  ) then
    create policy friendships_delete_related
      on public.friendships
      for delete
      to authenticated
      using (user_id = auth.uid() or friend_id = auth.uid());
  end if;
end $$;

-- Trigger for reciprocal friendship deletion
create or replace function public.handle_reciprocal_unfriend()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Delete the reciprocal row if it exists
  delete from public.friendships
  where user_id = old.friend_id and friend_id = old.user_id;
  
  -- Also delete any existing friend requests between these two
  delete from public.friend_requests
  where (sender_id = old.user_id and recipient_id = old.friend_id)
     or (sender_id = old.friend_id and recipient_id = old.user_id);
     
  return old;
end;
$$;

drop trigger if exists trg_reciprocal_unfriend on public.friendships;
create trigger trg_reciprocal_unfriend
after delete on public.friendships
for each row
execute function public.handle_reciprocal_unfriend();

create or replace function public.handle_friend_request_accept()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'accepted' and old.status <> 'accepted' then
    insert into public.friendships (user_id, friend_id)
    values (new.sender_id, new.recipient_id)
    on conflict do nothing;

    insert into public.friendships (user_id, friend_id)
    values (new.recipient_id, new.sender_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friend_request_accept on public.friend_requests;
create trigger trg_friend_request_accept
after update of status on public.friend_requests
for each row
execute function public.handle_friend_request_accept();

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id text not null,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create index if not exists idx_direct_messages_conversation_created_at
  on public.direct_messages(conversation_id, created_at);
create index if not exists idx_direct_messages_recipient_unread
  on public.direct_messages(recipient_id, is_read, created_at);

alter table public.direct_messages enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'direct_messages'
      and policyname = 'direct_messages_select_related'
  ) then
    create policy direct_messages_select_related
      on public.direct_messages
      for select
      to authenticated
      using (sender_id = auth.uid() or recipient_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'direct_messages'
      and policyname = 'direct_messages_insert_sender'
  ) then
    create policy direct_messages_insert_sender
      on public.direct_messages
      for insert
      to authenticated
      with check (
        sender_id = auth.uid()
        and exists (
          select 1
          from public.friendships f
          where f.user_id = auth.uid()
            and f.friend_id = direct_messages.recipient_id
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'direct_messages'
      and policyname = 'direct_messages_update_recipient'
  ) then
    create policy direct_messages_update_recipient
      on public.direct_messages
      for update
      to authenticated
      using (recipient_id = auth.uid())
      with check (recipient_id = auth.uid());
  end if;
end $$;

create table if not exists public.email_jobs (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  subject text not null,
  body_text text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts int not null default 0,
  provider_message_id text,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz
);

create index if not exists idx_email_jobs_status_created_at on public.email_jobs(status, created_at);
create index if not exists idx_email_jobs_recipient on public.email_jobs(recipient_user_id);

create or replace function public.set_email_jobs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_email_jobs_updated_at on public.email_jobs;
create trigger trg_email_jobs_updated_at
before update on public.email_jobs
for each row
execute function public.set_email_jobs_updated_at();



create table if not exists public.task_attachments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  file_name text not null,
  file_path text not null unique,
  public_url text not null,
  uploader_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists idx_task_attachments_task_id on public.task_attachments(task_id);
create index if not exists idx_task_attachments_created_at on public.task_attachments(created_at);

alter table public.task_attachments enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_attachments'
      and policyname = 'task_attachments_select_member'
  ) then
    create policy task_attachments_select_member
      on public.task_attachments
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_attachments.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_attachments.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_attachments'
      and policyname = 'task_attachments_insert_member'
  ) then
    create policy task_attachments_insert_member
      on public.task_attachments
      for insert
      to authenticated
      with check (
        uploader_id = auth.uid()
        and (
          exists (
            select 1
            from public.tasks t
            join public.board_members bm on bm.board_id = t.board_id
            where t.id = task_attachments.task_id
              and bm.user_id = auth.uid()
          )
          or exists (
            select 1
            from public.tasks t
            join public.boards b on b.id = t.board_id
            where t.id = task_attachments.task_id
              and b.owner_id = auth.uid()
          )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_attachments'
      and policyname = 'task_attachments_delete_owner'
  ) then
    create policy task_attachments_delete_owner
      on public.task_attachments
      for delete
      to authenticated
      using (uploader_id = auth.uid());
  end if;
end $$;

create table if not exists public.task_ratings (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (task_id, user_id)
);

create index if not exists idx_task_ratings_task_id on public.task_ratings(task_id);
create index if not exists idx_task_ratings_user_id on public.task_ratings(user_id);

create or replace function public.set_task_ratings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_task_ratings_updated_at on public.task_ratings;
create trigger trg_task_ratings_updated_at
before update on public.task_ratings
for each row
execute function public.set_task_ratings_updated_at();

alter table public.task_ratings enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_ratings'
      and policyname = 'task_ratings_select_member'
  ) then
    create policy task_ratings_select_member
      on public.task_ratings
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tasks t
          join public.board_members bm on bm.board_id = t.board_id
          where t.id = task_ratings.task_id
            and bm.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.tasks t
          join public.boards b on b.id = t.board_id
          where t.id = task_ratings.task_id
            and b.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_ratings'
      and policyname = 'task_ratings_insert_own'
  ) then
    create policy task_ratings_insert_own
      on public.task_ratings
      for insert
      to authenticated
      with check (
        user_id = auth.uid()
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'task_ratings'
      and policyname = 'task_ratings_update_own'
  ) then
    create policy task_ratings_update_own
      on public.task_ratings
      for update
      to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

insert into storage.buckets (id, name, public)
select 'task-attachments', 'task-attachments', true
where not exists (
  select 1 from storage.buckets where id = 'task-attachments'
);

insert into storage.buckets (id, name, public)
select 'profile-avatars', 'profile-avatars', true
where not exists (
  select 1 from storage.buckets where id = 'profile-avatars'
);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'task_attachments_public_read'
  ) then
    create policy task_attachments_public_read
      on storage.objects
      for select
      to public
      using (bucket_id = 'task-attachments');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'task_attachments_auth_insert'
  ) then
    create policy task_attachments_auth_insert
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'task-attachments');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'task_attachments_auth_delete'
  ) then
    create policy task_attachments_auth_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'task-attachments');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'profile_avatars_public_read'
  ) then
    create policy profile_avatars_public_read
      on storage.objects
      for select
      to public
      using (bucket_id = 'profile-avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'profile_avatars_auth_insert'
  ) then
    create policy profile_avatars_auth_insert
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'profile-avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'profile_avatars_auth_update'
  ) then
    create policy profile_avatars_auth_update
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'profile-avatars')
      with check (bucket_id = 'profile-avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'profile_avatars_auth_delete'
  ) then
    create policy profile_avatars_auth_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'profile-avatars');
  end if;
end $$;

-- 10. Robust RLS Policies (Final Fix)

-- Helper function to check board membership without recursion
-- Using security definer to bypass RLS in the check
create or replace function public.check_board_access(p_board_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.boards
    where id = p_board_id and owner_id = auth.uid()
    union all
    select 1 from public.board_members
    where board_id = p_board_id and user_id = auth.uid()
  );
$$;

-- Enable RLS
alter table public.boards enable row level security;
alter table public.board_members enable row level security;
alter table public.tasks enable row level security;

-- Drop all potentially conflicting policies
do $$
begin
  -- Tasks
  drop policy if exists "tasks_select_policy" on public.tasks;
  drop policy if exists "tasks_insert_policy" on public.tasks;
  drop policy if exists "tasks_update_policy" on public.tasks;
  drop policy if exists "tasks_delete_policy" on public.tasks;
  drop policy if exists "Users can update their own tasks" on public.tasks;
  drop policy if exists "Users can insert their own tasks" on public.tasks;
  drop policy if exists "tasks_access_policy" on public.tasks;
  
  -- Boards
  drop policy if exists "Enable read access for own boards" on public.boards;
  drop policy if exists "Enable insert for authenticated users" on public.boards;
  drop policy if exists "boards_access_policy" on public.boards;
  
  -- Board Members
  drop policy if exists "Enable read access for board members" on public.board_members;
  drop policy if exists "board_members_access_policy" on public.board_members;
end $$;

-- Policies for Boards
create policy "boards_access_policy" on public.boards
for all to authenticated
using ( public.check_board_access(id) );

-- Policies for Board Members
create policy "board_members_access_policy" on public.board_members
for all to authenticated
using ( 
  user_id = auth.uid() or -- Cho phép xem chính mình
  public.check_board_access(board_id) -- Cho phép xem thành viên khác nếu có quyền vào bảng
);

-- Unified Policy for Tasks
create policy "tasks_access_policy" on public.tasks
for all to authenticated
using ( public.check_board_access(board_id) )
with check ( public.check_board_access(board_id) );

-- 11. Consolidated Email & Notification Triggers

-- Function to handle Comment Notifications (In-app and Email)
create or replace function public.handle_comment_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task record;
begin
  select t.id, t.title, t.creator_id, t.assignee_id, b.owner_id, b.id as board_id
  into v_task
  from public.tasks t
  join public.boards b on b.id = t.board_id
  where t.id = new.task_id;

  if not found then
    return new;
  end if;

  -- 1. In-app notifications
  insert into public.user_notifications (user_id, task_id, comment_id, title, message)
  select distinct target_user_id, new.task_id, new.id, 'Bình luận mới', 'Có bình luận mới trong task "' || coalesce(v_task.title, 'Task') || '"'
  from (
    select v_task.owner_id as target_user_id
    union all
    select v_task.creator_id
    union all
    select user_id from public.task_assignees where task_id = new.task_id
    union all
    select bm.user_id
    from public.board_members bm
    where bm.board_id = v_task.board_id
  ) users
  where target_user_id is not null
    and target_user_id <> new.user_id;

  -- 2. Email notifications
  insert into public.email_jobs (
    event_type,
    recipient_user_id,
    recipient_email,
    subject,
    body_text,
    payload
  )
  select distinct
    'task_comment',
    recipients.target_user_id,
    au.email,
    '[TaskMate] Bình luận mới trong task: ' || coalesce(v_task.title, 'Task'),
    'Bạn có bình luận mới trong task "' || coalesce(v_task.title, 'Task') || '". Mở ứng dụng để xem chi tiết và phản hồi.',
    jsonb_build_object(
      'task_id', new.task_id,
      'comment_id', new.id,
      'task_title', coalesce(v_task.title, ''),
      'actor_user_id', new.user_id
    )
  from (
    select v_task.owner_id as target_user_id
    union all
    select v_task.creator_id
    union all
    select user_id from public.task_assignees where task_id = new.task_id
    union all
    select bm.user_id
    from public.board_members bm
    where bm.board_id = v_task.board_id
  ) recipients
  join auth.users au on au.id = recipients.target_user_id
  left join public.user_settings us on us.user_id = recipients.target_user_id
  where recipients.target_user_id is not null
    and recipients.target_user_id <> new.user_id
    and coalesce(us.email_notifications, true) = true
    and au.email is not null
    and length(trim(au.email)) > 0
    -- TRÁNH GỬI EMAIL CHO COMMENT TỰ ĐỘNG (GIAO VIỆC)
    and new.content not like 'Đã giao nhiệm vụ cho %';

  return new;
end;
$$;

-- Clean up ALL redundant triggers to prevent duplication
drop trigger if exists trg_comment_notifications on public.task_comments;
drop trigger if exists trg_task_comments_notifications on public.task_comments;

create trigger trg_comment_notifications
after insert on public.task_comments
for each row
execute function public.handle_comment_notifications();

-- Function to handle Task Assignment Emails & Notifications (Multi-Assignee Support)
create or replace function public.handle_task_assignment_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_email text;
  v_email_enabled boolean;
  v_actor_name text;
  v_task_title text;
begin
  -- Get task info and actor name
  select title into v_task_title from public.tasks where id = new.task_id;
  select coalesce(display_name, email) into v_actor_name from public.profiles where id = auth.uid();

  -- 1. In-app notification for the assignee
  insert into public.user_notifications (user_id, task_id, title, message)
  values (
    new.user_id,
    new.task_id,
    'Nhiệm vụ mới được giao',
    'Bạn đã được giao nhiệm vụ "' || coalesce(v_task_title, 'Task') || '" bởi ' || coalesce(v_actor_name, 'một người dùng khác')
  );

  -- 2. Email notification
  select us.email_notifications into v_email_enabled
  from public.user_settings us
  where us.user_id = new.user_id;

  if coalesce(v_email_enabled, true) = false then
    return new;
  end if;

  select au.email into v_recipient_email
  from auth.users au
  where au.id = new.user_id;

  if v_recipient_email is not null and length(trim(v_recipient_email)) > 0 then
    insert into public.email_jobs (
      event_type,
      recipient_user_id,
      recipient_email,
      subject,
      body_text,
      payload
    )
    values (
      'task_assignment',
      new.user_id,
      v_recipient_email,
      '[TaskMate] Bạn được giao một công việc mới: ' || coalesce(v_task_title, 'Task'),
      'Xin chào, bạn vừa được giao task mới "' || coalesce(v_task_title, 'Task') || '". Đăng nhập vào ứng dụng để xem chi tiết.',
      jsonb_build_object(
        'task_id', new.task_id,
        'task_title', coalesce(v_task_title, '')
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_task_assignment_notifications on public.task_assignees;
create trigger trg_task_assignment_notifications
after insert on public.task_assignees
for each row
execute function public.handle_task_assignment_notifications();

-- Drop old task-based assignment trigger
drop trigger if exists trg_task_assignment_notifications on public.tasks;
drop trigger if exists trg_task_notifications on public.tasks;
drop trigger if exists trg_task_assignment_email on public.tasks;

-- Function to handle Friend Request Emails
create or replace function public.handle_friend_request_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_email text;
  v_sender_name text;
  v_email_enabled boolean;
begin
  if (new.status = 'pending') then
    -- Check if user wants emails
    select us.email_notifications into v_email_enabled
    from public.user_settings us
    where us.user_id = new.recipient_id;

    if coalesce(v_email_enabled, true) = false then
      return new;
    end if;

    select au.email into v_recipient_email
    from auth.users au
    where au.id = new.recipient_id;

    select coalesce(display_name, 'Một người dùng') into v_sender_name
    from public.profiles
    where id = new.sender_id;

    if v_recipient_email is not null and length(trim(v_recipient_email)) > 0 then
      insert into public.email_jobs (
        event_type,
        recipient_user_id,
        recipient_email,
        subject,
        body_text,
        payload
      )
      values (
        'friend_request',
        new.recipient_id,
        v_recipient_email,
        '[TaskMate] Bạn nhận được lời mời kết bạn từ ' || v_sender_name,
        v_sender_name || ' muốn kết bạn với bạn trên TaskMate. Đăng nhập để đồng ý hoặc từ chối.',
        jsonb_build_object(
          'sender_id', new.sender_id,
          'sender_name', v_sender_name
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friend_request_email on public.friend_requests;
create trigger trg_friend_request_email
after insert on public.friend_requests
for each row
execute function public.handle_friend_request_email();

-- Function to handle Direct Message Emails
create or replace function public.handle_direct_message_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_email text;
  v_sender_name text;
  v_email_enabled boolean;
  v_in_app_enabled boolean;
begin
  -- Check settings
  select us.email_notifications, us.in_app_notifications 
  into v_email_enabled, v_in_app_enabled
  from public.user_settings us
  where us.user_id = new.recipient_id;

  select coalesce(display_name, 'Một người dùng') into v_sender_name
  from public.profiles
  where id = new.sender_id;

  -- 1. In-app notification
  if coalesce(v_in_app_enabled, true) = true then
    insert into public.user_notifications (user_id, sender_id, title, message)
    values (
      new.recipient_id,
      new.sender_id,
      'Tin nhắn mới',
      'Bạn có tin nhắn mới từ ' || v_sender_name || ': "' || left(new.content, 40) || (case when length(new.content) > 40 then '...' else '' end) || '"'
    );
  end if;

  -- 2. Email notification
  if coalesce(v_email_enabled, true) = true then
    select au.email into v_recipient_email
    from auth.users au
    where au.id = new.recipient_id;

    if v_recipient_email is not null and length(trim(v_recipient_email)) > 0 then
      insert into public.email_jobs (
        event_type,
        recipient_user_id,
        recipient_email,
        subject,
        body_text,
        payload
      )
      values (
        'direct_message',
        new.recipient_id,
        v_recipient_email,
        '[TaskMate] Bạn có tin nhắn mới từ ' || v_sender_name,
        'Bạn vừa nhận được một tin nhắn mới: "' || left(new.content, 50) || '...". Đăng nhập để trả lời.',
        jsonb_build_object(
          'sender_id', new.sender_id,
          'sender_name', v_sender_name,
          'conversation_id', new.conversation_id
        )
      );
    end if;
  end if;
  
  return new;
end;
$$;

drop trigger if exists trg_direct_message_email on public.direct_messages;
create trigger trg_direct_message_email
after insert on public.direct_messages
for each row
execute function public.handle_direct_message_email();
-- 12. Automatic Profile Creation for New Users (Handles Google OAuth too)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = coalesce(public.profiles.display_name, excluded.display_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
