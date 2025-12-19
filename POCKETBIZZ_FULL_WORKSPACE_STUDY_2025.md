# 📚 POCKETBIZZ FULL WORKSPACE STUDY 2025
## Complete System Analysis - All Modules, Features & Architecture

**Date:** December 20 2025  
**Version:** 2.0.0  
**Status:** Production Active  
**Framework:** Flutter + Supabase + Encore.ts  
**Target Market:** Malaysian SMEs (Food Businesses, Bakeries, Home Bakers)

---

## 📋 TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Modules Deep Dive](#core-modules-deep-dive)
6. [Data Models & Business Logic](#data-models--business-logic)
7. [Repository Pattern Implementation](#repository-pattern-implementation)
8. [UI/UX Architecture](#uiux-architecture)
9. [Database Schema & Migrations](#database-schema--migrations)
10. [Security & Multi-Tenancy](#security--multi-tenancy)
11. [Subscription & Payment System](#subscription--payment-system)
12. [Integration Points](#integration-points)
13. [Feature Inventory](#feature-inventory)
14. [Business Flows](#business-flows)
15. [Performance Optimizations](#performance-optimizations)
16. [Deployment Architecture](#deployment-architecture)

---

## 🎯 EXECUTIVE SUMMARY

PocketBizz is a **comprehensive multi-tenant SaaS platform** designed specifically for Malaysian SMEs, with a focus on food businesses (bakeries, home bakers, F&B establishments). The system provides end-to-end business management from inventory to sales, production planning, consignment management, and financial tracking.

### Key Characteristics:
- **Multi-tenant Architecture:** 1 User = 1 Business Owner = 1 Tenant (complete data isolation)
- **Scalability:** Designed for 10,000+ concurrent users
- **Platform:** Cross-platform (iOS, Android, Web, PWA)
- **Backend:** Supabase (PostgreSQL + Auth + Storage) + Encore.ts microservices
- **State Management:** Riverpod (Flutter)
- **Security:** Row Level Security (RLS) on all tables
- **Payment Gateway:** BCL.my integration
- **Subscription Model:** Free tier + Paid plans (RM 29 early adopter, RM 39 standard)

### Business Model:
- **Target Market:** Malaysian SMEs (25-45 years old, food businesses)
- **Revenue Model:** Subscription-based SaaS
- **Payment:** BCL.my payment gateway
- **Trial Period:** 7-day free trial available

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

### Multi-Tenant Data Isolation

**Tenant Model:**
```
1 User = 1 Business Owner
1 Business Owner = 1 Tenant
1 Tenant = Isolated Data Set
```

**RLS Pattern:**
Every table follows this pattern:
- `business_owner_id UUID NOT NULL REFERENCES users(id)`
- RLS policies ensure users can only access their own data
- All queries automatically filtered by `business_owner_id`

---

## 💻 TECHNOLOGY STACK

### Frontend (Flutter)
- **Framework:** Flutter 3.0+
- **State Management:** Riverpod 2.4.9
- **UI Libraries:**
  - Material Design
  - Table Calendar (for bookings)
  - FL Chart (for analytics)
  - PDF (for invoice generation)
  - Printing (for PDF printing)

### Backend
- **Database:** PostgreSQL (via Supabase)
- **Auth:** Supabase Auth (JWT-based)
- **Storage:** Supabase Storage (for images, receipts, documents)
- **Realtime:** Supabase Realtime (WebSocket)
- **Edge Functions:** Supabase Edge Functions (Deno)
- **Microservices:** Encore.ts (TypeScript)

### External Services
- **Payment Gateway:** BCL.my
- **OCR:** Google Cloud Vision API (for receipt scanning)
- **Hosting:** Firebase Hosting (for web deployment)
- **File Sync:** Google Drive API (optional)

### Development Tools
- **Version Control:** Git
- **Package Manager:** pub (Flutter), npm (Node.js)
- **Build Tools:** Flutter Build, Firebase CLI

---

## 📁 PROJECT STRUCTURE

```
pocketbizz-flutter/
├── lib/
│   ├── core/                          # Core utilities & config
│   │   ├── config/                    # App configuration
│   │   │   ├── app_config.dart
│   │   │   └── env_config.dart
│   │   ├── services/                  # Core services
│   │   │   ├── image_upload_service.dart
│   │   │   ├── receipt_storage_service.dart
│   │   │   ├── document_storage_service.dart
│   │   │   └── planner_auto_service.dart
│   │   ├── supabase/                  # Supabase client
│   │   │   └── supabase_client.dart
│   │   ├── theme/                     # App theming
│   │   │   ├── app_colors.dart
│   │   │   └── app_theme.dart
│   │   ├── utils/                     # Utility functions
│   │   │   ├── admin_helper.dart
│   │   │   ├── date_time_helper.dart
│   │   │   ├── unit_conversion.dart
│   │   │   ├── pdf_generator.dart
│   │   │   └── whatsapp_share.dart
│   │   └── widgets/                   # Reusable widgets
│   │       ├── pocketbizz_fab.dart
│   │       └── stat_card.dart
│   │
│   ├── data/                          # Data layer
│   │   ├── models/                    # Data models (35+ models)
│   │   │   ├── product.dart
│   │   │   ├── stock_item.dart
│   │   │   ├── recipe.dart
│   │   │   ├── production_batch.dart
│   │   │   ├── claim.dart
│   │   │   ├── vendor.dart
│   │   │   ├── expense.dart
│   │   │   ├── subscription.dart
│   │   │   └── ... (28 more models)
│   │   │
│   │   └── repositories/              # Data access layer (26 repositories)
│   │       ├── products_repository_supabase.dart
│   │       ├── stock_repository_supabase.dart
│   │       ├── production_repository_supabase.dart
│   │       ├── sales_repository_supabase.dart
│   │       ├── claims_repository_supabase.dart
│   │       ├── subscription_repository_supabase.dart
│   │       └── ... (20 more repositories)
│   │
│   └── features/                      # Feature modules (20+ features)
│       ├── auth/                      # Authentication
│       │   └── presentation/
│       │       ├── login_page.dart
│       │       ├── forgot_password_page.dart
│       │       └── reset_password_page.dart
│       │
│       ├── dashboard/                 # Main dashboard
│       │   ├── domain/
│       │   │   └── dashboard_models.dart
│       │   └── presentation/
│       │       ├── home_page.dart
│       │       ├── dashboard_page_optimized.dart
│       │       └── widgets/           # Dashboard widgets
│       │
│       ├── products/                  # Product management
│       │   └── presentation/
│       │       ├── product_list_page.dart
│       │       ├── add_product_page.dart
│       │       ├── product_detail_page.dart
│       │       └── widgets/
│       │
│       ├── stock/                     # Stock/inventory management
│       │   └── presentation/
│       │       ├── stock_page.dart
│       │       ├── stock_detail_page.dart
│       │       ├── add_edit_stock_item_page.dart
│       │       └── ... (7 more pages)
│       │
│       ├── production/                # Production planning
│       │   └── presentation/
│       │       ├── production_planning_page.dart
│       │       ├── record_production_page.dart
│       │       └── widgets/
│       │
│       ├── recipes/                   # Recipe management
│       │   └── presentation/
│       │       └── recipe_builder_page.dart
│       │
│       ├── sales/                     # Sales/POS system
│       │   └── presentation/
│       │       ├── sales_page.dart
│       │       ├── create_sale_page_enhanced.dart
│       │       └── sale_details_dialog.dart
│       │
│       ├── bookings/                  # Booking/tempahan system
│       │   └── presentation/
│       │       ├── bookings_page_optimized.dart
│       │       └── create_booking_page_enhanced.dart
│       │
│       ├── vendors/                   # Vendor/consignment system
│       │   └── presentation/
│       │       ├── vendors_page.dart
│       │       ├── add_vendor_page.dart
│       │       ├── vendor_detail_page.dart
│       │       └── assign_products_page.dart
│       │
│       ├── deliveries/                # Delivery management
│       │   └── presentation/
│       │       ├── deliveries_page.dart
│       │       └── delivery_form_dialog.dart
│       │
│       ├── claims/                    # Consignment claims
│       │   └── presentation/
│       │       ├── claims_page.dart
│       │       ├── claim_detail_page.dart
│       │       ├── create_claim_simplified_page.dart
│       │       └── record_payment_page.dart
│       │
│       ├── expenses/                  # Expense tracking
│       │   └── presentation/
│       │       ├── expenses_page.dart
│       │       └── receipt_scan_page.dart (OCR)
│       │
│       ├── subscription/              # Subscription management
│       │   ├── data/
│       │   │   ├── models/
│       │   │   └── repositories/
│       │   ├── services/
│       │   │   └── subscription_service.dart
│       │   └── presentation/
│       │       ├── subscription_page.dart
│       │       ├── payment_success_page.dart
│       │       └── admin/             # Admin pages
│       │
│       ├── planner/                   # Task planner
│       │   └── presentation/
│       │       ├── enhanced_planner_page.dart
│       │       ├── views/             # List, Calendar, Kanban
│       │       └── widgets/
│       │
│       ├── reports/                   # Reports & analytics
│       │   ├── data/
│       │   └── presentation/
│       │       └── reports_page.dart
│       │
│       ├── feedback/                  # User feedback system
│       │   └── presentation/
│       │       ├── submit_feedback_page.dart
│       │       ├── my_feedback_page.dart
│       │       ├── community_links_page.dart
│       │       └── admin/
│       │
│       ├── announcements/              # Announcement system
│       │   └── presentation/
│       │       ├── notifications_page.dart
│       │       └── admin/
│       │
│       └── ... (more features)
│
├── db/
│   └── migrations/                    # Database migrations (80+ files)
│       ├── add_stock_management.sql
│       ├── add_vendor_system.sql
│       ├── add_recipes_and_production.sql
│       ├── create_subscriptions.sql
│       ├── create_feedback_system.sql
│       └── ... (75+ more migrations)
│
├── supabase/
│   └── functions/                     # Supabase Edge Functions
│       └── OCR-Cloud-Vision/          # OCR for receipt scanning
│           └── index.ts
│
├── services/                          # Encore.ts microservices
│   ├── products/
│   ├── inventory/
│   ├── sales/
│   ├── recipes/
│   ├── vendors/
│   └── ... (more services)
│
├── pubspec.yaml                       # Flutter dependencies
├── package.json                       # Node.js dependencies
└── README.md

```

---

## 🔍 CORE MODULES DEEP DIVE

### 1. AUTHENTICATION MODULE

**Location:** `lib/features/auth/`

**Components:**
- `login_page.dart` - Login/signup page
- `forgot_password_page.dart` - Password recovery
- `reset_password_page.dart` - Password reset

**Features:**
- Email/password authentication
- Password reset flow
- Auto-redirect based on auth state
- JWT token management (handled by Supabase)

**Auth Flow:**
```
User opens app
    ↓
AuthWrapper checks session
    ↓
If session exists → HomePage
If no session → LoginPage
```

---

### 2. DASHBOARD MODULE

**Location:** `lib/features/dashboard/`

**Main Pages:**
- `home_page.dart` - Main navigation hub with drawer menu
- `dashboard_page_optimized.dart` - Optimized dashboard with widgets

**Key Widgets:**
- `today_performance_card.dart` - Today's sales, bookings stats
- `morning_briefing_card.dart` - Daily briefing with urgent actions
- `urgent_actions_widget.dart` - Action items requiring attention
- `smart_suggestions_widget.dart` - AI-powered suggestions
- `low_stock_alerts_widget.dart` - Stock alerts
- `sales_by_channel_card.dart` - Sales breakdown
- `quick_action_grid.dart` - Quick access buttons

**Features:**
- Real-time statistics
- Low stock alerts
- Pending bookings
- Unread notifications badge
- Quick actions (scan receipt, create sale, etc.)
- Morning briefing with actionable items

**Data Sources:**
- Sales repository
- Bookings repository
- Stock repository
- Purchase orders repository
- Planner auto service
- Reports repository
- Claims repository
- Subscription service
- Announcements repository

---

### 3. PRODUCTS MODULE

**Location:** `lib/features/products/`

**Main Pages:**
- `product_list_page.dart` - List all products
- `add_product_page.dart` - Create new product
- `product_detail_page.dart` - View/edit product details
- `edit_product_page.dart` - Edit product
- `add_product_with_recipe_page.dart` - Create product with recipe

**Data Model:** `lib/data/models/product.dart`

**Key Fields:**
- Basic info: `sku`, `name`, `category`, `unit`
- Pricing: `sale_price`, `cost_price`
- Production costing: `units_per_batch`, `labour_cost`, `other_costs`, `packaging_cost`
- Calculated costs: `materials_cost`, `total_cost_per_batch`, `cost_per_unit`
- Images: `image_url`

**Features:**
- Product CRUD operations
- Category management
- Image upload
- Recipe integration
- Cost calculation
- Subscription limits enforcement

**Repository:** `ProductsRepositorySupabase`

**Key Methods:**
- `getAll()` - Get all products (paginated)
- `getById()` - Get single product
- `createProduct()` - Create product (checks subscription limits)
- `updateProduct()` - Update product
- `deleteProduct()` - Delete product
- `searchProducts()` - Search products

---

### 4. STOCK MANAGEMENT MODULE

**Location:** `lib/features/stock/`

**Main Pages:**
- `stock_page.dart` - Main stock list
- `stock_detail_page.dart` - Stock item details
- `add_edit_stock_item_page.dart` - Create/edit stock item
- `adjust_stock_page.dart` - Adjust stock quantities
- `batch_management_page.dart` - Manage stock batches (FIFO)
- `stock_history_page.dart` - Stock movement history

**Data Models:**
- `stock_item.dart` - Stock item model
- `stock_item_batch.dart` - Batch tracking (FIFO)
- `stock_movement.dart` - Stock movement history

**Key Features:**
- Stock item CRUD
- Batch tracking (FIFO system)
- Low stock alerts
- Stock adjustments
- Movement history
- Unit conversion
- Expiry date tracking

**Repository:** `StockRepository`

**Key Methods:**
- `getAllStockItems()` - Get all stock items
- `getLowStockItems()` - Get low stock items
- `createStockItem()` - Create stock item
- `updateStockItem()` - Update stock item
- `adjustStock()` - Adjust stock quantity
- `recordStockMovement()` - Record stock movement
- `getStockHistory()` - Get movement history

**FIFO System:**
- Uses `stock_item_batches` table
- Tracks batches with expiry dates
- Automatically uses oldest batches first
- Prevents negative stock

---

### 5. RECIPES MODULE

**Location:** `lib/features/recipes/`

**Main Pages:**
- `recipe_builder_page.dart` - Build/edit recipes

**Data Models:**
- `recipe.dart` - Recipe master
- `recipe_item.dart` - Recipe ingredients

**Key Features:**
- Recipe builder UI
- Ingredient selection from stock items
- Quantity and unit management
- Auto-cost calculation
- Version control (multiple recipe versions)
- Yield tracking

**Repository:** `RecipesRepositorySupabase`

**Key Methods:**
- `getRecipesByProduct()` - Get recipes for a product
- `createRecipe()` - Create recipe
- `updateRecipe()` - Update recipe
- `deleteRecipe()` - Delete recipe
- `calculateRecipeCost()` - Calculate total cost

**Cost Calculation:**
- Sums all recipe items (ingredients)
- Adds labour cost
- Adds other costs (gas, electric)
- Adds packaging cost
- Calculates cost per unit

---

### 6. PRODUCTION MODULE

**Location:** `lib/features/production/`

**Main Pages:**
- `production_planning_page.dart` - View production batches
- `record_production_page.dart` - Record new production batch

**Data Model:** `production_batch.dart`

**Key Features:**
- Production batch recording
- Recipe-based production
- Automatic stock deduction (FIFO)
- Cost tracking
- Batch tracking (remaining quantity)
- Limited CRUD (edit notes, delete within 24h)

**Repository:** `ProductionRepository`

**Key Methods:**
- `getAllBatches()` - Get all production batches
- `recordProductionBatch()` - Record production
- `updateBatchNotes()` - Update batch notes
- `deleteBatchWithStockReversal()` - Delete batch and reverse stock

**Production Flow:**
```
User selects product & recipe
    ↓
System calculates required ingredients
    ↓
Checks stock availability
    ↓
Records production batch
    ↓
Deducts stock (FIFO)
    ↓
Calculates total cost
    ↓
Creates finished product inventory
```

**Stock Reversal:**
- When batch is deleted, stock is automatically reversed
- Uses `record_stock_movement` RPC
- Maintains audit trail

---

### 7. SALES MODULE

**Location:** `lib/features/sales/`

**Main Pages:**
- `sales_page.dart` - Sales list
- `create_sale_page_enhanced.dart` - Create sale (POS)
- `sale_details_dialog.dart` - Sale details

**Data Models:**
- `sales_models.dart` - Sale and sale item models

**Key Features:**
- Point of Sale (POS) system
- Multiple sales channels (walk-in, booking, consignment)
- Product selection with search
- Quantity and price management
- Discount support
- Invoice generation (Normal, Thermal, A5)
- Payment tracking
- FIFO stock deduction

**Repository:** `SalesRepositorySupabase`

**Key Methods:**
- `getAllSales()` - Get all sales
- `createSale()` - Create sale
- `getSaleById()` - Get sale details
- `generateInvoice()` - Generate PDF invoice

**Sales Channels:**
- `walk_in` - Direct sales
- `booking` - From bookings
- `consignment` - From vendor sales

---

### 8. BOOKINGS MODULE

**Location:** `lib/features/bookings/`

**Main Pages:**
- `bookings_page_optimized.dart` - Bookings list
- `create_booking_page_enhanced.dart` - Create booking

**Key Features:**
- Booking management
- Calendar view
- Status tracking (pending, confirmed, completed, cancelled)
- Invoice generation
- WhatsApp integration (send booking confirmation)
- Payment tracking

**Repository:** `BookingsRepositorySupabase`

**Key Methods:**
- `getAllBookings()` - Get all bookings
- `createBooking()` - Create booking
- `updateBookingStatus()` - Update status
- `generateInvoice()` - Generate PDF invoice

---

### 9. VENDORS MODULE

**Location:** `lib/features/vendors/`

**Main Pages:**
- `vendors_page.dart` - Vendors list
- `add_vendor_page.dart` - Add vendor
- `vendor_detail_page.dart` - Vendor details
- `assign_products_page.dart` - Assign products to vendor

**Data Model:** `vendor.dart`

**Key Features:**
- Vendor CRUD
- Commission structure (percentage or price range)
- Product assignment
- Bank details management
- Active/inactive status

**Repository:** `VendorsRepositorySupabase`

**Commission Types:**
- `percentage` - Fixed percentage commission
- `price_range` - Commission based on price ranges

---

### 10. DELIVERIES MODULE

**Location:** `lib/features/deliveries/`

**Main Pages:**
- `deliveries_page.dart` - Deliveries list
- `delivery_form_dialog.dart` - Create/edit delivery

**Data Model:** `delivery.dart`

**Key Features:**
- Delivery tracking
- Status management (pending, delivered, rejected)
- Invoice generation
- Payment status tracking
- Address management

**Repository:** `DeliveriesRepositorySupabase`

**Delivery Flow:**
```
Create delivery for vendor
    ↓
Assign products & quantities
    ↓
Generate delivery invoice
    ↓
Update status (delivered/rejected)
    ↓
Track payment status
```

---

### 11. CLAIMS MODULE

**Location:** `lib/features/claims/`

**Main Pages:**
- `claims_page.dart` - Claims list
- `claim_detail_page.dart` - Claim details
- `create_claim_simplified_page.dart` - Create claim
- `record_payment_page.dart` - Record payment

**Data Models:**
- `claim.dart` - Claim summary
- `consignment_claim.dart` - Detailed claim
- `consignment_payment.dart` - Payment record

**Key Features:**
- Consignment claim creation
- Commission calculation
- Payment recording
- Status tracking (pending, partial, settled)
- Claim history

**Repository:** `ConsignmentClaimsRepositorySupabase`

**Claim Flow:**
```
Vendor sells products
    ↓
Owner creates claim based on sales
    ↓
System calculates commission
    ↓
Owner records payment
    ↓
Claim status updated (partial/settled)
```

---

### 12. EXPENSES MODULE

**Location:** `lib/features/expenses/`

**Main Pages:**
- `expenses_page.dart` - Expenses list
- `receipt_scan_page.dart` - OCR receipt scanning

**Data Model:** `expense.dart`

**Key Features:**
- Manual expense entry
- OCR receipt scanning (Google Cloud Vision)
- Structured receipt data storage
- Expense categories
- Vendor linking
- Receipt image storage

**Repository:** `ExpensesRepositorySupabase`

**OCR Features:**
- Merchant name extraction
- Date extraction
- Item list extraction
- Total amount extraction (prioritizes TOTAL/NETT over CASH)
- Structured data storage (JSONB)

**Receipt Data Structure:**
```json
{
  "merchant": "Store Name",
  "date": "2025-01-15",
  "items": [
    {"name": "Item 1", "price": 10.00, "quantity": 2}
  ],
  "subtotal": 20.00,
  "tax": 1.20,
  "total": 21.20
}
```

---

### 13. SUBSCRIPTION MODULE

**Location:** `lib/features/subscription/`

**Main Pages:**
- `subscription_page.dart` - Subscription plans & status
- `payment_success_page.dart` - Payment callback handler
- `admin/` - Admin pages for subscription management

**Data Models:**
- `subscription.dart` - Subscription model
- `subscription_plan.dart` - Plan model
- `subscription_payment.dart` - Payment model

**Key Features:**
- Subscription plans (1, 3, 6, 12 months)
- Early adopter pricing (RM 29 vs RM 39)
- 7-day free trial
- Grace period (7 days after expiry)
- Payment integration (BCL.my)
- Auto-renewal
- Subscription pause
- Usage tracking (products, sales, etc.)

**Repository:** `SubscriptionRepositorySupabase`

**Service:** `SubscriptionService`

**Payment Flow:**
```
User selects plan
    ↓
Create pending payment session
    ↓
Redirect to BCL.my payment form
    ↓
User completes payment
    ↓
BCL.my sends webhook
    ↓
Update subscription status
    ↓
Activate subscription
```

**Subscription Statuses:**
- `trial` - Free trial period
- `active` - Active paid subscription
- `expired` - Subscription expired
- `grace` - Grace period (7 days)
- `cancelled` - Cancelled subscription

---

### 14. PLANNER MODULE

**Location:** `lib/features/planner/`

**Main Pages:**
- `enhanced_planner_page.dart` - Main planner (List/Calendar/Kanban views)
- `pages/categories_management_page.dart` - Task categories
- `pages/projects_management_page.dart` - Projects
- `pages/templates_management_page.dart` - Task templates

**Data Models:**
- `planner_task.dart` - Task model
- `planner_category.dart` - Category model
- `planner_project.dart` - Project model
- `planner_task_template.dart` - Template model

**Key Features:**
- Task management (CRUD)
- Multiple views (List, Calendar, Kanban)
- Categories and projects
- Task templates
- Auto-task generation (from bookings, low stock, etc.)
- Subtasks
- Comments
- Due dates and reminders

**Repository:** `PlannerTasksRepositorySupabase`

**Auto-Task Service:** `PlannerAutoService`

**Auto-Generated Tasks:**
- Booking reminders
- Low stock alerts
- Production planning
- Payment reminders

---

### 15. REPORTS MODULE

**Location:** `lib/features/reports/`

**Main Pages:**
- `reports_page.dart` - Reports dashboard

**Key Features:**
- Sales reports
- Product performance
- Vendor analysis
- Profit & loss
- Sales by channel
- Date range filtering
- PDF export

**Repository:** `ReportsRepositorySupabase`

**Report Types:**
- Overview (summary)
- Products (product performance)
- Vendors (vendor analysis)
- Trends (sales trends)

---

### 16. FEEDBACK MODULE

**Location:** `lib/features/feedback/`

**Main Pages:**
- `submit_feedback_page.dart` - Submit feedback
- `my_feedback_page.dart` - User's feedback
- `community_links_page.dart` - Community links
- `admin/admin_feedback_page.dart` - Admin feedback management
- `admin/admin_community_links_page.dart` - Admin community links

**Data Models:**
- `feedback_request.dart` - Feedback model
- `community_link.dart` - Community link model

**Key Features:**
- User feedback submission (problem, suggestion, feature request)
- Feedback status tracking (pending, in_progress, completed, rejected)
- Admin notes and implementation notes
- In-app notifications on status updates
- Community links (Facebook, Telegram, etc.)

**Repository:** `FeedbackRepositorySupabase`

---

### 17. ANNOUNCEMENTS MODULE

**Location:** `lib/features/announcements/`

**Main Pages:**
- `notifications_page.dart` - User notifications
- `notification_history_page.dart` - Notification history
- `admin/admin_announcements_page.dart` - Admin announcements

**Data Models:**
- `announcement.dart` - Announcement model
- `announcement_media.dart` - Media attachments

**Key Features:**
- Announcement creation (admin)
- Target audience filtering (all, trial, active, expired, grace)
- Media attachments (images, videos)
- Show until date
- Read/unread tracking
- Notification badge on dashboard

**Repository:** `AnnouncementsRepositorySupabase`

---

### 18. OTHER MODULES

**Categories:** Product category management  
**Suppliers:** Supplier management  
**Shopping List:** Shopping cart for purchase orders  
**Purchase Orders:** PO management  
**Finished Products:** Finished goods inventory  
**Documents:** Document storage  
**Drive Sync:** Google Drive integration  
**Settings:** App settings and business profile

---

## 📊 DATA MODELS & BUSINESS LOGIC

### Core Models

#### Product Model
```dart
class Product {
  String id;
  String businessOwnerId;
  String sku;
  String name;
  String? categoryId;
  String unit;
  double salePrice;
  double costPrice;
  
  // Production costing
  int unitsPerBatch;
  double labourCost;
  double otherCosts;
  double packagingCost;
  
  // Calculated costs
  double? materialsCost;
  double? totalCostPerBatch;
  double? costPerUnit;
}
```

#### Stock Item Model
```dart
class StockItem {
  String id;
  String businessOwnerId;
  String name;
  String unit;
  double packageSize;
  double purchasePrice;
  double currentQuantity;
  double lowStockThreshold;
  
  // Calculated
  double get costPerUnit => purchasePrice / packageSize;
  bool get isLowStock => currentQuantity <= lowStockThreshold;
}
```

#### Production Batch Model
```dart
class ProductionBatch {
  String id;
  String productId;
  String productName;
  int quantity;
  double remainingQty;
  DateTime batchDate;
  DateTime? expiryDate;
  double totalCost;
  double costPerUnit;
  
  // Helpers
  bool get isFullyUsed => remainingQty <= 0;
  bool canBeEdited({required bool isAdmin}) {
    // Can edit if admin or within 24 hours
  }
}
```

#### Subscription Model
```dart
class Subscription {
  String id;
  String userId;
  String planId;
  SubscriptionStatus status;
  DateTime expiresAt;
  DateTime? graceUntil;
  bool isEarlyAdopter;
  double pricePerMonth;
  double totalAmount;
  bool autoRenew;
}
```

---

## 🔄 REPOSITORY PATTERN IMPLEMENTATION

All repositories follow a consistent pattern:

1. **Supabase Client Injection**
   ```dart
   class ProductsRepositorySupabase {
     final SupabaseClient _supabase;
     ProductsRepositorySupabase(this._supabase);
   }
   ```

2. **CRUD Operations**
   - `getAll()` - List with pagination
   - `getById()` - Single item
   - `create()` - Create new
   - `update()` - Update existing
   - `delete()` - Delete

3. **Business Logic Methods**
   - Custom queries
   - Aggregations
   - Status updates

4. **Error Handling**
   - Try-catch blocks
   - User-friendly error messages
   - Logging

5. **Subscription Limits**
   - Check limits before operations
   - Throw exceptions if limit exceeded

---

## 🎨 UI/UX ARCHITECTURE

### Design Principles
- **Material Design** - Consistent with Material Design guidelines
- **Malaysian Context** - Bahasa Malaysia labels, RM currency
- **Mobile-First** - Optimized for mobile, responsive for web
- **Accessibility** - Clear labels, proper contrast

### Navigation Structure
- **Bottom Navigation** - Dashboard, Bookings, Products, Sales
- **Drawer Menu** - Full feature access
- **Tab Navigation** - For multi-view features (Planner, Reports)

### Common UI Patterns
- **Cards** - For displaying data
- **Dialogs** - For forms and confirmations
- **Bottom Sheets** - For detailed views
- **Floating Action Buttons** - For quick actions
- **Refresh Indicators** - For pull-to-refresh

### Theme
- **Primary Color:** Custom brand color
- **Dark Mode:** Supported
- **Typography:** System fonts with proper sizing

---

## 🗄️ DATABASE SCHEMA & MIGRATIONS

### Core Tables

#### Users & Auth
- `users` - User accounts (managed by Supabase Auth)
- `admin_users` - Admin access control

#### Business
- `business_profiles` - Business information
- `categories` - Product categories

#### Products & Inventory
- `products` - Product catalog
- `stock_items` - Raw materials/ingredients
- `stock_item_batches` - FIFO batch tracking
- `stock_movements` - Stock movement history

#### Production
- `recipes` - Recipe master
- `recipe_items` - Recipe ingredients
- `production_batches` - Production records
- `production_ingredient_usage` - Ingredient usage tracking
- `finished_products` - Finished goods inventory

#### Sales & Orders
- `sales` - Sales transactions
- `sale_items` - Sale line items
- `bookings` - Booking orders
- `booking_items` - Booking line items

#### Consignment
- `vendors` - Vendor/consignee list
- `vendor_products` - Product assignments
- `vendor_commission_price_ranges` - Commission ranges
- `deliveries` - Delivery records
- `delivery_items` - Delivery line items
- `consignment_claims` - Claims
- `consignment_payments` - Payments

#### Financial
- `expenses` - Expense records
- `subscriptions` - User subscriptions
- `subscription_payments` - Payment records
- `subscription_plans` - Plan definitions

#### Other
- `planner_tasks` - Task planner
- `planner_categories` - Task categories
- `planner_projects` - Projects
- `purchase_orders` - Purchase orders
- `shopping_cart_items` - Shopping cart
- `feedback_requests` - User feedback
- `community_links` - Community links
- `announcements` - Announcements
- `announcement_views` - Read tracking

### Migration Files
Located in `db/migrations/` (80+ migration files)

Key migrations:
- `add_stock_management.sql`
- `add_vendor_system.sql`
- `add_recipes_and_production.sql`
- `create_subscriptions.sql`
- `create_feedback_system.sql`
- `create_announcements_system.sql`

---

## 🔐 SECURITY & MULTI-TENANCY

### Row Level Security (RLS)

Every table has RLS policies:

```sql
-- Example: Products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_select_own" ON products
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY "products_insert_own" ON products
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "products_update_own" ON products
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY "products_delete_own" ON products
    FOR DELETE USING (business_owner_id = auth.uid());
```

### Admin Access Control

**Location:** `lib/core/utils/admin_helper.dart`

**Methods:**
- `isAdmin()` - Check if user is admin (async)
- `isAdminSync()` - Check cached admin status (sync)
- `initializeCache()` - Pre-load admin status

**Implementation:**
- Database-based (`admin_users` table)
- RPC function: `is_admin(user_uuid)`
- Fallback to email whitelist (for migration period)
- 5-minute cache TTL

---

## 💳 SUBSCRIPTION & PAYMENT SYSTEM

### Subscription Plans

**Plans:**
- 1 month: RM 29 (early) / RM 39 (standard)
- 3 months: RM 87 (early) / RM 117 (standard)
- 6 months: RM 174 (early) / RM 234 (standard)
- 12 months: RM 348 (early) / RM 468 (standard)

**Features:**
- 7-day free trial
- Grace period (7 days after expiry)
- Auto-renewal
- Subscription pause
- Early adopter pricing

### Payment Gateway: BCL.my

**Integration:**
- External redirect to BCL.my payment form
- `order_id` passed as query parameter
- Webhook callback to `/webhooks/bcl`
- Signature verification (HMAC SHA256)

**Webhook Handler:**
- Location: `services/payments/webhooks.ts` (Encore.ts)
- Verifies signature
- Updates payment status
- Activates subscription

**Payment Flow:**
1. User selects plan
2. Create pending payment session
3. Redirect to BCL.my
4. User completes payment
5. BCL.my sends webhook
6. Update subscription status
7. User returns to app

### Usage Tracking

**Plan Limits:**
- Products: Max count per plan
- Sales: Max transactions
- Stock items: Max count
- Other features: Based on plan tier

**Enforcement:**
- Checked before operations
- Throws exceptions if limit exceeded
- User-friendly error messages

---

## 🔌 INTEGRATION POINTS

### 1. Google Cloud Vision API
- **Purpose:** OCR for receipt scanning
- **Location:** `supabase/functions/OCR-Cloud-Vision/`
- **Features:**
  - Text extraction from receipt images
  - Merchant name extraction
  - Date extraction
  - Item list extraction
  - Total amount extraction

### 2. BCL.my Payment Gateway
- **Purpose:** Subscription payments
- **Integration:** External redirect + webhook
- **Security:** HMAC SHA256 signature verification

### 3. WhatsApp Business API
- **Purpose:** Send booking confirmations
- **Location:** `lib/core/utils/whatsapp_share.dart`
- **Features:** Share booking details via WhatsApp

### 4. Google Drive API
- **Purpose:** Document sync (optional)
- **Location:** `lib/features/drive_sync/`
- **Features:** Sync documents to Google Drive

### 5. Firebase Hosting
- **Purpose:** Web app deployment
- **Configuration:** `firebase.json`

---

## 📋 FEATURE INVENTORY

### Core Operations ✅
1. **Dashboard** - Real-time stats, alerts, quick actions
2. **Products** - Product catalog management
3. **Sales (POS)** - Point of sale system
4. **Bookings** - Order/booking management
5. **Stock Management** - Inventory tracking (FIFO)
6. **Production** - Production planning & tracking
7. **Recipes** - Recipe builder with cost calculation
8. **Expenses** - Expense tracking with OCR

### Advanced Operations ✅
9. **Vendors** - Consignment vendor management
10. **Deliveries** - Delivery tracking
11. **Claims** - Consignment claim management
12. **Payments** - Payment recording
13. **Purchase Orders** - PO management
14. **Shopping List** - Shopping cart
15. **Finished Products** - Finished goods inventory

### Supporting Features ✅
16. **Planner** - Task management (List/Calendar/Kanban)
17. **Reports** - Analytics & reports
18. **Categories** - Category management
19. **Suppliers** - Supplier management
20. **Documents** - Document storage
21. **Drive Sync** - Google Drive integration
22. **Settings** - App settings

### System Features ✅
23. **Authentication** - Login/signup/password reset
24. **Subscription** - Subscription management
25. **Feedback** - User feedback system
26. **Announcements** - Announcement system
27. **Notifications** - In-app notifications
28. **Admin Panel** - Admin management tools

---

## 🔄 BUSINESS FLOWS

### 1. Production Flow
```
User creates product
    ↓
User creates recipe (with ingredients)
    ↓
System calculates recipe cost
    ↓
User records production batch
    ↓
System deducts stock (FIFO)
    ↓
System creates finished product inventory
    ↓
User can sell finished products
```

### 2. Sales Flow
```
User creates sale
    ↓
Select products & quantities
    ↓
System checks stock (FIFO)
    ↓
Deduct stock
    ↓
Calculate total
    ↓
Generate invoice
    ↓
Record payment
```

### 3. Consignment Flow
```
User adds vendor
    ↓
Assign products to vendor
    ↓
Create delivery
    ↓
Vendor sells products
    ↓
User creates claim
    ↓
System calculates commission
    ↓
User records payment
```

### 4. Subscription Flow
```
User signs up
    ↓
7-day free trial starts
    ↓
User selects plan
    ↓
Redirect to BCL.my payment
    ↓
Payment completed
    ↓
Subscription activated
    ↓
Grace period if expired
```

---

## ⚡ PERFORMANCE OPTIMIZATIONS

### 1. Pagination
- All list queries use pagination
- Default limit: 100 items
- Offset-based pagination

### 2. Caching
- Admin status cache (5 minutes)
- Subscription status cache
- Business profile cache

### 3. Database Indexes
- Composite indexes on common queries
- Partial indexes for status queries
- GIN indexes for JSONB columns

### 4. Lazy Loading
- Load data on demand
- Use `Future.wait()` for parallel loading
- Debounce search queries

### 5. Image Optimization
- Compress images before upload
- Use appropriate image sizes
- Lazy load images in lists

---

## 🚀 DEPLOYMENT ARCHITECTURE

### Flutter Web
- **Build:** `flutter build web`
- **Hosting:** Firebase Hosting
- **Domain:** Custom domain support

### Mobile Apps
- **iOS:** App Store (planned)
- **Android:** Google Play (planned)

### Backend
- **Database:** Supabase PostgreSQL
- **Edge Functions:** Supabase Edge Functions (Deno)
- **Microservices:** Encore.ts (deployed to Encore Cloud)

### CI/CD
- Manual deployment process
- Git-based version control
- Migration management via SQL files

---

## 📝 NOTES & OBSERVATIONS

### Strengths
1. **Comprehensive Feature Set** - Covers all aspects of SME business management
2. **Multi-Tenant Architecture** - Proper data isolation with RLS
3. **FIFO Stock System** - Proper inventory tracking
4. **Production Costing** - Detailed cost calculation
5. **Subscription System** - Complete payment integration
6. **Clean Architecture** - Well-organized code structure

### Areas for Improvement
1. **Testing** - Limited test coverage
2. **Documentation** - Some modules lack inline documentation
3. **Error Handling** - Could be more consistent
4. **Performance** - Some queries could be optimized
5. **Accessibility** - Could improve accessibility features

### Future Enhancements
1. **Mobile Apps** - iOS and Android native apps
2. **Offline Support** - Offline-first architecture
3. **Multi-Language** - Support for more languages
4. **Advanced Analytics** - More detailed reports
5. **API Documentation** - OpenAPI/Swagger docs

---

## 🎓 CONCLUSION

PocketBizz is a **comprehensive, production-ready SaaS platform** for Malaysian SMEs. The system demonstrates:

- **Solid Architecture** - Clean separation of concerns
- **Scalability** - Designed for 10,000+ users
- **Security** - Proper multi-tenancy with RLS
- **Feature Completeness** - 28+ major features
- **Business Logic** - Complex workflows properly implemented

The codebase is well-organized, follows Flutter best practices, and uses modern technologies. The system is ready for production use and can scale as the user base grows.

---

**Document Version:** 1.0  
**Last Updated:** January 2025  
**Maintained By:** Development Team

