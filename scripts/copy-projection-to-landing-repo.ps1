# Script to Copy Projection Page to Landing Page Repo
# Usage: .\scripts\copy-projection-to-landing-repo.ps1

Write-Host "🚀 Copying Projection Page to Landing Page Repo" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if landing repo exists
$landingRepoPath = "..\pocketbizz-flutter-landingpage"
$sourceFile = "landing\projection.html"
$destFile = "$landingRepoPath\projection.html"
$vercelJsonSource = "landing\vercel.json"
$vercelJsonDest = "$landingRepoPath\vercel.json"

# Check if source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ Error: Source file not found: $sourceFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please make sure you're running this script from the repo root." -ForegroundColor Yellow
    exit 1
}

# Check if landing repo exists
if (-not (Test-Path $landingRepoPath)) {
    Write-Host "⚠️  Landing page repo not found at: $landingRepoPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please choose an option:" -ForegroundColor Cyan
    Write-Host "1. Clone repo to parent folder:" -ForegroundColor White
    Write-Host "   cd .." -ForegroundColor Gray
    Write-Host "   git clone https://github.com/bnidigitalmy/pocketbizz-flutter-landingpage.git" -ForegroundColor Gray
    Write-Host "   cd Pocketbizz-V2-Encore-1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Or specify custom path:" -ForegroundColor White
    Write-Host "   Edit this script and change `$landingRepoPath variable" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "✅ Landing repo found at: $landingRepoPath" -ForegroundColor Green
Write-Host ""

# Step 2: Copy projection.html
Write-Host "📋 Step 1: Copying projection.html..." -ForegroundColor Cyan
try {
    Copy-Item -Path $sourceFile -Destination $destFile -Force
    Write-Host "   ✅ projection.html copied successfully" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error copying projection.html: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Update vercel.json (read current, update with rewrite rule)
Write-Host "📋 Step 2: Updating vercel.json..." -ForegroundColor Cyan

if (Test-Path $vercelJsonDest) {
    # Read existing vercel.json
    $vercelJson = Get-Content $vercelJsonDest -Raw | ConvertFrom-Json
    
    # Check if /projection rewrite already exists
    $hasProjectionRewrite = $vercelJson.rewrites | Where-Object { $_.source -eq "/projection" }
    
    if (-not $hasProjectionRewrite) {
        # Add /projection rewrite before catch-all rule
        $projectionRewrite = @{
            source = "/projection"
            destination = "/projection.html"
        }
        
        # Insert at index 0 (before catch-all)
        $rewrites = @($projectionRewrite) + $vercelJson.rewrites
        $vercelJson.rewrites = $rewrites
        
        # Convert back to JSON with proper formatting
        $jsonContent = $vercelJson | ConvertTo-Json -Depth 10
        $jsonContent = $jsonContent -replace '"([^"]+)":', '"$1":'  # Fix spacing
        
        # Write to file
        Set-Content -Path $vercelJsonDest -Value $jsonContent -NoNewline
        Write-Host "   ✅ vercel.json updated with /projection rewrite rule" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  /projection rewrite rule already exists in vercel.json" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠️  vercel.json not found, creating new one..." -ForegroundColor Yellow
    $newVercelJson = @{
        version = 2
        buildCommand = $null
        outputDirectory = "."
        devCommand = $null
        installCommand = $null
        framework = $null
        rewrites = @(
            @{
                source = "/projection"
                destination = "/projection.html"
            },
            @{
                source = "/(.*)"
                destination = "/index.html"
            }
        )
        headers = @(
            @{
                source = "/:path*"
                headers = @(
                    @{
                        key = "Cache-Control"
                        value = "public, max-age=3600, must-revalidate"
                    }
                )
            },
            @{
                source = "/:path*\.(png|jpg|jpeg|svg|gif|webp|ico)"
                headers = @(
                    @{
                        key = "Cache-Control"
                        value = "public, max-age=31536000, immutable"
                    }
                )
            }
        )
    }
    $jsonContent = $newVercelJson | ConvertTo-Json -Depth 10
    Set-Content -Path $vercelJsonDest -Value $jsonContent -NoNewline
    Write-Host "   ✅ Created new vercel.json with /projection rewrite rule" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Files copied and updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Go to landing repo folder:" -ForegroundColor White
Write-Host "      cd $landingRepoPath" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. Check changes:" -ForegroundColor White
Write-Host "      git status" -ForegroundColor Gray
Write-Host ""
Write-Host "   3. Commit and push:" -ForegroundColor White
Write-Host "      git add projection.html vercel.json" -ForegroundColor Gray
Write-Host "      git commit -m `"Add projection page: BNI Digital Enterprise 5-year revenue projection`"" -ForegroundColor Gray
Write-Host "      git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "   4. Vercel will auto-deploy in 1-2 minutes" -ForegroundColor White
Write-Host ""
Write-Host "   5. Test URL: https://pocketbizz.my/projection" -ForegroundColor Green
Write-Host ""
