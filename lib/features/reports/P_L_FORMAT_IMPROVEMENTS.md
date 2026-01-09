# Profit & Loss Report - Standard Format Improvements

## Status: ✅ Model & Repository Updated | ⚠️ UI & PDF Need Update

## Standard P&L Format (Following GAAP/IFRS Principles)

### Current Implementation:
```
Total Sales
- Total Costs (COGS + Expenses combined) ❌
- Rejection Loss
= Net Profit
```

### Standard Format (Now Implemented):
```
Revenue (Jualan)
- Cost of Goods Sold (COGS / Kos Pengeluaran)
─────────────────────────────────────
= Gross Profit (Untung Kasar) ✅
- Operating Expenses (Kos Operasi)
─────────────────────────────────────
= Operating Profit / EBIT (Untung Operasi) ✅
- Other Expenses (Kerugian Tolakan, etc.)
─────────────────────────────────────
= Net Profit (Untung Bersih)
```

## Benefits of Standard Format:

1. **Gross Profit Margin** - Shows core business profitability
   - Indicates if products/services are profitable before overhead
   - Industry benchmark: > 40% is good for retail
   
2. **Operating Profit (EBIT)** - Shows operational efficiency
   - Excludes one-time expenses (like rejection loss)
   - Better indicator of recurring business health

3. **Clear Cost Breakdown** - Easier to identify cost drivers
   - COGS vs Operating Expenses separated
   - Better for cost control and budgeting

4. **Standard Accounting Practice** - Compatible with:
   - LHDN (Malaysian Tax) requirements
   - Bank loan applications
   - Investor reports
   - Accounting software exports

## Model Changes:

### New Fields:
- `costOfGoodsSold` - Direct costs to produce goods/services
- `grossProfit` - Revenue - COGS
- `operatingExpenses` - Overhead costs (rent, utilities, salaries, etc.)
- `operatingProfit` - Gross Profit - Operating Expenses (EBIT)
- `otherExpenses` - One-time/non-operating expenses (rejection loss, etc.)
- `grossProfitMargin` - (Gross Profit / Revenue) × 100
- `netProfitMargin` - (Net Profit / Revenue) × 100

### Legacy Fields (Deprecated but supported):
- `totalCosts` → use `costOfGoodsSold + operatingExpenses`
- `rejectionLoss` → use `otherExpenses`
- `profitMargin` → use `netProfitMargin`

## Next Steps:

1. ✅ Update Model (`profit_loss_report.dart`) - DONE
2. ✅ Update Repository (`reports_repository_supabase.dart`) - DONE
3. ⚠️ Update UI (`reports_page.dart`) - PENDING
   - Display Gross Profit section
   - Show Operating Profit separately
   - Add Gross Profit Margin indicator
   
4. ⚠️ Update PDF Generator (`pdf_generator.dart`) - PENDING
   - Format P&L section with standard layout
   - Include Gross Profit and Operating Profit
   - Add margin calculations

5. ⚠️ Update Tests - PENDING
   - Test new format calculations
   - Test backward compatibility

## UI Display Recommendations:

```
┌─────────────────────────────────────┐
│ Ringkasan Untung Rugi               │
├─────────────────────────────────────┤
│ Jualan (Revenue)        RM 29,591.43│
│ Kos Pengeluaran (COGS)  RM  8,774.72│
│ ─────────────────────────────────── │
│ Untung Kasar (Gross Profit)         │
│                         RM 20,816.71│
│ Margin Kasar: 70.34%                │
│                                     │
│ Kos Operasi (OpEx)      RM  2,385.82│
│ ─────────────────────────────────── │
│ Untung Operasi (EBIT)               │
│                         RM 18,430.89│
│                                     │
│ Perbelanjaan Lain                   │
│ (Kerugian Tolakan)      RM      0.00│
│ ─────────────────────────────────── │
│ Untung Bersih (Net Profit)          │
│                         RM 18,430.89│
│ Margin Untung: 62.28%               │
└─────────────────────────────────────┘
```

## Benefits for SME Users:

1. **Better Understanding** - See where money is actually made/lost
2. **Cost Control** - Identify if COGS or OpEx is the problem
3. **Pricing Decisions** - Gross margin helps set product prices
4. **Business Health** - Operating profit shows recurring profitability
5. **Professional Reports** - Standard format for banks/tax authorities
