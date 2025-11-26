-- AI Image Gen setup on Supabase (shares project with Mirror, isolated via names/policies).

-- 1) Metadata table in public schema (simpler API access than custom schema).
create table if not exists public.ai_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  kind text not null check (kind in ('original', 'generated')),
  scene text,
  storage_path text not null,
  prompt text,
  created_at timestamptz default now()
);

alter table public.ai_images enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ai_images' and policyname = 'ai_images select own'
  ) then
    create policy "ai_images select own"
    on public.ai_images
    for select
    to authenticated
    using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ai_images' and policyname = 'ai_images insert own'
  ) then
    create policy "ai_images insert own"
    on public.ai_images
    for insert
    to authenticated
    with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ai_images' and policyname = 'ai_images delete own'
  ) then
    create policy "ai_images delete own"
    on public.ai_images
    for delete
    to authenticated
    using (auth.uid() = user_id);
  end if;
end
$$;

-- 2) Private bucket for images.
insert into storage.buckets (id, name, public)
values ('ai-photo-remix', 'ai-photo-remix', false)
on conflict (id) do nothing;

-- 3) Storage policies for the bucket.
do $$
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

  -- Allow reads based on path prefix (user id) for cases when uploads use service role.
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'ai-photo-remix prefix select'
  ) then
    create policy "ai-photo-remix prefix select"
    on storage.objects
    for select
    to authenticated
    using (
      bucket_id = 'ai-photo-remix'
      and name like (auth.uid()::text || '/%')
    );
  end if;
end
$$;
