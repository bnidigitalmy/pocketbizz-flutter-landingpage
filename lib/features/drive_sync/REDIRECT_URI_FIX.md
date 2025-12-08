# Fix: redirect_uri_mismatch Error

## Problem
Error: `Error 400: redirect_uri_mismatch`

App running di `localhost:63636` (atau port lain) tapi Google Cloud Console hanya configure port tertentu.

**Root Cause:** Flutter web menggunakan random port setiap kali run, jadi port baru tidak didaftarkan dalam Google Cloud Console.

## Solution (Pilih Satu)

### ✅ Option 1: Use Fixed Port (RECOMMENDED untuk Development)

**Best solution** - Guna port yang sama setiap kali run:

```bash
flutter run -d chrome --web-port=3000
```

Kemudian dalam Google Cloud Console, hanya perlu add:
- `http://localhost:3000` (JavaScript origin)
- `http://localhost:3000` (Redirect URI)

**Advantages:**
- ✅ Hanya perlu configure sekali
- ✅ Port tetap setiap kali run
- ✅ Tidak perlu tambah banyak ports

**VS Code Launch Configuration:**
Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter Web (Port 3000)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "-d",
        "chrome",
        "--web-port=3000"
      ]
    }
  ]
}
```

### Option 2: Tambah Multiple Common Ports

Jika nak guna random ports, tambah common development ports:

**Authorized JavaScript origins:**
```
https://app.pocketbizz.my
https://pocketbizz-web-flutter.web.app
http://localhost:3000
http://localhost:5000
http://localhost:61660
http://localhost:63636
http://localhost:8080
http://localhost:8081
```

**Authorized redirect URIs:**
```
https://app.pocketbizz.my
https://app.pocketbizz.my/auth/callback
https://pocketbizz-web-flutter.web.app
https://pocketbizz-web-flutter.web.app/auth/callback
http://localhost:3000
http://localhost:3000/
http://localhost:5000
http://localhost:5000/
http://localhost:61660
http://localhost:61660/
http://localhost:63636
http://localhost:63636/
http://localhost:8080
http://localhost:8080/
```

**Disadvantages:**
- ❌ Perlu tambah port baru setiap kali guna port yang berbeza
- ❌ Banyak entries dalam Google Cloud Console

### Option 3: Guna Production Domain untuk Development

Jika ada custom domain, guna production domain untuk development juga:
- Setup local DNS atau hosts file untuk point `app.pocketbizz.my` ke `localhost`
- Atau guna ngrok/tunneling service

## Quick Fix Steps (Current Port: 63636)

1. **Buka Google Cloud Console**
   - Go to: https://console.cloud.google.com/apis/credentials?project=214368454746
   - Click on your OAuth 2.0 Client ID

2. **Tambah JavaScript Origin:**
   - Scroll to "Authorized JavaScript origins"
   - Click "+ ADD URI"
   - Tambah: `http://localhost:63636`
   - Click "SAVE"

3. **Tambah Redirect URI (if needed):**
   - Scroll to "Authorized redirect URIs"
   - Click "+ ADD URI"
   - Tambah: `http://localhost:63636`
   - Click "SAVE"

4. **Wait 1-2 minutes** untuk settings propagate

5. **Refresh app** dan test sign-in lagi

## Recommended Setup

Untuk development, **gunakan fixed port**:

1. **Run dengan fixed port:**
   ```bash
   flutter run -d chrome --web-port=3000
   ```

2. **Configure Google Cloud Console sekali:**
   - JavaScript origin: `http://localhost:3000`
   - Redirect URI: `http://localhost:3000`

3. **Selalu guna port 3000** untuk development

## Notes

- Google OAuth **TIDAK support wildcard** (`http://localhost:*`)
- Port mesti didaftarkan secara explicit
- Settings boleh ambil 1-2 minit untuk propagate
- Production domain tetap perlu ada untuk production deployment


