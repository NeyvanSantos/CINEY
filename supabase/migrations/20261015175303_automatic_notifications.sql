begin;

create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  movies boolean not null default true,
  series boolean not null default true,
  anime boolean not null default true,
  dorama boolean not null default true,
  episodes boolean not null default true,
  app_updates boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.notification_preferences(user_id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  updated_at timestamptz not null default now()
);
create index notification_devices_user_idx on public.notification_devices(user_id);

-- Server-only checkpoints. The first scan seeds these without broadcasting.
create table public.notification_automation_state (
  key text primary key check (char_length(key) between 1 and 250),
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table public.notification_catalog (
  key text primary key,
  category text not null check (category in ('movie', 'series', 'anime', 'dorama')),
  tmdb_id bigint not null check (tmdb_id > 0),
  title text not null check (char_length(title) between 1 and 500),
  pending boolean not null default false,
  first_seen_at timestamptz not null default now()
);
create index notification_catalog_pending_idx on public.notification_catalog(first_seen_at)
  where pending;

-- One delivery per device and event; retries do not resend successful devices.
create table public.notification_jobs (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.notification_devices(id) on delete cascade,
  dedupe_key text not null check (char_length(dedupe_key) between 1 and 250),
  kind text not null check (kind in ('digest', 'episode', 'app_update')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 1000),
  data jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'retry', 'sent', 'failed', 'cancelled')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  claim_token uuid,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  last_error text,
  created_at timestamptz not null default now(),
  unique(device_id, dedupe_key)
);
create index notification_jobs_due_idx on public.notification_jobs(available_at, created_at)
  where status in ('pending', 'retry', 'processing');

alter table public.notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notification_automation_state enable row level security;
alter table public.notification_catalog enable row level security;
alter table public.notification_jobs enable row level security;

revoke all on public.notification_preferences, public.notification_devices,
  public.notification_automation_state, public.notification_catalog,
  public.notification_jobs from public, anon, authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select, insert, update, delete on public.notification_devices to authenticated;
grant all on public.notification_preferences, public.notification_devices,
  public.notification_automation_state, public.notification_catalog,
  public.notification_jobs to service_role;

create policy notification_preferences_read on public.notification_preferences
  for select to authenticated using ((select auth.uid()) = user_id);
create policy notification_preferences_insert on public.notification_preferences
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy notification_preferences_update on public.notification_preferences
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy notification_devices_read on public.notification_devices
  for select to authenticated using ((select auth.uid()) = user_id);
create policy notification_devices_insert on public.notification_devices
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy notification_devices_update on public.notification_devices
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy notification_devices_delete on public.notification_devices
  for delete to authenticated using ((select auth.uid()) = user_id);

create schema if not exists ciney_notifications_private;
revoke all on schema ciney_notifications_private from public, anon, authenticated;
create function ciney_notifications_private.timestamp_write()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function ciney_notifications_private.timestamp_write() from public, anon, authenticated;
create trigger notification_preferences_timestamp before insert or update
  on public.notification_preferences for each row
  execute function ciney_notifications_private.timestamp_write();
create trigger notification_devices_timestamp before insert or update
  on public.notification_devices for each row
  execute function ciney_notifications_private.timestamp_write();

create function public.claim_notification_jobs(batch_size integer default 30)
returns setof public.notification_jobs
language plpgsql security invoker set search_path = '' as $$
begin
  update public.notification_jobs set status = 'cancelled', last_error = 'expired'
    where status in ('pending', 'retry', 'processing') and expires_at <= now();
  update public.notification_jobs set status = 'failed', last_error = 'attempt_limit'
    where attempts >= 5 and status = 'processing' and lease_until < now();
  return query
    with selected as (
      select id from public.notification_jobs
      where attempts < 5 and expires_at > now() and (
        (status in ('pending', 'retry') and available_at <= now()) or
        (status = 'processing' and lease_until < now())
      )
      order by created_at for update skip locked
      limit least(greatest(batch_size, 1), 50)
    )
    update public.notification_jobs as job
    set status = 'processing', attempts = attempts + 1,
        lease_until = now() + interval '5 minutes', claim_token = gen_random_uuid()
    from selected where job.id = selected.id returning job.*;
end;
$$;
revoke all on function public.claim_notification_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_notification_jobs(integer) to service_role;

create function public.notification_allow_self_test(caller_id uuid)
returns boolean language sql security invoker set search_path = '' as $$
  with accepted as (
    insert into public.notification_automation_state(key, value, updated_at)
    values ('test:' || caller_id::text, '{}'::jsonb, now())
    on conflict(key) do update set updated_at = now()
      where public.notification_automation_state.updated_at < now() - interval '1 minute'
    returning key
  ) select exists(select 1 from accepted);
$$;
revoke all on function public.notification_allow_self_test(uuid) from public, anon, authenticated;
grant execute on function public.notification_allow_self_test(uuid) to service_role;

commit;
