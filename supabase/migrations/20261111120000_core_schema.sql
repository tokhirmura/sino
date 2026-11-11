-- =====================================================================
-- Sino — core schema (barcha modullar uchun bitta boshlang'ich migratsiya)
-- Bu faylni TAHRIRLAMANG. O'zgarishlar faqat yangi migratsiya orqali:
--   supabase/migrations/<timestamp>_<core|pharmacy|wellness>_<nima>.sql
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- CORE (modul A)
-- ---------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  birth_year  int check (birth_year between 1900 and 2100),
  height_cm   numeric(5, 1) check (height_cm > 0),
  weight_kg   numeric(5, 1) check (weight_kg > 0),
  blood_type  text,
  allergies   text[] not null default '{}',
  lang        text not null default 'uz' check (lang in ('uz', 'ru', 'en')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Ro'yxatdan o'tganda profiles qatorini avtomatik yaratish
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, lang)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'lang', 'uz')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.family_members (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  relation    text not null,
  birth_year  int check (birth_year between 1900 and 2100),
  blood_type  text,
  allergies   text[] not null default '{}',
  created_at  timestamptz not null default now()
);
create index family_members_user_id_idx on public.family_members (user_id);

create table public.medical_records (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  member_id    uuid references public.family_members (id) on delete cascade,
  date         date not null,
  kind         text not null,
  title        text not null,
  institution  text,
  source       text not null check (source in ('davlat', 'xususiy')),
  notes        text,
  created_at   timestamptz not null default now()
);
create index medical_records_user_date_idx on public.medical_records (user_id, date desc);
create index medical_records_member_id_idx on public.medical_records (member_id);

create table public.lab_results (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  value      numeric not null,
  unit       text,
  ref_low    numeric,
  ref_high   numeric,
  taken_at   timestamptz not null default now()
);
create index lab_results_user_taken_idx on public.lab_results (user_id, taken_at desc);

-- ---------------------------------------------------------------------
-- MODUL B: dorixona, eslatmalar, shifokorlar
-- ---------------------------------------------------------------------

create table public.medicines (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  ingredient   text,
  form         text,
  category     text,
  rx           boolean not null default false,
  price_uzs    int check (price_uzs >= 0),
  barcode      text,
  description  jsonb not null default '{}'::jsonb,  -- {uz, ru, en}
  warning      jsonb not null default '{}'::jsonb,  -- {uz, ru, en}
  analogs      text[] not null default '{}'
);
create index medicines_name_idx on public.medicines (lower(name));
create index medicines_ingredient_idx on public.medicines (lower(ingredient));
create unique index medicines_barcode_idx on public.medicines (barcode) where barcode is not null;
create index medicines_category_idx on public.medicines (category);

create table public.pharmacies (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  address   text,
  lat       double precision not null,
  lng       double precision not null,
  hours     text,
  open24    boolean not null default false,
  rating    numeric(2, 1) check (rating between 0 and 5)
);
create index pharmacies_lat_lng_idx on public.pharmacies (lat, lng);

create table public.pharmacy_stock (
  id           uuid primary key default gen_random_uuid(),
  pharmacy_id  uuid not null references public.pharmacies (id) on delete cascade,
  medicine_id  uuid not null references public.medicines (id) on delete cascade,
  price_uzs    int not null check (price_uzs >= 0),
  qty          int not null default 0 check (qty >= 0),
  unique (pharmacy_id, medicine_id)
);
create index pharmacy_stock_medicine_id_idx on public.pharmacy_stock (medicine_id);

create table public.reservations (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  medicine_id    uuid not null references public.medicines (id) on delete restrict,
  pharmacy_id    uuid not null references public.pharmacies (id) on delete restrict,
  for_member_id  uuid references public.family_members (id) on delete set null,
  status         text not null default 'pending'
                 check (status in ('pending', 'ready', 'picked', 'cancelled')),
  rx_attached    boolean not null default false,
  created_at     timestamptz not null default now()
);
create index reservations_user_created_idx on public.reservations (user_id, created_at desc);
create index reservations_medicine_id_idx on public.reservations (medicine_id);
create index reservations_pharmacy_id_idx on public.reservations (pharmacy_id);

create table public.reminders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  member_id   uuid references public.family_members (id) on delete cascade,
  name        text not null,
  dose        text,
  time        time not null,
  days        int[] not null default '{1,2,3,4,5,6,7}',  -- 1 = dushanba ... 7 = yakshanba
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index reminders_user_id_idx on public.reminders (user_id);

create table public.reminder_logs (
  id           uuid primary key default gen_random_uuid(),
  reminder_id  uuid not null references public.reminders (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  taken_at     timestamptz not null default now()
);
create index reminder_logs_user_taken_idx on public.reminder_logs (user_id, taken_at desc);
create index reminder_logs_reminder_id_idx on public.reminder_logs (reminder_id);

create table public.doctors (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  specialty  text not null,
  years      int check (years >= 0),
  rating     numeric(2, 1) check (rating between 0 and 5),
  price_uzs  int check (price_uzs >= 0),
  clinic     text,
  online     boolean not null default false
);
create index doctors_specialty_idx on public.doctors (specialty);

create table public.appointments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  doctor_id   uuid not null references public.doctors (id) on delete restrict,
  member_id   uuid references public.family_members (id) on delete cascade,
  starts_at   timestamptz not null,
  online      boolean not null default false,
  status      text not null default 'booked'
              check (status in ('booked', 'done', 'cancelled')),
  created_at  timestamptz not null default now()
);
create index appointments_user_starts_idx on public.appointments (user_id, starts_at);
create index appointments_doctor_starts_idx on public.appointments (doctor_id, starts_at);

-- ---------------------------------------------------------------------
-- MODUL C: ovqatlanish, sport, ko'rsatkichlar
-- ---------------------------------------------------------------------

create table public.foods (
  id       uuid primary key default gen_random_uuid(),
  name     jsonb not null,  -- {uz, ru, en}
  emoji    text,
  portion  text,
  kcal     numeric not null check (kcal >= 0),
  protein  numeric not null default 0,
  fat      numeric not null default 0,
  carbs    numeric not null default 0
);

create table public.exercises (
  id       uuid primary key default gen_random_uuid(),
  type     text not null,
  muscle   text,
  name     jsonb not null,                  -- {uz, ru, en}
  hint     jsonb not null default '{}'::jsonb,
  reps     int,
  seconds  int
);
create index exercises_type_idx on public.exercises (type);

create table public.food_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  date        date not null default current_date,
  meal        text not null check (meal in ('breakfast', 'lunch', 'dinner', 'snack')),
  food_id     uuid not null references public.foods (id) on delete restrict,
  servings    numeric not null default 1 check (servings > 0),
  created_at  timestamptz not null default now()
);
create index food_logs_user_date_idx on public.food_logs (user_id, date);
create index food_logs_food_id_idx on public.food_logs (food_id);

create table public.water_logs (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references auth.users (id) on delete cascade,
  date     date not null default current_date,
  glasses  int not null default 0 check (glasses >= 0),
  unique (user_id, date)
);

create table public.workout_plans (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  params      jsonb not null default '{}'::jsonb,
  plan        jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now()
);
create index workout_plans_user_created_idx on public.workout_plans (user_id, created_at desc);

create table public.workout_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  plan_day     int,
  kcal         numeric not null default 0,
  finished_at  timestamptz not null default now()
);
create index workout_sessions_user_finished_idx on public.workout_sessions (user_id, finished_at desc);

create table public.vitals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         text not null,     -- 'pressure', 'pulse', 'glucose', 'weight', 'temp', ...
  value        numeric not null,
  value2       numeric,           -- masalan, diastolik bosim
  measured_at  timestamptz not null default now()
);
create index vitals_user_kind_measured_idx on public.vitals (user_id, kind, measured_at desc);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------

-- Kataloglar: anon va authenticated uchun faqat SELECT
do $$
declare t text;
begin
  foreach t in array array[
    'medicines', 'pharmacies', 'pharmacy_stock', 'doctors', 'foods', 'exercises'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for select to anon, authenticated using (true)',
      t || '_select_all', t
    );
  end loop;
end $$;

-- Profil: faqat o'zi
alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_delete_own on public.profiles
  for delete to authenticated using (id = (select auth.uid()));

-- Foydalanuvchi jadvallari: barcha amallar faqat user_id = auth.uid()
do $$
declare t text;
begin
  foreach t in array array[
    'family_members', 'medical_records', 'lab_results',
    'reservations', 'reminders', 'reminder_logs', 'appointments',
    'food_logs', 'water_logs', 'workout_plans', 'workout_sessions', 'vitals'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',
      t || '_own', t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Realtime: bron holati o'zgarishini jonli kuzatish
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.reservations;
