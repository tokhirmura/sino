-- =====================================================================
-- Sino — modul C: mashqlar katalogiga sarflanadigan kaloriya (kkal/daqiqa).
-- Mashg‘ulot rejasi va sessiya kaloriyasi shundan hisoblanadi.
-- Jadval allaqachon RLS + GRANT ostida (core_schema, core_grants) —
-- yangi huquq kerak emas.
-- =====================================================================

alter table public.exercises
  add column if not exists kcal_per_min numeric not null default 5
  check (kcal_per_min > 0);
