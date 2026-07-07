-- Client crash/error sink. The app's global error handlers best-effort INSERT
-- here in release builds (see lib/core/utils/app_logger.dart) so production
-- failures are visible. Insert-only from the client; reads are dashboard /
-- service-role only (no SELECT policy → RLS denies client reads).

create table if not exists public.client_errors (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete set null,
  message     text not null,
  stack       text,
  platform    text,
  app_version text,
  created_at  timestamptz not null default now()
);

create index if not exists client_errors_created_idx
  on public.client_errors (created_at desc);

alter table public.client_errors enable row level security;

-- Clients may only INSERT their own (or anonymous) reports; never read/update.
drop policy if exists client_errors_insert on public.client_errors;
create policy client_errors_insert on public.client_errors
  for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());
