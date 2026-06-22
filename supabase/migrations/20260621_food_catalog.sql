-- ════════════════════════════════════════════════════════════════════
-- Food search engine: a shared, fuzzy-searchable catalog of foods with
-- full micronutrients. Online-only reference data, public-read.
--
-- Sources seeded separately (tooling/food_catalog/*):
--   • IFCT 2017  (ICMR–NIN, via @ifct2017 MIT)  — Indian foods, full micros
--   • USDA FDC   (CC0 public domain)            — global whole foods
-- Branded/barcode items keep coming live from Open Food Facts.
--
-- Search = pg_trgm trigram similarity (typo tolerant: "panner" → paneer)
-- + substring + exact/prefix boosts + popularity, via search_foods().
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pg_trgm;

create table if not exists public.food_catalog (
  id              text primary key,                 -- 'ifct:A015', 'usda:173706'
  source          text not null,                    -- 'ifct' | 'usda' | 'curated'
  name            text not null,
  brand           text,
  serving_qty     numeric not null default 100,
  serving_unit    text    not null default 'g',
  -- macros
  kcal            numeric default 0,
  protein_g       numeric default 0,
  carbs_g         numeric default 0,
  fat_g           numeric default 0,
  fiber_g         numeric default 0,
  sugar_g         numeric default 0,
  sat_fat_g       numeric default 0,
  trans_fat_g     numeric default 0,
  -- minerals
  cholesterol_mg  numeric default 0,
  sodium_mg       numeric default 0,
  potassium_mg    numeric default 0,
  calcium_mg      numeric default 0,
  iron_mg         numeric default 0,
  magnesium_mg    numeric default 0,
  zinc_mg         numeric default 0,
  -- vitamins
  vit_a_ug        numeric default 0,
  vit_c_mg        numeric default 0,
  vit_d_ug        numeric default 0,
  vit_e_mg        numeric default 0,
  vit_k_ug        numeric default 0,
  b6_mg           numeric default 0,
  b12_ug          numeric default 0,
  folate_ug       numeric default 0,
  -- search / display metadata
  aliases         text[]  not null default '{}',
  measures        jsonb   not null default '[]'::jsonb,   -- [{label, g}]
  food_group      text,
  region          text    default 'IN',
  popularity      int     not null default 0,
  search_text     text    not null,                       -- lower(name + aliases + group)
  created_at      timestamptz default now()
);

-- Trigram index over the combined search text powers fuzzy + substring search.
create index if not exists food_catalog_search_trgm
  on public.food_catalog using gin (search_text gin_trgm_ops);
create index if not exists food_catalog_name_trgm
  on public.food_catalog using gin (lower(name) gin_trgm_ops);

-- Reference data: readable by everyone, writable only by service role / migrations.
alter table public.food_catalog enable row level security;
drop policy if exists "food_catalog readable by all" on public.food_catalog;
create policy "food_catalog readable by all"
  on public.food_catalog for select
  to anon, authenticated
  using (true);

-- ── Fuzzy search RPC ─────────────────────────────────────────────────
-- A blended relevance score: exact-name / prefix / alias / word-start /
-- substring boosts, plus name-weighted trigram similarity (typo tolerance),
-- plus a popularity nudge. Name similarity dominates so a coincidental alias
-- match on another food can't outrank the food you actually typed.
create or replace function public.search_foods(q text, lim int default 25)
returns setof public.food_catalog
language plpgsql
stable
-- pg_trgm (word_similarity/%) lives in the `extensions` schema on Supabase,
-- so it must be on the search_path alongside public.
set search_path = public, extensions, pg_temp
as $$
declare
  nq text := lower(trim(coalesce(q, '')));
begin
  if length(nq) = 0 then
    return;
  end if;
  -- typo recall for the index-backed <% operator (default 0.6 is too strict)
  perform set_config('pg_trgm.word_similarity_threshold', '0.4', true);
  return query
    select c.*
    from public.food_catalog c
    -- both predicates are GIN-trigram-indexable, so similarity is only
    -- computed over the small filtered set in ORDER BY (≈24 ms vs 193 ms).
    where c.search_text ilike '%' || nq || '%'
       or nq <% c.search_text
    order by
      ( (case
           when lower(c.name) = nq                                              then 100
           when lower(c.name) like nq || '%'                                    then 60
           when exists (select 1 from unnest(c.aliases) a where lower(a) = nq)  then 64
           when exists (select 1 from unnest(c.aliases) a where lower(a) like nq||'%') then 46
           when c.name like '% ' || nq || '%'                                   then 42
           when c.search_text like '%' || nq || '%'                             then 26
           else 0
         end)
        + 26 * word_similarity(nq, lower(c.name))
        + 6  * word_similarity(nq, c.search_text)
        -- commonly-eaten foods beat rare ones within the matched set
        + least(c.popularity, 95) * 0.62
        -- penalise specific/rare qualified variants ("Egg, quail, whole, raw")
        - 7 * (length(c.name) - length(translate(c.name, ',', '')))
      ) desc,
      length(c.name) asc
    limit greatest(coalesce(lim, 25), 1);
end;
$$;

grant execute on function public.search_foods(text, int) to anon, authenticated;

-- ── Logging support ──────────────────────────────────────────────────
-- When a catalog food is logged it is mirrored into `foods` (per-user cache)
-- so Recents/Favorites work; catalog_id makes that mirror idempotent.
alter table public.foods add column if not exists catalog_id text;
create index if not exists foods_catalog_id_idx on public.foods (catalog_id);
