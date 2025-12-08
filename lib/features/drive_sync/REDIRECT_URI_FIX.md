# Fix: redirect_uri_mismatch Error

## Problem
Error: `Error 400: redirect_uri_mismatch`

App running di `localhost:61660` tapi Google Cloud Console hanya configure `localhost:3000`.

## Solution

### Option 1: Tambah Multiple Localhost Ports (Recommended untuk Development)

Dalam Google Cloud Console > OAuth Client ID:

**Authorized redirect URIs:**
```
https://app.pocketbizz.my
https://app.pocketbizz.my/auth/callback
http://localhost:3000
http://localhost:61660
http://localhost:61660/
http://localhost:61660/auth/callback
http://localhost:8080
http://localhost:8080/
http://localhost:8080/auth/callback
```

**Authorized JavaScript origins:**
```
https://app.pocketbizz.my
http://localhost:3000
http://localhost:61660
http://localhost:8080
```

### Option 2: Guna Wildcard untuk Localhost (Jika Supported)

Sesetengah OAuth providers support wildcard untuk development:
```
http://localhost:*
```

Tapi Google OAuth **TIDAK support wildcard**, jadi perlu tambah setiap port secara explicit.

### Option 3: Fix Port Configuration

Jika Flutter web selalu guna port yang sama, configure dalam `launch.json` atau run command:
```bash
flutter run -d chrome --web-port=3000
```

## Quick Fix Steps

1. **Buka Google Cloud Console**
   - Go to: APIs & Services > Credentials
   - Click on your OAuth Client ID

2. **Tambah Redirect URIs:**
   - Scroll to "Authorized redirect URIs"
   - Click "+ Add URI"
   - Tambah: `http://localhost:61660`
   - Tambah: `http://localhost:61660/`
   - Tambah: `http://localhost:61660/auth/callback`
   - (Optional) Tambah common ports: `8080`, `5000`, etc.

3. **Tambah JavaScript Origins:**
   - Scroll to "Authorized JavaScript origins"
   - Click "+ Add URI"
   - Tambah: `http://localhost:61660`

4. **Save** dan tunggu 5 minit untuk settings take effect

5. **Test lagi** - Error sepatutnya hilang

## Notes

- Flutter web port boleh berubah setiap kali run
- Better tambah common development ports (3000, 5000, 61660, 8080, etc.)
- Production domain (`app.pocketbizz.my`) tetap perlu ada

