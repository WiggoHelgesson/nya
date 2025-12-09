-- ============================================
-- GOLF LESSONS EXTENDED SCHEMA
-- Comprehensive trainer profiles, booking flow, reviews
-- ============================================

-- Enable required extensions
create extension if not exists "uuid-ossp";

-- ============================================
-- 1. TRAINER SPECIALTIES
-- ============================================

-- Predefined specialties
create table if not exists public.trainer_specialties_catalog (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    description text,
    icon text, -- SF Symbol name
    created_at timestamptz default now()
);

-- Insert default specialties
insert into public.trainer_specialties_catalog (name, description, icon) values
    ('Driving', 'Långa slag och utslagsteknik', 'figure.golf'),
    ('Putting', 'Puttning och kortspel', 'target'),
    ('Järnspel', 'Järnslag och approach', 'arrow.up.forward'),
    ('Chipping', 'Korta slag runt green', 'leaf.arrow.triangle.circlepath'),
    ('Bunker', 'Bunkerslag och sandteknik', 'square.stack.3d.up'),
    ('Banmanagement', 'Strategi och spelplanering', 'map'),
    ('Mental träning', 'Fokus och mental styrka', 'brain.head.profile'),
    ('Nybörjare', 'Grundläggande teknik för nybörjare', 'star'),
    ('Tävlingsförberedelse', 'Förberedelse inför tävlingar', 'trophy'),
    ('Videoanalys', 'Swing-analys med video', 'video')
on conflict (name) do nothing;

-- Trainer's selected specialties (many-to-many)
create table if not exists public.trainer_specialties (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    specialty_id uuid not null references public.trainer_specialties_catalog(id) on delete cascade,
    created_at timestamptz default now(),
    unique(trainer_id, specialty_id)
);

-- ============================================
-- 2. TRAINER CERTIFICATIONS
-- ============================================

create table if not exists public.trainer_certifications (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    name text not null, -- e.g., "PGA Certified", "Level 3 Coach"
    issuer text, -- e.g., "Svenska Golfförbundet"
    year_obtained integer,
    certificate_url text, -- Optional link to certificate image
    created_at timestamptz default now()
);

-- ============================================
-- 3. LESSON TYPES WITH PRICING
-- ============================================

create table if not exists public.trainer_lesson_types (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    name text not null, -- e.g., "60 min lektion", "Teknikgenomgång"
    description text,
    duration_minutes integer not null default 60,
    price integer not null, -- Price in SEK (öre)
    is_active boolean default true,
    sort_order integer default 0,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- 4. TRAINER AVAILABILITY (Calendar)
-- ============================================

create table if not exists public.trainer_availability (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    day_of_week integer not null check (day_of_week between 0 and 6), -- 0=Sunday, 6=Saturday
    start_time time not null,
    end_time time not null,
    is_active boolean default true,
    created_at timestamptz default now()
);

-- Specific blocked/available dates
create table if not exists public.trainer_availability_overrides (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    date date not null,
    is_available boolean default false, -- false = blocked, true = extra available
    start_time time,
    end_time time,
    reason text,
    created_at timestamptz default now()
);

-- ============================================
-- 5. TRAINER MEDIA (Images & Videos)
-- ============================================

create table if not exists public.trainer_media (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    media_type text not null check (media_type in ('image', 'video')),
    url text not null,
    thumbnail_url text,
    caption text,
    sort_order integer default 0,
    created_at timestamptz default now()
);

-- ============================================
-- 6. REVIEWS & RATINGS
-- ============================================

create table if not exists public.trainer_reviews (
    id uuid primary key default uuid_generate_v4(),
    trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
    reviewer_id uuid not null references auth.users(id) on delete cascade,
    booking_id uuid references public.trainer_bookings(id) on delete set null,
    rating integer not null check (rating between 1 and 5),
    title text,
    comment text,
    trainer_response text,
    is_verified boolean default false, -- True if linked to actual booking
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- 7. GOLF COURSES (for location selection)
-- ============================================

create table if not exists public.golf_courses (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    address text,
    city text,
    latitude double precision,
    longitude double precision,
    website text,
    phone text,
    is_verified boolean default false,
    created_at timestamptz default now()
);

-- Insert some Swedish golf courses
insert into public.golf_courses (name, city, latitude, longitude) values
    ('Djursholms Golfklubb', 'Djursholm', 59.3977, 18.0874),
    ('Stockholms Golfklubb', 'Danderyd', 59.4033, 18.0364),
    ('Bro Hof Slott Golf Club', 'Bro', 59.5150, 17.6417),
    ('Ullna Golf', 'Åkersberga', 59.4833, 18.1833),
    ('Nacka Golfklubb', 'Nacka', 59.3167, 18.1667),
    ('Lidingö Golfklubb', 'Lidingö', 59.3667, 18.1833),
    ('Täby Golfklubb', 'Täby', 59.4500, 18.0500),
    ('Vallentuna Golfklubb', 'Vallentuna', 59.5333, 18.0833)
on conflict do nothing;

-- ============================================
-- 8. ENHANCED BOOKINGS TABLE
-- ============================================

-- Add new columns to existing trainer_bookings
alter table public.trainer_bookings 
    add column if not exists lesson_type_id uuid references public.trainer_lesson_types(id),
    add column if not exists scheduled_date date,
    add column if not exists scheduled_time time,
    add column if not exists duration_minutes integer,
    add column if not exists price integer,
    add column if not exists location_type text check (location_type in ('course', 'custom', 'trainer_location')),
    add column if not exists golf_course_id uuid references public.golf_courses(id),
    add column if not exists custom_location_name text,
    add column if not exists custom_location_lat double precision,
    add column if not exists custom_location_lng double precision,
    add column if not exists payment_status text default 'pending' check (payment_status in ('pending', 'paid', 'refunded', 'failed')),
    add column if not exists stripe_payment_id text,
    add column if not exists cancelled_at timestamptz,
    add column if not exists cancellation_reason text;

-- ============================================
-- 9. UPDATE TRAINER_PROFILES
-- ============================================

alter table public.trainer_profiles
    add column if not exists experience_years integer default 0,
    add column if not exists club_affiliation text,
    add column if not exists city text,
    add column if not exists bio text,
    add column if not exists average_rating double precision default 0,
    add column if not exists total_reviews integer default 0,
    add column if not exists total_lessons integer default 0,
    add column if not exists response_time_hours integer; -- Average response time

-- ============================================
-- 10. RLS POLICIES
-- ============================================

-- Enable RLS on all tables
alter table public.trainer_specialties_catalog enable row level security;
alter table public.trainer_specialties enable row level security;
alter table public.trainer_certifications enable row level security;
alter table public.trainer_lesson_types enable row level security;
alter table public.trainer_availability enable row level security;
alter table public.trainer_availability_overrides enable row level security;
alter table public.trainer_media enable row level security;
alter table public.trainer_reviews enable row level security;
alter table public.golf_courses enable row level security;

-- Specialties catalog - everyone can read
create policy "Anyone can read specialties catalog" on public.trainer_specialties_catalog
    for select using (true);

-- Trainer specialties - trainers manage their own
create policy "Anyone can read trainer specialties" on public.trainer_specialties
    for select using (true);
    
create policy "Trainers can manage their specialties" on public.trainer_specialties
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

-- Certifications
create policy "Anyone can read certifications" on public.trainer_certifications
    for select using (true);
    
create policy "Trainers can manage their certifications" on public.trainer_certifications
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

-- Lesson types
create policy "Anyone can read lesson types" on public.trainer_lesson_types
    for select using (true);
    
create policy "Trainers can manage their lesson types" on public.trainer_lesson_types
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

-- Availability
create policy "Anyone can read availability" on public.trainer_availability
    for select using (true);
    
create policy "Trainers can manage their availability" on public.trainer_availability
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

create policy "Anyone can read availability overrides" on public.trainer_availability_overrides
    for select using (true);
    
create policy "Trainers can manage their availability overrides" on public.trainer_availability_overrides
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

-- Media
create policy "Anyone can read trainer media" on public.trainer_media
    for select using (true);
    
create policy "Trainers can manage their media" on public.trainer_media
    for all using (
        trainer_id in (select id from public.trainer_profiles where user_id = auth.uid())
    );

-- Reviews
create policy "Anyone can read reviews" on public.trainer_reviews
    for select using (true);
    
create policy "Users can create reviews" on public.trainer_reviews
    for insert with check (reviewer_id = auth.uid());
    
create policy "Users can update their reviews" on public.trainer_reviews
    for update using (reviewer_id = auth.uid());

-- Golf courses - everyone can read
create policy "Anyone can read golf courses" on public.golf_courses
    for select using (true);

-- ============================================
-- 11. FUNCTIONS
-- ============================================

-- Function to update trainer's average rating
create or replace function public.update_trainer_rating()
returns trigger as $$
begin
    update public.trainer_profiles
    set 
        average_rating = (
            select coalesce(avg(rating), 0) 
            from public.trainer_reviews 
            where trainer_id = coalesce(new.trainer_id, old.trainer_id)
        ),
        total_reviews = (
            select count(*) 
            from public.trainer_reviews 
            where trainer_id = coalesce(new.trainer_id, old.trainer_id)
        )
    where id = coalesce(new.trainer_id, old.trainer_id);
    
    return coalesce(new, old);
end;
$$ language plpgsql security definer;

-- Trigger for rating updates
drop trigger if exists update_trainer_rating_trigger on public.trainer_reviews;
create trigger update_trainer_rating_trigger
    after insert or update or delete on public.trainer_reviews
    for each row execute function public.update_trainer_rating();

-- Function to get available time slots for a trainer on a specific date
create or replace function public.get_trainer_available_slots(
    p_trainer_id uuid,
    p_date date,
    p_duration_minutes integer default 60
)
returns table (
    start_time time,
    end_time time
) as $$
declare
    day_num integer;
    slot_start time;
    slot_end time;
begin
    day_num := extract(dow from p_date);
    
    -- Get regular availability for this day
    for slot_start, slot_end in
        select ta.start_time, ta.end_time
        from public.trainer_availability ta
        where ta.trainer_id = p_trainer_id
          and ta.day_of_week = day_num
          and ta.is_active = true
    loop
        -- Check for overrides
        if not exists (
            select 1 from public.trainer_availability_overrides tao
            where tao.trainer_id = p_trainer_id
              and tao.date = p_date
              and tao.is_available = false
        ) then
            -- Check for existing bookings
            return query
            select slot_start as start_time, 
                   (slot_start + (p_duration_minutes || ' minutes')::interval)::time as end_time
            where not exists (
                select 1 from public.trainer_bookings tb
                where tb.trainer_id = (select tp.id from public.trainer_profiles tp where tp.id = p_trainer_id)
                  and tb.scheduled_date = p_date
                  and tb.scheduled_time = slot_start
                  and tb.booking_status not in ('declined', 'cancelled')
            );
        end if;
    end loop;
    
    -- Also check for extra available slots from overrides
    for slot_start, slot_end in
        select tao.start_time, tao.end_time
        from public.trainer_availability_overrides tao
        where tao.trainer_id = p_trainer_id
          and tao.date = p_date
          and tao.is_available = true
    loop
        return query
        select slot_start as start_time,
               (slot_start + (p_duration_minutes || ' minutes')::interval)::time as end_time;
    end loop;
end;
$$ language plpgsql security definer;

-- Function to search trainers with filters
create or replace function public.search_trainers(
    p_search_text text default null,
    p_min_price integer default null,
    p_max_price integer default null,
    p_min_rating double precision default null,
    p_specialties uuid[] default null,
    p_city text default null,
    p_sort_by text default 'rating', -- 'rating', 'price', 'reviews'
    p_limit integer default 50
)
returns table (
    id uuid,
    user_id uuid,
    name text,
    description text,
    hourly_rate integer,
    handicap integer,
    latitude double precision,
    longitude double precision,
    avatar_url text,
    city text,
    experience_years integer,
    average_rating double precision,
    total_reviews integer,
    specialties text[]
) as $$
begin
    return query
    select 
        tp.id,
        tp.user_id,
        tp.name,
        tp.description,
        tp.hourly_rate,
        tp.handicap,
        tp.latitude,
        tp.longitude,
        tp.avatar_url,
        tp.city,
        tp.experience_years,
        tp.average_rating,
        tp.total_reviews,
        array_agg(distinct tsc.name) filter (where tsc.name is not null) as specialties
    from public.trainer_profiles tp
    left join public.trainer_specialties ts on ts.trainer_id = tp.id
    left join public.trainer_specialties_catalog tsc on tsc.id = ts.specialty_id
    where tp.is_active = true
      and (p_search_text is null or 
           tp.name ilike '%' || p_search_text || '%' or
           tp.city ilike '%' || p_search_text || '%' or
           tp.club_affiliation ilike '%' || p_search_text || '%')
      and (p_min_price is null or tp.hourly_rate >= p_min_price)
      and (p_max_price is null or tp.hourly_rate <= p_max_price)
      and (p_min_rating is null or tp.average_rating >= p_min_rating)
      and (p_city is null or tp.city ilike '%' || p_city || '%')
      and (p_specialties is null or ts.specialty_id = any(p_specialties))
    group by tp.id
    order by 
        case when p_sort_by = 'rating' then tp.average_rating end desc nulls last,
        case when p_sort_by = 'price' then tp.hourly_rate end asc nulls last,
        case when p_sort_by = 'reviews' then tp.total_reviews end desc nulls last
    limit p_limit;
end;
$$ language plpgsql security definer;

-- Grant execute permissions
grant execute on function public.get_trainer_available_slots(uuid, date, integer) to authenticated;
grant execute on function public.search_trainers(text, integer, integer, double precision, uuid[], text, text, integer) to authenticated;


