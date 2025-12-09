# Vercel Deployment Guide untuk Landing Page

## Option 1: Deploy dari Subdirectory (Recommended - Guna Repo Sama)

Ini cara paling mudah - deploy `landing` folder dari repo yang sama.

### Langkah-langkah:

1. **Pergi ke Vercel Dashboard**
   - Login ke https://vercel.com
   - Klik "Add New Project"

2. **Import Repository**
   - Pilih repo `pocketbizz-flutter` (atau repo yang sesuai)
   - Klik "Import"

3. **Configure Project Settings**
   - **Root Directory**: Pilih `landing` (bukan root!)
   - **Framework Preset**: Pilih "Other" atau "Static HTML"
   - **Build Command**: Kosongkan (tiada build step)
   - **Output Directory**: `.` (current directory)
   - **Install Command**: Kosongkan

4. **Environment Variables** (jika perlu)
   - Tambah environment variables jika ada

5. **Deploy**
   - Klik "Deploy"
   - Vercel akan deploy `landing/index.html` dan semua assets

6. **Custom Domain** (Optional)
   - Pergi ke Project Settings > Domains
   - Tambah `pocketbizz.my` atau domain lain

### Kelebihan:
- ✅ Semua code dalam satu repo
- ✅ Mudah maintain
- ✅ Auto-deploy setiap kali push ke main branch
- ✅ Free tier cukup untuk static site

---

## Option 2: Buat Repo Baru untuk Landing Page

Kalau nak pisahkan landing page ke repo sendiri.

### Langkah-langkah:

1. **Buat Repo Baru di GitHub**
   ```bash
   # Di folder landing
   git init
   git add .
   git commit -m "Initial commit: Landing page"
   git branch -M main
   git remote add origin https://github.com/username/pocketbizz-landing.git
   git push -u origin main
   ```

2. **Deploy ke Vercel**
   - Import repo baru dari Vercel
   - Framework: "Other" atau "Static HTML"
   - Root Directory: `.` (root)
   - Deploy!

### Kelebihan:
- ✅ Repo lebih clean (landing page sahaja)
- ✅ Boleh deploy secara berasingan
- ✅ Team lain boleh contribute tanpa access ke main repo

### Kekurangan:
- ❌ Kena maintain 2 repos
- ❌ Kena sync changes manually kalau ada shared assets

---

## Recommended: Option 1

Saya recommend **Option 1** sebab:
- Landing page ni simple static HTML
- Tak perlu repo berasingan
- Mudah maintain dalam satu repo
- Auto-deploy setiap kali update landing page

## Setup Vercel untuk Option 1:

1. File `vercel.json` dah ada dalam `landing/` folder
2. Bila import project di Vercel, pastikan:
   - **Root Directory**: `landing`
   - **Framework**: "Other"
   - **Build Command**: (kosong)
   - **Output Directory**: `.`

## Custom Domain Setup:

1. Di Vercel Project Settings > Domains
2. Tambah domain `pocketbizz.my`
3. Vercel akan bagi DNS records untuk configure
4. Update DNS di domain provider (Namecheap, GoDaddy, etc.)

## Auto-Deploy:

Setiap kali push ke `main` branch, Vercel akan auto-deploy landing page!

