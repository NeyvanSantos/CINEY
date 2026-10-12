begin;

-- Apenas a conta do administrador pode publicar/desativar avisos.
-- O e-mail vem de auth.jwt() (auth.users), não de user_metadata editável.
create policy app_notifications_admin_insert on public.app_notifications
  for insert to authenticated
  with check ((select auth.jwt() ->> 'email') = 'neyvanivan@gmail.com');

create policy app_notifications_admin_update on public.app_notifications
  for update to authenticated
  using ((select auth.jwt() ->> 'email') = 'neyvanivan@gmail.com')
  with check ((select auth.jwt() ->> 'email') = 'neyvanivan@gmail.com');

commit;
