# 🚀 Deploy Projection Page ke Landing Page Repo

## 📋 Yang Perlu Dibuat

Landing page guna repo berasingan: https://github.com/bnidigitalmy/pocketbizz-flutter-landingpage

## 🎯 Langkah-langkah:

### Step 1: Clone atau Update Repo Landing Page

```bash
# Jika belum clone
git clone https://github.com/bnidigitalmy/pocketbizz-flutter-landingpage.git
cd pocketbizz-flutter-landingpage

# Atau jika dah ada, just pull latest
git pull origin main
```

### Step 2: Copy File projection.html

Copy file `projection.html` dari folder `landing/` dalam repo utama ke repo landing page:

```bash
# Dari repo utama, copy file
# File location: landing/projection.html
# Copy ke: pocketbizz-flutter-landingpage/projection.html
```

**Atau manual:**
1. Buka `landing/projection.html` dari repo utama
2. Copy semua content
3. Create file baru `projection.html` dalam repo landing page
4. Paste content

### Step 3: Update vercel.json

Update `vercel.json` dalam repo landing page dengan rewrite rule:

```json
{
  "version": 2,
  "buildCommand": null,
  "outputDirectory": ".",
  "devCommand": null,
  "installCommand": null,
  "framework": null,
  "rewrites": [
    {
      "source": "/projection",
      "destination": "/projection.html"
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/:path*",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=3600, must-revalidate"
        }
      ]
    },
    {
      "source": "/:path*\\.(png|jpg|jpeg|svg|gif|webp|ico)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

**Important:** Pastikan rewrite rule untuk `/projection` ada **SEBELUM** catch-all rule `/(.*)`.

### Step 4: Commit dan Push

```bash
git add projection.html vercel.json
git commit -m "Add projection page: BNI Digital Enterprise 5-year revenue projection"
git push origin main
```

### Step 5: Vercel Auto-Deploy

Vercel akan auto-detect push dan deploy dalam 1-2 minit.

## ✅ Selepas Deploy

Projection page akan accessible di:
- **https://pocketbizz.my/projection**

## 📝 Files yang Perlu Di-Update

1. ✅ `projection.html` - File baru (copy dari repo utama)
2. ✅ `vercel.json` - Update dengan rewrite rule untuk `/projection`

## 🔍 Verify Deployment

1. Check Vercel Dashboard: https://vercel.com
2. Pilih project untuk landing page
3. Tengok deployment status
4. Test URL: https://pocketbizz.my/projection

---

**Note:** File `projection.html` dah ready dalam repo utama di `landing/projection.html`. Just copy ke repo landing page.
