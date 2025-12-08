# Fix: OAuth Testing Mode - Access Denied

## Problem
Error: `Error 403: access_denied`
Message: "Pocketbizz App - Flutter has not completed the Google verification process"

## Cause
OAuth consent screen masih dalam **"Testing"** mode. Hanya approved test users boleh sign in.

## Solution: Add Test Users

### Steps:

1. **Buka Google Cloud Console**
   - Go to: APIs & Services > OAuth consent screen

2. **Scroll ke "Test users" section**
   - Atau click tab "Test users" di atas

3. **Add Test Users**
   - Click "+ ADD USERS"
   - Masukkan email Google yang nak test:
     - `pocketbizz.my@gmail.com` (atau email lain)
     - Boleh tambah multiple emails (separate dengan comma)
   - Click "ADD"

4. **Save Changes**
   - Settings akan auto-save

5. **Test Lagi**
   - Refresh app
   - Sign in dengan email yang dah di-add sebagai test user
   - Seharusnya boleh sign in sekarang

## Alternative: Publish App (For Production)

Jika nak semua users boleh sign in tanpa add test users:

1. **Complete OAuth Consent Screen**
   - Fill semua required fields
   - Upload app logo
   - Add privacy policy & terms of service links

2. **Submit for Verification**
   - Google akan review app
   - Process boleh ambil beberapa hari/weeks
   - After approved, semua users boleh sign in

3. **For Development:**
   - Better guna "Test users" approach (faster)
   - No need verification untuk testing

## Quick Fix (Recommended untuk Development)

1. Go to: **Google Cloud Console > APIs & Services > OAuth consent screen**
2. Scroll to **"Test users"** section
3. Click **"+ ADD USERS"**
4. Add email: `pocketbizz.my@gmail.com` (atau email Google anda)
5. Click **"ADD"**
6. Test sign in lagi - sepatutnya boleh sekarang!

## Notes

- Test users boleh sign in immediately (no verification needed)
- Boleh add up to 100 test users
- Untuk production, perlu submit untuk verification
- Testing mode adalah normal untuk development

