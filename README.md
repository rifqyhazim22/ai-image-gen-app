# ai_image_gen_app

Flutter client for the AI Image Gen flow. Backend will reuse the existing Supabase project (Mirror) but uses its own schema/bucket so data tidak bentrok.

## Backend (shared Supabase, isolated resources)
- Jalankan `supabase/sql/ai_image_setup.sql` di SQL Editor project Supabase Mirror untuk membuat tabel `public.ai_images` (kolom `group_id`) plus bucket privat `ai-photo-remix` (RLS owner-only + prefix path).
- Edge Functions:
  - `generate_images` (mode text, edit; OpenAI only; simpan prompt/kind/group_id ke DB + storage).
  - `cleanup_group` (hapus batch per `group_id`).
  - `delete_item` (hapus file+record satuan).
  Set env `SERVICE_ROLE_KEY`, `OPENAI_API_KEY`.

## Menjalankan Flutter (dev)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://gutibpbuoigchxltzxbb.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<mirror_supabase_anon_key>
```

## Testing (Step 6)
- Saat ini baru diuji di web/Chrome (localhost:3000).
- Untuk mencoba platform lain:  
  - Android: `flutter run -d android` (pastikan emulator/device aktif)  
  - iOS: `flutter run -d ios` (butuh Xcode + provisioning)  
  - Desktop: `flutter run -d macos|windows|linux`  
- Jika menemukan isu UI/responsif, catat device & log konsol.

## Deployment/Docs (Step 7)
- Port dev: 3000 (flutter run -d chrome default).  
- Build web: `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` lalu deploy ke hosting (mis. Vercel/Netlify) dengan output `build/web`.
- Build desktop/mobile: gunakan `flutter build macos|windows|linux|apk|ipa` dengan dart-define yang sama.
- Repo GitHub: https://github.com/rifqyhazim22/ai-image-gen-app (tambahkan release/artifact unduhan bila sudah siap).

### Contoh deploy ke Vercel (web)
1) Jalankan `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`  
2) Upload folder `build/web` ke Vercel dengan `vercel --prod --cwd build/web` atau lewat dashboard (set “Output Directory” = `build/web`).  
3) Pastikan env di browser sudah sesuai (anon key & URL diset saat build).

### Download (web-only button)
- Tombol “Download app” muncul di versi web (mis. deploy di Vercel) dan mengarah ke halaman rilis GitHub.
- Halaman rilis: https://github.com/rifqyhazim22/ai-image-gen-app/releases (unggah artifact build di sana bila sudah tersedia).

## Catatan
- UI: prompt input + preset chips, mode dropdown (Text / Edit), upload hanya untuk Edit (5MB max), gallery menampilkan scene/kind/prompt, tombol delete per item, clear current/all (via functions).
- History: toggle “Keep previous results” untuk tetap simpan batch lama. Clear current/all memanggil functions cleanup.
- Jangan gunakan service role di client. Semua secrets di env; lihat `.env.example`. Jangan commit kunci apa pun.
