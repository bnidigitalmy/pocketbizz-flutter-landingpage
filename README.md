# PocketBizz Landing Page

Static HTML landing page for PocketBizz - deployed to Vercel.

## Structure

```
.
├── index.html              # Main landing page
├── favicon.png            # Favicon
├── site.webmanifest       # PWA manifest
├── transparentlogo2.png   # Logo
├── vercel.json            # Vercel deployment config
└── assets/
    └── images/           # All feature screenshots and images
```

## Deployment

This is a static HTML site deployed to Vercel. No build process required.

### Vercel Configuration

- Framework: None (Static HTML)
- Build Command: None
- Output Directory: `.` (root)
- Install Command: None

### Features

- Fully responsive design
- SEO optimized
- PWA ready
- All images optimized
- Fast loading with CDN

## Local Development

Simply open `index.html` in a browser or use a local server:

```bash
# Using Python
python -m http.server 8000

# Using Node.js
npx serve
```

Then visit `http://localhost:8000`

## Assets

All images are in `assets/images/` folder:
- Dashboard screenshots
- Feature screenshots
- Founder image
- Comparison images

## Notes

- This is a pure static HTML site (no Next.js, no Encore)
- Uses Tailwind CSS via CDN
- Uses Lucide icons via CDN
- All paths are relative
