# Setup PocketBizz Official Logo

## Logo File Location

Simpan logo PocketBizz image file di:
```
assets/images/logo.png
```

## Logo Specifications

- **Format:** PNG dengan transparent background (recommended) atau SVG
- **Size:** 
  - Logo icon: 512x512px (untuk high-res displays)
  - Logo dengan text: 1024x512px (optional)
- **Design:** 
  - Rounded square dengan gradient (teal/green to blue)
  - White checkmark shape di dalam
  - Modern, clean design

## Steps to Add Logo

1. **Create assets folder:**
   ```bash
   mkdir -p assets/images
   ```

2. **Copy logo file:**
   - Copy logo image ke `assets/images/logo.png`
   - Atau `assets/images/logo.svg` jika guna SVG

3. **Update pubspec.yaml:**
   - Assets sudah ditambah dalam `pubspec.yaml`
   - Run `flutter pub get` untuk refresh

4. **Verify:**
   - Logo akan auto display dalam drawer header
   - Logo widget boleh digunakan di mana-mana: `PocketBizzLogo()`

## Current Implementation

Logo widget sudah dibuat dan digunakan dalam:
- ✅ Drawer header (home page)
- ✅ Logo widget component (`lib/core/widgets/pocketbizz_logo.dart`)

## Using Logo Widget

```dart
// Simple logo
PocketBizzLogo(size: 48)

// Logo with text
PocketBizzLogo(size: 64, showText: true)

// Full brand (logo + text below)
PocketBizzBrand(logoSize: 80)
```

## Theme Colors Updated

Theme colors sudah di-update untuk match dengan logo:
- **Primary:** Teal (#14B8A6) - logo top color
- **Accent:** Blue (#3B82F6) - logo bottom color
- **Gradient:** Teal to Blue (matches logo gradient)

