# Enable People API - Fix 403 Error

## Problem
Error: `403 PERMISSION_DENIED - People API has not been used in project 214368454746 before or it is disabled`

## Cause
The `google_sign_in` plugin automatically tries to fetch user profile information (name, email, photo) which requires the **People API** to be enabled. Even though we only need Drive API for file uploads, the plugin still requests user profile data.

## Solution: Enable People API

### Quick Fix (5 minutes)

1. **Go to Google Cloud Console**
   - Open: https://console.cloud.google.com/apis/api/people.googleapis.com/overview?project=214368454746
   - Or navigate: APIs & Services > Library > Search "People API"

2. **Enable People API**
   - Click the **"ENABLE"** button
   - Wait 1-2 minutes for the API to be activated

3. **Test Again**
   - Refresh your app
   - Try signing in to Google Drive again
   - The error should be gone

## Alternative: Disable Profile Fetching (Advanced)

If you want to avoid enabling People API, you can modify the `google_sign_in` plugin usage, but this requires more complex changes and may not work well with the current plugin version.

**Recommendation:** Just enable People API - it's free and doesn't have any negative impact. It's a standard Google API that many apps use.

## Why People API?

The `google_sign_in` plugin uses People API to:
- Get user's display name
- Get user's email address
- Get user's profile photo

This information is displayed in the sign-in UI and stored in `GoogleSignInAccount`.

## Cost

- **People API is FREE** for reasonable usage
- No charges for basic profile information requests
- Only charges apply for very high-volume usage (millions of requests)

## Verification

After enabling, you can verify by:
1. Go to: APIs & Services > Enabled APIs
2. Look for "Google People API" in the list
3. Status should be "Enabled"

## Notes

- Enabling People API is a one-time setup
- It doesn't affect your app's functionality
- It's a standard practice for Google Sign-In implementations
- The API will be available immediately after enabling (may take 1-2 minutes to propagate)

