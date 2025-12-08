# Sales Channel Analysis & Recommendations

## Current Situation

### Sales Channels in PocketBizz:
1. **Direct Sales** (Walk-in/POS)
   - Recorded in `sales` table
   - Channel: 'walk-in', 'myshop', etc.
   - Full revenue to business owner

2. **Bookings → Sales**
   - Bookings are converted to sales when fulfilled
   - Should be tracked with channel = 'booking' or 'tempahan'
   - Full revenue to business owner

3. **Consignment Sales (Vendor)**
   - Products delivered to vendors
   - Vendors sell and claim payment
   - Revenue = `net_amount` (after commission deduction)
   - Tracked in `consignment_claims` table

## Question: Kira Asing atau Sekali?

### Recommendation: **KIRA SEKALI, TAPI TRACK SEPARATELY**

**Rationale:**
- ✅ **Total Revenue** = Sum semua channels (accurate business picture)
- ✅ **Breakdown by Channel** = Untuk analysis & decision making
- ✅ **Dashboard Visibility** = Tengok contribution setiap channel

### Calculation Logic:

```
Total Revenue = 
  Direct Sales (sales table) +
  Booking Sales (sales table where channel='booking') +
  Consignment Revenue (consignment_claims.net_amount where status='settled')
```

## Implementation Plan

### Option 1: Combine in Reports (Recommended)
- Reports page: Show breakdown by channel
- Dashboard: Show total + breakdown card
- Easy to understand, no confusion

### Option 2: Separate Tracking
- Keep separate metrics
- More complex, might confuse users
- Harder to see overall business health

## Dashboard Display Recommendation

### Add "Sales by Channel" Card:
```
┌─────────────────────────────────┐
│ Jualan Mengikut Saluran         │
├─────────────────────────────────┤
│ 🏪 Walk-in:    RM 5,000 (50%)   │
│ 📱 Tempahan:   RM 3,000 (30%)   │
│ 🏬 Vendor:      RM 2,000 (20%)   │
├─────────────────────────────────┤
│ Total:         RM 10,000       │
└─────────────────────────────────┘
```

### Benefits:
- Quick visibility of revenue sources
- Identify which channel performs best
- Make informed decisions on channel focus

## Next Steps

1. Update Reports Repository to include:
   - Sales by channel breakdown
   - Consignment revenue calculation
   - Combined total revenue

2. Add Dashboard Widget:
   - Sales by Channel card
   - Visual breakdown (pie chart or bars)

3. Update Reports Page:
   - Add "Channel Performance" tab
   - Show breakdown in Overview tab

