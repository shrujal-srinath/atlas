-- ════════════════════════════════════════════════════════════════════
-- Barcode support on the food catalog + a compounding write-through cache.
--
-- Bulk-imported Open Food Facts India products and freshly-scanned products
-- are stored in food_catalog with their barcode, so scans resolve locally
-- (instant, offline-friendly) and branded coverage grows with every scan.
-- ════════════════════════════════════════════════════════════════════

alter table public.food_catalog add column if not exists barcode text;
create index if not exists food_catalog_barcode_idx
  on public.food_catalog (barcode) where barcode is not null;

-- Authenticated users may cache branded (OFF) products they scan into the
-- shared catalog. Constrained to source='off' rows so curated IFCT / USDA /
-- dish data can never be altered from the client (no SECURITY DEFINER needed).
drop policy if exists "auth caches branded foods" on public.food_catalog;
create policy "auth caches branded foods"
  on public.food_catalog for insert to authenticated
  with check (source = 'off' and barcode is not null);

drop policy if exists "auth refreshes branded foods" on public.food_catalog;
create policy "auth refreshes branded foods"
  on public.food_catalog for update to authenticated
  using (source = 'off') with check (source = 'off');
