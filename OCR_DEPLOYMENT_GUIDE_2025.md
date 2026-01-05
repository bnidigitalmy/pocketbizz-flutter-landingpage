# 🚀 OCR CLOUD VISION - DEPLOYMENT GUIDE
**Date:** 2025-01-16  
**Function:** `OCR-Cloud-Vision`  
**Status:** ✅ Ready to Deploy

---

## 📋 DEPLOYMENT OPTIONS

### Option 1: Supabase Dashboard (Recommended - Fastest) ⚡

**Steps:**

1. **Go to Supabase Dashboard**
   - URL: https://app.supabase.com
   - Select your PocketBizz project

2. **Navigate to Edge Functions**
   - Click **Edge Functions** in left sidebar
   - Or go to: **Project Settings** → **Edge Functions**

3. **Update Existing Function**
   - Find `OCR-Cloud-Vision` function
   - Click **Edit** or **Update**

4. **Copy Updated Code**
   - Open: `supabase/functions/OCR-Cloud-Vision/index.ts`
   - Copy **ALL** code (Ctrl+A, Ctrl+C)
   - Paste into Supabase Dashboard editor

5. **Verify Environment Variables**
   - Check these are set:
     - `GOOGLE_CLOUD_API_KEY` ✅
     - `SUPABASE_URL` ✅
     - `SUPABASE_SERVICE_ROLE_KEY` ✅

6. **Deploy**
   - Click **Deploy** button
   - Wait for deployment to complete (~30 seconds)
   - Check for ✅ Success message

7. **Test Deployment**
   - Use **Invoke Function** button
   - Test with sample payload:
   ```json
   {
     "imageBase64": "<base64_encoded_test_image>",
     "uploadImage": true
   }
   ```

---

### Option 2: Supabase CLI (If CLI Installed)

**Install CLI (if needed):**
```powershell
# Using Scoop (recommended for Windows)
scoop install supabase

# Or using npm
npm install -g supabase
```

**Deploy:**
```powershell
# Login to Supabase
supabase login

# Link to project (if not already linked)
supabase link --project-ref <your-project-ref>

# Deploy function
supabase functions deploy OCR-Cloud-Vision
```

---

## ✅ PRE-DEPLOYMENT CHECKLIST

- [x] Code updated with all improvements
- [x] Unit tests passed (16/16)
- [ ] Environment variables configured
- [ ] Function code reviewed
- [ ] Ready to deploy

---

## 🔍 POST-DEPLOYMENT VERIFICATION

### 1. Check Function Status
- Go to **Edge Functions** → `OCR-Cloud-Vision`
- Status should be: ✅ **Active**

### 2. Test with Sample Request

**Using Supabase Dashboard:**
- Click **Invoke Function**
- Use test payload:
```json
{
  "imageBase64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "uploadImage": true
}
```

**Expected Response:**
```json
{
  "success": true,
  "rawText": "...",
  "parsed": {
    "amount": null,
    "date": null,
    "merchant": null,
    "items": [],
    "rawText": "...",
    "category": "lain",
    "amountSource": null,
    "confidence": 0.0
  },
  "storagePath": null
}
```

### 3. Test Improvements

**Test Case 1: Thousand Separator**
```json
// Use receipt image with "TOTAL RM 1,234.50"
// Expected: amount = 1234.50, source = "total", confidence = 0.95
```

**Test Case 2: CASH Exclusion**
```json
// Use receipt with CASH on separate line
// Expected: CASH amount ignored, TOTAL used
```

**Test Case 3: Confidence Score**
```json
// Verify confidence field in response
// Expected: 0.95 (high), 0.8 (medium), or 0.6 (low)
```

---

## 🐛 TROUBLESHOOTING

### Issue: Function deployment fails

**Solution:**
1. Check code syntax (no TypeScript errors)
2. Verify all imports are correct
3. Check environment variables are set
4. Review deployment logs for errors

### Issue: Function returns error

**Solution:**
1. Check function logs in Supabase Dashboard
2. Verify `GOOGLE_CLOUD_API_KEY` is valid
3. Check `SUPABASE_SERVICE_ROLE_KEY` has correct permissions
4. Review error message in response

### Issue: Amount parsing incorrect

**Solution:**
1. Check OCR text output (`rawText` field)
2. Verify receipt format matches expected patterns
3. Review `amountSource` and `confidence` values
4. Check function logs for parsing details

---

## 📊 DEPLOYMENT CHECKLIST

- [ ] Code deployed to Supabase
- [ ] Function status: Active
- [ ] Environment variables verified
- [ ] Test request successful
- [ ] Improvements verified:
  - [ ] Thousand separator format works
  - [ ] CASH exclusion works
  - [ ] Confidence score included
- [ ] Function logs reviewed (no errors)
- [ ] Ready for production use

---

## 🎯 NEXT STEPS AFTER DEPLOYMENT

1. **Monitor Function Logs**
   - Check for any errors
   - Monitor response times
   - Review confidence score distribution

2. **Test with Real Receipts**
   - Test with 5-10 actual Malaysian receipts
   - Verify amount parsing accuracy
   - Check CASH exclusion working

3. **Update Flutter App (if needed)**
   - Verify app handles new `confidence` field
   - Add UI indicators for confidence levels (optional)
   - Test end-to-end flow

4. **Monitor Production Usage**
   - Track OCR usage
   - Monitor Google Cloud Vision API costs
   - Review user feedback

---

## 📝 DEPLOYMENT NOTES

**Changes Deployed:**
1. ✅ Thousand separator format support (`1,234.50`)
2. ✅ Payment context window (skip CASH lines)
3. ✅ TOTAL lock mechanism
4. ✅ Confidence score calculation
5. ✅ Simplified code (removed redundant check)

**Backward Compatibility:**
- ✅ Existing API response format unchanged
- ✅ `confidence` field is optional
- ✅ No breaking changes

---

**Deployment Guide Created:** 2025-01-16  
**Status:** ✅ Ready to Deploy  
**Next:** Follow steps above to deploy via Supabase Dashboard

