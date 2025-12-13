-- Fix trainer_availability table - add is_active column if missing

ALTER TABLE public.trainer_availability 
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Update any existing rows to have is_active = true
UPDATE public.trainer_availability 
SET is_active = true 
WHERE is_active IS NULL;

-- Fix trainer_lesson_types table - add is_active and sort_order columns if missing

ALTER TABLE public.trainer_lesson_types 
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

ALTER TABLE public.trainer_lesson_types 
ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

-- Update any existing rows
UPDATE public.trainer_lesson_types 
SET is_active = true 
WHERE is_active IS NULL;

UPDATE public.trainer_lesson_types 
SET sort_order = 0 
WHERE sort_order IS NULL;

