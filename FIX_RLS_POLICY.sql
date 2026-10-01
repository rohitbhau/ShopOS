-- ============================================
-- Fix RLS Policy for Tenant Creation
-- Run this in Supabase SQL Editor
-- ============================================

-- Drop the restrictive INSERT policy on tenants
DROP POLICY IF EXISTS "Users can insert tenant" ON public.tenants;

-- Create a permissive INSERT policy that allows authenticated users to create tenants
CREATE POLICY "Authenticated users can create tenant"
    ON public.tenants FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Also ensure the SELECT policy exists so users can view their tenants
DROP POLICY IF EXISTS "Users can view their tenant" ON public.tenants;
CREATE POLICY "Users can view their tenant"
    ON public.tenants FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT tenant_id FROM public.memberships 
            WHERE user_id = auth.uid() AND is_active = true
        )
    );

-- Update policy allows owners/managers to update their tenant
DROP POLICY IF EXISTS "Users can update their tenant" ON public.tenants;
CREATE POLICY "Users can update their tenant"
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

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'tenants'
ORDER BY policyname;

SELECT 'RLS policies updated successfully!' as status;
