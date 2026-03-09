-- Extension for Email Notifications
-- This script adds triggers to queue email jobs for Task Assignments, Friend Requests and Direct Messages.

-- 1. Function to handle Task Assignment Emails
create or replace function public.handle_task_assignment_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_email text;
begin
  -- Only if assignee is set or changed
  if (new.assignee_id is not null) and (old.assignee_id is null or old.assignee_id <> new.assignee_id) then
    
    select au.email into v_recipient_email
    from auth.users au
    where au.id = new.assignee_id;

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
        new.assignee_id,
        v_recipient_email,
        '[TaskMate] Bạn được giao một công việc mới: ' || coalesce(new.title, 'Task'),
        'Xin chào, bạn vừa được giao task mới "' || coalesce(new.title, 'Task') || '". Đăng nhập vào ứng dụng để xem chi tiết.',
        jsonb_build_object(
          'task_id', new.id,
          'task_title', coalesce(new.title, '')
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_task_assignment_email on public.tasks;
create trigger trg_task_assignment_email
after update or insert on public.tasks
for each row
execute function public.handle_task_assignment_email();

-- 2. Function to handle Friend Request Emails
create or replace function public.handle_friend_request_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_email text;
  v_sender_name text;
begin
  if (new.status = 'pending') then
    
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

-- 3. Function to handle Direct Message Emails
-- Note: This only fires if the recipient hasn't read the message within a short window, 
-- but for simplicity here we trigger it on insert if they aren't online (if we had presence)
-- Simplest approach: trigger for all if email_notifications is on. 
-- RLS/Settings check is handled by the job processor usually, but we check setting here like in comments.
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
begin
  
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
  
  return new;
end;
$$;

drop trigger if exists trg_direct_message_email on public.direct_messages;
create trigger trg_direct_message_email
after insert on public.direct_messages
for each row
execute function public.handle_direct_message_email();
