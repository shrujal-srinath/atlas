-- P1-1 (SECURITY_AUDIT_2026-07-02.md finding 1b / FUTURE_PLANS.md P1-1):
-- food_catalog is a SHARED table every user's search reads from. The
-- policies added in 20260622_food_barcode.sql let any authenticated user
-- INSERT/UPDATE any 'off' row directly — including one another user has
-- already cached — with whatever macro/micro values the client sends. A
-- malicious (or just buggy) client can silently poison nutrition data every
-- other user sees in search results. There is no ownership column to
-- narrow the policy to "rows you created", so the fix is to remove client
-- write access to the table entirely and replace it with a SECURITY
-- DEFINER RPC that:
--   * derives `id`/`source`/`barcode` itself from a validated barcode —
--     never trusts a client-supplied id, so a curated 'ifct:'/'usda:' row
--     can never be targeted by this path;
--   * clamps every numeric field to a physically-sane range;
--   * recomputes `search_text` from the (length-capped) name/brand instead
--     of trusting the client's string, closing a search-stuffing vector too.

drop policy if exists "auth caches branded foods" on public.food_catalog;
drop policy if exists "auth refreshes branded foods" on public.food_catalog;

-- Small helper: a numeric field from the payload, coalesced to 0 and
-- clamped to [0, hi]. Declared separately because plpgsql has no local
-- function syntax.
create or replace function public._clamp_food_field(payload jsonb, key text, hi numeric)
returns numeric
language sql
immutable
as $$
  select greatest(least(coalesce((payload->>key)::numeric, 0), hi), 0)
$$;

revoke all on function public._clamp_food_field(jsonb, text, numeric) from public;

create or replace function public.cache_branded_food(payload jsonb)
returns public.food_catalog
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_barcode text := trim(coalesce(payload->>'barcode', ''));
  v_id text;
  v_name text := trim(coalesce(payload->>'name', ''));
  v_brand text := nullif(trim(coalesce(payload->>'brand', '')), '');
  v_serving_qty numeric := greatest(least(coalesce((payload->>'serving_qty')::numeric, 100), 10000), 1);
  v_serving_unit text := coalesce(nullif(trim(coalesce(payload->>'serving_unit', '')), ''), 'g');
  v_measures jsonb := coalesce(payload->'measures', '[]'::jsonb);
  v_row public.food_catalog;
begin
  if v_barcode = '' or v_barcode !~ '^[0-9]{6,20}$' then
    raise exception 'cache_branded_food: invalid barcode';
  end if;
  if v_name = '' then
    raise exception 'cache_branded_food: name required';
  end if;
  v_name := left(v_name, 200);
  if v_brand is not null then
    v_brand := left(v_brand, 200);
  end if;
  v_id := 'off:' || v_barcode;

  insert into public.food_catalog (
    id, source, barcode, name, brand, serving_qty, serving_unit,
    kcal, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sat_fat_g, trans_fat_g,
    cholesterol_mg, sodium_mg, potassium_mg, calcium_mg, iron_mg, magnesium_mg, zinc_mg,
    vit_a_ug, vit_c_mg, vit_d_ug, vit_e_mg, vit_k_ug, b6_mg, b12_ug, folate_ug,
    measures, region, popularity, search_text
  ) values (
    v_id, 'off', v_barcode, v_name, v_brand, v_serving_qty, v_serving_unit,
    public._clamp_food_field(payload, 'kcal', 950),
    public._clamp_food_field(payload, 'protein_g', 100),
    public._clamp_food_field(payload, 'carbs_g', 100),
    public._clamp_food_field(payload, 'fat_g', 100),
    public._clamp_food_field(payload, 'fiber_g', 100),
    public._clamp_food_field(payload, 'sugar_g', 100),
    public._clamp_food_field(payload, 'sat_fat_g', 100),
    public._clamp_food_field(payload, 'trans_fat_g', 100),
    public._clamp_food_field(payload, 'cholesterol_mg', 5000),
    public._clamp_food_field(payload, 'sodium_mg', 50000),
    public._clamp_food_field(payload, 'potassium_mg', 50000),
    public._clamp_food_field(payload, 'calcium_mg', 20000),
    public._clamp_food_field(payload, 'iron_mg', 500),
    public._clamp_food_field(payload, 'magnesium_mg', 5000),
    public._clamp_food_field(payload, 'zinc_mg', 500),
    public._clamp_food_field(payload, 'vit_a_ug', 50000),
    public._clamp_food_field(payload, 'vit_c_mg', 5000),
    public._clamp_food_field(payload, 'vit_d_ug', 1000),
    public._clamp_food_field(payload, 'vit_e_mg', 2000),
    public._clamp_food_field(payload, 'vit_k_ug', 5000),
    public._clamp_food_field(payload, 'b6_mg', 500),
    public._clamp_food_field(payload, 'b12_ug', 5000),
    public._clamp_food_field(payload, 'folate_ug', 5000),
    v_measures, 'IN', 4,
    lower(trim(v_name || ' ' || coalesce(v_brand, '')))
  )
  on conflict (id) do update set
    name = excluded.name,
    brand = excluded.brand,
    serving_qty = excluded.serving_qty,
    serving_unit = excluded.serving_unit,
    kcal = excluded.kcal, protein_g = excluded.protein_g, carbs_g = excluded.carbs_g, fat_g = excluded.fat_g,
    fiber_g = excluded.fiber_g, sugar_g = excluded.sugar_g, sat_fat_g = excluded.sat_fat_g, trans_fat_g = excluded.trans_fat_g,
    cholesterol_mg = excluded.cholesterol_mg, sodium_mg = excluded.sodium_mg, potassium_mg = excluded.potassium_mg,
    calcium_mg = excluded.calcium_mg, iron_mg = excluded.iron_mg, magnesium_mg = excluded.magnesium_mg, zinc_mg = excluded.zinc_mg,
    vit_a_ug = excluded.vit_a_ug, vit_c_mg = excluded.vit_c_mg, vit_d_ug = excluded.vit_d_ug, vit_e_mg = excluded.vit_e_mg, vit_k_ug = excluded.vit_k_ug,
    b6_mg = excluded.b6_mg, b12_ug = excluded.b12_ug, folate_ug = excluded.folate_ug,
    measures = excluded.measures,
    search_text = excluded.search_text
  where public.food_catalog.source = 'off'
  returning * into v_row;

  if v_row.id is null then
    select * into v_row from public.food_catalog where id = v_id;
  end if;
  return v_row;
end;
$$;

revoke all on function public.cache_branded_food(jsonb) from public;
grant execute on function public.cache_branded_food(jsonb) to authenticated;
