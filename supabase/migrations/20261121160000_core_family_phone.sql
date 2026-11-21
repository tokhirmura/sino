-- «Oila» (family care): a phone per family member for «Qoʻngʻiroq qilish»
-- when a dose is missed. Optional. family_members already has RLS (own
-- rows) and grants for authenticated — a new column is covered.

alter table public.family_members
  add column phone text
  check (phone is null or char_length(phone) between 5 and 32);
