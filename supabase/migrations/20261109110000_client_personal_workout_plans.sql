alter table public.workout_plans
  alter column trainer_id drop not null;

alter table public.workout_session_logs
  alter column trainer_id drop not null;

create policy "Clients can view their personal workout plans"
  on public.workout_plans for select to authenticated
  using (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
  );

create policy "Clients can create their personal workout plans"
  on public.workout_plans for insert to authenticated
  with check (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
  );

create policy "Clients can update their personal workout plans"
  on public.workout_plans for update to authenticated
  using (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
  )
  with check (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
  );

create policy "Clients can delete their personal workout plans"
  on public.workout_plans for delete to authenticated
  using (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
  );

create policy "Clients can view their personal workout logs"
  on public.workout_session_logs for select to authenticated
  using (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
    and exists (
      select 1
      from public.workout_plans p
      where p.id = workout_session_logs.plan_id
        and p.trainer_id is null
        and p.client_id = (select auth.uid())
    )
  );

create policy "Clients can record their personal workout sessions"
  on public.workout_session_logs for insert to authenticated
  with check (
    trainer_id is null
    and client_id = (select auth.uid())
    and (select public.current_account_role()) = 'client'
    and exists (
      select 1
      from public.workout_plans p
      where p.id = workout_session_logs.plan_id
        and p.trainer_id is null
        and p.client_id = (select auth.uid())
    )
  );
