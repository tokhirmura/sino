-- Sprint 2.0 (S2-3): user badges. One row per earned badge; the app
-- (home feature) inserts with ON CONFLICT DO NOTHING, the profile reads.
-- Codes: first_workout, water_7, meds_3, first_reservation, steps_10k,
-- index_90, streak_7, full_day (lib/core/data/achievements.dart).

create table public.achievements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  code         text not null check (code ~ '^[a-z0-9_]{1,40}$'),
  unlocked_at  timestamptz not null default now(),
  unique (user_id, code)
);

alter table public.achievements enable row level security;

create policy achievements_own on public.achievements
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.achievements to authenticated;
grant all on public.achievements to service_role;
