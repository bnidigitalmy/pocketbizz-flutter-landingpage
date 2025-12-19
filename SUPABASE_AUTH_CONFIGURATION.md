# 🔐 Supabase Authentication Configuration Guide

This guide shows how to configure Supabase Auth settings for enterprise-grade security.

---

## 📍 Accessing Auth Settings

1. Go to **Supabase Dashboard**: https://app.supabase.com
2. Select your project
3. Navigate to **Authentication** > **Settings**

---

## ⚙️ Recommended Settings

### **1. Email Confirmation**

**Location:** Authentication > Settings > Email Auth

**Recommended Settings:**

```
✅ Enable email confirmation
✅ Confirm email: Required (users must verify email before access)
✅ Secure email change: Enable
```

**Why:**
- Prevents fake accounts
- Reduces spam signups
- Ensures valid email addresses
- Better security

---

### **2. Magic Link Validity**

**Location:** Authentication > Settings > Magic Link

**Recommended Settings:**

```
✅ Enable magic links: Yes
✅ Link validity: 1 hour (3600 seconds)
✅ Max attempts per hour: 5
```

**Why:**
- Limits abuse
- Reduces security risk
- Prevents link sharing

---

### **3. Password Requirements**

**Location:** Authentication > Settings > Password

**Recommended Settings:**

```
✅ Minimum length: 8 characters
✅ Require uppercase: Yes
✅ Require lowercase: Yes
✅ Require numbers: Yes
✅ Require symbols: Optional (recommended: Yes)
```

**Why:**
- Stronger passwords = better security
- Reduces brute force risk
- Industry best practice

---

### **4. Rate Limiting**

**Location:** Authentication > Settings > Rate Limits

**Recommended Settings:**

```
✅ Login attempts: 5 per 15 minutes
✅ Password reset requests: 3 per hour
✅ Magic link requests: 5 per hour
✅ Email change requests: 3 per hour
```

**Why:**
- Prevents brute force attacks
- Reduces abuse
- Protects user accounts

---

### **5. Session Management**

**Location:** Authentication > Settings > Sessions

**Recommended Settings:**

```
✅ JWT expiry: 3600 seconds (1 hour)
✅ Refresh token rotation: Enable
✅ Refresh token reuse detection: Enable
```

**Why:**
- Better security
- Prevents token theft
- Industry best practice

---

### **6. CAPTCHA (Optional but Recommended)**

**Location:** Authentication > Settings > CAPTCHA

**If Available:**

```
✅ Enable CAPTCHA for:
  - Signup
  - Password reset
  - Magic link requests
  - Email change
```

**Why:**
- Prevents bot attacks
- Reduces spam
- Better security

---

### **7. OAuth Providers**

**Location:** Authentication > Providers

**For PocketBizz (Google OAuth already configured):**

```
✅ Google: Enabled (already configured)
✅ Email: Enabled (already configured)
❌ Facebook: Disabled (unless needed)
❌ Twitter: Disabled (unless needed)
```

**Why:**
- Only enable what you need
- Reduces attack surface
- Simpler configuration

---

## 🔒 Security Best Practices

### **✅ DO:**

- ✅ Enable email confirmation
- ✅ Set strong password requirements
- ✅ Enable rate limiting
- ✅ Use short JWT expiry (1 hour)
- ✅ Enable refresh token rotation
- ✅ Limit magic link validity
- ✅ Enable CAPTCHA if available

### **❌ DON'T:**

- ❌ Disable email confirmation (security risk)
- ❌ Allow weak passwords (security risk)
- ❌ Disable rate limiting (brute force risk)
- ❌ Use long JWT expiry (security risk)
- ❌ Share magic links (security risk)

---

## 📝 Configuration Checklist

- [ ] Email confirmation enabled
- [ ] Password requirements configured
- [ ] Rate limits configured
- [ ] Session management configured
- [ ] Magic link validity set
- [ ] CAPTCHA enabled (if available)
- [ ] OAuth providers configured correctly
- [ ] Test login flow
- [ ] Test password reset flow
- [ ] Test email confirmation flow

---

## 🧪 Testing

After configuring, test:

1. **Signup Flow:**
   - Create new account
   - Verify email confirmation works
   - Check rate limiting

2. **Login Flow:**
   - Test normal login
   - Test rate limiting (try 6+ failed logins)
   - Verify session expiry

3. **Password Reset:**
   - Request password reset
   - Verify email received
   - Check rate limiting

4. **Magic Link:**
   - Request magic link
   - Verify link expiry
   - Check rate limiting

---

## 📚 Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [OWASP Authentication Guide](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---

**Last Updated:** December 2025  
**Status:** ✅ Configuration Guide Ready

