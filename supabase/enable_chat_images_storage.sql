-- Enable storage bucket and policies for chat images.
-- Run this in Supabase SQL Editor.

begin;

insert into storage.buckets (id, name, public)
select 'chat-images', 'chat-images', true
where not exists (
  select 1 from storage.buckets where id = 'chat-images'
);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'chat_images_public_read'
  ) then
    create policy chat_images_public_read
      on storage.objects
      for select
      to public
      using (bucket_id = 'chat-images');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'chat_images_auth_insert'
  ) then
    create policy chat_images_auth_insert
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'chat-images');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'chat_images_auth_delete'
  ) then
    create policy chat_images_auth_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'chat-images');
  end if;
end $$;

commit;
