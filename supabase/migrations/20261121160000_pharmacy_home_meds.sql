-- Sprint 2.0 B+ (Task 4): «Uy dorixonasi» — the user's home medicine cabinet.
-- One row per medicine pack at home: from the catalog (medicine_id) or typed
-- by hand (medicine_id null, name only). The app warns 30 days before
-- expiry_date and offers to re-order (/pharmacy?q=<name>).

create table public.home_meds (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  medicine_id  uuid references public.medicines (id) on delete set null,
  name         text not null check (length(trim(name)) between 1 and 120),
  expiry_date  date,
  quantity     int not null default 1 check (quantity between 0 and 999),
  notes        text check (notes is null or length(notes) <= 500),
  created_at   timestamptz not null default now()
);
create index home_meds_user_expiry_idx on public.home_meds (user_id, expiry_date);

alter table public.home_meds enable row level security;

create policy home_meds_own on public.home_meds
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.home_meds to authenticated;
grant all on public.home_meds to service_role;
