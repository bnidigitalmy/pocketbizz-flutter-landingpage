-- Enable Supabase Realtime for Dashboard Tables
-- This migration enables real-time subscriptions for all tables used in the dashboard
-- Run this in Supabase SQL Editor

-- Enable Realtime for Sales (affects Masuk/Untung)
ALTER PUBLICATION supabase_realtime ADD TABLE sales;

-- Enable Realtime for Sale Items (affects Kos/Production Cost)
ALTER PUBLICATION supabase_realtime ADD TABLE sale_items;

-- Enable Realtime for Bookings (affects Masuk when status = completed)
ALTER PUBLICATION supabase_realtime ADD TABLE bookings;

-- Enable Realtime for Booking Items (affects Kos)
ALTER PUBLICATION supabase_realtime ADD TABLE booking_items;

-- Enable Realtime for Consignment Claims (affects Masuk when status = settled)
ALTER PUBLICATION supabase_realtime ADD TABLE consignment_claims;

-- Enable Realtime for Consignment Claim Items (affects Kos)
ALTER PUBLICATION supabase_realtime ADD TABLE consignment_claim_items;

-- Enable Realtime for Expenses (affects Belanja)
ALTER PUBLICATION supabase_realtime ADD TABLE expenses;

-- Enable Realtime for Products (affects Kos if cost_per_unit changes)
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- Also enable for other tables that might be used in dashboard widgets
-- Stock Items (for Low Stock Alerts - already enabled in shopping_list_page)
ALTER PUBLICATION supabase_realtime ADD TABLE stock_items;

-- Purchase Orders (for Pending Tasks)
ALTER PUBLICATION supabase_realtime ADD TABLE purchase_orders;

-- Production Batches (for Finished Products Alerts)
ALTER PUBLICATION supabase_realtime ADD TABLE production_batches;

-- Verify: Check which tables are enabled for realtime
-- SELECT schemaname, tablename 
-- FROM pg_publication_tables 
-- WHERE pubname = 'supabase_realtime';

