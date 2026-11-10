alter table public.client_daily_checkins
  add column sleep_quality smallint
  check (sleep_quality >= 1 and sleep_quality <= 10);
