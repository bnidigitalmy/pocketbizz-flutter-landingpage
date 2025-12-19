# 🔐 Environment Variables Configuration

## Overview

PocketBizz requires environment variables for secure configuration. **Hardcoded credentials have been removed** for production security.

---

## Required Environment Variables

### 1. **Supabase Configuration**

```bash
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key-here
```

**Where to get:**
- Go to your Supabase project dashboard
- Navigate to **Settings** > **API**
- Copy the **Project URL** and **anon/public key**

**Security Note:**
- ✅ Anon key is **designed to be public** (client-side)
- ✅ **RLS policies protect data** even if key is exposed
- ✅ Still use environment variables for best practices

---

### 2. **Google OAuth Client ID**

```bash
GOOGLE_OAUTH_CLIENT_ID=your-google-oauth-client-id.apps.googleusercontent.com
```

**Where to get:**
- Go to [Google Cloud Console](https://console.cloud.google.com/)
- Navigate to **APIs & Services** > **Credentials**
- Create **OAuth 2.0 Client ID** for **Web Application**
- Copy the **Client ID** (not the Client Secret)

**Security Note:**
- ✅ Client IDs are **public by design** (OAuth standard)
- ✅ Client Secret is **NOT needed** (server-side only)
- ✅ Still use environment variables for consistency

---

## Setup Instructions

### **Local Development:**

1. **Create `.env` file** in the project root:
   ```bash
   # Copy from template
   cp .env.example .env
   ```

2. **Fill in your values:**
   ```bash
   SUPABASE_URL=https://gxllowlurizrkvpdircw.supabase.co
   SUPABASE_ANON_KEY=your-actual-anon-key
   GOOGLE_OAUTH_CLIENT_ID=your-actual-client-id
   ```

3. **Verify `.env` is in `.gitignore`:**
   ```bash
   # .env should be ignored
   .env
   ```

---

### **Production Deployment:**

#### **Firebase Hosting (Web):**

1. **Set environment variables in Firebase:**
   ```bash
   firebase functions:config:set \
     supabase.url="https://your-project.supabase.co" \
     supabase.anon_key="your-anon-key" \
     google.oauth_client_id="your-client-id"
   ```

2. **Or use Firebase Hosting environment variables:**
   - Go to Firebase Console > Hosting > Environment Variables
   - Add each variable

#### **Other Platforms:**

- **Vercel:** Add in Project Settings > Environment Variables
- **Netlify:** Add in Site Settings > Build & Deploy > Environment
- **Docker:** Use `-e` flags or `.env` file
- **Kubernetes:** Use ConfigMaps or Secrets

---

## Security Best Practices

### ✅ **DO:**
- ✅ Use environment variables for all credentials
- ✅ Keep `.env` in `.gitignore`
- ✅ Use different keys for dev/staging/production
- ✅ Rotate keys regularly
- ✅ Monitor Supabase dashboard for unusual activity

### ❌ **DON'T:**
- ❌ Commit `.env` to version control
- ❌ Hardcode credentials in source code
- ❌ Share credentials in chat/email
- ❌ Use production keys in development

---

## Troubleshooting

### **Error: "Missing required environment variables"**

**Solution:**
1. Check that `.env` file exists in project root
2. Verify all required variables are set
3. Restart the app after adding variables
4. Check for typos in variable names

### **Error: "Could not load environment variables"**

**Solution:**
1. Ensure `flutter_dotenv` package is installed
2. Check that `EnvConfig.load()` is called in `main.dart`
3. Verify `.env` file format (no spaces around `=`)
4. Check file encoding (should be UTF-8)

---

## Example `.env` File

```bash
# Supabase
SUPABASE_URL=https://gxllowlurizrkvpdircw.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Google OAuth
GOOGLE_OAUTH_CLIENT_ID=214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com
```

---

## Migration from Hardcoded Values

If you were using hardcoded values before:

1. **Extract values** from old code
2. **Create `.env` file** with those values
3. **Test locally** to ensure everything works
4. **Deploy** with environment variables set
5. **Verify** production is working

---

## Support

If you encounter issues:
1. Check this documentation
2. Review error messages carefully
3. Verify environment variables are set correctly
4. Check Supabase/Google Cloud Console for key validity

---

**Last Updated:** December 2025  
**Security Status:** ✅ Hardcoded credentials removed

