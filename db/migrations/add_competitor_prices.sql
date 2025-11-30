-- Migration: Add Competitor Prices Table
-- Purpose: Store competitor pricing data for market analysis and pricing decisions

-- Create competitor_prices table
CREATE TABLE IF NOT EXISTS competitor_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  competitor_name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL CHECK (price > 0),
  source TEXT CHECK (source IN ('physical_store', 'online_platform', 'marketplace', 'other')),
  last_updated DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure unique competitor name per product
  CONSTRAINT unique_competitor_per_product UNIQUE (product_id, competitor_name)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_competitor_prices_product ON competitor_prices(product_id);
CREATE INDEX IF NOT EXISTS idx_competitor_prices_owner ON competitor_prices(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_competitor_prices_updated ON competitor_prices(last_updated DESC);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_competitor_prices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_competitor_prices_updated_at
  BEFORE UPDATE ON competitor_prices
  FOR EACH ROW
  EXECUTE FUNCTION update_competitor_prices_updated_at();

-- Enable RLS (Row Level Security)
ALTER TABLE competitor_prices ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only access their own competitor prices
CREATE POLICY "Users can view their own competitor prices"
  ON competitor_prices
  FOR SELECT
  USING (business_owner_id = auth.uid());

CREATE POLICY "Users can insert their own competitor prices"
  ON competitor_prices
  FOR INSERT
  WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can update their own competitor prices"
  ON competitor_prices
  FOR UPDATE
  USING (business_owner_id = auth.uid())
  WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "Users can delete their own competitor prices"
  ON competitor_prices
  FOR DELETE
  USING (business_owner_id = auth.uid());

-- Function to calculate average competitor price for a product
CREATE OR REPLACE FUNCTION get_average_competitor_price(p_product_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
  v_avg_price DECIMAL(10,2);
BEGIN
  SELECT AVG(price) INTO v_avg_price
  FROM competitor_prices
  WHERE product_id = p_product_id
    AND business_owner_id = auth.uid();
  
  RETURN COALESCE(v_avg_price, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get market statistics for a product
CREATE OR REPLACE FUNCTION get_market_stats(p_product_id UUID)
RETURNS TABLE (
  avg_price DECIMAL(10,2),
  min_price DECIMAL(10,2),
  max_price DECIMAL(10,2),
  price_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(AVG(price), 0)::DECIMAL(10,2) as avg_price,
    COALESCE(MIN(price), 0)::DECIMAL(10,2) as min_price,
    COALESCE(MAX(price), 0)::DECIMAL(10,2) as max_price,
    COUNT(*)::INTEGER as price_count
  FROM competitor_prices
  WHERE product_id = p_product_id
    AND business_owner_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment
COMMENT ON TABLE competitor_prices IS 'Stores competitor pricing data for market analysis and pricing decisions';
COMMENT ON COLUMN competitor_prices.competitor_name IS 'Name of the competitor (e.g., "Kedai A", "Shopee", "Lazada")';
COMMENT ON COLUMN competitor_prices.source IS 'Source of price: physical_store, online_platform, marketplace, or other';
COMMENT ON COLUMN competitor_prices.last_updated IS 'Date when this price was last verified/updated';

