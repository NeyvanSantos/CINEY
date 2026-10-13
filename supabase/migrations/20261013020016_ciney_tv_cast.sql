begin;

-- Private Broadcast topic: ciney-cast:<authenticated user UUID>.
-- Only the same authenticated account may join, receive, or publish commands.
create policy "ciney_tv_cast_receive_own_account"
  on realtime.messages
  for select
  to authenticated
  using (
    extension = 'broadcast'
    and (select realtime.topic()) = 'ciney-cast:' || (select auth.uid())::text
  );

create policy "ciney_tv_cast_send_own_account"
  on realtime.messages
  for insert
  to authenticated
  with check (
    extension = 'broadcast'
    and (select realtime.topic()) = 'ciney-cast:' || (select auth.uid())::text
  );

commit;
