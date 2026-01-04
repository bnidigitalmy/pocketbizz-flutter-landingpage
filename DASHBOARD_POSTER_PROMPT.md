# PocketBizz Dashboard - Poster Prompt (Ringkas)

## Visual Description untuk Poster Landing Page

### Hero Section - Today Snapshot
**Large card dengan soft gradient background (teal-50 → blue-50)**
- **4 metric tiles dalam 2x2 grid**:
  1. **Masuk Hari Ini** (RM) - Hijau, icon savings, besar & bold
  2. **Belanja Hari Ini** (RM) - Merah, icon payments
  3. **Untung Hari Ini** (RM) - Auto-calculated, hijau/merah based on value
  4. **Transaksi Hari Ini** (count) - Biru, icon shopping cart
- **Info badge**: "Termasuk tempahan & vendor"
- **Design**: White cards dengan subtle borders & shadows untuk contrast

---

### Key Sections (Visual Hierarchy)

#### 1. **Tindakan Segera** ⚡
Color-coded alert cards:
- Orange/Red badges untuk urgent items
- Pending bookings, POs, low stock alerts
- CTA buttons untuk setiap action

#### 2. **Stok Produk Siap Alert** 📦
**2-column alert card**:
- **Left**: "Hampir Habis" (≤5 unit) - Orange warning dengan product names
- **Right**: "Hampir Luput" (≤3 hari) - Red urgent dengan expiry dates
- Badge chips showing quantities/days

#### 3. **Cashflow Minggu Ini** 💰
**Clean white card dengan**:
- Icon: Waterfall chart (blue)
- **3 metrics**: Masuk | Belanja | Net (hijau/merah badge)
- Progress bar showing expense/inflow ratio
- Subtitle: "Ahad → Sabtu"

#### 4. **Top Produk Paling Laju** 🔥
**2 cards side-by-side** (atau stacked):
- **Left Card** (Orange accent): "Top Produk Hari Ini"
  - Ranked list (1, 2, 3) dengan product names
  - Quantity badges: "X unit"
- **Right Card** (Blue accent): "Top Produk Minggu Ini"
  - Same format, weekly data
- **Interactive**: Tappable rows (show tap state)

#### 5. **Cadangan Produksi** 🏭
**Purple accent card** (conditional):
- Factory icon
- Title + message text
- Large CTA button: "Mulakan Produksi"

#### 6. **Insight Ringkas** 💡
**Color-coded insight cards** (max 2):
- Orange/Red/Green backgrounds based on type
- Icon + bold title + message text
- Outlined button untuk action

#### 7. **Tindakan Pantas** ⚡
**3x2 grid dengan 6 action cards**:
1. Tambah Jualan (Blue)
2. Tambah Stok (Blue)
3. Produksi (Purple)
4. Penghantaran (Orange)
5. Belanja (Red)
6. Lain-lain (Teal) - opens modal

**Each card**: Icon dalam colored circle + label text

---

## Design Elements untuk Poster

### Color Palette
- **Primary Blue**: #3B82F6 (actions, primary elements)
- **Success Green**: #10B981 (untung, masuk, positive)
- **Warning Orange**: #F59E0B (alerts, hampir habis)
- **Critical Red**: #EF4444 (belanja, rugi, expiry)
- **Purple**: #8B5CF6 (production, premium)
- **Teal**: #14B8A6 (secondary actions)
- **Background**: #F9FAFB (light grey)
- **Card Background**: #FFFFFF (white)
- **Text Primary**: #111827 (dark grey)
- **Text Secondary**: #6B7280 (medium grey)

### Typography
- **Hero Numbers**: Bold, 22-24px
- **Section Titles**: Bold, 16-18px
- **Labels**: Semi-bold, 11-12px
- **Body**: Regular, 12-13px

### Spacing
- Card padding: 16-18px
- Card gaps: 16-20px
- Border radius: 14-20px (rounded, modern)
- Shadows: Soft, subtle elevation

### Icons Style
- Rounded, filled style
- Size: 20-24px untuk main icons
- Color-coded untuk visual hierarchy

---

## Key Visual Features untuk Highlight

1. **Gradient Hero Section** - Soft pastel background untuk Today Snapshot
2. **Color-Coded Alerts** - Immediate visual feedback (green/orange/red)
3. **Ranked Lists** - Numbered badges (1, 2, 3) untuk Top Products
4. **Progress Indicators** - Cashflow ratio bar
5. **Interactive Elements** - Tappable cards dengan hover/tap states
6. **Modal Overlay** - "Lain-lain" menu dengan smooth animation
7. **Badge Chips** - Quantity, expiry, status indicators

---

## Marketing Copy untuk Poster

### Headline
**"Dashboard yang Menjawab 5 Soalan Kritikal dalam 5 Saat"**

### Subheadline
**"Urus bisnes dari poket tanpa stress"**

### Key Points (Bullet List)
- ✅ **Lihat untung/rugi hari ini** dengan sekali pandang
- ✅ **Tahu produk paling laku** (hari ini & minggu ini)
- ✅ **Alert awal** untuk stok hampir habis atau luput
- ✅ **Cadangan produksi** berdasarkan data sebenar
- ✅ **Insight ringkas** untuk tindakan segera
- ✅ **Tindakan pantas** - semua fungsi penting dalam 1 tap

### CTA
**"Mulakan Percuma Sekarang"** atau **"Cuba Dashboard Sekarang"**

---

## Layout Suggestion untuk Poster

### Option 1: Hero-First
1. **Top**: Large Today Snapshot card (hero)
2. **Middle Left**: Tindakan Segera + Stock Alerts
3. **Middle Right**: Cashflow + Top Products
4. **Bottom**: Quick Actions grid (6 cards)

### Option 2: Feature Grid
1. **Top Row**: Today Snapshot (full width)
2. **Second Row**: 2-column (Cashflow | Top Products)
3. **Third Row**: 3-column (Alerts | Production | Insights)
4. **Bottom**: Quick Actions (6 cards grid)

### Option 3: Mobile-First Stack
1. Today Snapshot (hero)
2. Tindakan Segera
3. Stock Alerts
4. Cashflow
5. Top Products (stacked)
6. Production Suggestion
7. Insights
8. Quick Actions (3x2 grid)

---

## Technical Notes untuk Designer

- **Platform**: Flutter Web (responsive)
- **Breakpoint**: Mobile < 768px (cards stack)
- **Animation**: Pulse effect untuk focused items
- **Navigation**: Deep linking dengan focus states
- **Data**: Real-time updates, pull-to-refresh
- **Performance**: Parallel loading, optimized queries

---

## Call-to-Action Ideas

1. **"Lihat Demo Dashboard"** - Link ke interactive demo
2. **"Cuba Percuma 14 Hari"** - Trial signup
3. **"Daftar Sekarang"** - Direct registration
4. **"Lihat Features"** - Scroll to features section
5. **QR Code** - Link langsung ke app/web



