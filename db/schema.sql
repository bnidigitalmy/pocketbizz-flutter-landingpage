CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PRODUCTS -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    sale_price NUMERIC(12,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_products_owner ON products (business_owner_id);

-- VENDORS --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    type TEXT NOT NULL CHECK (type IN ('supplier','reseller')),
    address JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_vendors_owner ON vendors (business_owner_id);

-- CUSTOMERS ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    loyalty_tier TEXT,
    lifetime_value NUMERIC(14,2) DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customers_owner ON customers (business_owner_id);

-- INGREDIENTS ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    name TEXT NOT NULL,
    unit TEXT NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    supplier_id UUID REFERENCES vendors (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ingredients_owner ON ingredients (business_owner_id);

-- RECIPES --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    product_id UUID REFERENCES products (id),
    name TEXT NOT NULL,
    yield_quantity NUMERIC(12,3),
    yield_unit TEXT,
    total_cost NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recipe_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients (id),
    quantity NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    position INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items (recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_ingredient ON recipe_items (ingredient_id);

-- INVENTORY BATCHES ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    product_id UUID NOT NULL REFERENCES products (id),
    batch_code TEXT,
    quantity NUMERIC(12,3) NOT NULL,
    available_quantity NUMERIC(12,3) NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    manufacture_date DATE,
    expiry_date DATE,
    warehouse TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory_batches (product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_owner ON inventory_batches (business_owner_id);

-- INVENTORY MOVEMENTS -------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    batch_id UUID REFERENCES inventory_batches (id),
    product_id UUID NOT NULL REFERENCES ingredients (id),
    type TEXT NOT NULL CHECK (type IN ('in','out')),
    qty NUMERIC(12,3) NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_owner ON inventory_movements (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product ON inventory_movements (product_id);

-- FINISHED PRODUCT BATCHES (PRODUCTION OUTPUT) --------------------------------
CREATE TABLE IF NOT EXISTS finished_product_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    product_id UUID NOT NULL REFERENCES products (id),
    recipe_id UUID REFERENCES recipes (id),
    quantity NUMERIC(12,3) NOT NULL,
    available_quantity NUMERIC(12,3) NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL,
    total_cost NUMERIC(14,2) NOT NULL,
    production_date DATE NOT NULL,
    expiry_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_finished_batches_owner ON finished_product_batches (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_finished_batches_product ON finished_product_batches (product_id);
ALTER TABLE finished_product_batches
    ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE TABLE IF NOT EXISTS production_ingredient_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    production_batch_id UUID NOT NULL REFERENCES finished_product_batches (id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients (id),
    quantity NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    cost NUMERIC(14,4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_production_usage_owner ON production_ingredient_usage (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_production_usage_batch ON production_ingredient_usage (production_batch_id);
ALTER TABLE production_ingredient_usage ENABLE ROW LEVEL SECURITY;

-- SALES ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    customer_id UUID REFERENCES customers (id),
    channel TEXT NOT NULL,
    status TEXT NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    tax NUMERIC(12,2) DEFAULT 0,
    discount NUMERIC(12,2) DEFAULT 0,
    total NUMERIC(12,2) NOT NULL,
    cogs NUMERIC(12,2) DEFAULT 0,
    profit NUMERIC(12,2) DEFAULT 0,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sales_owner ON sales (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales (customer_id);

CREATE TABLE IF NOT EXISTS sales_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    cost_of_goods NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sales_items_sale ON sales_items (sale_id);
CREATE INDEX IF NOT EXISTS idx_sales_items_product ON sales_items (product_id);
CREATE INDEX IF NOT EXISTS idx_sales_items_owner ON sales_items (business_owner_id);

-- OCR RECEIPTS ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ocr_receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    file_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    detected_text TEXT,
    amount NUMERIC(12,2),
    currency TEXT,
    expense_date DATE,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ocr_owner ON ocr_receipts (business_owner_id);

-- EXPENSES -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID REFERENCES vendors (id),
    category TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'MYR',
    expense_date DATE NOT NULL,
    notes TEXT,
    ocr_receipt_id UUID REFERENCES ocr_receipts (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_expenses_owner ON expenses (business_owner_id);

-- MYSHOP ORDERS --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS myshop_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    customer_id UUID REFERENCES customers (id),
    reference TEXT NOT NULL,
    status TEXT NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    channel TEXT NOT NULL DEFAULT 'MYSHOP',
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_myshop_owner ON myshop_orders (business_owner_id);

-- CONSIGNMENT MODULE -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS consignment_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    reference TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','submitted','claimed','closed')),
    note TEXT,
    total_items NUMERIC(12,3) NOT NULL DEFAULT 0,
    total_value NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consignment_sessions_owner ON consignment_sessions (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_consignment_sessions_vendor ON consignment_sessions (vendor_id);

CREATE TABLE IF NOT EXISTS consignment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    session_id UUID NOT NULL REFERENCES consignment_sessions (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    qty_sent NUMERIC(12,3) NOT NULL,
    qty_sold NUMERIC(12,3) NOT NULL DEFAULT 0,
    qty_returned NUMERIC(12,3) NOT NULL DEFAULT 0,
    list_price NUMERIC(12,2) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    commission_type TEXT NOT NULL CHECK (commission_type IN ('percent','fixed')),
    commission_rate NUMERIC(7,3),
    commission_amount NUMERIC(12,4) NOT NULL,
    total_value NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consignment_items_session ON consignment_items (session_id);
CREATE INDEX IF NOT EXISTS idx_consignment_items_product ON consignment_items (product_id);
CREATE INDEX IF NOT EXISTS idx_consignment_items_owner ON consignment_items (business_owner_id);

CREATE TABLE IF NOT EXISTS consignment_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    session_id UUID NOT NULL REFERENCES consignment_sessions (id),
    total_sold_value NUMERIC(14,2) NOT NULL,
    total_commission NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_payout NUMERIC(14,2) NOT NULL,
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consignment_claims_owner ON consignment_claims (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_consignment_claims_session ON consignment_claims (session_id);

CREATE TABLE IF NOT EXISTS consignment_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    session_id UUID NOT NULL REFERENCES consignment_sessions (id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    details JSONB,
    performed_by UUID REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consignment_history_owner ON consignment_history (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_consignment_history_session ON consignment_history (session_id);

ALTER TABLE consignment_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE consignment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE consignment_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE consignment_history ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'consignment_sessions',
            'consignment_items',
            'consignment_claims',
            'consignment_history',
            'production_ingredient_usage'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_update_own ON %I
            FOR UPDATE
            USING (business_owner_id = auth.uid())
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;

-- SHOPPING LIST ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shopping_list (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    ingredient_id UUID NOT NULL REFERENCES ingredients (id),
    ingredient_name TEXT NOT NULL,
    shortage_qty NUMERIC(12,4) NOT NULL,
    unit TEXT NOT NULL,
    notes TEXT,
    linked_production_batch UUID REFERENCES finished_product_batches (id),
    is_purchased BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_shopping_list_owner ON shopping_list (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_shopping_list_ingredient ON shopping_list (ingredient_id);

ALTER TABLE shopping_list ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'shopping_list'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_update_own ON %I
            FOR UPDATE
            USING (business_owner_id = auth.uid())
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;

-- SUPPLIERS -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    commission NUMERIC(7,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_suppliers_owner ON suppliers (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_email ON suppliers (email) WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS supplier_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    supplier_id UUID NOT NULL REFERENCES suppliers (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    commission NUMERIC(7,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_supplier_products_supplier ON supplier_products (supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_products_product ON supplier_products (product_id);

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_products ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'suppliers',
            'supplier_products'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_update_own ON %I
            FOR UPDATE
            USING (business_owner_id = auth.uid())
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;

-- PURCHASE ORDERS -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    supplier_id UUID REFERENCES suppliers (id),
    reference TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    currency TEXT DEFAULT 'MYR',
    total_value NUMERIC(14,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_po_owner ON purchase_orders (business_owner_id);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_id UUID NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES ingredients (id),
    product_id UUID REFERENCES products (id),
    description TEXT,
    qty_ordered NUMERIC(12,4) NOT NULL,
    qty_received NUMERIC(12,4) DEFAULT 0,
    unit TEXT,
    unit_price NUMERIC(12,4) DEFAULT 0,
    total_price NUMERIC(14,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    business_owner_id UUID REFERENCES users (id)
);
CREATE INDEX IF NOT EXISTS idx_poi_po ON purchase_order_items (po_id);

-- GOODS RECEIVED NOTES --------------------------------------------------------
CREATE TABLE IF NOT EXISTS grn (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    po_id UUID REFERENCES purchase_orders (id),
    reference TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    total_received_value NUMERIC(14,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_grn_owner ON grn (business_owner_id);

CREATE TABLE IF NOT EXISTS grn_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_id UUID NOT NULL REFERENCES grn (id) ON DELETE CASCADE,
    po_item_id UUID REFERENCES purchase_order_items (id),
    ingredient_id UUID REFERENCES ingredients (id),
    product_id UUID REFERENCES products (id),
    qty_received NUMERIC(12,4) NOT NULL,
    unit TEXT,
    unit_price NUMERIC(12,4) DEFAULT 0,
    total_price NUMERIC(14,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_grni_grn ON grn_items (grn_id);

-- PO / GRN LOGS ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS po_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    ref_type TEXT NOT NULL,
    ref_id UUID NOT NULL,
    action TEXT NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_po_logs_owner ON po_logs (business_owner_id);

ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE po_logs ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'purchase_orders',
            'purchase_order_items',
            'grn',
            'grn_items',
            'po_logs'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_update_own ON %I
            FOR UPDATE
            USING (business_owner_id = auth.uid())
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;

-- BOOKINGS --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    customer_id UUID REFERENCES customers (id),
    booking_number TEXT UNIQUE NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    customer_email TEXT,
    event_type TEXT NOT NULL,
    event_date DATE,
    delivery_date DATE NOT NULL,
    delivery_time TEXT,
    delivery_location TEXT,
    notes TEXT,
    discount_type TEXT DEFAULT 'fixed' CHECK (discount_type IN ('percentage','fixed')),
    discount_value NUMERIC(12,2) DEFAULT 0,
    discount_amount NUMERIC(12,2) DEFAULT 0,
    total_amount NUMERIC(12,2) NOT NULL,
    deposit_amount NUMERIC(12,2),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending','confirmed','completed','cancelled')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bookings_owner ON bookings (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_number ON bookings (booking_number);

CREATE TABLE IF NOT EXISTS booking_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    booking_id UUID NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products (id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_booking_items_booking ON booking_items (booking_id);

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_items ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'bookings',
            'booking_items'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_update_own ON %I
            FOR UPDATE
            USING (business_owner_id = auth.uid())
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;

-- GOOGLE DRIVE SYNC LOGS ------------------------------------------------------
CREATE TABLE IF NOT EXISTS google_drive_sync_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id),
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL,
    drive_file_id TEXT NOT NULL,
    drive_web_view_link TEXT NOT NULL,
    vendor_name TEXT,
    metadata JSONB,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_drive_logs_owner ON google_drive_sync_logs (business_owner_id);
CREATE INDEX IF NOT EXISTS idx_drive_logs_synced ON google_drive_sync_logs (synced_at DESC);

ALTER TABLE google_drive_sync_logs ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'google_drive_sync_logs'
        ])
    LOOP
        EXECUTE format($q$
            CREATE POLICY %I_select_own ON %I
            FOR SELECT
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_insert_own ON %I
            FOR INSERT
            WITH CHECK (business_owner_id = auth.uid());
        $q$, tbl, tbl);

        EXECUTE format($q$
            CREATE POLICY %I_delete_own ON %I
            FOR DELETE
            USING (business_owner_id = auth.uid());
        $q$, tbl, tbl);
    END LOOP;
END $$;
