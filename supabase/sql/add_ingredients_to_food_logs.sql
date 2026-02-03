-- Add ingredients column to food_logs table
-- Run this in Supabase SQL Editor

-- Add the ingredients column as JSONB (allows storing array of ingredient objects)
ALTER TABLE food_logs 
ADD COLUMN IF NOT EXISTS ingredients JSONB DEFAULT NULL;

-- Add a comment to describe the column
COMMENT ON COLUMN food_logs.ingredients IS 'JSON array of ingredients with name, calories, protein, carbs, fat, and amount';

-- Example of what the data looks like:
-- [
--   {"name": "Kyckling", "calories": 200, "protein": 30, "carbs": 0, "fat": 8, "amount": "150g"},
--   {"name": "Ris", "calories": 150, "protein": 3, "carbs": 35, "fat": 1, "amount": "100g"}
-- ]

-- Verify the column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'food_logs' AND column_name = 'ingredients';
