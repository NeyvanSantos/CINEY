begin;
insert into auth.users(id, raw_user_meta_data) values
  ('20000000-0000-0000-0000-000000000001', '{"display_name":"Push A"}'),
  ('20000000-0000-0000-0000-000000000002', '{"display_name":"Push B"}');
insert into public.notification_preferences(user_id) values
  ('20000000-0000-0000-0000-000000000001'), ('20000000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
insert into public.notification_devices(user_id, token) values
  ('20000000-0000-0000-0000-000000000001', 'notification-test-token-owner-a');
update public.notification_preferences set movies = false
  where user_id = '20000000-0000-0000-0000-000000000001';
do $$ begin
  if (select count(*) from public.notification_preferences) <> 1 then raise exception 'Cross-account preference leak'; end if;
  if (select movies from public.notification_preferences) then raise exception 'Own preference update failed'; end if;
  if has_table_privilege('anon', 'public.notification_devices', 'select')
    or has_table_privilege('authenticated', 'public.notification_jobs', 'select')
    or has_table_privilege('authenticated', 'public.notification_automation_state', 'select')
    or has_function_privilege('authenticated', 'public.claim_notification_jobs(integer)', 'execute')
    or has_function_privilege('authenticated', 'public.notification_allow_self_test(uuid)', 'execute') then
    raise exception 'Server-only notifications access exposed';
  end if;
  begin
    insert into public.notification_devices(user_id,token) values
      ('20000000-0000-0000-0000-000000000002', 'notification-test-token-forged');
    raise exception 'Foreign insert accepted';
  exception when insufficient_privilege then null; end;
  begin
    update public.notification_devices set user_id = '20000000-0000-0000-0000-000000000002';
    raise exception 'Token ownership transfer accepted';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.notification_devices) <> 0 then raise exception 'FCM token leaked to another account'; end if;
end $$;
reset role;
set local role service_role;
insert into public.notification_jobs(device_id, dedupe_key, kind, title, body)
  select id, 'test:one', 'digest', 'Teste', 'Teste' from public.notification_devices;
insert into public.notification_jobs(device_id, dedupe_key, kind, title, body)
  select id, 'test:one', 'digest', 'Teste', 'Teste' from public.notification_devices
  on conflict(device_id, dedupe_key) do nothing;
do $$ declare job public.notification_jobs; begin
  if (select count(*) from public.notification_jobs) <> 1 then raise exception 'Event duplicated'; end if;
  select * into job from public.claim_notification_jobs(5);
  if job.attempts <> 1 or job.status <> 'processing' or job.claim_token is null then raise exception 'Invalid queue claim'; end if;
  if (select count(*) from public.claim_notification_jobs(5)) <> 0 then raise exception 'Active lease reclaimed'; end if;
  update public.notification_jobs set lease_until = now() - interval '1 second';
  select * into job from public.claim_notification_jobs(5);
  if job.attempts <> 2 then raise exception 'Expired lease did not retry'; end if;
  update public.notification_jobs set attempts = 5, lease_until = now() - interval '1 second';
  if (select count(*) from public.claim_notification_jobs(5)) <> 0 then raise exception 'Retry budget exceeded'; end if;
  if (select status from public.notification_jobs) <> 'failed' then raise exception 'Exhausted job not failed'; end if;
  if not public.notification_allow_self_test('20000000-0000-0000-0000-000000000001') then raise exception 'Initial self test denied'; end if;
  if public.notification_allow_self_test('20000000-0000-0000-0000-000000000001') then raise exception 'Rate limit bypassed'; end if;
end $$;
rollback;
