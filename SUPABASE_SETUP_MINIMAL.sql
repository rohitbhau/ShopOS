-- ============================================
-- ShopOS - MINIMAL Database Setup (No Auth Schema Access)
-- Run this in Supabase SQL Editor if full setup fails
-- ============================================

-- 1. CREATE TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    shop_type TEXT,
    phone TEXT,
    address TEXT,
    gstin TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT,
    name TEXT,
    locale TEXT DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'owner',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, user_id)
);

-- 2. CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_tenants_phone ON public.tenants(phone);
CREATE INDEX IF NOT EXISTS idx_tenants_is_active ON public.tenants(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_memberships_tenant ON public.memberships(tenant_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON public.memberships(user_id);

-- 3. ENABLE RLS (Row Level Security)
-- ============================================

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;

-- 4. CREATE RLS POLICIES
-- ============================================

-- Profiles: Users can manage their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Memberships: Users can view their own memberships
DROP POLICY IF EXISTS "Users can view own memberships" ON public.memberships;
CREATE POLICY "Users can view own memberships"
    ON public.memberships FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own memberships" ON public.memberships;
CREATE POLICY "Users can insert own memberships"
    ON public.memberships FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Tenants: Users can view and manage their tenant's data
DROP POLICY IF EXISTS "Users can view their tenant" ON public.tenants;
CREATE POLICY "Users can view their tenant"
    ON public.tenants FOR SELECT
    USING (
        id IN (
            SELECT tenant_id FROM public.memberships 
            WHERE user_id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "Users can insert tenant" ON public.tenants;
CREATE POLICY "Users can insert tenant"
    ON public.tenants FOR INSERT
    WITH CHECK (true); -- Allow insert for shop creation

DROP POLICY IF EXISTS "Users can update their tenant" ON public.tenants;
CREATE POLICY "Users can update their tenant"
    ON public.tenants FOR UPDATE
    USING (
        id IN (
            SELECT tenant_id FROM public.memberships 
            WHERE user_id = auth.uid() AND is_active = true
        )
    );

-- 5. VERIFY SETUP
-- ============================================

SELECT 'Tables created successfully!' as status;

SELECT tablename, schemaname 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'profiles', 'memberships')
ORDER BY tablename;
