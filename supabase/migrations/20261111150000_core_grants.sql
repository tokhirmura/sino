-- =====================================================================
-- Sino — Data API uchun jadval huquqlari (GRANT)
-- RLS faqat qatorlarni filtrlaydi; anon/authenticated rollariga jadval
-- darajasidagi huquqlar ham kerak. core_schema CLI login roli orqali
-- qo'llangani uchun default privileges ishlamadi — shu yerda aniq beramiz.
-- =====================================================================

grant usage on schema public to anon, authenticated, service_role;

-- Kataloglar: faqat o'qish (RLS: select using (true))
grant select on
  public.medicines,
  public.pharmacies,
  public.pharmacy_stock,
  public.doctors,
  public.foods,
  public.exercises
to anon, authenticated;

-- Foydalanuvchi jadvallari: faqat authenticated (RLS: user_id = auth.uid())
grant select, insert, update, delete on
  public.profiles,
  public.family_members,
  public.medical_records,
  public.lab_results,
  public.reservations,
  public.reminders,
  public.reminder_logs,
  public.appointments,
  public.food_logs,
  public.water_logs,
  public.workout_plans,
  public.workout_sessions,
  public.vitals
to authenticated;

-- service_role (faqat server/skriptlar uchun, ilovada EMAS)
grant all on all tables in schema public to service_role;

-- Trigger funksiyasini Data API orqali chaqirib bo'lmasin
revoke execute on function public.handle_new_user() from public, anon, authenticated;
