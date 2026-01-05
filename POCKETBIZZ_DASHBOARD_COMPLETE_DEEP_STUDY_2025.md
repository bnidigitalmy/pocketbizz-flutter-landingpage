# 📊 POCKETBIZZ DASHBOARD - COMPLETE DEEP STUDY 2025
## Full Comprehensive Analysis: Architecture, Features, UI/UX, Data Flow & Implementation

**Date:** 2025-01-16  
**Version:** V2 (Optimized Dashboard)  
**Concept:** "Urus bisnes dari poket tanpa stress"  
**Target Audience:** Malaysian SME Owners (F&B, Retail, Small Manufacturing)  
**Design Goal:** First app SME owners check every morning

---

## 📋 EXECUTIVE SUMMARY

### Dashboard Overview
The PocketBizz Dashboard is a comprehensive, adaptive business management interface designed specifically for Malaysian SMEs. It provides real-time financial insights, actionable suggestions, urgent alerts, and quick access to all business operations in a single, intuitive, mobile-first view.

### Key Design Philosophy
1. **"Tenang bila boleh, tegas bila perlu"** - Calm when possible, firm when needed
2. **Action-First Approach** - Urgent items appear first, quick actions are prominent
3. **Minimal Cognitive Load** - Information hierarchy reduces stress
4. **Adaptive UX** - Content adapts to time of day and business state
5. **Coach-Style Messaging** - Supportive, encouraging, not bossy (BM santai)

### Core Metrics Displayed
- **Today:** Masuk (Inflow), Belanja (Expense), Untung (Profit), Transaksi (Transactions)
- **Week:** Cashflow (Ahad–Sabtu), Top Products
- **Alerts:** Low Stock, Expiring Products, Pending Orders
- **Insights:** Smart suggestions based on business data

---

## 🏗️ ARCHITECTURE & STRUCTURE

### File Organization
```
lib/features/dashboard/
├── domain/
│   ├── dashboard_models.dart              # Legacy models (deprecated)
│   ├── sme_dashboard_v2_models.dart       # V2 data models (active)
│   ├── dashboard_mood_engine.dart         # Adaptive mood/tone engine
│   └── dashboard_ux_copy.dart             # Coach-style UX copy helper
├── presentation/
│   ├── dashboard_page_optimized.dart      # Main dashboard page (active)
│   ├── dashboard_page_simple.dart         # Alternative simple view (legacy)
│   ├── home_page.dart                     # Main scaffold with navigation
│   └── widgets/
│       ├── morning_briefing_card.dart     # Adaptive greeting card
│       ├── urgent_actions_widget.dart     # Urgent tasks widget
│       ├── smart_suggestions_widget.dart  # Legacy suggestions (deprecated)
│       ├── quick_action_grid.dart         # Legacy quick actions (deprecated)
│       ├── low_stock_alerts_widget.dart   # Raw material stock alerts
│       ├── sales_by_channel_card.dart     # Sales breakdown by channel
│       ├── today_performance_card.dart    # Legacy performance card (deprecated)
│       └── v2/                            # V2 Widgets (Latest - Active)
│           ├── today_snapshot_hero_v2.dart        # Today's metrics (Masuk/Belanja/Untung/Transaksi)
│           ├── primary_quick_actions_v2.dart      # Quick action buttons
│           ├── finished_products_alerts_v2.dart   # Finished products stock alerts
│           ├── smart_insights_card_v2.dart        # Smart suggestions (adaptive)
│           ├── weekly_cashflow_card_v2.dart       # Weekly cashflow (Ahad–Sabtu)
│           ├── top_products_cards_v2.dart         # Top products (today & week)
│           ├── production_suggestion_card_v2.dart # Production suggestions
│           └── dashboard_v2_format.dart           # Formatting utilities
└── services/
    └── sme_dashboard_v2_service.dart      # Data aggregation service
```

### Component Hierarchy
```
HomePage (Main Scaffold with Bottom Navigation)
└── DashboardPageOptimized (StatefulWidget)
    ├── AppBar
    │   ├── Menu Button (opens drawer)
    │   ├── Title: "PocketBizz" + Date
    │   └── Notifications Icon (with badge)
    └── Body (ListView with RefreshIndicator)
        ├── [Conditional] Subscription Expiring Alert
        ├── Morning Briefing Card (Adaptive greeting)
        ├── Today Snapshot Hero V2 (Masuk/Belanja/Untung/Transaksi)
        ├── Primary Quick Actions V2 (5 main actions + "Lain-lain")
        ├── [Conditional] Sales by Channel Card
        ├── Planner Today Card (today's tasks)
        ├── Urgent Actions Widget (pending bookings, POs, low stock)
        ├── Finished Products Alerts V2 (low stock, expiring)
        ├── Low Stock Alerts Widget (raw materials)
        ├── Weekly Cashflow Card V2 (Ahad–Sabtu)
        ├── Top Products Cards V2 (today & week)
        ├── [Conditional] Production Suggestion Card V2
        └── [Conditional] Smart Insights Card V2 (adaptive suggestions)
```

### Data Flow
```
User Opens Dashboard
    ↓
DashboardPageOptimized.initState()
    ↓
_loadAllData() [Parallel Loading]
    ├── PlannerAutoService.runAll() (auto-task generation)
    ├── BookingsRepository.getStatistics()
    ├── _loadPendingTasks() → PurchaseOrderRepository + StockRepository
    ├── _loadSalesByChannel() → ReportsRepository
    ├── SubscriptionService.getCurrentSubscription()
    ├── BusinessProfileRepository.getBusinessProfile()
    └── SmeDashboardV2Service.load() [Main V2 Data]
        ├── _loadInflowAndTransactions() [Sales + Bookings + Claims]
        ├── _loadExpenseTotal() [Expenses table]
        ├── _loadTopProducts() [Cross-channel aggregation]
        └── _buildProductionSuggestion() [Rule-based logic]
    ↓
_loadUnreadNotifications() [After subscription loaded]
    ↓
setState() → UI Updates
```

---

## 🎨 UI/UX DESIGN SYSTEM

### Color Palette (AppColors)
```dart
Primary Colors:
- Primary: #14B8A6 (Vibrant Teal - main brand color)
- Primary Dark: #0D9488
- Primary Light: #2DD4BF
- Accent: #3B82F6 (Bright Blue)

Status Colors:
- Success: #14B8A6 (Teal)
- Warning: #F59E0B (Amber/Orange)
- Error: #EF4444 (Red)
- Info: #3B82F6 (Blue)

Neutral Colors:
- Background: #F9FAFB (Very light grey)
- Surface: White (#FFFFFF)
- Text Primary: #1F2937 (Deep charcoal)
- Text Secondary: #6B7280 (Medium grey)

Mood-Based Colors (DashboardMoodEngine):
- Calm (Morning): #60A5FA (Soft blue)
- Focused (Afternoon): #3B82F6 (Bright blue)
- Reflective (Evening): #8B5CF6 (Soft purple)
- Urgent: #EF4444 (Red)
```

### Typography
- **Headings:** Bold, 16-28px
- **Body:** Regular, 12-14px
- **Labels:** Semi-bold, 11-12px
- **Currency:** Bold, 16-18px (RM format)
- **Language:** Bahasa Malaysia (BM santai)

### Spacing System
- **Card Padding:** 14-18px
- **Card Margin:** 16-20px vertical
- **Internal Spacing:** 8-12px
- **Border Radius:** 12-16px (cards), 999px (pills)

### Card Design Pattern
```dart
Container(
  padding: EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: AppColors.cardShadow, // Subtle shadow
  ),
  child: Column(...)
)
```

---

## 🔄 ADAPTIVE DASHBOARD SYSTEM

### Mood Engine (DashboardMoodEngine)

#### Dashboard Modes (Time-Based)
```dart
enum DashboardMode {
  morning,    // 5am - 11am: Tenang, 1 cadangan sahaja
  afternoon,  // 11am - 6pm: Fokus & Action, max 2 cadangan
  evening,    // 6pm - 12am: Refleksi & ringkasan
  urgent,     // Override: Tegas mode bila kritikal
}
```

#### Mood Tones
```dart
enum MoodTone {
  calm,       // Tenang, reassuring (Morning)
  focused,    // Fokus, action-oriented (Afternoon)
  reflective, // Refleksi, review (Evening)
  urgent,     // Tegas, direct (Critical issues)
}
```

#### Mode Detection Logic
```dart
static DashboardMode getCurrentMode() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 11) return DashboardMode.morning;
  if (hour >= 11 && hour < 18) return DashboardMode.afternoon;
  return DashboardMode.evening;
}

static MoodTone getMoodTone({
  required DashboardMode mode,
  required bool hasUrgentIssues, // stok = 0, order overdue, batch expired
}) {
  if (hasUrgentIssues) return MoodTone.urgent;
  switch (mode) {
    case DashboardMode.morning: return MoodTone.calm;
    case DashboardMode.afternoon: return MoodTone.focused;
    case DashboardMode.evening: return MoodTone.reflective;
  }
}
```

#### Max Suggestions by Mode
- **Morning:** 1 suggestion (golden rule - jangan overwhelm pagi)
- **Afternoon:** 2 suggestions (fokus & action)
- **Evening:** 1 suggestion (refleksi)
- **Urgent:** 3 suggestions (show all critical issues)

### UX Copy System (DashboardUXCopy)

#### Coach-Style Principles
1. **Nada coach, bukan boss** - Supportive, not commanding
2. **Ayat pendek** - Short, clear messages
3. **Jangan caps lock** - Lowercase, friendly tone
4. **BM santai** - Casual Bahasa Malaysia
5. **Encouraging** - Positive reinforcement

#### Suggestion Titles (Adaptive)
```dart
// Calm/Focused tone:
- 'low_stock' → "Satu persediaan kecil hari ini"
- 'no_sales' → "Mula momentum hari ini"
- 'high_expense' → "Perhatian kecil"
- 'production_suggestion' → "Cadangan untuk hari ini"

// Urgent tone:
- 'stock_zero' → "Stok kritikal"
- 'order_overdue' → "Order perlu tindakan"
- 'batch_expired' → "Batch tamat tempoh"
```

#### Suggestion Messages (Coach Style)
```dart
// Example: Low Stock (Calm)
"Untuk elak gangguan produksi, stok {productName} disyorkan untuk ditambah."

// Example: No Sales (Calm)
"Belum ada jualan hari ini. Buat 1 transaksi awal untuk mula momentum."

// Example: Stock Zero (Urgent)
"Stok habis. Produksi tidak boleh diteruskan tanpa restock."
```

#### CTA Text (Encouraging, Not Bossy)
```dart
// Calm/Focused:
- 'add_stock' → "Tambah Stok Supaya Produksi Lancar"
- 'add_sale' → "Buat Jualan Pertama"
- 'view_expense' → "Semak Belanja"

// Urgent:
- 'add_stock' → "Tambah Stok Sekarang"
- 'add_sale' → "Buat Jualan"
- 'view_order' → "Semak Order"
```

---

## 📊 DATA MODELS

### SmeDashboardV2Data (Main Container)
```dart
class SmeDashboardV2Data {
  final DashboardMoneySummary today;        // Today's financial summary
  final DashboardCashflowWeekly week;       // Weekly cashflow (Ahad–Sabtu)
  final DashboardTopProducts topProducts;   // Top products (today & week)
  final DashboardProductionSuggestion productionSuggestion; // Production advice
}
```

### DashboardMoneySummary (Today's Metrics)
```dart
class DashboardMoneySummary {
  final double inflow;      // Masuk (Sales + Bookings + Claims)
  final double expense;     // Belanja (Expenses)
  final double profit;      // Untung (inflow - expense, accounting-lite)
  final int transactions;   // Transaksi count (Sales + Bookings)
}
```

**Calculation Logic:**
- **Inflow:** Direct sales (finalAmount) + Completed bookings (totalAmount) + Settled consignment claims (netAmount)
- **Expense:** Sum of expenses.expense_date for today (DATE field, local time)
- **Profit:** inflow - expense (no COGS, accounting-lite approach)
- **Transactions:** Sales count + Completed bookings count

### DashboardCashflowWeekly (Weekly Cashflow)
```dart
class DashboardCashflowWeekly {
  final double inflow;    // Masuk (Ahad–Sabtu)
  final double expense;   // Belanja (Ahad–Sabtu)
  final double net;       // Net (inflow - expense)
}
```

**Week Calculation:**
- Week starts: **Ahad (Sunday)** at 00:00 local time
- Week ends: **Sabtu (Saturday)** at 23:59 local time
- Uses `_startOfWeekSunday()` helper: `dateLocal.weekday % 7` days back

### DashboardTopProducts
```dart
class DashboardTopProducts {
  final List<TopProductUnits> todayTop3;  // Top 3 today
  final List<TopProductUnits> weekTop3;   // Top 3 week
}

class TopProductUnits {
  final String key;           // Normalized key (lowercase, trimmed, collapsed spaces)
  final String displayName;   // Original-friendly name (best effort)
  final double units;         // Total units sold
}
```

**Aggregation Logic:**
1. **Cross-Channel:** Aggregates from Sales, Bookings, Consignment Claims
2. **Normalization:** Product names normalized (lowercase, trim, collapse spaces)
3. **Grouping:** Grouped by normalized key, displayName from first occurrence
4. **Sorting:** Sorted by units (descending), take top 3

**Sources:**
- `sale_items` (joined with `sales.created_at`)
- `booking_items` (joined with `bookings` where status='completed')
- `consignment_claim_items` (joined with `consignment_claims` where status='settled')

### DashboardProductionSuggestion
```dart
class DashboardProductionSuggestion {
  final bool show;      // Whether to show suggestion
  final String title;   // "Cadangan Produksi Hari Ini"
  final String message; // Contextual message
}
```

**Rule-Based Logic:**
- Show if: Week top product exists AND units >= 3
- Message adapts to week net:
  - **Negative net:** "Produk \"{name}\" paling laku minggu ini. Buat batch kecil hari ini untuk naikkan sales."
  - **Positive net:** "Produk \"{name}\" paling laku minggu ini. Disyorkan buat batch hari ini supaya stok cukup."

---

## 🔧 SERVICE LAYER

### SmeDashboardV2Service

**Purpose:** Aggregates data from multiple repositories for dashboard display

**Key Methods:**

#### `load() → Future<SmeDashboardV2Data>`
Main entry point. Loads all dashboard data in parallel.

**Parallel Loading:**
```dart
Future.wait([
  _loadInflowAndTransactions(todayStartUtc, todayEndUtc),
  _loadExpenseTotal(todayStartLocal, todayEndLocal),
  _loadInflowTotal(weekStartUtc, weekEndUtc),
  _loadExpenseTotal(weekStartLocal, weekEndLocal),
  _loadTopProducts(todayStartUtc, todayEndUtc, weekStartUtc, weekEndUtc),
])
```

#### `_loadInflowAndTransactions()`
Loads today's inflow and transaction count.

**Sources:**
1. **Sales:** `SalesRepository.listSales()` → sum `finalAmount`, count transactions
2. **Bookings:** `BookingsRepository.listBookings(status: 'completed')` → filter by `createdAt`, sum `totalAmount`, count
3. **Claims:** `ConsignmentClaimsRepository.listClaims(status: 'settled')` → sum `netAmount` (not counted as transaction)

**Time Handling:**
- Input: UTC timestamps (for `timestamptz` fields)
- Filters: `createdAt >= startUtc AND createdAt < endUtc`

#### `_loadExpenseTotal()`
Loads expense total for a date range.

**Implementation:**
- Query: `expenses` table
- Filter: `expense_date >= startDateStr AND expense_date <= endDateStr`
- Field: `expense_date` is DATE (stored as 'yyyy-MM-dd' string)
- Sum: `amount` field

**Time Handling:**
- Input: Local DateTime (for DATE field)
- Conversion: `_dateOnly()` helper → 'yyyy-MM-dd' string

#### `_loadTopProducts()`
Loads top products for today and week.

**Aggregation Process:**
1. Create map: `Map<String, _UnitsAgg>`
2. Accumulate from 3 sources in parallel:
   - `_accumulateFromSalesItems()`
   - `_accumulateFromBookingItems()`
   - `_accumulateFromSettledConsignment()`
3. Normalize product names: `_normalizeProductName()` → lowercase, trim, collapse spaces
4. Group by normalized key, sum units
5. Sort by units (descending), take top 3

**Product Name Normalization:**
```dart
String _normalizeProductName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final lowered = trimmed.toLowerCase();
  final collapsed = lowered.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed;
}
```

**Display Name Selection:**
- First non-empty product name encountered
- Falls back to normalized key if no display name

---

## 🎯 WIDGET DETAILS

### Morning Briefing Card

**Purpose:** Adaptive greeting based on time of day and business state

**Adaptive Behavior:**
- **Greeting:** "Selamat Pagi/Tengah Hari/Petang 👋" or "Perhatian Diperlukan"
- **Message:** Reassurance message based on mood
- **Icon:** Sun/Twilight/Night or Warning icon
- **Gradient:** Color based on mood tone

**Implementation:**
- Uses `DashboardMoodEngine.getCurrentMode()` for time detection
- Uses `DashboardMoodEngine.getMoodTone()` for tone (with `hasUrgentIssues`)
- Uses `DashboardMoodEngine.getGreeting()` and `getReassuranceMessage()`
- Gradient uses `DashboardMoodEngine.getPrimaryColor(mood)`

**Props:**
- `userName`: Business name or email username
- `hasUrgentIssues`: Boolean flag (TODO: implement actual checks)

### Today Snapshot Hero V2

**Purpose:** Display today's key financial metrics

**Metrics Displayed:**
1. **Masuk (Inflow):** Green accent, savings icon
2. **Belanja (Expense):** Red accent, payments icon
3. **Untung (Profit):** Green/Red based on value, graph icon, shows "Masuk - Belanja"
4. **Transaksi (Transactions):** Primary accent, cart icon

**Layout:**
- 2x2 grid on mobile, responsive
- Info tooltip: "Termasuk tempahan & vendor"
- Currency formatting: `DashboardV2Format.currency()` (RM, 0 decimals)

**Visual Design:**
- Soft gradient background (teal-50 to blue-50)
- White cards with colored borders
- Icons in colored containers

### Primary Quick Actions V2

**Purpose:** Quick access to main business actions

**Primary Actions (Always Visible):**
1. **Tambah Jualan** (Primary color) → `/sales/create`
2. **Tambah Stok** (Blue) → `/stock`
3. **Produksi** (Purple) → `/production`
4. **Penghantaran** (Orange) → `/deliveries`
5. **Belanja** (Red) → `/expenses`
6. **Lain-lain** (Teal) → Opens bottom sheet

**More Actions (Bottom Sheet):**
- Scan Resit, Tempahan, PO, Tuntutan, Laporan, Dokumen, Komuniti, Langganan, Tetapan

**Layout:**
- Grid: 3 columns (mobile), 5 columns (desktop)
- Action tiles with icons, labels, colored borders
- "Lain-lain" opens modal bottom sheet with all additional actions

### Smart Insights Card V2

**Purpose:** Contextual, adaptive suggestions based on business data

**Suggestion Types:**
1. **No Sales Today:** If `inflow <= 0 AND transactions == 0`
   - Title: "Mula momentum hari ini" (calm) / "Perhatian diperlukan" (urgent)
   - Message: "Belum ada jualan hari ini. Buat 1 transaksi awal untuk mula momentum."
   - CTA: "Buat Jualan Pertama" / "Buat Jualan"

2. **Expense Exceeds Inflow:** If `expense > inflow AND inflow > 0`
   - Title: "Perhatian kecil"
   - Message: "Kos agak tinggi. Boleh semak bila ada masa."
   - CTA: "Semak Belanja"

3. **Week Net Negative:** If `week.net < 0`
   - Title: "Perhatian kecil"
   - Message: Contextual based on mood
   - CTA: "Lihat Jualan"

4. **Top Performing Product:** If top today product units >= 5
   - Title: "Produk paling perform hari ini"
   - Message: "\"{name}\" dah terjual {units} unit. Pastikan stok cukup."
   - CTA: "Semak Stok Siap"

**Adaptive Behavior:**
- **Max Suggestions:** Based on `DashboardMoodEngine.getMaxSuggestions(mode)`
  - Morning: 1
  - Afternoon: 2
  - Evening: 1
  - Urgent: 3 (shows all)
- **Tone:** Uses `DashboardUXCopy` for titles, messages, CTAs, colors
- **Ordering:** Priority-based (no sales > expense > week net > top product)

### Weekly Cashflow Card V2

**Purpose:** Display weekly cashflow summary (Ahad–Sabtu)

**Metrics:**
- **Masuk (Inflow):** Green accent, downward arrow
- **Belanja (Expense):** Red accent, upward arrow
- **Net Badge:** Green/Red pill showing net value

**Visual Elements:**
- Progress bar showing expense/inflow ratio
- Tip text: "kalau belanja hampir sama/lebih dari masuk, cuba semak expenses yang besar."

**Week Calculation:**
- Uses `_startOfWeekSunday()` helper
- Shows "Ahad → Sabtu" subtitle

### Top Products Cards V2

**Purpose:** Display top 3 products for today and week

**Layout:**
- Mobile: Stacked cards
- Desktop: Side-by-side cards

**Display:**
- Ranked list (1, 2, 3) with product names
- Unit count badges
- Clickable → navigates to Finished Products page with focus

**Data:**
- Shows empty state if no data
- "Ikut kuantiti (unit)" subtitle

### Finished Products Alerts V2

**Purpose:** Alert for low stock and expiring finished products

**Alert Types:**
1. **Low Stock (Hampir Habis):** Products with `totalRemaining <= 5`
   - Orange accent
   - Shows product name and remaining units
   - Sorted by remaining units (ascending)

2. **Expiring (Hampir Luput):** Products expiring within 3 days
   - Red accent
   - Shows product name, expiry date, days remaining
   - Sorted by expiry date (ascending)

**States:**
- Loading: Circular progress indicator
- Empty: "Belum ada batch produksi yang aktif"
- OK: "Semua stok produk siap nampak okay"
- Alerts: Shows top 3 for each type

**Data Source:**
- `FinishedProductsRepository.getFinishedProductsSummary()`

### Production Suggestion Card V2

**Purpose:** Rule-based production suggestion

**Conditions to Show:**
- Week top product exists
- Week top product units >= 3

**Message:**
- Adapts to week net:
  - Negative: "Buat batch kecil hari ini untuk naikkan sales."
  - Positive: "Disyorkan buat batch hari ini supaya stok cukup."

**CTA:**
- "Mulakan Produksi" button → `/production`

### Urgent Actions Widget

**Purpose:** Display urgent tasks requiring attention

**Tasks:**
1. **Pending Bookings:** Count from statistics
2. **Pending POs:** Count from purchase orders (status='pending')
3. **Low Stock:** Count from low stock items

**Layout:**
- Action cards with icons, counts, "Lihat" buttons
- Only shows if count > 0

### Sales by Channel Card

**Purpose:** Display sales breakdown by channel

**Channels:**
- Direct Sales
- Bookings
- Consignment

**Data Source:**
- `ReportsRepository.getSalesByChannel()` (today's data)

**Display:**
- Channel name, revenue, percentage
- Total revenue header

---

## 🔄 DATA FLOW & STATE MANAGEMENT

### State Variables (DashboardPageOptimized)
```dart
Map<String, dynamic>? _stats;              // Legacy statistics
Map<String, dynamic>? _pendingTasks;       // Pending POs, low stock count
List<SalesByChannel> _salesByChannel;      // Sales breakdown
Subscription? _subscription;               // Current subscription
BusinessProfile? _businessProfile;         // Business profile
int _unreadNotifications;                  // Notification count
bool _loading;                             // Loading state
SmeDashboardV2Data? _v2;                   // V2 dashboard data (main)
```

### Lifecycle Methods

#### `initState()`
- Calls `_loadAllData()` immediately

#### `didChangeDependencies()`
- Calls `_loadAllData()` when page becomes visible (refresh on return)

#### `_loadAllData()`
1. Set loading = true
2. Run `PlannerAutoService.runAll()` (non-blocking, best effort)
3. Load all data in parallel using `Future.wait()`
4. Load unread notifications (after subscription loaded)
5. Set state with all data
6. Handle errors with snackbar

### Repositories Used
1. **BookingsRepositorySupabase** - Statistics, bookings data
2. **SalesRepositorySupabase** - Sales data
3. **PurchaseOrderRepository** - Pending POs
4. **StockRepository** - Low stock items
5. **ReportsRepositorySupabase** - Sales by channel
6. **ConsignmentClaimsRepositorySupabase** - Claims data (via V2 service)
7. **BusinessProfileRepository** - Business profile
8. **AnnouncementsRepositorySupabase** - Notifications
9. **SmeDashboardV2Service** - V2 data aggregation

### Error Handling
- All repository calls wrapped in try-catch
- Errors logged with `debugPrint`
- Fallback to empty/default values
- User-facing errors shown via SnackBar

---

## 📱 RESPONSIVE DESIGN

### Breakpoints
- **Mobile:** < 768px width
- **Desktop:** >= 768px width

### Adaptive Layouts

#### Primary Quick Actions V2
- Mobile: 3 columns
- Desktop: 5 columns

#### Top Products Cards V2
- Mobile: Stacked vertically
- Desktop: Side-by-side

#### More Actions Bottom Sheet
- Mobile: 3 columns
- Desktop: 5 columns

### Touch Targets
- Minimum 44x44px (iOS guidelines)
- Padding: 12-14px for comfortable tapping

---

## 🎯 UX PATTERNS

### Pull-to-Refresh
- `RefreshIndicator` wraps ListView
- Calls `_loadAllData()` on refresh

### Navigation Patterns
- Primary actions: Named routes (`/sales/create`, `/stock`, etc.)
- Secondary actions: Modal bottom sheet
- Deep links: Top products → Finished Products with focus

### Loading States
- Initial: `CircularProgressIndicator` in center
- Per-widget: Individual loading states (e.g., Finished Products Alerts)

### Empty States
- Friendly messages: "Belum ada data untuk tempoh ini."
- Actionable: "Lihat" buttons to navigate

### Error States
- SnackBar for global errors
- Per-widget: Graceful degradation (empty states)

---

## 🔮 FUTURE ENHANCEMENTS (TODOs)

### Urgent Issues Detection
Currently `_hasUrgentIssues()` returns `false` (placeholder).

**Planned Implementation:**
1. Check if any stock items have quantity = 0 (critical)
2. Check if any orders are overdue
3. Check if any batches are expired

**Integration Points:**
- `_pendingTasks?['lowStockCount']` (but need to check if any are actually 0, not just low)
- `_stats?['overdue']` (if available)
- Finished products repository for expired batches

### Evening Summary Card
- Show daily summary in "Malam Mode"
- Highlight achievements and improvements
- Gentle reflection message

### A/B Testing
- Test UX copy variations
- Test suggestion ordering
- Test color schemes

---

## 📚 KEY DESIGN DECISIONS

### 1. Accounting-Lite Approach
- **Decision:** Profit = Masuk - Belanja (no COGS)
- **Rationale:** SME-friendly, simple, actionable
- **Trade-off:** Less accurate than full accounting, but more understandable

### 2. Week Starts on Sunday
- **Decision:** Week = Ahad–Sabtu (Sunday–Saturday)
- **Rationale:** Common in Malaysia, matches local business culture
- **Implementation:** `_startOfWeekSunday()` helper using `weekday % 7`

### 3. Cross-Channel Product Aggregation
- **Decision:** Top products aggregate from Sales, Bookings, Claims
- **Rationale:** Gives complete picture of product performance
- **Implementation:** Normalize product names, group by key, sum units

### 4. Adaptive Suggestions (Mood-Based)
- **Decision:** Limit suggestions based on time of day
- **Rationale:** "Tenang bila boleh, tegas bila perlu" - don't overwhelm in morning
- **Implementation:** `DashboardMoodEngine.getMaxSuggestions(mode)`

### 5. Coach-Style Messaging
- **Decision:** Supportive, encouraging, not bossy
- **Rationale:** Reduces stress, increases engagement
- **Implementation:** `DashboardUXCopy` helper with BM santai messages

### 6. Parallel Data Loading
- **Decision:** Load all data in parallel using `Future.wait()`
- **Rationale:** Faster page load, better UX
- **Trade-off:** Slightly more complex error handling

---

## 🧪 TESTING CONSIDERATIONS

### Unit Tests
- `DashboardMoodEngine` - Mode detection, mood tone logic
- `DashboardUXCopy` - Message generation
- `SmeDashboardV2Service` - Data aggregation logic
- `_normalizeProductName()` - Product name normalization

### Widget Tests
- `TodaySnapshotHeroV2` - Currency formatting, layout
- `SmartInsightsCardV2` - Suggestion logic, adaptive behavior
- `PrimaryQuickActionsV2` - Navigation, bottom sheet

### Integration Tests
- Full dashboard load flow
- Error handling scenarios
- Refresh functionality

---

## 📖 GLOSSARY

### Terms (BM → English)
- **Masuk** → Inflow (Revenue)
- **Belanja** → Expense
- **Untung** → Profit
- **Transaksi** → Transactions
- **Stok** → Stock
- **Produksi** → Production
- **Penghantaran** → Delivery
- **Tempahan** → Booking
- **Tuntutan** → Claim
- **Laporan** → Report
- **Tetapan** → Settings
- **Komuniti** → Community
- **Langganan** → Subscription

### Technical Terms
- **COGS** → Cost of Goods Sold
- **UTC** → Coordinated Universal Time
- **Local Time** → Device timezone
- **Normalization** → Converting to standard form (lowercase, trim, collapse spaces)
- **Cross-Channel** → Aggregating from multiple sources (Sales, Bookings, Claims)

---

## 🎓 LESSONS LEARNED

### What Works Well
1. **Adaptive UX** - Users appreciate context-aware content
2. **Coach-Style Messaging** - Reduces stress, increases engagement
3. **Parallel Loading** - Fast page loads
4. **Action-First Design** - Quick actions prominently placed
5. **Mobile-First** - Optimized for smartphone usage

### Areas for Improvement
1. **Urgent Detection** - Needs actual implementation
2. **Error Handling** - Could be more granular
3. **Caching** - Could cache data for better performance
4. **Offline Support** - No offline capabilities yet
5. **Analytics** - Limited tracking of user interactions

---

## 📞 SUPPORT & MAINTENANCE

### Key Files to Modify
- **New Features:** Add widgets in `widgets/v2/`
- **Data Models:** Modify `domain/sme_dashboard_v2_models.dart`
- **Service Logic:** Modify `services/sme_dashboard_v2_service.dart`
- **UX Copy:** Modify `domain/dashboard_ux_copy.dart`
- **Mood Logic:** Modify `domain/dashboard_mood_engine.dart`

### Common Patterns
1. **New Widget:** Follow V2 widget pattern (Container with padding, border, shadow)
2. **New Suggestion:** Add to `SmartInsightsCardV2._buildInsights()`
3. **New Metric:** Add to `SmeDashboardV2Data` model and service
4. **New Action:** Add to `PrimaryQuickActionsV2.moreActions`

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-16  
**Maintainer:** Corey (AI Assistant)

---

**End of Document**

