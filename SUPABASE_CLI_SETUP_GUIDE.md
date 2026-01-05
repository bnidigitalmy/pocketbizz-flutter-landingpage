# 🛠️ SUPABASE CLI SETUP GUIDE
**Date:** 2026-01-06  
**Purpose:** Setup Supabase CLI untuk upload landing page images

---

## 📦 INSTALLATION

### ⚠️ **IMPORTANT: npm global install NOT supported!**

**Error jika guna npm:**
```
npm error Installing Supabase CLI as a global module is not supported.
```

**Solution:** Guna package manager lain atau direct download.

---

### **Option 1: Via Scoop (Windows - Recommended)**

**Install Scoop first (if not installed):**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

**Then install Supabase CLI:**
```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

**Verify installation:**
```powershell
supabase --version
```

---

### **Option 2: Via Homebrew (macOS/Linux)**

```bash
brew install supabase/tap/supabase
```

**Verify installation:**
```bash
supabase --version
```

---

### **Option 3: Direct Download (Windows - Alternative)**

1. **Download latest release:**
   - Go to: https://github.com/supabase/cli/releases
   - Download: `supabase_X.X.X_windows_amd64.zip` (latest version)

2. **Extract:**
   - Extract to folder: `C:\supabase\` (or any folder)

3. **Add to PATH:**
   - Open **System Properties** > **Environment Variables**
   - Edit **Path** variable
   - Add: `C:\supabase` (or your extraction folder)
   - Click **OK**

4. **Verify:**
   ```powershell
   supabase --version
   ```

---

### **Option 4: Via Chocolatey (Windows - Alternative)**

```powershell
choco install supabase
```

**Note:** Requires Chocolatey installed first.

---

## 🔐 AUTHENTICATION

### **Step 1: Login to Supabase**

```bash
supabase login
```

**This will:**
1. Open browser untuk authentication
2. Redirect ke Supabase Dashboard
3. Generate access token
4. Save token locally

**Alternative (Manual Token):**
```bash
supabase login --token YOUR_ACCESS_TOKEN
```

**Get token from:** Supabase Dashboard > Account Settings > Access Tokens

---

### **Step 2: Link to Project**

```bash
supabase link --project-ref gxllowlurizrkvpdircw
```

**Or if you have `supabase/config.toml`:**
```bash
supabase link
```

---

## 📤 UPLOAD IMAGES TO STORAGE

### **Method 1: Upload Single File**

```bash
supabase storage upload landing-page/dashboard_baru.png ./landing/assets/images/dashboard_baru.png
```

---

### **Method 2: Upload Multiple Files (Batch)**

**Create upload script:**

**Windows (PowerShell):**
```powershell
# upload-landing-images.ps1
$images = @(
    "dashboard_baru.png",
    "produk_kos3.png",
    "delivery.png",
    "booking.png",
    "laporan2.png",
    "scan_resit.png",
    "Production2.png",
    "stok2.png",
    "sarapan_pagi_v2.png",
    "founder_pocketbizz.png"
)

foreach ($img in $images) {
    Write-Host "Uploading $img..."
    supabase storage upload "landing-page/$img" "landing/assets/images/$img"
    Write-Host "✅ $img uploaded"
}
```

**Run:**
```powershell
.\upload-landing-images.ps1
```

---

**Linux/macOS (Bash):**
```bash
#!/bin/bash
# upload-landing-images.sh

images=(
    "dashboard_baru.png"
    "produk_kos3.png"
    "delivery.png"
    "booking.png"
    "laporan2.png"
    "scan_resit.png"
    "Production2.png"
    "stok2.png"
    "sarapan_pagi_v2.png"
    "founder_pocketbizz.png"
)

for img in "${images[@]}"; do
    echo "Uploading $img..."
    supabase storage upload "landing-page/$img" "landing/assets/images/$img"
    echo "✅ $img uploaded"
done
```

**Run:**
```bash
chmod +x upload-landing-images.sh
./upload-landing-images.sh
```

---

### **Method 3: Upload Entire Folder**

```bash
# Upload all images from folder
supabase storage upload landing-page/ ./landing/assets/images/ --recursive
```

**Note:** This might upload all files including non-image files. Better to use selective upload.

---

## 🔍 VERIFY UPLOAD

### **List Files in Bucket**

```bash
supabase storage list landing-page
```

**Expected output:**
```
dashboard_baru.png
produk_kos3.png
delivery.png
...
```

---

### **Get Public URL**

```bash
# Get URL for specific file
supabase storage url landing-page/dashboard_baru.png
```

**Output:**
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/dashboard_baru.png
```

---

## 🧪 TESTING

### **Test 1: Check Authentication**

```bash
supabase projects list
```

**Expected:** List of your Supabase projects

---

### **Test 2: Check Storage Access**

```bash
supabase storage list landing-page
```

**Expected:** List of files in bucket (or empty if not uploaded yet)

---

### **Test 3: Upload Test File**

```bash
# Create test file
echo "test" > test.txt

# Upload
supabase storage upload landing-page/test.txt ./test.txt

# Verify
supabase storage list landing-page

# Delete test file
supabase storage remove landing-page/test.txt
```

---

## ⚠️ TROUBLESHOOTING

### **Issue: "command not found"**

**Solution:**
- Verify installation: `supabase --version`
- Check PATH environment variable
- Restart terminal
- **If using direct download:** Ensure extracted folder is in PATH

---

### **Issue: "npm global install not supported"**

**Error:**
```
npm error Installing Supabase CLI as a global module is not supported.
```

**Solution:**
- ❌ **Don't use:** `npm install -g supabase`
- ✅ **Use instead:**
  - Scoop: `scoop install supabase`
  - Direct download from GitHub releases
  - Chocolatey: `choco install supabase`

---

### **Issue: "not authenticated"**

**Solution:**
```bash
supabase login
```

---

### **Issue: "project not linked"**

**Solution:**
```bash
supabase link --project-ref gxllowlurizrkvpdircw
```

---

### **Issue: "bucket not found"**

**Solution:**
1. Create bucket via Supabase Dashboard first
2. Or create via CLI:
```bash
supabase storage create landing-page --public
```

---

### **Issue: "permission denied"**

**Solution:**
- Check RLS policies are set correctly
- Verify you're authenticated
- Check bucket is public (for public access)

---

## 📝 QUICK REFERENCE

### **Common Commands**

```bash
# Login
supabase login

# Link project
supabase link --project-ref gxllowlurizrkvpdircw

# List buckets
supabase storage list

# List files in bucket
supabase storage list landing-page

# Upload file
supabase storage upload landing-page/filename.png ./path/to/file.png

# Download file
supabase storage download landing-page/filename.png ./downloads/

# Remove file
supabase storage remove landing-page/filename.png

# Get public URL
supabase storage url landing-page/filename.png
```

---

## 🚀 QUICK START SCRIPT

**Create `upload-all-images.ps1`:**

```powershell
# Supabase CLI Upload Script for Landing Page Images
# Run: .\upload-all-images.ps1

Write-Host "🚀 Starting image upload to Supabase Storage..." -ForegroundColor Green

# Verify Supabase CLI is installed
try {
    $version = supabase --version
    Write-Host "✅ Supabase CLI found: $version" -ForegroundColor Green
} catch {
    Write-Host "❌ Supabase CLI not found. Install with: npm install -g supabase" -ForegroundColor Red
    exit 1
}

# Check if logged in
Write-Host "`n🔐 Checking authentication..." -ForegroundColor Yellow
try {
    supabase projects list | Out-Null
    Write-Host "✅ Authenticated" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Not authenticated. Running login..." -ForegroundColor Yellow
    supabase login
}

# Images to upload
$images = @(
    "dashboard_baru.png",
    "produk_kos3.png",
    "delivery.png",
    "booking.png",
    "laporan2.png",
    "scan_resit.png",
    "Production2.png",
    "stok2.png",
    "sarapan_pagi_v2.png",
    "founder_pocketbizz.png"
)

Write-Host "`n📤 Uploading images..." -ForegroundColor Yellow
$successCount = 0
$failCount = 0

foreach ($img in $images) {
    $sourcePath = "landing/assets/images/$img"
    $destPath = "landing-page/$img"
    
    if (Test-Path $sourcePath) {
        Write-Host "  Uploading $img..." -NoNewline
        try {
            supabase storage upload $destPath $sourcePath 2>&1 | Out-Null
            Write-Host " ✅" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host " ❌ Failed" -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "  ⚠️ File not found: $sourcePath" -ForegroundColor Yellow
        $failCount++
    }
}

Write-Host "`n📊 Upload Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $failCount" -ForegroundColor Red

if ($successCount -gt 0) {
    Write-Host "`n🔗 Public URLs:" -ForegroundColor Cyan
    Write-Host "  Base URL: https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/" -ForegroundColor Yellow
    Write-Host "`n✅ Upload complete! Update HTML paths now." -ForegroundColor Green
}
```

---

## ✅ VERIFICATION

After upload, verify:

1. **Check files in bucket:**
```bash
supabase storage list landing-page
```

2. **Test public URL:**
Open in browser:
```
https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/dashboard_baru.png
```

3. **Verify RLS policies:**
- Go to Supabase Dashboard > Storage > Policies
- Check 4 policies exist for `landing-page` bucket

---

## 🎯 NEXT STEPS

1. ✅ Install Supabase CLI
2. ✅ Login: `supabase login`
3. ✅ Link project: `supabase link --project-ref gxllowlurizrkvpdircw`
4. ✅ Upload images (use script above)
5. ✅ Verify uploads
6. ✅ Update HTML paths
7. ✅ Test landing page

---

**Verified By:** Corey (AI Assistant)  
**Date:** 2025-01-16  
**Status:** ✅ Setup Guide Complete

