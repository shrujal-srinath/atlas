# ATLAS — Full Security Audit (2026-07-02)

Targeted deep review of the Flutter client, Supabase backend (project
`wtiejjohcjoukjqkpgim`), Android/web config, secrets, and local storage,
structured around the eight requested checks. Backend facts verified live via the
Supabase MCP (read-only): `pg_policies`, `pg_proc`, FK cascade rules, table columns,
advisors.

**Headline:** no critical vulnerability. No cross-user data read/write, no privilege
escalation, no SSRF, no leaked service-role key, complete account deletion. The one
class that is genuinely unprotected — **client-authoritative game state (XP / level /
achievements)** — is Low impact today only because the app is single-player with no
leaderboard, rewards, or money attached. If any social/competitive surface is ever
added, it jumps to High. Everything else is hardening.

Legend: 🔴 critical · 🟠 high · 🟡 medium · 🟢 low · ⚪ info. Items where I'm inferring
intent rather than certain are marked **[inference]**.

---

## 1. RLS coverage (per operation)

**Result: no critical finding. All 28 tables have RLS enabled; no table is missing
protection.**

Important correction to the framing: in Postgres, when RLS is *enabled* and *no*
policy exists for an operation, that operation is **denied by default**. So a missing
per-op policy is fail-safe (a functionality gap at worst), not a hole. The exploitable
condition is the opposite — an *overly permissive* policy — which I checked for
directly. Per-operation coverage from live `pg_policies`:

- **20 tables** use a single `ALL`-command policy scoped `auth.uid() = user_id` with a
  matching `WITH CHECK` — full S/I/U/D coverage: `users`, `habits`, `habit_logs`,
  `meals`, `food_logs`, `body_weight_logs`, `daily_journal`, `phase_history`,
  `water_logs`, `xp_events`, `user_achievements`, `daily_logins`, `notifications`,
  `daily_score_snapshots`, `level_prerequisites`, `note_folders`, `note_items`,
  `notes`, `meal_bundles`, `meal_bundle_items`.
- **5 tables** with explicit per-op policies, all four ops present & owner-scoped:
  `foods`, `intentions`, `measurements`, `mood_logs`, `recipe_ingredients`.
- `focus_sessions`: SELECT/INSERT/DELETE only — **no UPDATE policy** → UPDATE is
  denied. ⚪ Info (functional gap, not exploitable).
- `food_catalog`: SELECT (all), INSERT/UPDATE limited to `source='off'` rows, no
  DELETE. → see **§ finding 2b** (permissive shared write).

🟡 **1a — `UPDATE` policies missing `WITH CHECK`** — `measurements`, `mood_logs`,
`intentions`, `foods`. Their UPDATE policy has `USING (user_id = auth.uid())` but
`WITH CHECK = null`, so a user can UPDATE their own row and set `user_id` to another
user's id, injecting a row into a victim's account (cannot *read* the victim's data).
*Fix:* add `WITH CHECK (user_id = (SELECT auth.uid()))` to each. Migration:
```sql
alter policy "measurements update own" on public.measurements
  with check (user_id = (select auth.uid()));
-- repeat for mood_logs / intentions / foods UPDATE policies
```

🟡 **1b / 2b — `food_catalog` shared table is writable by any authenticated user.**
Policies `auth caches branded foods` (INSERT `source='off' AND barcode IS NOT NULL`)
and `auth refreshes branded foods` (UPDATE any `source='off'` row) let a signed-in
user overwrite the nutrition of shared branded foods that all 9,512-row catalog readers
see. Cross-user data *poisoning* (integrity), not disclosure. *Fix:* route branded-food
caching through a `SECURITY DEFINER` RPC that validates input, or restrict writes to the
service role, or add a `created_by` column and gate UPDATE to the creator.

---

## 2. Client-trusted writes (XP / score / streak / achievements)

**Can RLS alone stop a user writing implausible values via the API directly? No.**
RLS enforces *ownership* (`user_id = auth.uid()`), never *value plausibility*. The anon
key is public and a signed-in user's JWT is trivially extractable, so any of these can
be driven directly against `/rest/v1/...` outside the app UI. Every client-authoritative
write path:

| Value | Path | Table/column written | Server validation |
|---|---|---|---|
| Cumulative level XP (source of truth) | `leveling_providers.dart:434` (upsert), `:504` (insert) | `daily_score_snapshots.score`, `.score_xp` | none |
| Achievement bonus XP | `achievement_engine.dart:613` → `DailySnapshotWriter.addTodayBonus` | `daily_score_snapshots.bonus_xp` | none |
| Achievement unlocks | `achievement_engine.dart:606` | `user_achievements(achievement_id)` — insert *any* id | none |
| Confirmed level (leveling v2.1 gate) | `auth_provider.dart:159-167` (arbitrary patch) | `users.confirmed_level` | none |
| Level milestones | `level_prereq_repository.dart:22/39/53` | `level_prerequisites` | none |
| Self-reported facts (less meaningful to fake) | `habit_logs`/`food_logs`/`water_logs`/`body_weight_logs` inserts | — | none |

🟢 **2a — Game state is fully client-authoritative.** A user can POST arbitrary
`score_xp` / `bonus_xp`, set `confirmed_level` to any value, and insert every
`user_achievements` row — RLS permits all of it because the rows are "theirs."
- *Why only Low today:* single-player, self-only vanity data. No leaderboard, no
  rewards, no payment, no cross-user or server-trusted consequence. The user is only
  able to lie to themselves. **This becomes High the moment a leaderboard, social
  comparison, or reward is introduced.**
- *Privilege-escalation check: negative.* The `users` table has **no** role/admin/
  premium/entitlement column (verified via `information_schema`), so the arbitrary
  `update(patch)` at `auth_provider.dart:159` cannot escalate privileges — worst case
  is faking one's own level.
- *Fix (if you ever want integrity):* derive `score_xp`/`bonus_xp` server-side in a
  `SECURITY DEFINER` function or trigger from the underlying logs rather than accepting
  a client-supplied number; add `CHECK` range constraints; or make `confirmed_level`
  server-computed. Otherwise, document it as accepted-by-design for a personal app.

---

## 3. Auth & session handling

🟢 **3a — Account deletion is complete (no `auth.users` retention).**
`deleteAccount()` (`auth_provider.dart:172`) calls `rpc('delete_user')`, which is
`SECURITY DEFINER` and runs `delete from auth.users where id = auth.uid()`. Verified
live: **every** child FK cascades from `auth.users`/`public.users` — all 20+ public
tables *and* auth internals (`sessions`, `identities`, `mfa_factors`, `one_time_tokens`,
`webauthn_*`, `oauth_*`). The subsequent client-side per-table `wipe()` (`:191-204`) is
redundant belt-and-braces. No residual data.

🟢 **3b — No re-authentication on the destructive delete.** The only gate before account
deletion is a confirm dialog (`settings_screen.dart:248-286`). An attacker with an
unlocked device / live session can delete the account. Session-bound and own-account
only, so Low. *Fix:* require a fresh password / OAuth re-auth (or biometric) immediately
before `delete_user`.

⚪ **3c — Session handling.** `appUserProvider` uses `maybeSingle()` so a missing profile
row degrades to null instead of throwing (`auth_provider.dart:30-35`) — good. Auth state
flows from `onAuthStateChange`; router gates on it. No session-fixation vector found.
**[inference]** I did not find a password-change or email-change flow in the client, so
"re-auth on those sensitive actions" is N/A rather than missing — flagging in case such
a flow exists elsewhere and I missed it.

---

## 4. Dev-mode / debug bypass safety

🟡 **4a — The bypass IS reachable in a release build (default-on compile flag).**
`kDevAccessEnabled = bool.fromEnvironment('ATLAS_DEV_ACCESS', defaultValue: true)`
(`dev_unlock.dart:12`). Because the default is `true`, a normal `flutter build` ships
the bypass: typing `shrujal@gmail.com` / `SHRUJAL@123` (`dev_unlock.dart:33-34`) into
the login form (`login_screen.dart:113`) calls `enterDevMode` and skips the auth +
onboarding gates (`app_router.dart:80`). A real personal email + plaintext password ship
in the binary.
- *Bounded impact:* dev mode serves only **mock** data with **no** Supabase session
  (`auth_provider.dart:24` → `mockUser`); no real user data is exposed.
- *Fix:* `defaultValue: false` (or gate on `!kReleaseMode`), and remove/rotate the
  plaintext password. Ideally strip `core/dev/` from release via the same flag.

🟢 **4b — Not persisted, not remotely toggleable — confirmed.** `devModeProvider` is an
in-memory `StateProvider<bool>((_) => false)` (`dev_mode.dart:7`). It is never written to
Hive/shared_prefs and never read from any network response. Every reader
(`app_router.dart:80`, `auth_provider.dart:24`, `achievement_engine.dart:149`,
`achievement_provider.dart:9`) only *serves mock data / skips gates* — none exposes real
data. It resets to `false` on every cold start. So the only way in is 4a.

---

## 5. Third-party API calls

🟢 **No SSRF, all hosts hardcoded, all requests bounded.** Complete outbound inventory:
- Supabase (own project) — `supabase_service.dart:12`.
- Open Food Facts — search (`off_client.dart:25`) and barcode (`:117`). Host is a fixed
  literal; only the query/barcode is user-controlled and it's `Uri.encodeQueryComponent`
  / `Uri.encodeComponent`-encoded into the query/path, so no host or path breakout. 8 s
  timeout. Responses parsed with null-safe casts (`(n[key] as num?)?.toDouble() ?? 0`).
- Open-Meteo weather — `weather_service.dart:15`, params via `Uri.replace`, 6 s timeout.

⚪ **5a — Response trust:** OFF/weather payloads are trusted for numeric values only;
worst case is a wrong nutrition number cached locally — Low. ⚪ **5b:** OFF `User-Agent`
embeds the developer's email (`off_client.dart:13`) — minor third-party info leak, not a
vuln.

---

## 6. Secrets handling

🟢 **6a — Anon key is the correct public-safe key.** Decoded the hardcoded JWT
(`supabase_service.dart:17`): payload `{"role":"anon", ...}` — **not** service-role.
Public-by-design, RLS-gated. The Google Web client ID (`:27`) is also a public
identifier. Fine to ship.

🟢 **6b — No secrets committed.** `.env` is untracked and gitignored (verified);
`.env.example` (`atlas/.env.example`) contains keys with **empty** values only. Git
history has no secret files. `web/` and `android/` contain no embedded keys.

🟡 **6c — `.env` holds a management-API token in a shared workspace.**
`.env` includes `SUPABASE_ACCESS_TOKEN` (Supabase Management API — far more powerful
than the anon key: can alter project config, run SQL, read all data). It's correctly
gitignored, but this workspace/session has been shared with tooling. *Fix:* rotate the
token at supabase.com/dashboard/account/tokens and treat it as burned if it's ever left
the machine.

⚪ **6d** — Only "hardcoded credential" in source beyond public identifiers is the demo
password (see 4a) and the dev email. No API secrets in `android/`/`web/`/`lib/`.

---

## 7. Local storage (unencrypted on-device)

🟢 **7a — Hive caches are unencrypted.** `hive_service.dart` opens plaintext boxes for
food logs, habits, weight logs, water, to-dos, and the sync queue. Mitigated by
`android:allowBackup="false"` (blocks ADB backup) + the OS app sandbox → only exposed on
a rooted/physically-compromised device. The most sensitive data (journal, notes, mood) is
server-only and *not* cached locally. *Fix (optional):* `Hive.openBox(encryptionCipher:)`
with a key in `flutter_secure_storage`.

🟡 **7b — Session tokens likely persisted in plaintext SharedPreferences. [inference]**
`SupabaseService.initialize()` (`supabase_service.dart:30`) calls `Supabase.initialize`
with no custom `localStorage`/`AuthOptions`, so it uses supabase_flutter 2.x's default
session store, which is `SharedPreferences`-backed (**not** encrypted). That means the
access + **refresh** token sit in plaintext app-private storage; on a rooted device the
refresh token grants persistent account access. Device-access-bound (Low likelihood) but
higher value than the Hive data. *Fix:* pass a secure `LocalStorage` backed by
`flutter_secure_storage` (Keystore/Keychain). Marked inference because it depends on the
library default rather than explicit code I can point to a line of — worth a 2-minute
confirmation by inspecting the on-device prefs file.

---

## 8. Platform manifests

🟢 **8a — Permissions are minimal and justified.** `AndroidManifest.xml`: INTERNET
(Supabase), CAMERA (barcode scanner), POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM
(deliberately *not* the Play-restricted USE_EXACT_ALARM — degrades to inexact),
RECEIVE_BOOT_COMPLETED + WAKE_LOCK + VIBRATE (scheduled reminders). No location,
contacts, storage, SMS, or other over-broad grants.

🟢 **8b — Exported components are correct.** Only `MainActivity` is `exported=true`
(required for the launcher + deep link); both `flutterlocalnotifications` receivers are
`exported=false`. No content providers/services exported.

🟢 **8c — Deep-link scheme is hijackable by a malicious app. [inference on likelihood]**
The OAuth callback uses a **custom scheme** `io.atlas.app://login-callback`
(`AndroidManifest.xml` intent-filter). Any other installed app can register the same
scheme and intercept the redirect. Supabase uses **PKCE** by default, which prevents a
stolen `code` from being exchanged without the verifier, so the practical risk is low.
*Fix (hardening):* migrate to Android App Links (`https` scheme + `autoVerify="true"` +
`assetlinks.json`), which are cryptographically bound to your domain and not
claimable by other apps.

---

## Priority queue

1. 🟡 **4a** — flip `ATLAS_DEV_ACCESS` default to `false` + drop the plaintext demo password. One line, highest leverage; keeps a real backdoor out of shipped APKs.
2. 🟡 **1b** — lock down `food_catalog` writes (migration).
3. 🟡 **1a** — add `WITH CHECK` to the four UPDATE policies (migration, ~4 lines).
4. 🟡 **6c** — rotate the Supabase management token.
5. 🟡 **7b** — move session storage to `flutter_secure_storage` (confirm the default first).
6. 🟢 **2a** — decide: server-authoritative XP, or explicitly accept client-authoritative game state as by-design. Only urgent if social/competitive features are on the roadmap.
7. 🟢 **3b, 7a, 8c** and ⚪ items — hardening as time allows.

## Verified clean (no action)
RLS enabled + correctly owner-scoped on all 28 tables; all 3 SQL functions pin
`search_path`; `search_foods` is not injectable (query bound as a value into ILIKE, no
dynamic SQL); `delete_user` deletes only the caller; `handle_new_user` not executable by
anon/authenticated; account-deletion cascade complete; anon key is `role:anon`; no
service-role key or secrets in source/history; no SSRF; no storage buckets; dependencies
current with no known CVEs (supabase_flutter 2.12.4, http 1.6.0, url_launcher 6.3.2,
crypto 3.0.7, flutter_local_notifications 19.5.0, hive 2.2.3).
