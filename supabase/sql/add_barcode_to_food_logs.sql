-- Add barcode column to food_logs table
-- This allows linking food log entries back to their barcode scan / health analysis

ALTER TABLE food_logs 
ADD COLUMN IF NOT EXISTS barcode text;

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_food_logs_barcode ON food_logs(barcode) WHERE barcode IS NOT NULL;
