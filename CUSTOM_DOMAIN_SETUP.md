# Setup Custom Domain: app.pocketbizz.my

## Current Status
- **Firebase Project**: `pocketbizz-web-flutter`
- **Default URL**: `https://pocketbizz-web-flutter.web.app`
- **Custom Domain**: `app.pocketbizz.my` (to be configured)

## Steps to Add Custom Domain

### 1. Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/project/pocketbizz-web-flutter/hosting)
2. Navigate to **Hosting** section
3. Click on **Add custom domain** button

### 2. Enter Domain
1. Enter domain: `app.pocketbizz.my`
2. Click **Continue**

### 3. Verify Domain Ownership
Firebase will provide DNS records that need to be added to your domain provider:

**Option A: A Record (Recommended)**
- Type: `A`
- Name: `app` (or `@` for root domain)
- Value: Firebase will provide IP addresses (usually 2-4 IPs)

**Option B: CNAME Record**
- Type: `CNAME`
- Name: `app`
- Value: Firebase will provide a CNAME target (e.g., `pocketbizz-web-flutter.web.app`)

### 4. Add DNS Records
1. Go to your domain provider (where `pocketbizz.my` is registered)
2. Access DNS management
3. Add the DNS records provided by Firebase
4. Save changes

### 5. Wait for Verification
- Firebase will automatically verify the DNS records
- This usually takes 5-30 minutes
- You'll receive an email when verification is complete

### 6. SSL Certificate
- Firebase automatically provisions SSL certificate for custom domains
- SSL will be active once domain is verified

## DNS Configuration Example

If using A records:
```
Type: A
Name: app
Value: [IP addresses from Firebase]
TTL: 3600
```

If using CNAME:
```
Type: CNAME
Name: app
Value: [CNAME target from Firebase]
TTL: 3600
```

## Verification

After setup, test the domain:
- `https://app.pocketbizz.my` should load your Flutter app
- SSL certificate should be valid (green padlock)

## Troubleshooting

### Domain not resolving
- Check DNS records are correct
- Wait up to 48 hours for DNS propagation
- Verify DNS records using: `nslookup app.pocketbizz.my`

### SSL certificate issues
- Firebase automatically provisions SSL
- Wait 24-48 hours after domain verification
- Check Firebase Console for SSL status

### Redirect issues
- Ensure `firebase.json` has correct rewrites
- Check that all routes redirect to `/index.html`

## Current firebase.json Configuration

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

This configuration is correct for Flutter web apps.

## Notes

- Custom domain setup must be done through Firebase Console (not CLI)
- Both default URL and custom domain will work after setup
- No code changes needed - just DNS configuration
- Firebase handles SSL automatically

