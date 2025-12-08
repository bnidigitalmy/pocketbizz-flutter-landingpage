# Google OAuth Setup Guide

## Client ID Configuration

Client ID telah di-configure dalam `lib/core/config/app_config.dart`:

```dart
static const String googleOAuthClientId = '214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com';
```

## Important Notes

### ✅ Client ID - REQUIRED
- **Location**: `lib/core/config/app_config.dart`
- **Usage**: Digunakan untuk Google Sign-In authentication
- **Format**: `xxxxxx-xxxxx.apps.googleusercontent.com`
- **Status**: ✅ Already configured

### ❌ Client Secret - NOT NEEDED
- **Why**: Client Secret hanya diperlukan untuk **server-side OAuth flows**
- **Flutter Web**: Menggunakan **client-side OAuth**, jadi Client Secret tidak diperlukan
- **Security**: Client Secret tidak boleh di-expose dalam client-side code

## How It Works

1. **User clicks "Sign In to Google Drive"**
2. **Google Sign-In dialog opens** (using Client ID)
3. **User selects Google account**
4. **OAuth flow completes** (no Client Secret needed)
5. **Access token obtained** for Google Drive API
6. **Files can be uploaded** to user's Google Drive

## Security Best Practices

1. ✅ **Client ID** - Safe to include in client code (public)
2. ❌ **Client Secret** - NEVER include in client code (server-only)
3. ✅ **OAuth Scopes** - Limited to `drive.file` (only files created by app)
4. ✅ **RLS Policies** - Database sync logs are isolated per user

## Required APIs

### ✅ Google Drive API - REQUIRED
- **Enable**: APIs & Services > Library > "Google Drive API" > Enable
- **Purpose**: Upload files to user's Google Drive

### ✅ People API - REQUIRED
- **Enable**: APIs & Services > Library > "People API" > Enable
- **Purpose**: Get user profile (name, email, photo) for sign-in
- **Why**: The `google_sign_in` plugin automatically fetches user profile
- **Quick Link**: https://console.cloud.google.com/apis/api/people.googleapis.com/overview?project=214368454746
- **Note**: People API is FREE and standard for Google Sign-In

## Testing

1. Run app: `flutter run -d chrome`
2. Navigate to "Google Drive Sync" page
3. Click "Sign In to Google Drive"
4. Select Google account
5. Generate a PDF document (invoice, claim, etc.)
6. Check Google Drive - file should appear in appropriate folder

## Troubleshooting

### "Sign in failed"
- Check Client ID is correct in `app_config.dart`
- Verify OAuth consent screen is configured
- Check authorized domains in Google Cloud Console

### "Access denied" (403)
- **People API not enabled**: Enable People API (see Required APIs above)
- **OAuth consent screen**: Add test users or submit for verification
- Verify OAuth scopes include `drive.file`
- Check user has granted permissions
- Verify redirect URIs match Google Cloud Console

### "People API has not been used" (403)
- **Solution**: Enable People API in Google Cloud Console
- **Quick Fix**: https://console.cloud.google.com/apis/api/people.googleapis.com/overview?project=214368454746
- See `ENABLE_PEOPLE_API.md` for detailed instructions

### "File upload failed"
- Check user is signed in
- Verify Google Drive API is enabled
- Check file size limits (Google Drive has limits)

### Deprecated `signIn` method warning
- This is a warning from `google_sign_in` plugin
- It doesn't affect functionality
- Future versions will migrate to Google Identity Services
- For now, the current implementation works fine


