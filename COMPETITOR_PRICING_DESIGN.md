# Competitor Pricing Feature Design

## 🎯 Objektif
Membantu SME membuat keputusan pricing yang lebih baik dengan:
1. Benchmark harga dengan pesaing
2. Tentukan harga yang kompetitif
3. Kira profit margin dengan lebih tepat
4. Analisis kedudukan harga dalam pasaran

## 📊 Struktur Data

### Product Model - Tambahan Fields
```dart
// Competitor Pricing
final List<CompetitorPrice>? competitorPrices; // Senarai harga pesaing
final double? averageCompetitorPrice; // Harga purata pesaing (calculated)
final double? minCompetitorPrice; // Harga terendah pesaing
final double? maxCompetitorPrice; // Harga tertinggi pesaing
final MarketPosition? marketPosition; // Kedudukan dalam pasaran
```

### CompetitorPrice Model (NEW)
```dart
class CompetitorPrice {
  final String id;
  final String productId;
  final String competitorName; // Nama pesaing (cth: "Kedai A", "Shopee", "Lazada")
  final double price;
  final String? source; // "physical_store", "online_platform", "marketplace"
  final DateTime? lastUpdated; // Tarikh harga dikemaskini
  final String? notes; // Nota tambahan
}
```

### MarketPosition Enum
```dart
enum MarketPosition {
  belowMarket,    // Harga di bawah pasaran (< 90% purata)
  atMarket,        // Harga dalam pasaran (90-110% purata)
  aboveMarket,     // Harga di atas pasaran (> 110% purata)
}
```

## 🧮 Calculations & Analytics

### 1. Average Competitor Price
```
averageCompetitorPrice = SUM(competitorPrices) / COUNT(competitorPrices)
```

### 2. Market Position
```
if (salePrice < averageCompetitorPrice * 0.9) → belowMarket
if (salePrice >= averageCompetitorPrice * 0.9 && salePrice <= averageCompetitorPrice * 1.1) → atMarket
if (salePrice > averageCompetitorPrice * 1.1) → aboveMarket
```

### 3. Profit Margin Analysis
```
Current Profit Margin = ((salePrice - costPerUnit) / salePrice) * 100%
Market Average Profit Margin = ((averageCompetitorPrice - estimatedMarketCost) / averageCompetitorPrice) * 100%

Comparison:
- If current margin > market margin → Competitive advantage
- If current margin < market margin → Need to review costs or pricing
```

### 4. Recommended Price Range
```
Min Recommended = averageCompetitorPrice * 0.95 (5% below market)
Max Recommended = averageCompetitorPrice * 1.05 (5% above market)
Optimal = averageCompetitorPrice (at market)
```

### 5. Price Competitiveness Score
```
Score = 100 - ((|salePrice - averageCompetitorPrice| / averageCompetitorPrice) * 100)
- Score 90-100: Highly competitive
- Score 80-89: Competitive
- Score 70-79: Moderate
- Score < 70: Not competitive
```

## 🎨 UI/UX Features

### 1. Product Form - Competitor Pricing Section
```
┌─────────────────────────────────────┐
│ Competitor Pricing                  │
├─────────────────────────────────────┤
│ [Add Competitor Price]              │
│                                     │
│ Competitor Prices:                  │
│ • Kedai A: RM 5.50 (Physical Store)│
│ • Shopee: RM 5.20 (Online)         │
│ • Lazada: RM 5.80 (Online)         │
│                                     │
│ Market Analysis:                    │
│ • Average: RM 5.50                 │
│ • Range: RM 5.20 - RM 5.80         │
│ • Your Price: RM 5.00              │
│ • Position: ⬇️ Below Market (-9%)  │
│                                     │
│ Recommendations:                    │
│ • Min: RM 5.23                     │
│ • Optimal: RM 5.50                 │
│ • Max: RM 5.78                     │
└─────────────────────────────────────┘
```

### 2. Product Detail Page - Market Analysis Card
```
┌─────────────────────────────────────┐
│ 📊 Market Analysis                  │
├─────────────────────────────────────┤
│ Average Competitor Price            │
│ RM 5.50                             │
│                                     │
│ Your Price: RM 5.00                 │
│ Position: ⬇️ Below Market (-9.1%)   │
│                                     │
│ Profit Margin:                      │
│ • Your Margin: 45%                  │
│ • Market Avg Margin: ~40%           │
│ • Status: ✅ Competitive            │
│                                     │
│ Price Competitiveness:              │
│ ████████░░ 85/100                   │
│                                     │
│ [View Details] [Update Prices]      │
└─────────────────────────────────────┘
```

### 3. Competitor Price Management Dialog
```
┌─────────────────────────────────────┐
│ Manage Competitor Prices            │
├─────────────────────────────────────┤
│ Competitor Name: [___________]      │
│ Price: RM [____]                     │
│ Source: [Dropdown: Physical/Online]  │
│ Last Updated: [Date Picker]          │
│ Notes: [Text Area]                   │
│                                     │
│ [Add] [Cancel]                      │
└─────────────────────────────────────┘
```

### 4. Pricing Recommendations Widget
```
┌─────────────────────────────────────┐
│ 💡 Pricing Recommendations         │
├─────────────────────────────────────┤
│ Based on market analysis:           │
│                                     │
│ Current: RM 5.00                    │
│ Recommended: RM 5.50                │
│                                     │
│ Impact:                              │
│ • Revenue: +10%                     │
│ • Margin: +2.5%                     │
│ • Position: At Market ✅            │
│                                     │
│ [Apply Recommendation]              │
└─────────────────────────────────────┘
```

## 📈 Benefits untuk SME

1. **Data-Driven Pricing**
   - Buat keputusan berdasarkan data pasaran, bukan tekaan
   - Fahami kedudukan harga dalam pasaran

2. **Competitive Advantage**
   - Tahu bila harga terlalu tinggi/rendah
   - Optimize profit margin sambil kekal kompetitif

3. **Cost Management**
   - Bandingkan kos sendiri dengan anggaran kos pasaran
   - Kenal pasti peluang untuk kurangkan kos

4. **Market Intelligence**
   - Track perubahan harga pesaing
   - Respond cepat kepada perubahan pasaran

5. **Profit Optimization**
   - Balance antara harga kompetitif dan profit margin
   - Tentukan sweet spot untuk pricing

## 🔄 Workflow

1. **Setup Competitor Prices**
   - User masukkan harga pesaing (manual atau import)
   - System calculate average, min, max

2. **Market Analysis**
   - System compare harga user dengan pasaran
   - Show market position dan recommendations

3. **Pricing Decision**
   - User review recommendations
   - Adjust harga berdasarkan analysis
   - Track impact pada profit margin

4. **Ongoing Monitoring**
   - Update competitor prices regularly
   - System alert jika market position berubah
   - Track pricing trends over time

## 🗄️ Database Schema

### competitor_prices table
```sql
CREATE TABLE competitor_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  business_owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
  competitor_name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  source TEXT, -- 'physical_store', 'online_platform', 'marketplace'
  last_updated DATE,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_competitor_prices_product ON competitor_prices(product_id);
CREATE INDEX idx_competitor_prices_owner ON competitor_prices(business_owner_id);
```

## 🚀 Implementation Priority

### Phase 1: Basic Features
- [ ] Add competitor_prices table
- [ ] Update Product model dengan competitor pricing fields
- [ ] Basic CRUD untuk competitor prices
- [ ] Calculate average/min/max competitor prices
- [ ] Display market analysis dalam product detail

### Phase 2: Analytics & Recommendations
- [ ] Market position calculation
- [ ] Profit margin comparison
- [ ] Pricing recommendations
- [ ] Competitiveness score

### Phase 3: Advanced Features
- [ ] Price trend tracking
- [ ] Market alerts (price changes)
- [ ] Bulk import competitor prices
- [ ] Pricing strategy suggestions

## 💡 Additional Ideas

1. **Price History Tracking**
   - Track perubahan harga pesaing over time
   - Show price trends dalam chart

2. **Automated Price Monitoring**
   - Integration dengan web scraping (optional)
   - Auto-update competitor prices

3. **Pricing Strategies**
   - "Match Market" - Set harga sama dengan purata
   - "Premium" - Set harga 10-20% above market
   - "Budget" - Set harga 10-20% below market

4. **Category-Level Analysis**
   - Average competitor prices by category
   - Market trends by product category

5. **Export/Import**
   - Export competitor prices untuk backup
   - Import dari CSV/Excel

---

**Kesimpulan**: Feature ini akan menjadikan PocketBizz lebih powerful untuk SME dalam membuat keputusan pricing yang lebih baik dan data-driven! 🚀

