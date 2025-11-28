# AI Image Gen App

Flutter client for text-to-image and text+image edit, backed by Supabase + OpenAI (via Edge Functions). Releases: GitHub (APK, macOS DMG/ZIP, web bundle).

---

## Setup & Run (Dev)
```bash
flutter pub get

# Run (Chrome example)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<supabase_url> \
  --dart-define=SUPABASE_ANON_KEY=<publishable_or_anon_key>

# Build examples
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build macos --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
> Supabase keys must be provided via env/`--dart-define`. No fallback in code.

## Architecture
- **Flutter app**: chat-like feed (results), history, library, nickname gate, EN/ID l10n, update check (GitHub Releases “latest”).
- **Supabase**: table `ai_images`, bucket `ai-photo-remix`, Edge Functions `generate_images`, `cleanup_group`, `delete_item`. Client uses anon/publishable key; RLS is owner-only (`user_id`).
- **OpenAI**: called inside Edge Function (not from client) for generation/edit.
- **Distribution**: build `web_dist` (Vercel), APK, macOS (ad-hoc sign), uploaded to GitHub Releases.

## Security & Secrets
- No Supabase fallback; app requires `SUPABASE_URL` & `SUPABASE_ANON_KEY` via env.
- Only anon/publishable key in client; never bake service_role. Security relies on **RLS** + private bucket policies (per-user path).
- `release/` is gitignored; artifacts only live in GitHub Releases.
- For public macOS distribution, prefer proper codesign/notarize (currently ad-hoc sign).

## UI/UX Features
- Modes: **Text → Image** and **Text + Image (Edit)**, prompt presets, aspect/quality chips, keep-history toggle, clear batch/all.
- History & Library: copy/open/share/download, session grouping.
- Nickname prompt once post-login; editable later.
- EN/ID localization, light/dark theme, hero CTA + download panel (web).
- Update check (native): compare local version with GitHub latest; show download button if newer.

## Evaluation (current state)
- **Implementation of flow**: signup shows “check email” when session null, nickname gate, text/edit flow in place.
- **Code quality & structure**: centralized state per tab, `translate(...)` helper, glass UI components; still a large single file, can be split later.
- **Stack use**: Flutter + Supabase (RLS, private bucket), Edge Functions for OpenAI, GitHub Releases for distribution (Vercel for web).
- **Security & secrets**: fallback removed; anon key via env; RLS + bucket privacy as main guard; release artifacts excluded from git.
- **UI/UX & responsiveness**: responsive layouts for chat/feed/history/library; more device testing recommended.
- **Decision with limited spec**: prioritized nickname, email notice, download panel, update check to cover core flows while keeping backward compatibility (web_dist + GitHub releases).

## Next Steps
- Provide secrets in CI (if used): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GITHUB_TOKEN` (optional Vercel token).
- Run CI to build/publish to Releases (tag-driven or manual).
- Optionally disable SW if blank-page cache issues persist.
