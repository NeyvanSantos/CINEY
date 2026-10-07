-- Run in a disposable database with the migration applied. Everything rolls back.
begin;

-- Deletes in Postgres Changes cannot rely on row policies for old values.
-- Only an opaque UUID may be exposed as replica identity, never a title/user ID.
do $$
declare replica_columns text[];
begin
  select array_agg(a.attname::text order by a.attnum) into replica_columns
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    where c.conrelid = 'public.favorites'::regclass and c.contype = 'p';
  if replica_columns <> array['id']::text[]
    or (select relreplident from pg_class where oid = 'public.favorites'::regclass) <> 'd' then
    raise exception 'Realtime delete identity must only contain an opaque ID';
  end if;
end $$;

insert into auth.users(id, raw_user_meta_data) values
  ('10000000-0000-0000-0000-000000000001', '{"display_name":"Conta A"}'),
  ('10000000-0000-0000-0000-000000000002', '{"display_name":"Conta B"}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
begin
  if has_table_privilege('anon', 'public.tv_pairing_requests', 'select')
    or has_table_privilege('authenticated', 'public.tv_pairing_requests', 'select') then
    raise exception 'Pairing requests must not be readable by app clients';
  end if;
  if not has_table_privilege('service_role', 'public.tv_pairing_requests', 'select') then
    raise exception 'Only the pairing service role may read pairing requests';
  end if;
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'A must only see its own profile';
  end if;
  if (select display_name from public.profiles) <> 'Conta A' then
    raise exception 'Signup trigger must populate the name';
  end if;
end $$;

update public.profiles set display_name = 'Conta A editada'
where id = '10000000-0000-0000-0000-000000000001';
update public.profiles set display_name = 'Ataque'
where id = '10000000-0000-0000-0000-000000000002';

insert into public.favorites(user_id, content_id, plugin_id, content_type, title, poster_url)
values ('10000000-0000-0000-0000-000000000001', '42', 'source-a', 'movie', 'Filme A', '');
insert into public.favorites(user_id, content_id, plugin_id, content_type, title, poster_url)
values ('10000000-0000-0000-0000-000000000001', '42', 'source-a', 'movie', 'Filme atualizado', '')
on conflict(user_id, content_id, plugin_id, content_type) do update
  set user_id = excluded.user_id, content_id = excluded.content_id,
      plugin_id = excluded.plugin_id, content_type = excluded.content_type,
      title = excluded.title, poster_url = excluded.poster_url;

do $$
begin
  if (select count(*) from public.favorites) <> 1 then
    raise exception 'Upserts must be idempotent';
  end if;
  if (select title from public.favorites) <> 'Filme atualizado' then
    raise exception 'Upsert must update metadata';
  end if;
  begin
    insert into public.favorites(user_id, content_id, plugin_id, content_type, title)
      values ('10000000-0000-0000-0000-000000000002', 'forged', 'source-a', 'movie', 'Ataque');
    raise exception 'Foreign inserts must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.favorites set user_id = '10000000-0000-0000-0000-000000000002';
    raise exception 'Ownership changes must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set id = '10000000-0000-0000-0000-000000000002';
    raise exception 'Profile IDs must be immutable';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set display_name = ' ';
    raise exception 'Blank names must be rejected';
  exception when check_violation then null;
  end;
end $$;

-- Identical content IDs in other providers/types must not collide.
insert into public.favorites(user_id, content_id, plugin_id, content_type, title) values
  ('10000000-0000-0000-0000-000000000001', '42', 'source-b', 'movie', 'Outro provedor'),
  ('10000000-0000-0000-0000-000000000001', '42', 'source-a', 'series', 'Série');

select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.favorites) <> 0 then
    raise exception 'B must not read A favorites';
  end if;
  if (select display_name from public.profiles) <> 'Conta B' then
    raise exception 'A must not update B profile';
  end if;
end $$;
delete from public.favorites where user_id = '10000000-0000-0000-0000-000000000001';
update public.favorites set title = 'Ataque' where user_id = '10000000-0000-0000-0000-000000000001';
insert into public.favorites(user_id, content_id, plugin_id, content_type, title)
values ('10000000-0000-0000-0000-000000000002', '42', 'source-a', 'movie', 'Filme B');

set local role anon;
select set_config('request.jwt.claims', '{}', true);
do $$
begin
  begin
    perform 1 from public.profiles;
    raise exception 'Anonymous profile access must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.favorites;
    raise exception 'Anonymous favorites access must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.delete_own_account();
    raise exception 'Anonymous account deletion must be rejected';
  exception when insufficient_privilege then null;
  end;
end $$;

set local role authenticated;
do $$
begin
  begin
    perform public.delete_own_account();
    raise exception 'Account deletion without a user ID must fail';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.favorites) <> 3 then
    raise exception 'B must not delete A favorites; sources/types must remain separate';
  end if;
  if exists(select 1 from public.favorites where title = 'Ataque') then
    raise exception 'B must not update A favorites';
  end if;
end $$;
delete from public.favorites where plugin_id = 'source-b';
do $$
begin
  if (select count(*) from public.favorites) <> 2 then
    raise exception 'A must be able to remove a favorite';
  end if;
end $$;
select public.delete_own_account();

reset role;
do $$
begin
  if exists(select 1 from auth.users where id = '10000000-0000-0000-0000-000000000001')
    or exists(select 1 from public.profiles where id = '10000000-0000-0000-0000-000000000001')
    or exists(select 1 from public.favorites where user_id = '10000000-0000-0000-0000-000000000001') then
    raise exception 'Deleting A must cascade its profile and favorites';
  end if;
  if not exists(select 1 from auth.users where id = '10000000-0000-0000-0000-000000000002')
    or not exists(select 1 from public.profiles where id = '10000000-0000-0000-0000-000000000002')
    or not exists(select 1 from public.favorites where user_id = '10000000-0000-0000-0000-000000000002') then
    raise exception 'Deleting A must preserve B and its data';
  end if;
end $$;

rollback;
select 'PASS: signup, profile edits, RLS isolation, idempotent favorites and account deletion' as result;
