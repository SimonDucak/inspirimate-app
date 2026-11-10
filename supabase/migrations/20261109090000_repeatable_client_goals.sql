create table public.client_habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null
    check (category in ('nutrition', 'training', 'custom')),
  title text not null
    check (char_length(btrim(title)) between 1 and 120),
  repeat_mode text not null
    check (repeat_mode in ('fixed', 'daily')),
  scheduled_for date,
  is_active boolean not null default true,
  ended_on date,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  check (
    (repeat_mode = 'fixed' and scheduled_for is null)
    or (repeat_mode = 'daily' and scheduled_for is not null)
  )
);

create index client_habits_user_active_idx
  on public.client_habits (user_id, is_active, category);

create table public.client_habit_checkins (
  habit_id uuid not null,
  user_id uuid not null,
  checkin_date date not null,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (habit_id, checkin_date),
  foreign key (habit_id, user_id)
    references public.client_habits (id, user_id) on delete cascade
);

create index client_habit_checkins_user_date_idx
  on public.client_habit_checkins (user_id, checkin_date desc);

alter table public.client_habits enable row level security;
alter table public.client_habit_checkins enable row level security;

create policy "Users can manage their own habits"
  on public.client_habits for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can manage their own habit checkins"
  on public.client_habit_checkins for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Preserve existing per-day nutrition and training goals as one-off tasks.
with legacy_goals as (
  select user_id, 'nutrition'::text as category, btrim(nutrition_goal) as title,
         checkin_date as scheduled_for
  from public.client_daily_checkins
  where btrim(nutrition_goal) <> ''
  union all
  select user_id, 'training'::text, btrim(training_goal), checkin_date
  from public.client_daily_checkins
  where btrim(training_goal) <> ''
)
insert into public.client_habits (user_id, category, title, repeat_mode, scheduled_for)
select distinct user_id, category, title, 'daily', scheduled_for
from legacy_goals;

with legacy_goals as (
  select user_id, 'nutrition'::text as category, btrim(nutrition_goal) as title,
         checkin_date as scheduled_for, nutrition_completed as completed
  from public.client_daily_checkins
  where btrim(nutrition_goal) <> ''
  union all
  select user_id, 'training'::text, btrim(training_goal), checkin_date,
         training_completed
  from public.client_daily_checkins
  where btrim(training_goal) <> ''
)
insert into public.client_habit_checkins
  (habit_id, user_id, checkin_date, completed)
select h.id, h.user_id, g.scheduled_for, bool_or(g.completed)
from legacy_goals g
join public.client_habits h
  on h.user_id = g.user_id
  and h.category = g.category
  and h.title = g.title
  and h.repeat_mode = 'daily'
  and h.scheduled_for = g.scheduled_for
