alter table public.ai_images add column if not exists group_id uuid default gen_random_uuid();
update public.ai_images set group_id = coalesce(group_id, gen_random_uuid());
create index if not exists ai_images_group_id_idx on public.ai_images(group_id);
