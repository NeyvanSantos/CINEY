begin;

create table public.diagnostic_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  description text not null default ''
    check (char_length(description) <= 1000),
  app_version text not null
    check (char_length(app_version) between 1 and 100),
  platform text not null
    check (platform in ('android', 'ios', 'windows', 'macos', 'linux', 'fuchsia', 'other')),
  logs jsonb not null
    check (
      jsonb_typeof(logs) = 'array'
      and jsonb_array_length(logs) between 1 and 500
      and pg_column_size(logs) <= 225280
    ),
  created_at timestamptz not null default now()
);

create index diagnostic_reports_created_at_idx
  on public.diagnostic_reports(created_at desc);
create index diagnostic_reports_user_created_at_idx
  on public.diagnostic_reports(user_id, created_at desc);

alter table public.diagnostic_reports enable row level security;
revoke all on public.diagnostic_reports from public, anon, authenticated;
grant select, insert, delete on public.diagnostic_reports to service_role;

comment on table public.diagnostic_reports is
  'User-submitted diagnostic logs. Accessible only to the backend service role and project administrators.';

commit;