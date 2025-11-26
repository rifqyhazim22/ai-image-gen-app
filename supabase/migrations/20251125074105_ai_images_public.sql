create table if not exists public.ai_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  kind text not null check (kind in ('original','generated')),
  scene text,
  storage_path text not null,
  prompt text,
  created_at timestamptz default now()
);

alter table public.ai_images enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_images' and policyname='ai_images select own'
  ) then
    create policy "ai_images select own"
      on public.ai_images
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_images' and policyname='ai_images insert own'
  ) then
    create policy "ai_images insert own"
      on public.ai_images
      for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='ai_images' and policyname='ai_images delete own'
  ) then
    create policy "ai_images delete own"
      on public.ai_images
      for delete
      to authenticated
      using (auth.uid() = user_id);
  end if;
end$$;
