-- Add delivery_address column to sales table
-- This field is required for online and delivery channels

ALTER TABLE sales
ADD COLUMN IF NOT EXISTS delivery_address TEXT;

-- Add comment to explain the field
COMMENT ON COLUMN sales.delivery_address IS 'Delivery address for online and delivery channel sales';

