-- Dedicated schema + tables for AI Image Gen app to avoid clashing with Mirror data.

create schema if not exists ai_image_app;

create table if not exists ai_image_app.images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  kind text not null check (kind in ('original', 'generated')),
  scene text,
  storage_path text not null,
  prompt text,
  created_at timestamptz default now()
);

alter table ai_image_app.images enable row level security;

do
$$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'ai_image_app' and tablename = 'images' and policyname = 'Allow owners select'
  ) then
    create policy "Allow owners select"
    on ai_image_app.images
    for select
    to authenticated
    using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'ai_image_app' and tablename = 'images' and policyname = 'Allow owners insert'
  ) then
    create policy "Allow owners insert"
    on ai_image_app.images
    for insert
    to authenticated
    with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'ai_image_app' and tablename = 'images' and policyname = 'Allow owners delete'
  ) then
    create policy "Allow owners delete"
    on ai_image_app.images
    for delete
    to authenticated
    using (auth.uid() = user_id);
  end if;
end
$$;

-- Private bucket dedicated for this app.
insert into storage.buckets (id, name, public)
values ('ai-photo-remix', 'ai-photo-remix', false)
on conflict (id) do nothing;

-- Storage policies scoped to this bucket.
do
$$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'ai-photo-remix owners select'
  ) then
    create policy "ai-photo-remix owners select"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id = 'ai-photo-remix'
      and auth.uid() = owner
    );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'ai-photo-remix owners insert'
  ) then
    create policy "ai-photo-remix owners insert"
    on storage.objects
    for insert
    to authenticated
    with check (
      bucket_id = 'ai-photo-remix'
      and auth.uid() = owner
    );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'ai-photo-remix owners delete'
  ) then
    create policy "ai-photo-remix owners delete"
    on storage.objects
    for delete
    to authenticated
    using (
      bucket_id = 'ai-photo-remix'
      and auth.uid() = owner
    );
  end if;
end
$$;
