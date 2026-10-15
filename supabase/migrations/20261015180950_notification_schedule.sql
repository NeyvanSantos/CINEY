begin;
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- The credential is inserted separately into Vault, never in versioned SQL.
select cron.schedule('ciney-notification-scan', '*/15 * * * *', $job$
  select net.http_post(
    url := 'https://fekultszwaxbzejdfluq.supabase.co/functions/v1/notification-worker',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-ciney-job-key', decrypted_secret),
    body := '{"action":"tick"}'::jsonb,
    timeout_milliseconds := 120000
  ) from vault.decrypted_secrets where name = 'ciney_notification_job_key';
$job$);
select cron.schedule('ciney-notification-delivery', '* * * * *', $job$
  select net.http_post(
    url := 'https://fekultszwaxbzejdfluq.supabase.co/functions/v1/notification-worker',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-ciney-job-key', decrypted_secret),
    body := '{"action":"dispatch"}'::jsonb,
    timeout_milliseconds := 120000
  ) from vault.decrypted_secrets where name = 'ciney_notification_job_key';
$job$);
select cron.schedule('ciney-notification-cleanup', '15 6 * * *', $job$
  delete from public.notification_jobs where created_at < now() - interval '7 days';
  delete from public.notification_catalog where first_seen_at < now() - interval '120 days';
  delete from public.notification_devices where updated_at < now() - interval '90 days';
$job$);
commit;
