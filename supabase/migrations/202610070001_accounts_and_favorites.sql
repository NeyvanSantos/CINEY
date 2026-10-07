begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 60),
  created_at timestamptz not null default now()
);

create table public.favorites (
  -- Realtime DELETE events expose replica identity; keep it an opaque ID.
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null check (char_length(content_id) between 1 and 500),
  plugin_id text not null check (char_length(plugin_id) between 1 and 200),
  content_type text not null check (content_type in ('movie', 'series', 'anime', 'dorama')),
  title text not null check (char_length(title) between 1 and 500),
  poster_url text not null default '' check (char_length(poster_url) <= 2048),
  created_at timestamptz not null default now(),
  unique (user_id, content_id, plugin_id, content_type)
);

alter table public.favorites replica identity default;

create index favorites_user_created_at_idx on public.favorites(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.favorites enable row level security;

revoke all on public.profiles, public.favorites from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant select, delete on public.favorites to authenticated;
grant insert (user_id, content_id, plugin_id, content_type, title, poster_url)
  on public.favorites to authenticated;
grant update (user_id, content_id, plugin_id, content_type, title, poster_url)
  on public.favorites to authenticated;

create policy profiles_read_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy favorites_read_own on public.favorites for select to authenticated
  using ((select auth.uid()) = user_id);
create policy favorites_insert_own on public.favorites for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy favorites_update_own on public.favorites for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy favorites_delete_own on public.favorites for delete to authenticated
  using ((select auth.uid()) = user_id);

create function public.create_account_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  account_name text := btrim(new.raw_user_meta_data ->> 'display_name');
begin
  if account_name is null or char_length(account_name) < 2 then
    account_name := 'Usuário CiNey';
  end if;
  insert into public.profiles(id, display_name)
    values (new.id, left(account_name, 60));
  return new;
end;
$$;

revoke all on function public.create_account_profile() from public, anon, authenticated;
create trigger on_ciney_account_created after insert on auth.users
  for each row execute function public.create_account_profile();

-- Also provision profiles for accounts created before this migration.
insert into public.profiles(id, display_name)
select id, case
  when char_length(btrim(raw_user_meta_data ->> 'display_name')) >= 2
    then left(btrim(raw_user_meta_data ->> 'display_name'), 60)
  else 'Usuário CiNey' end
from auth.users
on conflict (id) do nothing;

-- No caller-supplied ID: a session can only delete its own account.
create function public.delete_own_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  delete from auth.users where id = caller_id;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- The mobile and TV apps subscribe to changes for the signed-in user.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'favorites'
  ) then
    alter publication supabase_realtime add table public.favorites;
  end if;
end;
$$;

commit;
