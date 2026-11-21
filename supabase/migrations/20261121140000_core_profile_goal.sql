-- Sprint 2.0 (S2-5): the user's main goal, asked right after sign-in.
-- Home lifts the cards that help with it. NULL — not chosen yet.
-- Codes: lib/core/data/health_goal.dart. profiles already has RLS
-- (own row) and grants for authenticated — a new column is covered.

alter table public.profiles
  add column goal text
  check (goal in ('lose_weight', 'energy', 'pressure_sugar', 'family'));
