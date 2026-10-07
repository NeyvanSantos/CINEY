begin;

create table public.tv_pairing_requests (
  id uuid primary key,
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'consumed')),
  user_id uuid references auth.users(id) on delete cascade,
  auth_email text,
  auth_token_hash text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at),
  check (
    (status = 'pending' and user_id is null and auth_token_hash is null)
    or (status in ('approved', 'consumed') and user_id is not null)
  )
);

create index tv_pairing_requests_expiration_idx
  on public.tv_pairing_requests(expires_at);

alter table public.tv_pairing_requests enable row level security;
revoke all on public.tv_pairing_requests from public, anon, authenticated;
grant all on public.tv_pairing_requests to service_role;

commit;