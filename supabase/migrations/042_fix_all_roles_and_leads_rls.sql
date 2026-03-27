-- ============================================================
-- CRITICAL: Run this in Supabase SQL Editor immediately
-- Fixes role names + leads RLS so telecallers see only their leads
-- ============================================================

-- STEP 1: Rename old roles to new names
UPDATE profiles SET role = 'lead' WHERE role = 'telecaller';
UPDATE profiles SET role = 'backend' WHERE role = 'finance';

-- STEP 2: Update profiles check constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'lead', 'backend'));

-- STEP 3: Fix leads RLS policies

-- Remove old policies
DROP POLICY IF EXISTS "Admin and backend can view all leads" ON leads;
DROP POLICY IF EXISTS "Telecaller can view own leads" ON leads;
DROP POLICY IF EXISTS "Lead can view own leads" ON leads;
DROP POLICY IF EXISTS "Lead can view assigned leads" ON leads;
DROP POLICY IF EXISTS "Admin and telecaller can update own leads" ON leads;
DROP POLICY IF EXISTS "Admin and lead can update own leads" ON leads;
DROP POLICY IF EXISTS "Admin and backend can update leads" ON leads;
DROP POLICY IF EXISTS "Telecaller and admin can insert leads" ON leads;
DROP POLICY IF EXISTS "Lead and admin can insert leads" ON leads;
DROP POLICY IF EXISTS "Admin can delete leads" ON leads;
DROP POLICY IF EXISTS "Admin and backend can delete leads" ON leads;

-- Recreate clean policies
CREATE POLICY "Admin and backend can view all leads"
  ON leads FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

CREATE POLICY "Lead can view assigned leads"
  ON leads FOR SELECT
  USING (
    auth.uid() = assigned_to
  );

CREATE POLICY "Admin and backend can insert leads"
  ON leads FOR INSERT
  WITH CHECK (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend', 'lead'))
  );

CREATE POLICY "Admin and backend can update leads"
  ON leads FOR UPDATE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
    OR auth.uid() = assigned_to
  );

CREATE POLICY "Admin and backend can delete leads"
  ON leads FOR DELETE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );
