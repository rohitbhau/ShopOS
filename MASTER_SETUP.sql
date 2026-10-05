-- ============================================
-- ShopOS - MASTER SETUP SCRIPT
-- Run this ONCE in Supabase SQL Editor
-- This will create everything needed for the app
-- ============================================

-- ============================================
-- PART 1: HELPER FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 2: CREATE TABLES
-- ============================================

-- 2.1: TENANTS TABLE (Shops/Businesses)
DROP TABLE IF EXISTS public.tenants CASCADE;
CREATE TABLE public.tenants (
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

-- 2.2: PROFILES TABLE (User Information)
DROP TABLE IF EXISTS public.profiles CASCADE;
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT,
    name TEXT,
    locale TEXT DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3: MEMBERSHIPS TABLE (Links Users to Shops)
DROP TABLE IF EXISTS public.memberships CASCADE;
CREATE TABLE public.memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'manager', 'cashier', 'viewer')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, user_id)
);

-- ============================================
-- PART 3: CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_tenants_phone ON public.tenants(phone);
CREATE INDEX IF NOT EXISTS idx_tenants_is_active ON public.tenants(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_memberships_tenant ON public.memberships(tenant_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON public.memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_active ON public.memberships(is_active);

-- ============================================
-- PART 4: CREATE TRIGGERS
-- ============================================

DROP TRIGGER IF EXISTS update_tenants_updated_at ON public.tenants;
CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_memberships_updated_at ON public.memberships;
CREATE TRIGGER update_memberships_updated_at
    BEFORE UPDATE ON public.memberships
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- PART 5: ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PART 6: DROP OLD POLICIES (Clean Slate)
-- ============================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own memberships" ON public.memberships;
DROP POLICY IF EXISTS "Users can insert own memberships" ON public.memberships;
DROP POLICY IF EXISTS "Users can view their tenant" ON public.tenants;
DROP POLICY IF EXISTS "Users can insert tenant" ON public.tenants;
DROP POLICY IF EXISTS "Authenticated users can create tenant" ON public.tenants;
DROP POLICY IF EXISTS "Users can update their tenant" ON public.tenants;

-- ============================================
-- PART 7: CREATE RLS POLICIES (Correct Order)
-- ============================================

-- 7.1: PROFILES POLICIES
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- 7.2: TENANTS POLICIES (Most Permissive for Shop Creation)
CREATE POLICY "Authenticated users can create tenant"
    ON public.tenants FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users can view their tenant"
    ON public.tenants FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT tenant_id FROM public.memberships 
            WHERE user_id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Owners can update their tenant"
    ON public.tenants FOR UPDATE
    TO authenticated
    USING (
        id IN (
            SELECT tenant_id FROM public.memberships 
            WHERE user_id = auth.uid() 
            AND role IN ('owner', 'manager')
            AND is_active = true
        )
    );

-- 7.3: MEMBERSHIPS POLICIES
CREATE POLICY "Users can view own memberships"
    ON public.memberships FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own memberships"
    ON public.memberships FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- ============================================
-- PART 8: CREATE HELPER FUNCTIONS FOR APP
-- ============================================

-- Function to get user's current tenant_id
CREATE OR REPLACE FUNCTION public.get_user_tenant_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT tenant_id 
        FROM public.memberships 
        WHERE user_id = auth.uid() 
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is owner/manager
CREATE OR REPLACE FUNCTION public.is_user_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.memberships 
        WHERE user_id = auth.uid() 
        AND role IN ('owner', 'manager')
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 9: GRANT PERMISSIONS
-- ============================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Grant table permissions
GRANT ALL ON public.tenants TO authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.memberships TO authenticated;

-- Grant sequence permissions (for auto-increment if any)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================
-- PART 10: VERIFICATION
-- ============================================

-- Verify tables exist
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename IN ('tenants', 'profiles', 'memberships');
    
    IF table_count = 3 THEN
        RAISE NOTICE '✅ All 3 tables created successfully!';
    ELSE
        RAISE EXCEPTION '❌ Only % tables created. Expected 3.', table_count;
    END IF;
END $$;

-- Verify RLS is enabled
DO $$
DECLARE
    rls_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO rls_count
    FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename IN ('tenants', 'profiles', 'memberships')
    AND rowsecurity = true;
    
    IF rls_count = 3 THEN
        RAISE NOTICE '✅ RLS enabled on all tables!';
    ELSE
        RAISE EXCEPTION '❌ RLS only enabled on % tables. Expected 3.', rls_count;
    END IF;
END $$;

-- Verify policies exist
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename IN ('tenants', 'profiles', 'memberships');
    
    IF policy_count >= 8 THEN
        RAISE NOTICE '✅ % RLS policies created!', policy_count;
    ELSE
        RAISE EXCEPTION '❌ Only % policies created. Expected at least 8.', policy_count;
    END IF;
END $$;

-- Display final status
SELECT 
    '✅ DATABASE SETUP COMPLETE!' as status,
    NOW() as completed_at;

-- Show created tables
SELECT 
    tablename as "Table Name",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as "Size"
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'profiles', 'memberships')
ORDER BY tablename;

-- Show RLS policies
SELECT 
    tablename as "Table",
    policyname as "Policy Name",
    cmd as "Command"
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'profiles', 'memberships')
ORDER BY tablename, policyname;

-- ============================================
-- SETUP COMPLETE - YOU CAN NOW USE THE APP!
-- ============================================
