-- Security audit 2026-07-02, finding 1a: the UPDATE policies on these four
-- tables have USING (user_id = auth.uid()) but no WITH CHECK, so a user can
-- UPDATE their own row and set user_id to another user's id — injecting a row
-- into a victim's account (no read exposure, but an integrity hole).
--
-- Adds WITH CHECK (user_id = (select auth.uid())) to every UPDATE policy on
-- the four tables. Written name-agnostically (policy names are discovered from
-- pg_policies) so it applies cleanly regardless of how the policies were named,
-- and is idempotent — re-running it is harmless.

do $$
declare
  p record;
begin
  for p in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and cmd = 'UPDATE'
      and tablename in ('measurements', 'mood_logs', 'intentions', 'foods')
  loop
    execute format(
      'alter policy %I on public.%I with check (user_id = (select auth.uid()))',
      p.policyname, p.tablename
    );
  end loop;
end $$;
