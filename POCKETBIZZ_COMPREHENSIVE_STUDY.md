# 📚 POCKETBIZZ COMPREHENSIVE DEEP STUDY
## Complete System Architecture, Modules, Flows & Features Analysis

**Date:** DEC 19, 2025  
**Version:** 2.0.0  
**Status:** Production Active  
**Framework:** Flutter + Supabase + Encore.ts

---

## 📋 TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Database Schema & Design](#database-schema--design)
5. [Core Modules Deep Dive](#core-modules-deep-dive)
6. [Business Logic Flows](#business-logic-flows)
7. [Integration Points](#integration-points)
8. [Security & Multi-Tenancy](#security--multi-tenancy)
9. [UI/UX Architecture](#uiux-architecture)
10. [State Management](#state-management)
11. [File Structure](#file-structure)
12. [Key Features Inventory](#key-features-inventory)
13. [Data Models](#data-models)
14. [Repository Pattern](#repository-pattern)
15. [API & Services](#api--services)
16. [Payment & Subscription System](#payment--subscription-system)
17. [Production & Recipe System](#production--recipe-system)
18. [Consignment System](#consignment-system)
19. [Performance Optimizations](#performance-optimizations)
20. [Deployment Architecture](#deployment-architecture)
21. [Future Roadmap](#future-roadmap)

---

## 🎯 EXECUTIVE SUMMARY

PocketBizz is a comprehensive **multi-tenant SaaS platform** designed for Malaysian SMEs, specifically targeting food businesses (bakeries, home bakers, F&B). The system provides end-to-end business management from inventory to sales, production planning, consignment management, and financial tracking.

### Key Characteristics:
- **Multi-tenant Architecture:** 1 User = 1 Business Owner = 1 Tenant (complete data isolation)
- **Scalability:** Designed for 10,000+ concurrent users
- **Platform:** Cross-platform (iOS, Android, Web, PWA)
- **Backend:** Supabase (PostgreSQL + Auth + Storage) + Encore.ts microservices
- **State Management:** Riverpod (Flutter)
- **Security:** Row Level Security (RLS) on all tables

### Business Model:
- **Subscription-based:** Free tier + Paid plans (RM 29 early adopter, RM 39 standard)
- **Payment Gateway:** BCL.my integration
- **Target Market:** Malaysian SMEs (25-45 years old, food businesses)

---

## 🏗️ SYSTEM ARCHITECTURE

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER CLIENT LAYER                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   iOS App    │  │ Android App │  │   Web App    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              SUPABASE (Backend as a Service)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Auth       │  │   Database   │  │   Storage   │      │
│  │   (JWT)      │  │ (PostgreSQL) │  │   (Files)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Realtime    │  │   Edge Fns   │  │   RLS        │      │
│  │  (WebSocket) │  │  (Serverless)│  │  (Security)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              ENCORE.TS (Microservices Layer)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Products   │  │    Sales     │  │  Inventory   │      │
│  │   Service    │  │   Service    │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Recipes    │  │   Vendors    │  │   Analytics  │      │
│  │   Service    │  │   Service    │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL INTEGRATIONS                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   BCL.my     │  │   WhatsApp   │  │   Firebase   │      │
│  │  (Payment)   │  │   Business   │  │  (Hosting)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Pattern

```
User Action (Flutter UI)
    ↓
Feature Page/Widget
    ↓
Repository (Supabase Client)
    ↓
Supabase (PostgreSQL + RLS)
    ↓
Data returned to Repository
    ↓
Model conversion
    ↓
UI update (Riverpod)
```

### Alternative Flow (with Encore.ts)

```
User Action (Flutter UI)
    ↓
Feature Page/Widget
    ↓
HTTP Request to Encore.ts API
    ↓
Encore.ts Service
    ↓
Supabase (via service key)
    ↓
Response back to Flutter
    ↓
UI update
```

---

## 💻 TECHNOLOGY STACK

### Frontend (Flutter)
- **Framework:** Flutter 3.24.0+ (Dart 3.0+)
- **State Management:** Riverpod 2.4.9
- **UI Framework:** Material Design 3
- **Key Packages:**
  - `supabase_flutter: ^2.3.4` - Backend integration
  - `flutter_riverpod: ^2.4.9` - State management
  - `intl: ^0.20.2` - Internationalization
  - `image_picker: ^1.0.7` - Image handling
  - `pdf: ^3.11.1` - PDF generation
  - `printing: ^5.13.3` - PDF printing
  - `excel: ^4.0.3` - Excel export
  - `fl_chart: ^0.65.0` - Charts
  - `url_launcher: ^6.2.5` - External links
  - `share_plus: ^7.2.1` - Sharing
  - `google_sign_in: ^6.2.1` - Google OAuth
  - `googleapis: ^11.3.0` - Google APIs

### Backend
- **Primary:** Supabase
  - PostgreSQL (database)
  - Supabase Auth (JWT authentication)
  - Supabase Storage (file storage)
  - Supabase Edge Functions (serverless)
  - Row Level Security (RLS)
  - Realtime subscriptions

- **Secondary:** Encore.ts
  - TypeScript microservices
  - Type-safe APIs
  - Event-driven architecture
  - Cron jobs

### External Services
- **Payment Gateway:** BCL.my
- **Hosting:** Firebase Hosting (web)
- **Analytics:** Firebase Analytics (planned)
- **Error Tracking:** Sentry (planned)

---

## 🗄️ DATABASE SCHEMA & DESIGN

### Core Design Principles

1. **Multi-Tenant Isolation:**
   - Every table has `business_owner_id UUID` column
   - RLS policies enforce data isolation
   - All queries automatically filtered by `auth.uid()`

2. **Standard Pattern:**
   ```sql
   CREATE TABLE <table_name> (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       business_owner_id UUID NOT NULL REFERENCES users(id),
       -- other columns...
       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   
   CREATE INDEX idx_<table>_owner ON <table>(business_owner_id);
   
   ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
   
   CREATE POLICY "<table>_select_own" ON <table>
       FOR SELECT USING (business_owner_id = auth.uid());
   ```

3. **Soft Deletes:** Most tables use `is_archived` or `is_active` flags

### Core Tables

#### 1. **Users & Authentication**
```sql
users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone TEXT,
    subscription_plan TEXT DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

business_profiles (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    business_name TEXT NOT NULL,
    business_type TEXT,
    registration_number TEXT,
    tax_number TEXT,
    address JSONB,
    logo_url TEXT,
    settings JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
```

#### 2. **Products & Inventory**
```sql
products (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    sale_price NUMERIC(12,2) NOT NULL,
    current_stock NUMERIC(12,3) DEFAULT 0,
    min_stock NUMERIC(12,3) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    barcode TEXT,
    images JSONB,
    -- Recipe/Production fields:
    units_per_batch INTEGER,
    labour_cost NUMERIC,
    other_costs NUMERIC,
    packaging_cost NUMERIC,
    materials_cost NUMERIC,
    total_cost_per_batch NUMERIC,
    cost_per_unit NUMERIC,
    suggested_margin NUMERIC,
    suggested_price NUMERIC,
    selling_price NUMERIC,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

categories (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    name TEXT NOT NULL,
    description TEXT,
    color TEXT,
    icon TEXT,
    created_at TIMESTAMPTZ
)

stock_items (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    name TEXT NOT NULL,
    unit TEXT NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    supplier_id UUID REFERENCES vendors(id),
    current_stock NUMERIC(12,3) DEFAULT 0,
    min_stock NUMERIC(12,3) DEFAULT 0,
    created_at TIMESTAMPTZ
)

stock_item_batches (
    id UUID PRIMARY KEY,
    stock_item_id UUID REFERENCES stock_items(id),
    quantity NUMERIC(12,3) NOT NULL,
    available_quantity NUMERIC(12,3) NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    purchase_date DATE,
    expiry_date DATE,
    created_at TIMESTAMPTZ
)

stock_movements (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    stock_item_id UUID REFERENCES stock_items(id),
    batch_id UUID REFERENCES stock_item_batches(id),
    movement_type TEXT CHECK (type IN ('in','out')),
    quantity NUMERIC(12,3) NOT NULL,
    reference_type TEXT, -- 'purchase', 'production', 'adjustment', 'sale'
    reference_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ
)
```

#### 3. **Recipes & Production**
```sql
recipes (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    name TEXT NOT NULL,
    description TEXT,
    yield_quantity NUMERIC(12,3),
    yield_unit TEXT,
    total_cost NUMERIC(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

recipe_items (
    id UUID PRIMARY KEY,
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    stock_item_id UUID NOT NULL REFERENCES stock_items(id),
    quantity_needed NUMERIC(12,4) NOT NULL,
    usage_unit TEXT NOT NULL,
    cost_per_recipe NUMERIC(12,4),
    position INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ
)

finished_product_batches (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    product_id UUID NOT NULL REFERENCES products(id),
    recipe_id UUID REFERENCES recipes(id),
    quantity NUMERIC(12,3) NOT NULL,
    available_quantity NUMERIC(12,3) NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    total_cost NUMERIC(14,2) NOT NULL,
    production_date DATE NOT NULL,
    expiry_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ
)

production_ingredient_usage (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    production_batch_id UUID REFERENCES finished_product_batches(id),
    stock_item_id UUID REFERENCES stock_items(id),
    quantity NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    cost NUMERIC(14,4) NOT NULL,
    created_at TIMESTAMPTZ
)
```

#### 4. **Sales & Orders**
```sql
sales (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    customer_id UUID REFERENCES customers(id),
    channel TEXT NOT NULL, -- 'walk-in', 'online', 'delivery', 'booking', 'consignment'
    status TEXT NOT NULL, -- 'pending', 'completed', 'cancelled'
    subtotal NUMERIC(12,2) NOT NULL,
    tax NUMERIC(12,2) DEFAULT 0,
    discount NUMERIC(12,2) DEFAULT 0,
    total NUMERIC(12,2) NOT NULL,
    cogs NUMERIC(12,2) DEFAULT 0, -- Cost of Goods Sold
    profit NUMERIC(12,2) DEFAULT 0,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

sales_items (
    id UUID PRIMARY KEY,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    business_owner_id UUID REFERENCES users(id),
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    cost_of_goods NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ
)

customers (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    loyalty_tier TEXT,
    lifetime_value NUMERIC(14,2) DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMPTZ
)

bookings (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    customer_id UUID REFERENCES customers(id),
    booking_number TEXT UNIQUE,
    booking_date DATE NOT NULL,
    delivery_date DATE,
    status TEXT, -- 'pending', 'confirmed', 'completed', 'cancelled'
    total_amount NUMERIC(12,2),
    notes TEXT,
    created_at TIMESTAMPTZ
)
```

#### 5. **Vendors & Consignment**
```sql
vendors (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    type TEXT CHECK (type IN ('supplier','reseller')),
    address JSONB,
    commission_type TEXT, -- 'percentage', 'price_range'
    default_commission_rate NUMERIC(5,2),
    bank_name TEXT,
    bank_account_number TEXT,
    bank_account_holder TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ
)

vendor_products (
    id UUID PRIMARY KEY,
    vendor_id UUID REFERENCES vendors(id),
    product_id UUID REFERENCES products(id),
    business_owner_id UUID REFERENCES users(id),
    commission_rate NUMERIC(5,2), -- NULL = use vendor default
    created_at TIMESTAMPTZ
)

vendor_deliveries (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    vendor_id UUID REFERENCES vendors(id),
    vendor_name TEXT,
    delivery_date DATE,
    status TEXT, -- 'delivered', 'pending', 'claimed', 'rejected'
    payment_status TEXT, -- 'pending', 'partial', 'settled'
    total_amount NUMERIC(12,2),
    invoice_number TEXT UNIQUE,
    notes TEXT,
    created_at TIMESTAMPTZ
)

vendor_delivery_items (
    id UUID PRIMARY KEY,
    delivery_id UUID REFERENCES vendor_deliveries(id),
    product_id UUID REFERENCES products(id),
    product_name TEXT,
    quantity NUMERIC(12,3),
    unit_price NUMERIC(12,2),
    total_price NUMERIC(12,2),
    retail_price NUMERIC(12,2),
    rejected_qty NUMERIC(12,3) DEFAULT 0,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ
)

consignment_claims (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    vendor_id UUID REFERENCES vendors(id),
    claim_number TEXT UNIQUE,
    claim_date DATE,
    status TEXT, -- 'draft', 'submitted', 'approved', 'rejected', 'settled'
    gross_amount NUMERIC(12,2),
    commission_rate NUMERIC(5,2),
    commission_amount NUMERIC(12,2),
    net_amount NUMERIC(12,2),
    paid_amount NUMERIC(12,2) DEFAULT 0,
    balance_amount NUMERIC(12,2),
    notes TEXT,
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    paid_by UUID REFERENCES users(id),
    paid_at TIMESTAMPTZ,
    payment_reference TEXT,
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)

consignment_claim_items (
    id UUID PRIMARY KEY,
    claim_id UUID REFERENCES consignment_claims(id),
    delivery_id UUID REFERENCES vendor_deliveries(id),
    delivery_item_id UUID REFERENCES vendor_delivery_items(id),
    product_id UUID REFERENCES products(id),
    product_name TEXT,
    delivered_qty NUMERIC(12,3),
    sold_qty NUMERIC(12,3),
    unsold_qty NUMERIC(12,3),
    expired_qty NUMERIC(12,3),
    damaged_qty NUMERIC(12,3),
    unit_price NUMERIC(12,2),
    claimed_amount NUMERIC(12,2),
    created_at TIMESTAMPTZ
)

consignment_payments (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    vendor_id UUID REFERENCES vendors(id),
    payment_date DATE,
    amount NUMERIC(12,2),
    payment_method TEXT,
    payment_reference TEXT,
    claim_ids UUID[],
    notes TEXT,
    recorded_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ
)
```

#### 6. **Purchasing & Shopping**
```sql
purchase_orders (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    supplier_id UUID REFERENCES vendors(id),
    po_number TEXT UNIQUE,
    order_date DATE,
    status TEXT, -- 'draft', 'pending', 'received', 'cancelled'
    total_amount NUMERIC(12,2),
    notes TEXT,
    created_at TIMESTAMPTZ
)

purchase_order_items (
    id UUID PRIMARY KEY,
    po_id UUID REFERENCES purchase_orders(id),
    stock_item_id UUID REFERENCES stock_items(id),
    quantity NUMERIC(12,3),
    unit_price NUMERIC(12,2),
    total_price NUMERIC(12,2),
    created_at TIMESTAMPTZ
)

shopping_cart_items (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    stock_item_id UUID REFERENCES stock_items(id),
    quantity NUMERIC(12,3),
    notes TEXT,
    created_at TIMESTAMPTZ
)
```

#### 7. **Subscriptions**
```sql
subscription_plans (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    duration_months INTEGER NOT NULL,
    price_per_month NUMERIC(10,2) NOT NULL,
    features JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ
)

subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    plan_id UUID REFERENCES subscription_plans(id),
    status TEXT, -- 'trial', 'pending_payment', 'active', 'expired', 'cancelled'
    started_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    grace_until TIMESTAMPTZ,
    payment_status TEXT,
    payment_completed_at TIMESTAMPTZ,
    payment_reference TEXT,
    auto_renew BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

subscription_payments (
    id UUID PRIMARY KEY,
    subscription_id UUID REFERENCES subscriptions(id),
    user_id UUID REFERENCES users(id),
    plan_id UUID REFERENCES subscription_plans(id),
    amount NUMERIC(10,2) NOT NULL,
    status TEXT, -- 'pending', 'completed', 'failed', 'refunded'
    payment_reference TEXT,
    gateway_transaction_id TEXT,
    paid_at TIMESTAMPTZ,
    receipt_url TEXT,
    created_at TIMESTAMPTZ
)

early_adopters (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) UNIQUE,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
)
```

#### 8. **Other Tables**
```sql
deliveries (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    customer_id UUID REFERENCES customers(id),
    delivery_date DATE,
    status TEXT,
    address JSONB,
    notes TEXT,
    created_at TIMESTAMPTZ
)

expenses (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    vendor_id UUID REFERENCES vendors(id),
    category TEXT,
    amount NUMERIC(12,2),
    description TEXT,
    expense_date DATE,
    receipt_url TEXT,
    created_at TIMESTAMPTZ
)

competitor_prices (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    competitor_name TEXT,
    price NUMERIC(12,2),
    source TEXT,
    recorded_at TIMESTAMPTZ
)

announcements (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    media_type TEXT, -- 'image', 'video', 'none'
    media_url TEXT,
    target_audience TEXT, -- 'all', 'free', 'paid', 'early_adopter'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ
)

feedback_requests (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    category TEXT,
    title TEXT,
    description TEXT,
    status TEXT, -- 'open', 'in_progress', 'resolved', 'closed'
    created_at TIMESTAMPTZ
)

community_links (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    description TEXT,
    category TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ
)
```

### Indexes & Performance

```sql
-- Composite indexes for common queries
CREATE INDEX idx_sales_owner_date ON sales(business_owner_id, created_at DESC);
CREATE INDEX idx_products_owner_active ON products(business_owner_id, is_active) WHERE is_active = true;
CREATE INDEX idx_stock_movements_product ON stock_movements(stock_item_id, created_at DESC);
CREATE INDEX idx_sales_items_product ON sales_items(product_id);

-- Partial indexes for status queries
CREATE INDEX idx_sales_pending ON sales(business_owner_id) WHERE status = 'pending';
CREATE INDEX idx_consignment_claims_pending ON consignment_claims(business_owner_id) WHERE status = 'submitted';

-- GIN indexes for JSONB columns
CREATE INDEX idx_business_settings ON business_profiles USING GIN(settings);
```

---

## 📦 CORE MODULES DEEP DIVE

### 1. **Authentication Module** (`lib/features/auth/`)

**Purpose:** User authentication and authorization

**Files:**
- `login_page.dart` - Login/signup UI
- `forgot_password_page.dart` - Password reset
- `reset_password_page.dart` - Reset password confirmation

**Features:**
- Email/password authentication via Supabase Auth
- Password reset flow
- Session management
- Auto-login on app start

**Flow:**
```
App Start → AuthWrapper → Check Session
    ↓
Session exists? → HomePage
    ↓
No session → LoginPage
    ↓
User logs in → Supabase Auth
    ↓
Session created → HomePage
```

---

### 2. **Dashboard Module** (`lib/features/dashboard/`)

**Purpose:** Main landing page with business overview

**Files:**
- `home_page.dart` - Main navigation container
- `dashboard_page_optimized.dart` - Dashboard UI
- `widgets/morning_briefing_card.dart` - Daily briefing
- `widgets/quick_action_grid.dart` - Quick actions
- `widgets/low_stock_alerts_widget.dart` - Stock alerts
- `widgets/smart_suggestions_widget.dart` - AI suggestions
- `widgets/urgent_actions_widget.dart` - Urgent tasks
- `widgets/sales_by_channel_card.dart` - Sales breakdown

**Features:**
- Today's sales summary
- Monthly trends
- Low stock alerts
- Quick actions (Create Sale, Add Product, etc.)
- Morning briefing with urgent actions
- Sales by channel breakdown
- Performance metrics

**Data Sources:**
- Sales repository (today's sales, monthly trends)
- Stock repository (low stock items)
- Products repository (product count)
- Bookings repository (pending bookings)

---

### 3. **Products Module** (`lib/features/products/`)

**Purpose:** Product catalog management

**Files:**
- `product_list_page.dart` - Product listing
- `add_product_page.dart` - Create product
- `edit_product_page.dart` - Edit product
- `product_form_page.dart` - Product form (shared)
- `widgets/product_image_picker.dart` - Image upload
- `widgets/category_dropdown.dart` - Category selector
- `widgets/market_analysis_card.dart` - Competitor analysis
- `widgets/competitor_price_dialog.dart` - Add competitor price

**Features:**
- CRUD operations (Create, Read, Update, Delete)
- Product images (multiple)
- Category management
- SKU management
- Cost & sale price tracking
- Stock tracking
- Recipe-based costing
- Competitor price tracking
- Market analysis
- Barcode support (planned)

**Data Model:**
```dart
class Product {
  final String id;
  final String businessOwnerId;
  final String sku;
  final String name;
  final String? description;
  final String? category;
  final String unit;
  final double costPrice;
  final double salePrice;
  final double currentStock;
  final double minStock;
  final bool isActive;
  final String? barcode;
  final List<String>? images;
  // Recipe/Production fields:
  final int? unitsPerBatch;
  final double? labourCost;
  final double? otherCosts;
  final double? packagingCost;
  final double? materialsCost;
  final double? totalCostPerBatch;
  final double? costPerUnit;
  final double? suggestedMargin;
  final double? suggestedPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Repository:** `ProductsRepositorySupabase`

**Key Methods:**
- `getAllProducts()` - List all products
- `getProductById(String id)` - Get single product
- `createProduct(Product product)` - Create new product
- `updateProduct(String id, Product product)` - Update product
- `deleteProduct(String id)` - Delete product
- `getProductsByCategory(String category)` - Filter by category
- `searchProducts(String query)` - Search products
- `updateProductStock(String id, double quantity)` - Update stock
- `getCompetitorPrices(String productId)` - Get competitor data
- `addCompetitorPrice(...)` - Add competitor price

---

### 4. **Sales Module** (`lib/features/sales/`)

**Purpose:** Point of Sale (POS) and sales management

**Files:**
- `sales_page.dart` - Sales listing
- `sales_page_enhanced.dart` - Enhanced sales page
- `create_sale_page_enhanced.dart` - Create sale UI
- `sale_details_dialog.dart` - Sale details modal

**Features:**
- Create sales transactions
- Multiple sales channels (walk-in, online, delivery, booking, consignment)
- Customer selection/creation
- Multiple items per sale
- Discount & tax calculation
- Profit calculation (COGS)
- Sales history
- Invoice generation (PDF)
- Receipt printing (thermal, A5, normal)

**Data Model:**
```dart
class Sale {
  final String id;
  final String businessOwnerId;
  final String? customerId;
  final String channel; // 'walk-in', 'online', 'delivery', 'booking', 'consignment'
  final String status; // 'pending', 'completed', 'cancelled'
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final double cogs; // Cost of Goods Sold
  final double profit;
  final DateTime occurredAt;
  final List<SaleItem> items;
}

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final double total;
  final double costOfGoods;
}
```

**Repository:** `SalesRepositorySupabase`

**Key Methods:**
- `getAllSales({DateTime? from, DateTime? to})` - List sales
- `getSaleById(String id)` - Get single sale
- `createSale(Sale sale)` - Create sale
- `updateSale(String id, Sale sale)` - Update sale
- `deleteSale(String id)` - Delete sale
- `getSalesByChannel(String channel)` - Filter by channel
- `getSalesByDateRange(DateTime from, DateTime to)` - Date range filter
- `calculateProfit(String saleId)` - Calculate profit

**Business Logic:**
- FIFO stock deduction on sale
- Automatic COGS calculation
- Profit = Total - COGS
- Stock updates automatically

---

### 5. **Stock/Inventory Module** (`lib/features/stock/`)

**Purpose:** Raw materials/ingredients inventory management

**Files:**
- `stock_page.dart` - Stock listing
- `add_stock_page.dart` - Add stock item
- `adjust_stock_page.dart` - Stock adjustment
- `batch_management_page.dart` - Batch tracking
- `stock_history_page.dart` - Stock movement history
- `widgets/shopping_list_dialog.dart` - Shopping list integration

**Features:**
- Stock items (raw materials/ingredients)
- Batch tracking (FIFO)
- Stock movements (audit trail)
- Low stock alerts
- Stock adjustments
- Unit conversions
- Expiry date tracking
- Supplier linking
- Shopping list integration

**Data Model:**
```dart
class StockItem {
  final String id;
  final String businessOwnerId;
  final String name;
  final String unit;
  final double costPerUnit;
  final String? supplierId;
  final double currentStock;
  final double minStock;
  final DateTime createdAt;
}

class StockItemBatch {
  final String id;
  final String stockItemId;
  final double quantity;
  final double availableQuantity;
  final double costPerUnit;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
}

class StockMovement {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  final String? batchId;
  final String movementType; // 'in', 'out'
  final double quantity;
  final String? referenceType; // 'purchase', 'production', 'adjustment', 'sale'
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;
}
```

**Repository:** `StockRepositorySupabase`

**Key Methods:**
- `getAllStockItems()` - List all stock items
- `getStockItemById(String id)` - Get single item
- `createStockItem(StockItem item)` - Create item
- `updateStockItem(String id, StockItem item)` - Update item
- `deleteStockItem(String id)` - Delete item
- `addStock(String stockItemId, double quantity, {String? batchId})` - Add stock
- `removeStock(String stockItemId, double quantity, {String? batchId})` - Remove stock
- `adjustStock(String stockItemId, double newQuantity)` - Adjust stock
- `getStockMovements(String stockItemId)` - Get movement history
- `getLowStockItems()` - Get items below min stock
- `getBatches(String stockItemId)` - Get batches for item

---

### 6. **Production Module** (`lib/features/production/`)

**Purpose:** Production planning and batch recording

**Files:**
- `production_planning_page.dart` - Production planning UI
- `record_production_page.dart` - Record production batch
- `widgets/production_planning_dialog.dart` - Planning dialog
- `widgets/bulk_production_planning_dialog.dart` - Bulk planning

**Features:**
- Production planning (calculate materials needed)
- Record production batches
- Automatic stock deduction
- Ingredient usage tracking
- Cost calculation
- Batch tracking
- Expiry date management

**Data Model:**
```dart
class ProductionBatch {
  final String id;
  final String businessOwnerId;
  final String productId;
  final String? recipeId;
  final double quantity;
  final double availableQuantity;
  final double costPerUnit;
  final double totalCost;
  final DateTime productionDate;
  final DateTime? expiryDate;
  final String? notes;
}

class ProductionIngredientUsage {
  final String id;
  final String businessOwnerId;
  final String productionBatchId;
  final String stockItemId;
  final double quantity;
  final String unit;
  final double cost;
}
```

**Repository:** `ProductionRepositorySupabase`

**Key Methods:**
- `planProduction(String productId, int batches)` - Calculate materials needed
- `recordProductionBatch(...)` - Record production
- `getProductionBatches({String? productId, DateTime? from, DateTime? to})` - List batches
- `getProductionBatchById(String id)` - Get single batch
- `getIngredientUsage(String batchId)` - Get ingredient usage

**Business Logic:**
- Automatic stock deduction (FIFO)
- Cost calculation from recipe
- Ingredient usage audit trail
- Batch expiry tracking

---

### 7. **Recipes Module** (`lib/features/recipes/`)

**Purpose:** Recipe builder and management

**Files:**
- `recipe_builder_page.dart` - Recipe builder UI

**Features:**
- Create recipes for products
- Add ingredients to recipes
- Recipe versioning
- Yield quantity tracking
- Automatic cost calculation
- Unit conversion support
- Recipe activation/deactivation

**Data Model:**
```dart
class Recipe {
  final String id;
  final String businessOwnerId;
  final String productId;
  final String name;
  final String? description;
  final double? yieldQuantity;
  final String? yieldUnit;
  final double totalCost;
  final bool isActive;
  final int version;
  final List<RecipeItem> items;
}

class RecipeItem {
  final String id;
  final String recipeId;
  final String stockItemId;
  final double quantityNeeded;
  final String usageUnit;
  final double? costPerRecipe;
  final int position;
}
```

**Repository:** `RecipesRepositorySupabase`

**Key Methods:**
- `getRecipeForProduct(String productId)` - Get product's recipe
- `createRecipe(Recipe recipe)` - Create recipe
- `updateRecipe(String id, Recipe recipe)` - Update recipe
- `deleteRecipe(String id)` - Delete recipe
- `addRecipeItem(String recipeId, RecipeItem item)` - Add ingredient
- `removeRecipeItem(String itemId)` - Remove ingredient
- `updateRecipeItem(String itemId, RecipeItem item)` - Update ingredient
- `calculateRecipeCost(String recipeId)` - Calculate cost
- `replaceRecipe(String recipeId, List<RecipeItem> items)` - Replace all items

**Business Logic:**
- Automatic cost calculation when:
  - Recipe items added/removed
  - Quantities changed
  - Stock prices updated
- Cost breakdown:
  - Materials cost = Sum of ingredient costs
  - Total cost = Materials + Labour + Other + (Packaging × Units)
  - Cost per unit = Total cost / Yield quantity

---

### 8. **Vendors Module** (`lib/features/vendors/`)

**Purpose:** Vendor/supplier management

**Files:**
- `vendors_page.dart` - Vendor listing
- `add_vendor_page.dart` - Create vendor
- `vendor_detail_page.dart` - Vendor details
- `assign_products_page.dart` - Assign products to vendor
- `commission_dialog.dart` - Commission settings

**Features:**
- Vendor CRUD operations
- Product assignment
- Commission structure (percentage or price-range based)
- Bank details tracking
- Vendor summary (sales, commission, payments)
- Payment history

**Data Model:**
```dart
class Vendor {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? email;
  final String? phone;
  final String type; // 'supplier', 'reseller'
  final Map<String, dynamic>? address;
  final String? commissionType; // 'percentage', 'price_range'
  final double? defaultCommissionRate;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  final bool isActive;
  final DateTime createdAt;
}
```

**Repository:** `VendorsRepositorySupabase`

**Key Methods:**
- `getAllVendors({bool activeOnly = true})` - List vendors
- `getVendorById(String id)` - Get single vendor
- `createVendor(Vendor vendor)` - Create vendor
- `updateVendor(Vendor vendor)` - Update vendor
- `deleteVendor(String id)` - Delete vendor
- `assignProductToVendor(String vendorId, String productId, {double? commissionRate})` - Assign product
- `removeProductFromVendor(String vendorId, String productId)` - Remove product
- `getVendorProducts(String vendorId)` - Get vendor's products
- `getVendorSummary(String vendorId)` - Get summary

---

### 9. **Deliveries Module** (`lib/features/deliveries/`)

**Purpose:** Delivery tracking for consignment system

**Files:**
- `deliveries_page.dart` - Delivery listing
- `delivery_form_dialog.dart` - Create delivery
- `edit_rejection_dialog.dart` - Edit rejection
- `payment_status_dialog.dart` - Update payment status
- `invoice_dialog.dart` - View invoice

**Features:**
- Create deliveries to vendors
- Track delivery status
- Rejection tracking
- Payment status tracking
- Invoice generation (PDF)
- WhatsApp sharing
- CSV export
- Duplicate yesterday's deliveries

**Data Model:**
```dart
class Delivery {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String vendorName;
  final DateTime deliveryDate;
  final String status; // 'delivered', 'pending', 'claimed', 'rejected'
  final String? paymentStatus; // 'pending', 'partial', 'settled'
  final double totalAmount;
  final String? invoiceNumber;
  final String? notes;
  final List<DeliveryItem> items;
}

class DeliveryItem {
  final String id;
  final String deliveryId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? retailPrice;
  final double rejectedQty;
  final String? rejectionReason;
  
  double get acceptedQty => quantity - rejectedQty;
}
```

**Repository:** `DeliveriesRepositorySupabase`

**Key Methods:**
- `getDeliveries({String? vendorId, String? status, DateTime? from, DateTime? to})` - List deliveries
- `getDeliveryById(String id)` - Get single delivery
- `createDelivery({required String vendorId, required DateTime deliveryDate, required List<Map<String, dynamic>> items})` - Create delivery
- `updateDelivery(Delivery delivery)` - Update delivery
- `updateDeliveryStatus(String deliveryId, String status)` - Update status
- `updatePaymentStatus(String deliveryId, String paymentStatus)` - Update payment
- `updateRejection({required String itemId, required double rejectedQty, String? rejectionReason})` - Update rejection
- `exportDeliveriesToCSV({String? vendorId})` - Export CSV
- `duplicateYesterdayDeliveries()` - Duplicate yesterday

**Business Logic:**
- Auto-generate invoice number (DEL-YYMM-0001)
- Accepted quantity = Total - Rejected
- Stock deduction on delivery creation

---

### 10. **Claims Module** (`lib/features/claims/`)

**Purpose:** Consignment claims management

**Files:**
- `claims_page.dart` - Claims listing
- `create_claim_simplified_page.dart` - Create claim (wizard)
- `create_consignment_claim_page.dart` - Old create claim (reference)
- `claim_detail_page.dart` - Claim details
- `record_payment_page.dart` - Record payment
- `create_payment_simplified_page.dart` - Create payment
- `widgets/claim_summary_card.dart` - Summary card

**Features:**
- Create claims (step-by-step wizard)
- Claim status tracking (draft → submitted → approved → settled)
- Commission calculation
- Payment recording
- Payment history
- Claim validation

**Data Model:**
```dart
class ConsignmentClaim {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String claimNumber;
  final DateTime claimDate;
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'settled'
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final double paidAmount;
  final double balanceAmount;
  final String? notes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? paidBy;
  final DateTime? paidAt;
  final String? paymentReference;
  final List<ConsignmentClaimItem>? items;
}

class ConsignmentClaimItem {
  final String id;
  final String claimId;
  final String deliveryId;
  final String deliveryItemId;
  final String productId;
  final String productName;
  final double deliveredQty;
  final double soldQty;
  final double unsoldQty;
  final double expiredQty;
  final double damagedQty;
  final double unitPrice;
  final double claimedAmount; // soldQty × unitPrice
}

class ConsignmentPayment {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final DateTime paymentDate;
  final double amount;
  final String paymentMethod;
  final String? paymentReference;
  final List<String> claimIds;
  final String? notes;
  final String recordedBy;
}
```

**Repository:** `ConsignmentClaimsRepositorySupabase`

**Key Methods:**
- `getAllClaims({String? vendorId, String? status})` - List claims
- `getClaimById(String id)` - Get single claim
- `createClaim({required String vendorId, required List<String> deliveryIds, required DateTime claimDate})` - Create claim
- `validateClaimRequest({required String vendorId, required List<String> deliveryIds})` - Validate
- `getClaimSummary({required String vendorId, required List<String> deliveryIds})` - Get summary
- `submitClaim(String claimId)` - Submit claim
- `approveClaim(String claimId)` - Approve claim
- `rejectClaim(String claimId, String reason)` - Reject claim
- `recordPayment({required String vendorId, required double amount, required String paymentMethod, required List<String> claimIds})` - Record payment
- `getVendorPayments(String vendorId)` - Get payments
- `getPendingClaimsCount()` - Get pending count

**Business Logic:**
- Gross Amount = Sum of (Sold Quantity × Unit Price)
- Commission Amount = Gross × (Commission Rate / 100)
- Net Amount = Gross - Commission
- Balance Amount = Net - Paid

---

### 11. **Bookings Module** (`lib/features/bookings/`)

**Purpose:** Booking/tempahan system

**Files:**
- `bookings_page_optimized.dart` - Bookings listing
- `create_booking_page_enhanced.dart` - Create booking

**Features:**
- Create bookings
- Booking management
- Booking calendar
- PDF generation for bookings
- WhatsApp integration

**Data Model:**
```dart
class Booking {
  final String id;
  final String businessOwnerId;
  final String? customerId;
  final String bookingNumber;
  final DateTime bookingDate;
  final DateTime? deliveryDate;
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final double? totalAmount;
  final String? notes;
  final DateTime createdAt;
}
```

**Repository:** `BookingsRepositorySupabase`

---

### 12. **Purchase Orders Module** (`lib/features/purchase_orders/`)

**Purpose:** Purchase order management

**Files:**
- `purchase_orders_page.dart` - PO listing

**Features:**
- Create purchase orders
- PO line items
- PO status tracking
- Shopping cart integration

**Data Model:**
```dart
class PurchaseOrder {
  final String id;
  final String businessOwnerId;
  final String? supplierId;
  final String poNumber;
  final DateTime orderDate;
  final String status; // 'draft', 'pending', 'received', 'cancelled'
  final double? totalAmount;
  final String? notes;
  final List<PurchaseOrderItem> items;
}

class PurchaseOrderItem {
  final String id;
  final String poId;
  final String stockItemId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
}
```

**Repository:** `PurchaseOrderRepositorySupabase`

---

### 13. **Shopping List Module** (`lib/features/shopping/`)

**Purpose:** Shopping list for purchasing

**Files:**
- `shopping_list_page.dart` - Shopping list UI

**Features:**
- Shopping cart items
- Low stock suggestions
- Purchase order integration
- Auto-generated from low stock

**Data Model:**
```dart
class ShoppingCartItem {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  final double quantity;
  final String? notes;
  final DateTime createdAt;
}
```

**Repository:** `ShoppingCartRepositorySupabase`

---

### 14. **Expenses Module** (`lib/features/expenses/`)

**Purpose:** Expense tracking

**Files:**
- `expenses_page.dart` - Expenses listing
- `receipt_scan_page.dart` - OCR receipt scanning (planned)

**Features:**
- Manual expense entry
- Expense categories
- Vendor linking
- Receipt upload
- OCR receipt processing (planned)

**Data Model:**
```dart
class Expense {
  final String id;
  final String businessOwnerId;
  final String? vendorId;
  final String? category;
  final double amount;
  final String? description;
  final DateTime expenseDate;
  final String? receiptUrl;
  final DateTime createdAt;
}
```

**Repository:** `ExpensesRepositorySupabase`

---

### 15. **Subscription Module** (`lib/features/subscription/`)

**Purpose:** Subscription and payment management

**Files:**
- `subscription_page.dart` - Subscription plans & payment
- `payment_success_page.dart` - Payment success handler
- `admin/admin_dashboard_page.dart` - Admin dashboard
- `admin/subscription_list_page.dart` - Admin subscription list
- `admin/user_management_page.dart` - User management
- `widgets/subscription_guard.dart` - Feature gating

**Features:**
- Subscription plans (1, 3, 6, 12 months)
- Early adopter pricing (RM 29 vs RM 39)
- Trial period (7 days)
- Payment processing via BCL.my
- Payment history
- Receipt generation & download
- Admin dashboard
- Feature gating based on subscription

**Data Model:**
```dart
class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final int durationMonths;
  final double pricePerMonth;
  final Map<String, dynamic>? features;
  final bool isActive;
}

class Subscription {
  final String id;
  final String userId;
  final String planId;
  final String status; // 'trial', 'pending_payment', 'active', 'expired', 'cancelled'
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final String? paymentStatus;
  final DateTime? paymentCompletedAt;
  final String? paymentReference;
  final bool autoRenew;
  final SubscriptionPlan? plan;
}

class SubscriptionPayment {
  final String id;
  final String subscriptionId;
  final String userId;
  final String planId;
  final double amount;
  final String status; // 'pending', 'completed', 'failed', 'refunded'
  final String? paymentReference;
  final String? gatewayTransactionId;
  final DateTime? paidAt;
  final String? receiptUrl;
}
```

**Repository:** `SubscriptionRepositorySupabase`

**Key Methods:**
- `getAvailablePlans()` - Get all plans
- `getUserSubscription()` - Get user's subscription
- `startTrial()` - Start 7-day trial
- `isEarlyAdopter()` - Check early adopter status
- `createSubscription({required String planId, required double totalAmount, required String paymentReference})` - Create subscription
- `getPaymentHistory()` - Get payment history
- `generateReceipt(String paymentId)` - Generate receipt PDF

**Payment Flow:**
```
User selects plan
    ↓
Check early adopter status
    ↓
Calculate price (RM 29 or RM 39)
    ↓
Create subscription (status='pending_payment')
    ↓
Create payment record (status='pending')
    ↓
Redirect to BCL.my payment
    ↓
User completes payment
    ↓
BCL.my webhook → Update subscription & payment
    ↓
Redirect to PaymentSuccessPage
    ↓
Show success message
```

**BCL.my Integration:**
- Webhook: `supabase/functions/bcl-webhook/index.ts`
- Payment link creation: `supabase/functions/bcl-create-payment-link/index.ts`
- Receipt sync with BCL.my data

---

### 16. **Reports Module** (`lib/features/reports/`)

**Purpose:** Business analytics and reporting

**Files:**
- `reports_page.dart` - Reports dashboard
- `data/models/profit_loss_report.dart` - P&L model
- `data/models/monthly_trend.dart` - Trend model
- `data/models/sales_by_channel.dart` - Channel model
- `data/models/top_product.dart` - Top product model
- `data/models/top_vendor.dart` - Top vendor model
- `utils/pdf_generator.dart` - PDF report generation

**Features:**
- Profit & Loss report
- Monthly trends
- Sales by channel
- Top products
- Top vendors
- PDF export

**Repository:** `ReportsRepositorySupabase`

---

### 17. **Settings Module** (`lib/features/settings/`)

**Purpose:** App and business settings

**Files:**
- `settings_page.dart` - Settings UI

**Features:**
- Business profile management
- User settings
- App preferences
- Theme settings

---

### 18. **Categories Module** (`lib/features/categories/`)

**Purpose:** Product category management

**Files:**
- `categories_page.dart` - Category listing

**Features:**
- Create/edit/delete categories
- Category colors & icons
- Category assignment to products

---

### 19. **Suppliers Module** (`lib/features/suppliers/`)

**Purpose:** Supplier management (separate from vendors)

**Files:**
- `suppliers_page.dart` - Supplier listing

**Features:**
- Supplier CRUD
- Link suppliers to stock items

---

### 20. **Finished Products Module** (`lib/features/finished_products/`)

**Purpose:** Finished product batch management

**Files:**
- `finished_products_page.dart` - Finished products listing

**Features:**
- View finished product batches
- Batch expiry tracking
- Available quantity tracking

---

### 21. **Planner Module** (`lib/features/planner/`)

**Purpose:** Task and project planning

**Files:**
- `planner_page.dart` - Planner UI (old)
- `enhanced_planner_page.dart` - Enhanced planner
- `views/planner_calendar_view.dart` - Calendar view
- `views/planner_kanban_view.dart` - Kanban view
- `views/planner_list_view.dart` - List view
- `widgets/create_task_dialog.dart` - Create task
- `widgets/enhanced_task_card.dart` - Task card
- `pages/categories_management_page.dart` - Categories
- `pages/projects_management_page.dart` - Projects
- `pages/templates_management_page.dart` - Templates

**Features:**
- Task management
- Project management
- Calendar view
- Kanban board
- List view
- Task categories
- Task templates
- Subtasks
- Comments

**Data Model:**
```dart
class PlannerTask {
  final String id;
  final String businessOwnerId;
  final String? projectId;
  final String? categoryId;
  final String title;
  final String? description;
  final String status; // 'todo', 'in_progress', 'done', 'cancelled'
  final DateTime? dueDate;
  final int priority; // 1-5
  final List<PlannerSubtask>? subtasks;
  final List<PlannerComment>? comments;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PlannerProject {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? description;
  final String? color;
  final DateTime createdAt;
}

class PlannerCategory {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? color;
  final String? icon;
}
```

**Repository:** `PlannerTasksRepositorySupabase`

---

### 22. **Announcements Module** (`lib/features/announcements/`)

**Purpose:** System announcements and notifications

**Files:**
- `notifications_page.dart` - User notifications
- `notification_history_page.dart` - Notification history
- `admin/admin_announcements_page.dart` - Admin announcements

**Features:**
- System announcements
- User notifications
- Notification history
- Target audience (all, free, paid, early_adopter)
- Media support (image, video)

**Data Model:**
```dart
class Announcement {
  final String id;
  final String title;
  final String? content;
  final String? mediaType; // 'image', 'video', 'none'
  final String? mediaUrl;
  final String? targetAudience; // 'all', 'free', 'paid', 'early_adopter'
  final bool isActive;
  final DateTime createdAt;
}
```

**Repository:** `AnnouncementsRepositorySupabase`

---

### 23. **Feedback Module** (`lib/features/feedback/`)

**Purpose:** User feedback and community

**Files:**
- `submit_feedback_page.dart` - Submit feedback
- `my_feedback_page.dart` - User's feedback
- `community_links_page.dart` - Community links
- `admin/admin_feedback_page.dart` - Admin feedback management
- `admin/admin_community_links_page.dart` - Admin community links

**Features:**
- Submit feedback
- Feedback categories
- Feedback status tracking
- Community links
- Admin feedback management

**Data Model:**
```dart
class FeedbackRequest {
  final String id;
  final String userId;
  final String? category;
  final String title;
  final String? description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final DateTime createdAt;
}

class CommunityLink {
  final String id;
  final String title;
  final String url;
  final String? description;
  final String? category;
  final bool isActive;
  final DateTime createdAt;
}
```

**Repository:** `FeedbackRepositorySupabase`, `CommunityLinksRepositorySupabase`

---

### 24. **Documents Module** (`lib/features/documents/`)

**Purpose:** Document management

**Files:**
- `documents_page.dart` - Documents listing

**Features:**
- Document upload
- Document storage
- Document download

---

### 25. **Drive Sync Module** (`lib/features/drive_sync/`)

**Purpose:** Google Drive synchronization

**Files:**
- `drive_sync_page.dart` - Drive sync UI
- `services/google_drive_service.dart` - Drive service
- `utils/drive_sync_helper.dart` - Sync helper

**Features:**
- Google Drive OAuth
- File sync
- Backup to Drive

---

## 🔄 BUSINESS LOGIC FLOWS

### 1. **Sales Flow**

```
User creates sale
    ↓
Select customer (or create new)
    ↓
Add products to sale
    ↓
System calculates:
  - Subtotal
  - Tax
  - Discount
  - Total
    ↓
User confirms sale
    ↓
System processes:
  1. Create sale record
  2. Create sale items
  3. Deduct stock (FIFO)
  4. Calculate COGS
  5. Calculate profit
  6. Update product stock
    ↓
Generate invoice/receipt (PDF)
    ↓
Sale completed
```

### 2. **Production Flow**

```
User plans production
    ↓
Select product
    ↓
Enter batch quantity
    ↓
System calculates:
  - Materials needed (from recipe)
  - Current stock availability
  - Shortages (if any)
    ↓
User reviews plan
    ↓
User records production
    ↓
System processes:
  1. Create production batch
  2. Record ingredient usage
  3. Deduct stock (FIFO)
  4. Calculate cost
  5. Update finished product stock
    ↓
Production recorded
```

### 3. **Consignment Flow**

```
Owner adds vendor
    ↓
Assign products to vendor
    ↓
Create delivery to vendor
    ↓
Vendor receives delivery
    ↓
Vendor sells products
    ↓
Owner creates claim
    ↓
System calculates:
  - Gross amount (sold items)
  - Commission
  - Net amount (to pay)
    ↓
Owner approves claim
    ↓
Owner records payment
    ↓
Claim settled
```

### 4. **Recipe Costing Flow**

```
User creates recipe
    ↓
Add ingredients to recipe
    ↓
System calculates:
  - Materials cost (sum of ingredients)
    ↓
User sets:
  - Labour cost
  - Other costs
  - Packaging cost
  - Yield quantity
    ↓
System calculates:
  - Total cost per batch
  - Cost per unit
  - Suggested price (with margin)
    ↓
Recipe cost updated
```

### 5. **Subscription Flow**

```
User views subscription page
    ↓
Select plan (1, 3, 6, 12 months)
    ↓
System checks:
  - Early adopter status
  - Current subscription
    ↓
Calculate price
    ↓
Create subscription (pending_payment)
    ↓
Create payment record
    ↓
Redirect to BCL.my
    ↓
User completes payment
    ↓
BCL.my webhook received
    ↓
System updates:
  - Subscription status = 'active'
  - Payment status = 'completed'
  - Expiry date calculated
    ↓
User redirected to success page
    ↓
Subscription active
```

---

## 🔌 INTEGRATION POINTS

### 1. **BCL.my Payment Gateway**

**Purpose:** Subscription payment processing

**Integration:**
- **Payment Link Creation:** `supabase/functions/bcl-create-payment-link/index.ts`
- **Webhook Handler:** `supabase/functions/bcl-webhook/index.ts`
- **Payment Flow:** User → BCL.my → Webhook → Update subscription

**Key Features:**
- HMAC signature verification
- Payment status updates
- Receipt generation
- Data sync with BCL.my records

### 2. **Supabase Services**

**Auth:**
- JWT-based authentication
- Email/password login
- Password reset
- Session management

**Database:**
- PostgreSQL with RLS
- Real-time subscriptions
- Automatic backups

**Storage:**
- File uploads (images, PDFs, documents)
- Public/private buckets
- Signed URLs

**Edge Functions:**
- Serverless functions
- Webhook handlers
- Background jobs

### 3. **Encore.ts Microservices**

**Services:**
- Products service
- Inventory service
- Sales service
- Recipes service
- Vendors service
- Analytics service
- Production service
- Purchase service
- Bookings service
- Drive service
- Suppliers service
- Shopping service
- Consignment service
- Claims service
- Payments service

**Features:**
- Type-safe APIs
- Request validation
- Event-driven architecture
- Cron jobs

### 4. **Firebase Hosting**

**Purpose:** Web app deployment

**Configuration:**
- `firebase.json` - Hosting config
- `build/web` - Build output
- Auto-deploy via GitHub Actions

### 5. **Google Services**

**Google Sign-In:**
- OAuth authentication
- User profile access

**Google Drive:**
- File sync
- Backup functionality
- OAuth integration

---

## 🔒 SECURITY & MULTI-TENANCY

### Row Level Security (RLS)

**Pattern:**
```sql
-- Enable RLS
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;

-- Select policy
CREATE POLICY "<table>_select_own" ON <table>
    FOR SELECT USING (business_owner_id = auth.uid());

-- Insert policy
CREATE POLICY "<table>_insert_own" ON <table>
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

-- Update policy
CREATE POLICY "<table>_update_own" ON <table>
    FOR UPDATE USING (business_owner_id = auth.uid());

-- Delete policy
CREATE POLICY "<table>_delete_own" ON <table>
    FOR DELETE USING (business_owner_id = auth.uid());
```

**Benefits:**
- Automatic data isolation
- No way for User A to see User B's data
- Database-level security
- No client-side bypass possible

### Authentication

- JWT tokens via Supabase Auth
- Session management
- Password hashing (bcrypt)
- Email verification (optional)

### Input Validation

- Client-side validation (Flutter)
- Server-side validation (Supabase triggers, Encore.ts)
- SQL injection prevention (parameterized queries)
- XSS prevention (input sanitization)

### File Upload Security

- File type validation
- File size limits
- Virus scanning (planned)
- Signed URLs for private files

---

## 🎨 UI/UX ARCHITECTURE

### Design System

**Theme:**
- Material Design 3
- Light/Dark theme support
- Custom color scheme (AppColors)
- PocketBizz branding (logo, gradients)

**Colors:**
```dart
class AppColors {
  static const primary = Color(0xFF6366F1);
  static const secondary = Color(0xFF8B5CF6);
  static const accent = Color(0xFFEC4899);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  // ... more colors
}
```

### Navigation

**Bottom Navigation:**
- Dashboard
- Bookings
- Products
- Sales
- Scan (center button)

**Drawer Menu:**
- All features accessible
- Grouped by category
- Admin sections (if admin)

**Route-based Navigation:**
- Named routes in `main.dart`
- Deep linking support
- Navigation guards (subscription)

### Components

**Reusable Widgets:**
- `StatCard` - Statistics display
- `QuickActionButton` - Quick actions
- `SectionHeader` - Section titles
- `PocketBizzLogo` - Brand logo
- `PocketBizzFAB` - Floating action button

**Form Components:**
- Product form
- Sale form
- Booking form
- Vendor form

**PDF Generators:**
- Invoice generator
- Receipt generator
- Booking PDF
- Delivery invoice
- Subscription receipt

---

## 📊 STATE MANAGEMENT

### Riverpod Pattern

**Providers:**
```dart
// Repository providers
final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepositorySupabase(supabase);
});

// Data providers
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  return await repo.getAllProducts();
});

// State providers
final selectedProductProvider = StateProvider<Product?>((ref) => null);
```

**Usage:**
```dart
// In widget
final productsAsync = ref.watch(productsProvider);

productsAsync.when(
  data: (products) => ProductList(products: products),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
);
```

### State Patterns

**Loading States:**
- `AsyncValue` for async data
- Loading indicators
- Error handling

**Form States:**
- `StateProvider` for form fields
- Validation
- Submission states

**Cache Management:**
- Provider caching
- Auto-refresh on focus
- Manual refresh triggers

---

## 📁 FILE STRUCTURE

```
pocketbizz-flutter/
├── lib/
│   ├── core/
│   │   ├── config/              # App configuration
│   │   ├── services/             # Core services
│   │   ├── supabase/             # Supabase client
│   │   ├── theme/                # Theming
│   │   ├── utils/                # Utilities
│   │   └── widgets/              # Reusable widgets
│   ├── data/
│   │   ├── models/               # Data models
│   │   └── repositories/         # Repository implementations
│   ├── features/                 # Feature modules
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── products/
│   │   ├── sales/
│   │   ├── stock/
│   │   ├── production/
│   │   ├── recipes/
│   │   ├── vendors/
│   │   ├── deliveries/
│   │   ├── claims/
│   │   ├── bookings/
│   │   ├── purchase_orders/
│   │   ├── shopping/
│   │   ├── expenses/
│   │   ├── subscription/
│   │   ├── reports/
│   │   ├── settings/
│   │   ├── categories/
│   │   ├── suppliers/
│   │   ├── finished_products/
│   │   ├── planner/
│   │   ├── announcements/
│   │   ├── feedback/
│   │   ├── documents/
│   │   └── drive_sync/
│   └── main.dart                 # App entry point
├── db/
│   ├── migrations/               # Database migrations
│   └── schema.sql                # Database schema
├── services/                     # Encore.ts services
├── supabase/
│   └── functions/                # Edge functions
├── landing/                      # Landing page
├── web/                          # Web assets
├── assets/                       # App assets
└── pubspec.yaml                  # Dependencies
```

---

## 🎯 KEY FEATURES INVENTORY

### ✅ Implemented Features

1. **Authentication & Authorization**
   - Email/password login
   - Password reset
   - Session management
   - Multi-tenant isolation

2. **Dashboard**
   - Today's sales summary
   - Monthly trends
   - Low stock alerts
   - Quick actions
   - Morning briefing
   - Sales by channel

3. **Product Management**
   - CRUD operations
   - Product images
   - Categories
   - SKU management
   - Cost & pricing
   - Stock tracking
   - Recipe-based costing
   - Competitor prices
   - Market analysis

4. **Sales Management**
   - POS system
   - Multiple channels
   - Customer management
   - Discount & tax
   - Profit calculation
   - Invoice generation
   - Receipt printing

5. **Inventory Management**
   - Stock items
   - Batch tracking (FIFO)
   - Stock movements
   - Low stock alerts
   - Stock adjustments
   - Unit conversions
   - Expiry tracking

6. **Production System**
   - Production planning
   - Recipe builder
   - Batch recording
   - Automatic stock deduction
   - Cost calculation
   - Ingredient usage tracking

7. **Recipes System**
   - Recipe creation
   - Ingredient management
   - Recipe versioning
   - Automatic costing
   - Unit conversion
   - Yield tracking

8. **Vendor System**
   - Vendor management
   - Product assignment
   - Commission structure
   - Bank details
   - Vendor summary

9. **Consignment System**
   - Delivery tracking
   - Claim management
   - Commission calculation
   - Payment recording
   - Invoice generation

10. **Booking System**
    - Booking creation
    - Booking management
    - Calendar view
    - PDF generation

11. **Purchase Orders**
    - PO creation
    - PO tracking
    - Shopping cart integration

12. **Shopping List**
    - Shopping cart
    - Low stock suggestions
    - PO integration

13. **Expense Tracking**
    - Expense entry
    - Categories
    - Vendor linking
    - Receipt upload

14. **Subscription System**
    - Subscription plans
    - Payment processing
    - Early adopter pricing
    - Trial period
    - Receipt generation
    - Admin dashboard

15. **Reports**
    - Profit & Loss
    - Monthly trends
    - Sales by channel
    - Top products
    - Top vendors
    - PDF export

16. **Planner**
    - Task management
    - Project management
    - Calendar/Kanban/List views
    - Categories & templates

17. **Announcements**
    - System announcements
    - User notifications
    - Notification history

18. **Feedback**
    - Feedback submission
    - Community links
    - Admin management

### 🚧 In Progress

1. **OCR Receipt Processing**
   - Receipt scanning
   - Automatic expense extraction

2. **Advanced Analytics**
   - More detailed reports
   - Predictive analytics

3. **E-commerce Integration**
   - MyShop integration
   - Online store sync

### 📋 Planned

1. **Barcode Scanning**
   - Product scanning
   - Inventory scanning

2. **Thermal Printer Integration**
   - Direct printing
   - Receipt printing

3. **WhatsApp Business Integration**
   - Automated messages
   - Order confirmations

4. **Multi-warehouse Support**
   - Multiple locations
   - Transfer between warehouses

5. **Advanced Reporting**
   - Custom reports
   - Scheduled reports
   - Email reports

---

## 📈 PERFORMANCE OPTIMIZATIONS

### Database

- Composite indexes on common queries
- Partial indexes for filtered queries
- GIN indexes for JSONB columns
- Query optimization with EXPLAIN ANALYZE
- Connection pooling (Supabase handles)

### Flutter

- Lazy loading
- Pagination support
- Image caching
- State caching with Riverpod
- Optimized rebuilds
- Const constructors

### Supabase

- Edge functions for heavy operations
- Realtime subscriptions (selective)
- Automatic connection pooling
- Query result caching

---

## 🚀 DEPLOYMENT ARCHITECTURE

### Web Deployment

**Platform:** Firebase Hosting
**Build:** `flutter build web --release`
**Output:** `build/web/`
**Auto-deploy:** GitHub Actions

**GitHub Actions Workflow:**
```yaml
name: Build and Deploy to Firebase Hosting

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Setup Flutter
      - Get dependencies
      - Build Flutter web
      - Deploy to Firebase Hosting
```

### Mobile Deployment

**Platform:** iOS App Store, Google Play Store
**Status:** Planned
**Build:** `flutter build ios/android --release`

### Backend Deployment

**Supabase:** Cloud-hosted (managed)
**Encore.ts:** Encore Cloud (managed)

---

## 🔮 FUTURE ROADMAP

### Phase 1 (Q1 2025)
- [ ] OCR receipt processing
- [ ] Barcode scanning
- [ ] Advanced analytics
- [ ] Mobile app release

### Phase 2 (Q2 2025)
- [ ] Thermal printer integration
- [ ] WhatsApp Business integration
- [ ] Multi-warehouse support
- [ ] E-commerce integration

### Phase 3 (Q3 2025)
- [ ] AI-powered insights
- [ ] Predictive analytics
- [ ] Automated reporting
- [ ] API for third-party integrations

### Phase 4 (Q4 2025)
- [ ] Mobile apps for vendors
- [ ] Customer portal
- [ ] Marketplace integration
- [ ] Advanced compliance features

---

## 📝 SUMMARY

PocketBizz is a **comprehensive, production-ready SaaS platform** for Malaysian SMEs with:

✅ **25+ Feature Modules** - Complete business management suite  
✅ **Multi-Tenant Architecture** - Secure data isolation  
✅ **Scalable Design** - Ready for 10k+ users  
✅ **Modern Tech Stack** - Flutter + Supabase + Encore.ts  
✅ **Production Active** - Live deployment  
✅ **Comprehensive Features** - From inventory to sales to subscriptions  

**Key Strengths:**
- Clean architecture
- Type safety
- Security first (RLS)
- Scalable design
- Comprehensive features
- Production ready

**Areas for Enhancement:**
- Testing coverage
- Documentation
- Performance monitoring
- Error tracking
- CI/CD pipelines

---

**Document Version:** 1.0  
**Last Updated:** January 16, 2025  
**Maintained By:** Development Team

---

*This comprehensive study serves as the complete reference for understanding, maintaining, and enhancing the PocketBizz platform.*

