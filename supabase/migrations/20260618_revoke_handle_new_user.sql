-- Security hardening (2026-06-18)
-- handle_new_user() is an auth trigger function; it should never be invoked
-- directly via the PostgREST RPC endpoint (/rest/v1/rpc/handle_new_user).
-- Revoke EXECUTE from the API-facing roles so it is only callable in the
-- trigger (owner) context. Flagged by the Supabase security advisor.
--
-- Safe to run more than once.

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
