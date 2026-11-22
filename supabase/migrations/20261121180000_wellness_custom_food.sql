-- Nutrition: diary rows for food that is not in the `foods` catalog —
-- a homemade recipe, a store product by barcode, a photo estimate or a quick
-- «just calories» entry. Such a row has `food_id = null` and keeps its own
-- nutrients in `custom_food`:
--   {name: {uz, ru, en}, emoji, portion, kcal, protein, fat, carbs,
--    source: photo|recipe|barcode|quick, barcode?}
-- Nutrients are per one portion, like `foods`; `servings` still multiplies.
-- Existing RLS policies and grants of `food_logs` cover the new column.

alter table public.food_logs alter column food_id drop not null;

alter table public.food_logs add column custom_food jsonb;

alter table public.food_logs add constraint food_logs_food_or_custom check (
  food_id is not null
  or (
    jsonb_typeof(custom_food) = 'object'
    and jsonb_typeof(custom_food -> 'kcal') = 'number'
    and (custom_food ->> 'kcal')::numeric >= 0
  )
);
