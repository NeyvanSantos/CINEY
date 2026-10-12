begin;

-- Mensagens de notificação escritas pelo administrador no Supabase Dashboard.
-- Clientes autenticados apenas leem as mensagens ativas.
create table public.app_notifications (
  id bigint generated always as identity primary key,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.app_notifications enable row level security;

revoke all on public.app_notifications from public, anon, authenticated;
grant select on public.app_notifications to authenticated;

create policy app_notifications_read_active on public.app_notifications
  for select to authenticated
  using (is_active);

commit;
