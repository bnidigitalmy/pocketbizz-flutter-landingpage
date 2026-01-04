# PocketBizz Dashboard - Deskripsi untuk Landing Page Poster

## Konsep Utama
**"Urus bisnes dari poket tanpa stress"** - Dashboard yang menjawab 5 soalan kritikal dalam 5 saat:
1. **Hari ni untung ke rugi?**
2. **Stok aku cukup ke nak jual?**
3. **Perlu buat production tak hari ni?**
4. **Produk mana paling laju?**
5. **Ada masalah kritikal tak sekarang?**

---

## Struktur Dashboard (Action-First Flow)

### 1. **Today Snapshot Hero** 🎯
**Lokasi**: Atas sekali, hero section dengan gradient pastel lembut

**4 Metrik Utama**:
- **Masuk Hari Ini** (RM) - Hijau, icon savings
  - Termasuk: Jualan langsung + Tempahan siap + Consignment settled
- **Belanja Hari Ini** (RM) - Merah, icon payments
  - Semua expenses untuk hari ini
- **Untung Hari Ini** (RM) - Auto-calculated (Masuk - Belanja)
  - Hijau jika positif, merah jika negatif
  - Formula: Masuk - Belanja (tanpa COGS)
- **Transaksi Hari Ini** (count) - Biru, icon shopping cart
  - Bilangan jualan + tempahan siap

**Design**: 
- Background: Soft gradient (teal-50 → blue-50)
- Cards: Putih dengan border & shadow untuk contrast
- Info badge: "Termasuk tempahan & vendor"

---

### 2. **Tindakan Segera** ⚡
**Lokasi**: Segera selepas Today Snapshot

**Alert Cards**:
- Tempahan pending (jika ada)
- Purchase Orders pending (jika ada)
- Low stock bahan mentah (jika ada)

**Design**: Color-coded alerts dengan CTA buttons

---

### 3. **Stok Produk Siap - Alert Awal** 📦
**Lokasi**: Selepas Tindakan Segera

**2 Kategori Alert**:
- **Hampir Habis** (≤ 5 unit) - Orange warning
  - Top 3 produk dengan stok paling rendah
- **Hampir Luput** (≤ 3 hari) - Red urgent
  - Top 3 produk dengan expiry terdekat

**Design**: 
- Card putih dengan section headers berwarna
- Badge untuk quantity/expiry date
- CTA: "Lihat Stok" button

---

### 4. **Cashflow Minggu Ini** 💰
**Lokasi**: Selepas stock alerts

**Metrik**:
- **Masuk Minggu Ini** (Ahad → Sabtu)
- **Belanja Minggu Ini** (Ahad → Sabtu)
- **Net Minggu Ini** (Masuk - Belanja)
  - Badge hijau jika positif, merah jika negatif

**Design**:
- Card putih dengan icon waterfall chart
- Progress bar menunjukkan ratio belanja/masuk
- Tip text di bawah untuk guidance

---

### 5. **Top Produk Paling Laju** 🔥
**Lokasi**: Selepas cashflow

**2 Cards Side-by-Side** (atau stacked di mobile):
- **Top Produk Hari Ini** - Orange accent
  - Top 3 ikut kuantiti (unit) terjual
  - Cross-platform: Sales + Bookings + Consignment
- **Top Produk Minggu Ini** - Blue accent
  - Top 3 ikut kuantiti (unit) untuk minggu (Ahad-Sabtu)

**Design**:
- Ranked list dengan numbered badges (1, 2, 3)
- Product name + quantity badge
- **Tappable**: Tap product → navigate ke "Stok Siap" dengan highlight & pulse animation

---

### 6. **Cadangan Produksi** 🏭
**Lokasi**: Selepas Top Produk (conditional - hanya muncul jika ada suggestion)

**Logic**: Rule-based (bukan AI)
- Analisis top-selling products
- Check finished product stock levels
- Suggest production jika stock rendah

**Design**:
- Purple accent card
- Factory icon
- CTA: "Mulakan Produksi" button

---

### 7. **Insight Ringkas** 💡
**Lokasi**: Selepas production suggestion

**Smart Insights** (Rule-based, max 2):
- "Belum ada jualan hari ini" → CTA: Buat Jualan
- "Belanja melebihi masuk" → CTA: Semak Belanja
- "Net minggu ini negatif" → CTA: Lihat Jualan
- "Produk paling perform hari ini" → CTA: Semak Stok Siap

**Design**:
- Color-coded insight cards (orange/red/green)
- Icon + title + message + action button
- Snackable format (max 2 insights)

---

### 8. **Tindakan Pantas** ⚡
**Lokasi**: Selepas insights

**6 Primary Actions** (3x2 grid):
1. **Tambah Jualan** - Biru primary
2. **Tambah Stok** - Biru
3. **Produksi** - Purple
4. **Penghantaran** - Orange
5. **Belanja** - Merah
6. **Lain-lain** - Teal (opens modal)

**"Lain-lain" Modal** (Bottom sheet):
- Grid layout dengan additional actions:
  - Scan Resit
  - Tempahan
  - PO
  - Tuntutan
  - Laporan
  - Dokumen
  - Komuniti
  - Langganan
  - Tetapan

**Design**:
- Card-based grid dengan icon + label
- Color-coded untuk visual hierarchy
- Modal dengan smooth animation

---

### 9. **Sales by Channel** 📊
**Lokasi**: Selepas quick actions

**Breakdown**: Jualan mengikut channel (jika ada data)
- Direct Sales
- Bookings
- Consignment

**Design**: Chart/visualization card

---

### 10. **Planner Today** 📅
**Lokasi**: Bawah sekali

**Mini widget**: Tasks/reminders untuk hari ini
- CTA: "View All" → navigate ke full planner

---

## Design Principles

### Visual Hierarchy
1. **Hero Section**: Today Snapshot dengan gradient background
2. **Urgent Actions**: Color-coded alerts (red/orange)
3. **Performance Metrics**: Cashflow & Top Products
4. **Smart Suggestions**: Production & Insights
5. **Quick Actions**: Primary actions grid
6. **Supporting Data**: Sales by channel, planner

### Color System
- **Success/Positive**: Green (untung, masuk, OK status)
- **Warning/Urgent**: Orange (low stock, hampir habis)
- **Critical/Negative**: Red (belanja, rugi, expiry)
- **Primary Actions**: Blue/Purple
- **Neutral/Info**: Grey/Teal

### Typography
- **Hero Numbers**: Bold, large (18-22px)
- **Labels**: Medium weight, smaller (11-12px)
- **Section Titles**: Bold, 16px
- **Body Text**: Regular, 12-13px

### Spacing & Layout
- **Card Padding**: 16-18px
- **Card Spacing**: 16-20px vertical
- **Border Radius**: 14-20px (rounded, modern)
- **Shadows**: Soft, subtle (elevation untuk depth)

---

## Key Features Highlight

### ✅ Cross-Platform Aggregation
- Top Products combines data dari Sales + Bookings + Consignment
- Today Metrics includes semua revenue sources

### ✅ Real-Time Updates
- Auto-refresh on page focus
- Pull-to-refresh support
- Live notifications badge

### ✅ Action-First Design
- Critical actions visible immediately
- One-tap navigation ke relevant pages
- Smart CTAs based on current state

### ✅ Smart Navigation
- Tap Top Product → Auto-scroll & highlight di "Stok Siap" page
- Pulse animation untuk draw attention
- Focus color matches dashboard accent

### ✅ Rule-Based Intelligence
- Production suggestions (bukan AI, tapi logic-based)
- Smart insights based on metrics
- Alerts untuk critical thresholds

### ✅ Mobile-First Responsive
- Grid layouts adapt to screen size
- Cards stack vertically di mobile
- Touch-optimized button sizes

---

## User Experience Flow

1. **Open App** → See Today Snapshot immediately
2. **Check Urgent** → Review alerts & pending tasks
3. **Review Stock** → Check finished products & raw materials
4. **Analyze Performance** → View cashflow & top products
5. **Take Action** → Use quick actions atau follow insights
6. **Deep Dive** → Navigate to detailed pages as needed

---

## Technical Highlights

- **Fast Loading**: Parallel data fetching dengan `Future.wait`
- **Optimized Queries**: Aggregated data dari multiple sources
- **Type-Safe**: Full TypeScript/Flutter type safety
- **Error Handling**: Graceful degradation jika data unavailable
- **Performance**: Debounced updates, efficient re-renders

---

## Marketing Message

**"Dashboard yang menjawab soalan bisnes anda dalam 5 saat"**

- ✅ Lihat untung/rugi hari ini dengan sekali pandang
- ✅ Tahu produk mana paling laku (hari ini & minggu ini)
- ✅ Alert awal untuk stok hampir habis atau luput
- ✅ Cadangan produksi berdasarkan data sebenar
- ✅ Insight ringkas untuk tindakan segera
- ✅ Tindakan pantas - semua fungsi penting dalam 1 tap

**"Urus bisnes dari poket tanpa stress"** 🚀



