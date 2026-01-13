# 📋 Template Input Material untuk Demo Account PocketBizz

Template ini untuk setup demo account yang lengkap dengan sample data. Isi semua field yang diperlukan secara manual.

---

## 1. 👤 USER ACCOUNT

### Required Fields:
```
Email: demo@pocketbizz.my
Password: [password yang selamat]
Full Name: Demo User
Phone: 0123456789
```

**Note:** Email ini akan digunakan untuk login ke app.

---

## 2. 🏢 BUSINESS PROFILE

### Required Fields:
```
Business Name: [Nama Perniagaan Demo]
  Contoh: "Kedai Kek Cik Siti" atau "Bakery Demo Sdn Bhd"

Tagline: [Optional]
  Contoh: "Kek Terbaik di Bandar" atau "Fresh Baked Daily"

Registration Number: [Optional]
  Contoh: "SSM-12345678" atau "ROB-98765432"

Address: [Optional]
  Contoh: "123, Jalan Demo, Taman Demo, 12345 Kuala Lumpur"

Phone: [Optional]
  Contoh: "03-12345678" atau "0123456789"

Email: [Optional]
  Contoh: "info@demo.com"

Bank Name: [Optional]
  Contoh: "Maybank" atau "CIMB Bank"

Account Number: [Optional]
  Contoh: "1234567890"

Account Name: [Optional]
  Contoh: "Kedai Kek Cik Siti"
```

---

## 3. 📦 PRODUCTS (Minimum 5-10 produk)

### Format untuk setiap produk:
```
Product 1:
  SKU: PROD-001
  Name: Kek Coklat
  Category: Kek
  Unit: biji
  Cost Price: 8.50
  Sale Price: 15.00
  Description: Kek coklat yang sedap dan lembut

Product 2:
  SKU: PROD-002
  Name: Roti Canai
  Category: Roti
  Unit: keping
  Cost Price: 0.80
  Sale Price: 1.50
  Description: Roti canai goreng panas

Product 3:
  SKU: PROD-003
  Name: Nasi Lemak
  Category: Makanan
  Unit: bungkus
  Cost Price: 2.50
  Sale Price: 5.00
  Description: Nasi lemak dengan sambal, telur, dan ayam

Product 4:
  SKU: PROD-004
  Name: Teh Tarik
  Category: Minuman
  Unit: cawan
  Cost Price: 0.50
  Sale Price: 2.00
  Description: Teh tarik panas

Product 5:
  SKU: PROD-005
  Name: Kek Red Velvet
  Category: Kek
  Unit: biji
  Cost Price: 12.00
  Sale Price: 25.00
  Description: Kek red velvet premium

[Continue dengan lebih banyak produk...]
```

### Tips:
- Buat produk dari pelbagai kategori
- Vary harga (murah, sederhana, mahal)
- Gunakan unit yang berbeza (biji, keping, bungkus, cawan, kg, etc.)

---

## 4. 👥 CUSTOMERS (Minimum 5-10 pelanggan)

### Format untuk setiap customer:
```
Customer 1:
  Name: Ahmad bin Ali
  Phone: 0123456789
  Email: ahmad@email.com (optional)
  Address: 123, Jalan ABC, Taman XYZ, 12345 KL (optional)

Customer 2:
  Name: Siti Nurhaliza
  Phone: 0198765432
  Email: siti@email.com (optional)
  Address: 456, Jalan DEF, Taman UVW, 54321 KL (optional)

Customer 3:
  Name: Lim Ah Beng
  Phone: 0112233445
  Email: (optional)
  Address: (optional)

[Continue dengan lebih banyak customers...]
```

### Tips:
- Vary nama (Melayu, Cina, India)
- Gunakan nombor telefon yang realistik
- Mix dengan dan tanpa email/address

---

## 5. 🏪 VENDORS (Minimum 3-5 vendors)

### Format untuk setiap vendor:
```
Vendor 1:
  Name: Kedai Runcit ABC
  Vendor Number: NV-001 (optional)
  Email: vendor1@email.com (optional)
  Phone: 0123456789 (optional)
  Address: 123, Jalan Vendor, KL (optional)
  Commission Type: percentage
  Default Commission Rate: 15.0
  Bank Name: Maybank (optional)
  Bank Account Number: 1234567890 (optional)
  Bank Account Holder: Kedai Runcit ABC (optional)
  Notes: Vendor utama untuk produk makanan (optional)

Vendor 2:
  Name: Toko Mini XYZ
  Vendor Number: NV-002 (optional)
  Email: vendor2@email.com (optional)
  Phone: 0198765432 (optional)
  Address: 456, Jalan Vendor 2, KL (optional)
  Commission Type: percentage
  Default Commission Rate: 20.0
  Bank Name: CIMB Bank (optional)
  Bank Account Number: 9876543210 (optional)
  Bank Account Holder: Toko Mini XYZ (optional)
  Notes: (optional)

[Continue dengan lebih banyak vendors...]
```

### Tips:
- Commission rate biasanya 10-30%
- Vary commission rate untuk demo
- Tambah bank details untuk payment processing

---

## 6. 📊 STOCK ITEMS (Minimum 5-10 items)

### Format untuk setiap stock item:
```
Stock Item 1:
  Name: Tepung Gandum
  Unit: kg
  Package Size: 1.0
  Purchase Price: 5.50
  Current Quantity: 50.0
  Low Stock Threshold: 10.0
  Notes: Tepung untuk kek dan roti (optional)
  Supplier ID: (optional - link ke supplier jika ada)

Stock Item 2:
  Name: Gula Pasir
  Unit: kg
  Package Size: 1.0
  Purchase Price: 3.20
  Current Quantity: 30.0
  Low Stock Threshold: 5.0
  Notes: (optional)

Stock Item 3:
  Name: Telur Ayam
  Unit: biji
  Package Size: 30.0
  Purchase Price: 12.00
  Current Quantity: 120.0
  Low Stock Threshold: 30.0
  Notes: Satu tray 30 biji (optional)

Stock Item 4:
  Name: Mentega
  Unit: kg
  Package Size: 1.0
  Purchase Price: 8.90
  Current Quantity: 15.0
  Low Stock Threshold: 3.0
  Notes: (optional)

Stock Item 5:
  Name: Susu Segar
  Unit: liter
  Package Size: 1.0
  Purchase Price: 4.50
  Current Quantity: 20.0
  Low Stock Threshold: 5.0
  Notes: (optional)

[Continue dengan lebih banyak stock items...]
```

### Tips:
- Vary unit (kg, liter, biji, bungkus, etc.)
- Set current quantity yang realistik
- Low stock threshold biasanya 20-30% dari normal stock

---

## 7. 🧾 RECIPES (Optional - untuk produk yang guna recipe)

### Format untuk setiap recipe:
```
Recipe 1 (untuk Product: Kek Coklat):
  Product ID: [ID dari product yang dah create]
  Name: Resipi Kek Coklat V1
  Description: Resipi asas untuk kek coklat (optional)
  Yield Quantity: 1.0
  Yield Unit: biji
  Version: 1
  Is Active: true

  Recipe Items (bahan-bahan):
    Item 1:
      Stock Item ID: [ID dari stock item Tepung Gandum]
      Quantity: 0.5
      Unit: kg
    
    Item 2:
      Stock Item ID: [ID dari stock item Gula Pasir]
      Quantity: 0.3
      Unit: kg
    
    Item 3:
      Stock Item ID: [ID dari stock item Telur Ayam]
      Quantity: 3.0
      Unit: biji
    
    Item 4:
      Stock Item ID: [ID dari stock item Mentega]
      Quantity: 0.2
      Unit: kg

[Continue dengan recipes untuk produk lain...]
```

### Tips:
- Recipe items akan auto-calculate cost
- Yield quantity = berapa banyak produk yang dapat dari recipe
- Boleh buat multiple versions untuk recipe yang sama

---

## 8. 💰 SALES TRANSACTIONS (Minimum 10-20 transactions)

### Format untuk setiap sale:
```
Sale 1:
  Customer ID: [ID dari customer yang dah create]
  Channel: walk_in (atau: online, phone, delivery, etc.)
  Status: confirmed
  Tax: 0.00
  Discount: 0.00
  Occurred At: 2025-01-15 10:30:00
  
  Line Items:
    Item 1:
      Product ID: [ID dari product Kek Coklat]
      Quantity: 2
      Unit Price: 15.00
    
    Item 2:
      Product ID: [ID dari product Teh Tarik]
      Quantity: 2
      Unit Price: 2.00

Sale 2:
  Customer ID: [ID dari customer lain]
  Channel: online
  Status: confirmed
  Tax: 0.00
  Discount: 5.00
  Occurred At: 2025-01-15 14:20:00
  
  Line Items:
    Item 1:
      Product ID: [ID dari product Nasi Lemak]
      Quantity: 5
      Unit Price: 5.00

[Continue dengan lebih banyak sales...]
```

### Tips:
- Vary channels (walk_in, online, phone, delivery)
- Vary dates (spread across beberapa bulan untuk demo)
- Mix dengan dan tanpa discount
- Vary quantities dan products

---

## 9. 💸 EXPENSES (Minimum 5-10 expenses)

### Format untuk setiap expense:
```
Expense 1:
  Category: Bahan Mentah
  Amount: 150.00
  Currency: MYR
  Expense Date: 2025-01-10
  Vendor ID: [ID dari vendor jika ada] (optional)
  Notes: Beli tepung dan gula (optional)

Expense 2:
  Category: Sewa Kedai
  Amount: 800.00
  Currency: MYR
  Expense Date: 2025-01-01
  Vendor ID: (optional)
  Notes: Sewa bulanan (optional)

Expense 3:
  Category: Utiliti
  Amount: 120.00
  Currency: MYR
  Expense Date: 2025-01-05
  Vendor ID: (optional)
  Notes: Bil elektrik (optional)

Expense 4:
  Category: Gaji
  Amount: 2000.00
  Currency: MYR
  Expense Date: 2025-01-01
  Vendor ID: (optional)
  Notes: Gaji pekerja (optional)

Expense 5:
  Category: Marketing
  Amount: 300.00
  Currency: MYR
  Expense Date: 2025-01-12
  Vendor ID: (optional)
  Notes: Iklan Facebook (optional)

[Continue dengan lebih banyak expenses...]
```

### Common Categories:
- Bahan Mentah
- Sewa Kedai
- Utiliti (Elektrik, Air)
- Gaji
- Marketing
- Peralatan
- Lain-lain

---

## 10. 📅 BOOKINGS (Optional - Minimum 3-5 bookings)

### Format untuk setiap booking:
```
Booking 1:
  Customer Name: Ahmad bin Ali
  Customer Phone: 0123456789
  Customer Email: ahmad@email.com (optional)
  Event Type: Hari Jadi
  Event Date: 2025-02-15 (optional)
  Delivery Date: 2025-02-15
  Delivery Time: 14:00 (optional)
  Delivery Location: 123, Jalan ABC, KL (optional)
  Notes: Kek untuk 20 orang (optional)
  Discount Type: percentage (atau: fixed) (optional)
  Discount Value: 10.0 (optional)
  Deposit Amount: 50.00 (optional)
  
  Items:
    Item 1:
      Product ID: [ID dari product Kek Coklat]
      Quantity: 1
      Unit Price: 15.00

Booking 2:
  Customer Name: Siti Nurhaliza
  Customer Phone: 0198765432
  Customer Email: siti@email.com (optional)
  Event Type: Perkahwinan
  Event Date: 2025-03-01 (optional)
  Delivery Date: 2025-03-01
  Delivery Time: 10:00 (optional)
  Delivery Location: Dewan Serbaguna, KL (optional)
  Notes: Kek untuk 100 orang (optional)
  Discount Type: fixed (optional)
  Discount Value: 20.00 (optional)
  Deposit Amount: 200.00 (optional)
  
  Items:
    Item 1:
      Product ID: [ID dari product Kek Red Velvet]
      Quantity: 2
      Unit Price: 25.00

[Continue dengan lebih banyak bookings...]
```

### Common Event Types:
- Hari Jadi
- Perkahwinan
- Majlis Korporat
- Hari Raya
- Lain-lain

---

## 11. 🏭 SUPPLIERS (Optional - untuk stock items)

### Format untuk setiap supplier:
```
Supplier 1:
  Name: Pembekal Tepung Sdn Bhd
  Email: supplier1@email.com (optional)
  Phone: 0123456789 (optional)
  Address: 123, Jalan Supplier, KL (optional)
  Type: supplier
  Notes: Pembekal utama untuk bahan mentah (optional)

Supplier 2:
  Name: Kedai Bahan Kek
  Email: supplier2@email.com (optional)
  Phone: 0198765432 (optional)
  Address: 456, Jalan Supplier 2, KL (optional)
  Type: supplier
  Notes: (optional)

[Continue dengan lebih banyak suppliers...]
```

---

## 📝 CHECKLIST SETUP DEMO ACCOUNT

### Step 1: Create User Account
- [ ] Register dengan email dan password
- [ ] Verify email (jika perlu)
- [ ] Login ke app

### Step 2: Setup Business Profile
- [ ] Isi business name (required)
- [ ] Isi tagline (optional)
- [ ] Isi registration number (optional)
- [ ] Isi address, phone, email (optional)
- [ ] Isi bank details (optional)

### Step 3: Add Products
- [ ] Create minimum 5-10 products
- [ ] Vary categories dan prices
- [ ] Set cost price dan sale price

### Step 4: Add Customers
- [ ] Create minimum 5-10 customers
- [ ] Isi name dan phone (required)
- [ ] Isi email dan address (optional)

### Step 5: Add Vendors
- [ ] Create minimum 3-5 vendors
- [ ] Set commission type dan rate
- [ ] Isi bank details (optional)

### Step 6: Add Stock Items
- [ ] Create minimum 5-10 stock items
- [ ] Set current quantity
- [ ] Set low stock threshold
- [ ] Link ke suppliers (optional)

### Step 7: Create Recipes (Optional)
- [ ] Create recipes untuk products yang guna recipe
- [ ] Add recipe items (bahan-bahan)
- [ ] Verify cost calculation

### Step 8: Create Sales Transactions
- [ ] Create minimum 10-20 sales
- [ ] Vary channels dan dates
- [ ] Mix dengan dan tanpa discount
- [ ] Spread dates across beberapa bulan

### Step 9: Create Expenses
- [ ] Create minimum 5-10 expenses
- [ ] Vary categories
- [ ] Spread dates across beberapa bulan

### Step 10: Create Bookings (Optional)
- [ ] Create minimum 3-5 bookings
- [ ] Vary event types
- [ ] Set future delivery dates

---

## 💡 TIPS UNTUK DEMO ACCOUNT

1. **Realistic Data**: Gunakan data yang realistik dan munasabah
2. **Date Spread**: Spread transactions dan expenses across beberapa bulan untuk demo reports
3. **Variety**: Vary semua data (prices, quantities, categories, etc.)
4. **Complete Data**: Isi semua fields yang ada untuk demo yang lebih lengkap
5. **Test Scenarios**: Include edge cases (discounts, multiple items, etc.)

---

## 📊 SAMPLE DATA QUANTITY RECOMMENDATIONS

- **Products**: 10-15 produk
- **Customers**: 10-15 pelanggan
- **Vendors**: 3-5 vendors
- **Stock Items**: 10-15 items
- **Recipes**: 3-5 recipes (jika applicable)
- **Sales**: 20-30 transactions
- **Expenses**: 10-15 expenses
- **Bookings**: 5-10 bookings (jika applicable)

---

**Note:** Semua data ini akan diisi secara manual melalui app interface. Template ini sebagai guide untuk memastikan semua data lengkap dan realistik untuk demo purposes.
