# Supabase CLI Upload Script for Landing Page Images
# Run: .\scripts\upload-landing-images.ps1

Write-Host "🚀 Starting image upload to Supabase Storage..." -ForegroundColor Green

# Verify Supabase CLI is installed
try {
    $version = supabase --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Supabase CLI found: $version" -ForegroundColor Green
    } else {
        throw "Supabase CLI not found"
    }
} catch {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "`n📦 Installation Options:" -ForegroundColor Yellow
    Write-Host "   1. Scoop (Recommended):" -ForegroundColor White
    Write-Host "      scoop bucket add supabase https://github.com/supabase/scoop-bucket.git" -ForegroundColor Gray
    Write-Host "      scoop install supabase" -ForegroundColor Gray
    Write-Host "`n   2. Direct Download:" -ForegroundColor White
    Write-Host "      Download from: https://github.com/supabase/cli/releases" -ForegroundColor Gray
    Write-Host "      Extract and add to PATH" -ForegroundColor Gray
    Write-Host "`n   3. Chocolatey:" -ForegroundColor White
    Write-Host "      choco install supabase" -ForegroundColor Gray
    Write-Host "`n⚠️  Note: npm install -g supabase is NOT supported!" -ForegroundColor Yellow
    exit 1
}

# Check if logged in
Write-Host "`n🔐 Checking authentication..." -ForegroundColor Yellow
try {
    $projects = supabase projects list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Authenticated" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Not authenticated. Running login..." -ForegroundColor Yellow
        supabase login
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Login failed. Please login manually: supabase login" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "⚠️ Not authenticated. Running login..." -ForegroundColor Yellow
    supabase login
}

# Link to project if not linked
Write-Host "`n🔗 Checking project link..." -ForegroundColor Yellow
try {
    supabase projects list 2>&1 | Out-Null
    Write-Host "✅ Project linked" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Project not linked. Linking..." -ForegroundColor Yellow
    supabase link --project-ref gxllowlurizrkvpdircw
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Link failed. Please link manually: supabase link --project-ref gxllowlurizrkvpdircw" -ForegroundColor Red
        exit 1
    }
}

# Images to upload (10 images used in landing/index.html)
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

Write-Host "`n📤 Uploading images to landing-page bucket..." -ForegroundColor Yellow
$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($img in $images) {
    $sourcePath = "landing/assets/images/$img"
    $destPath = "landing-page/$img"
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  ⚠️ File not found: $sourcePath" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    Write-Host "  Uploading $img..." -NoNewline
    try {
        $output = supabase storage upload $destPath $sourcePath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✅" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " ❌ Failed: $output" -ForegroundColor Red
            $failCount++
        }
    } catch {
        Write-Host " ❌ Error: $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n📊 Upload Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $failCount" -ForegroundColor Red
Write-Host "  ⚠️ Skipped: $skippedCount" -ForegroundColor Yellow

if ($successCount -gt 0) {
    Write-Host "`n🔗 Public URLs (Base):" -ForegroundColor Cyan
    Write-Host "  https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/public/landing-page/" -ForegroundColor Yellow
    
    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Verify images in Supabase Dashboard > Storage > landing-page" -ForegroundColor White
    Write-Host "  2. Test URLs in browser" -ForegroundColor White
    Write-Host "  3. Update HTML paths in landing/index.html" -ForegroundColor White
    Write-Host "  4. Test landing page" -ForegroundColor White
    
    Write-Host "`n✅ Upload complete!" -ForegroundColor Green
} else {
    Write-Host "`n❌ No images uploaded. Please check errors above." -ForegroundColor Red
}

