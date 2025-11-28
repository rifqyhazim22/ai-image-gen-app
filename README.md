# AI Image Gen App

Flutter client untuk generate/edit gambar (mode teks + image edit) dengan Supabase backend dan OpenAI. Rilis tersedia di GitHub Releases (APK, DMG/ZIP macOS, web bundle).

---

## Setup & Run (Dev)
```bash
# Instal dep
flutter pub get

# Jalankan (Chrome)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<supabase_url> \
  --dart-define=SUPABASE_ANON_KEY=<publishable_or_anon_key>

# Contoh build rilis
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build macos --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
> Kunci Supabase wajib via env/`--dart-define`. Tidak ada fallback di kode.

## Arsitektur Singkat
- **Flutter app**: UI utama (chat-like feed + history + library), nickname, l10n EN/ID, cek update (via GitHub Releases latest).
- **Supabase**: tabel `ai_images`, bucket `ai-photo-remix`, Edge Functions `generate_images`, `cleanup_group`, `delete_item`. Semua akses pakai anon/publishable key + RLS owner-only (berdasarkan `user_id`).
- **OpenAI**: dipanggil di Edge Function (bukan di klien) untuk generate/edit.
- **Distribusi**: build web_dist (Vercel), APK, macOS (ad-hoc sign), upload ke GitHub Releases.

## Security & Handling Secrets
- **Tidak ada fallback Supabase** di kode; aplikasi wajib env `SUPABASE_URL` & `SUPABASE_ANON_KEY`.
- **Anon/publishable key saja** di klien; service_role/secret tidak pernah dibake. Keamanan utama di **RLS** dan kebijakan bucket privat (path per user).
- **release/** di-ignore Git (artefak tidak disimpan di repo). Rilis hanya via GitHub Releases.
- Untuk macOS publik, idealnya codesign + notarize (saat ini ad-hoc sign).

## CI/CD (baru ditambahkan)
- Workflow `.github/workflows/release.yml` (manual/tag `v*`):
  - Build web_dist (zip), APK release, macOS (zip + dmg, ad-hoc sign).
  - Upload artefak ke GitHub Release (butuh secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GITHUB_TOKEN`).
  - Bisa ditambah deploy Vercel jika ingin (pakai `VERCEL_TOKEN/ORG/PROJECT`).

## UI/UX & Fitur
- Mode **Text → Image** dan **Text + Image (Edit)**, presets prompt, aspek/quality chips, toggle simpan history, clear batch/all.
- History & Library dengan copy/open/share/download, session grouping.
- Nickname prompt sekali setelah login, edit nickname kapan saja.
- L10n EN/ID, theme light/dark, hero call-to-action + download panel (web).
- Cek update (native): bandingkan versi lokal dengan GitHub Releases “latest”, tampilkan tombol download jika ada versi baru.

## Evaluasi (apa yang sudah/sedang dikerjakan)
- **Implementation of flow**: signup menampilkan instruksi cek email jika session null, nickname gating, mode text/edit sesuai permintaan.
- **Code quality & structure**: state terpusat per tab, helper `translate(...)`, komponen Glass/sections; masih Flutter single-file besar, bisa dipecah jika diperlukan.
- **Use of required stack**: Flutter + Supabase (RLS, bucket privat), Edge Functions untuk OpenAI, Vercel/GitHub Releases untuk distribusi.
- **Security & secrets**: fallback dihapus; anon key wajib dari env; RLS + bucket privat adalah lapisan utama; release di-ignore dari Git.
- **UI/UX & responsiveness**: layout sudah responsif (chat/feed/history/library); perlu uji lintas device lebih lanjut.
- **Decision under limited spec**: fitur-fitur (nickname, cek email, download panel, update check) diprioritaskan sesuai kebutuhan dasar dan menjaga backward compatibility (web_dist + rilis GitHub).

## Checklist next
- Pastikan secrets di GitHub Actions: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GITHUB_TOKEN` (opsional Vercel token).
- Run workflow untuk build + publish otomatis ke Releases (tag `v*` atau manual dispatch).
- Jika mau hilangkan blank-page SW issue: bisa nonaktifkan SW di web build (opsional).
