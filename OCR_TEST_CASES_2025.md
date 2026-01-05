# 🧪 OCR TEST CASES - COMPREHENSIVE TESTING
**Date:** 2025-01-16  
**Purpose:** Verify all improvements work correctly

---

## 📋 TEST EXECUTION GUIDE

### Manual Testing:
1. Use Supabase Edge Functions dashboard
2. Call `OCR-Cloud-Vision` function with test images
3. Verify results match expected outputs

### Automated Testing:
- Run test script (if available)
- Or use Postman/curl to test function directly

---

## ✅ TEST CASE 1: Thousand Separator Format

### Input:
```
BAKERY ABC SDN BHD
TOTAL RM 1,234.50
CASH 1,500.00
CHANGE 265.50
```

### Expected Output:
```json
{
  "amount": 1234.50,
  "amountSource": "total",
  "confidence": 0.95,
  "merchant": "BAKERY ABC SDN BHD",
  "category": "bahan"
}
```

### What to Verify:
- ✅ Amount correctly parsed from `1,234.50` format
- ✅ Source is `"total"` (not fallback)
- ✅ Confidence is `0.95` (high)
- ✅ CASH amount ignored

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 2: CASH on Separate Line (Context Window)

### Input:
```
TOTAL 23.50
CASH
50.00
CHANGE 26.50
```

### Expected Output:
```json
{
  "amount": 23.50,
  "amountSource": "total",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ Amount is `23.50` (TOTAL), NOT `50.00` (CASH)
- ✅ Payment context window skips line after "CASH"
- ✅ Source is `"total"` (locked)

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 3: CASH Larger Than TOTAL (Lock Mechanism)

### Input:
```
TOTAL 15.00
CASH 50.00
CHANGE 35.00
```

### Expected Output:
```json
{
  "amount": 15.00,
  "amountSource": "total",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ Amount is `15.00` (TOTAL locked)
- ✅ CASH `50.00` is ignored (even though larger)
- ✅ Source is `"total"` (not fallback)

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 4: NET TOTAL Priority

### Input:
```
SUBTOTAL 100.00
DISCOUNT 10.00
NET TOTAL 90.00
TOTAL 100.00
```

### Expected Output:
```json
{
  "amount": 90.00,
  "amountSource": "net",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ NET TOTAL has priority over TOTAL
- ✅ Amount is `90.00` (NET TOTAL), not `100.00` (TOTAL)
- ✅ Source is `"net"`

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 5: Fallback with Confidence

### Input:
```
Item 1: 10.00
Item 2: 15.00
Item 3: 5.00
```

### Expected Output:
```json
{
  "amount": 15.00,
  "amountSource": "fallback",
  "confidence": 0.6
}
```

### What to Verify:
- ✅ Largest amount selected (`15.00`)
- ✅ Source is `"fallback"`
- ✅ Confidence is `0.6` (low - needs review)

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 6: JUMLAH with Medium Confidence

### Input:
```
JUMLAH 45.50
```

### Expected Output:
```json
{
  "amount": 45.50,
  "amountSource": "jumlah",
  "confidence": 0.8
}
```

### What to Verify:
- ✅ Amount correctly parsed
- ✅ Source is `"jumlah"`
- ✅ Confidence is `0.8` (medium)

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 7: Simple Format (No Thousand Separator)

### Input:
```
TOTAL 23.50
```

### Expected Output:
```json
{
  "amount": 23.50,
  "amountSource": "total",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ Simple format still works
- ✅ Amount correctly parsed
- ✅ Confidence is high

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 8: Multiple CASH Lines (Context Window)

### Input:
```
TOTAL 100.00
CASH
200.00
CHANGE
100.00
```

### Expected Output:
```json
{
  "amount": 100.00,
  "amountSource": "total",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ CASH lines skipped via context window
- ✅ Amount is `100.00` (TOTAL), not `200.00` (CASH)
- ✅ Multiple payment keywords handled correctly

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 9: SUBTOTAL with Medium Confidence

### Input:
```
SUBTOTAL 75.50
```

### Expected Output:
```json
{
  "amount": 75.50,
  "amountSource": "subtotal",
  "confidence": 0.8
}
```

### What to Verify:
- ✅ SUBTOTAL correctly parsed
- ✅ Source is `"subtotal"`
- ✅ Confidence is `0.8` (medium)

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 10: Real Malaysian Receipt Format

### Input:
```
KEDAI ROTI CANAI ABC
123, JALAN TUN RAZAK
KUALA LUMPUR

TARIKH: 16/01/2025
MASA: 10:30 AM

ROTI CANAI        2.00
TEH TARIK         3.50
NASI LEMAK        5.00
-------------------
SUBTOTAL         10.50
SST               0.63
-------------------
NET TOTAL        11.13

TUNAI            20.00
BAKI               8.87
```

### Expected Output:
```json
{
  "amount": 11.13,
  "amountSource": "net",
  "confidence": 0.95,
  "date": "16/01/2025",
  "merchant": "KEDAI ROTI CANAI ABC",
  "category": "bahan"
}
```

### What to Verify:
- ✅ NET TOTAL selected (priority)
- ✅ CASH/TUNAI ignored
- ✅ Date extracted correctly
- ✅ Merchant name extracted
- ✅ Category auto-detected

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 11: Edge Case - No Amount Found

### Input:
```
RECEIPT
No items listed
Thank you for your purchase
```

### Expected Output:
```json
{
  "amount": null,
  "amountSource": null,
  "confidence": 0.0
}
```

### What to Verify:
- ✅ Gracefully handles missing amount
- ✅ No errors thrown
- ✅ Confidence is `0.0`

### Status: ⏳ PENDING TEST

---

## ✅ TEST CASE 12: Edge Case - Multiple Totals (Priority Check)

### Input:
```
GRAND TOTAL 200.00
TOTAL 150.00
NET TOTAL 140.00
```

### Expected Output:
```json
{
  "amount": 140.00,
  "amountSource": "net",
  "confidence": 0.95
}
```

### What to Verify:
- ✅ NET TOTAL has highest priority
- ✅ Other totals ignored
- ✅ Correct priority order maintained

### Status: ⏳ PENDING TEST

---

## 📊 TEST SUMMARY

| Test Case | Feature Tested | Status |
|-----------|---------------|--------|
| 1 | Thousand separator format | ⏳ PENDING |
| 2 | Payment context window | ⏳ PENDING |
| 3 | TOTAL lock mechanism | ⏳ PENDING |
| 4 | NET TOTAL priority | ⏳ PENDING |
| 5 | Fallback confidence | ⏳ PENDING |
| 6 | JUMLAH confidence | ⏳ PENDING |
| 7 | Simple format | ⏳ PENDING |
| 8 | Multiple CASH lines | ⏳ PENDING |
| 9 | SUBTOTAL confidence | ⏳ PENDING |
| 10 | Real receipt format | ⏳ PENDING |
| 11 | No amount found | ⏳ PENDING |
| 12 | Priority order | ⏳ PENDING |

---

## 🚀 HOW TO RUN TESTS

### Option 1: Supabase Dashboard
1. Go to Supabase Dashboard → Edge Functions
2. Select `OCR-Cloud-Vision`
3. Use "Invoke Function" with test payload:
```json
{
  "imageBase64": "<base64_encoded_test_image>"
}
```

### Option 2: Using curl
```bash
curl -X POST \
  https://<project>.supabase.co/functions/v1/OCR-Cloud-Vision \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "imageBase64": "<base64_encoded_test_image>"
  }'
```

### Option 3: Flutter App
1. Use receipt scanner in app
2. Scan test receipts
3. Verify parsed results match expected outputs

---

## ✅ ACCEPTANCE CRITERIA

All tests must pass:
- ✅ Amount parsing correct (including thousand separators)
- ✅ CASH exclusion working (context window)
- ✅ TOTAL lock mechanism working
- ✅ Confidence scores accurate
- ✅ Priority order correct (NET > TOTAL > JUMLAH > SUBTOTAL > fallback)
- ✅ No errors thrown for edge cases

---

## 📝 TEST RESULTS LOG

**Date:** ___________  
**Tester:** ___________  
**Environment:** ___________  

| Test # | Result | Notes |
|--------|--------|-------|
| 1 | ⏳ | |
| 2 | ⏳ | |
| 3 | ⏳ | |
| 4 | ⏳ | |
| 5 | ⏳ | |
| 6 | ⏳ | |
| 7 | ⏳ | |
| 8 | ⏳ | |
| 9 | ⏳ | |
| 10 | ⏳ | |
| 11 | ⏳ | |
| 12 | ⏳ | |

---

**Status:** ⏳ Ready for Testing  
**Next Step:** Execute tests and update results

