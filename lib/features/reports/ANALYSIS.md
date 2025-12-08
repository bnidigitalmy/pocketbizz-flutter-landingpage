# Reports Module Analysis

## Comparison: React vs Flutter Implementation

### React Version Features
1. **Profit/Loss Report**
   - Total Sales
   - Total Costs (Production & Expenses)
   - Rejection Loss (from consignment claims)
   - Net Profit
   - Profit Margin %

2. **Top Products Report**
   - Products ranked by profit
   - Total sold quantity
   - Total profit per product

3. **Top Vendors Report**
   - Vendors ranked by activity
   - Total deliveries
   - Total amount

4. **Monthly Trends**
   - Line chart: Sales vs Costs over time
   - Monthly aggregation

5. **PDF Export**
   - Generate profit/loss report as PDF

### PocketBizz Flutter - Current State

#### ✅ Available Data
- **Sales**: `sales` table with `profit`, `cogs`, `total`
- **Expenses**: `expenses` table with `amount`, `category`
- **Consignment Claims**: `consignment_claims` with rejection tracking
- **Products**: `products` table with sales items
- **Vendors**: `vendors` table with consignment deliveries

#### ❌ Missing Components
- Reports page UI
- Profit/Loss aggregation logic
- Top products/vendors queries
- Monthly trends calculation
- Charts visualization
- PDF export functionality

## Implementation Plan

### Phase 1: Data Layer
1. Create `ReportsRepository` with methods:
   - `getProfitLossReport(DateTime? startDate, DateTime? endDate)`
   - `getTopProducts(int limit, DateTime? startDate, DateTime? endDate)`
   - `getTopVendors(int limit, DateTime? startDate, DateTime? endDate)`
   - `getMonthlyTrends(int months)`

### Phase 2: Models
1. `ProfitLossReport` model
2. `TopProduct` model
3. `TopVendor` model
4. `MonthlyTrend` model

### Phase 3: UI
1. Reports page with tabs:
   - Overview (Profit/Loss summary cards)
   - Products (Top products list + chart)
   - Vendors (Top vendors list)
   - Trends (Monthly line chart)

### Phase 4: Export
1. PDF generation using `pdf` package
2. Export button in reports page

## Calculation Logic

### Profit/Loss
```dart
totalSales = sum(sales.total where date in range)
totalCosts = sum(expenses.amount where date in range) + sum(sales.cogs where date in range)
rejectionLoss = sum(consignment_claims.rejected_amount where status='rejected' and date in range)
netProfit = totalSales - totalCosts - rejectionLoss
profitMargin = (netProfit / totalSales) * 100
```

### Top Products
```dart
// Group sales_items by product_id
// Sum profit per product
// Sort by total profit DESC
// Limit to top N
```

### Top Vendors
```dart
// Group consignment_deliveries by vendor_id
// Count deliveries and sum amounts
// Sort by activity DESC
// Limit to top N
```

### Monthly Trends
```dart
// Group sales by month
// Aggregate: sum(sales.total), sum(sales.cogs + expenses)
// Return array of {month, sales, costs}
```

## Recommended Packages
- `fl_chart: ^0.65.0` - For charts
- `pdf: ^3.10.0` - For PDF generation
- `printing: ^5.11.0` - For PDF preview/print
- `intl: ^0.18.1` - Already used, for date formatting

