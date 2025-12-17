-- Add structured receipt data field to expenses table
-- Store OCR parsed data (items, merchant, etc.) in organized JSONB format

ALTER TABLE expenses 
ADD COLUMN IF NOT EXISTS receipt_data JSONB DEFAULT NULL;

-- Add index for JSONB queries (optional, for future filtering/search)
CREATE INDEX IF NOT EXISTS idx_expenses_receipt_data ON expenses USING GIN (receipt_data);

COMMENT ON COLUMN expenses.receipt_data IS 'Structured receipt data from OCR: {merchant, date, items: [{name, price, quantity?}], subtotal?, tax?, total?}';
