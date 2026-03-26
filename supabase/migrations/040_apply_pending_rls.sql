-- ============================================================
-- Migration 040: Apply all pending RLS fixes
-- Run this entire script in Supabase SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- 1. EXPENSES: fix roles (finance→backend) + add DELETE policy
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Finance and admin can view all expenses" ON expenses;
DROP POLICY IF EXISTS "Admin and backend can view all expenses" ON expenses;
CREATE POLICY "Admin and backend can view all expenses"
  ON expenses FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

DROP POLICY IF EXISTS "Finance and admin can update expenses" ON expenses;
DROP POLICY IF EXISTS "Admin and backend can update expenses" ON expenses;
CREATE POLICY "Admin and backend can update expenses"
  ON expenses FOR UPDATE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

DROP POLICY IF EXISTS "Users can view own expenses" ON expenses;
CREATE POLICY "Users can view own expenses"
  ON expenses FOR SELECT
  USING (submitted_by = auth.uid());

DROP POLICY IF EXISTS "Admin and backend can delete expenses" ON expenses;
CREATE POLICY "Admin and backend can delete expenses"
  ON expenses FOR DELETE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

-- ------------------------------------------------------------
-- 2. PAYROLL: allow backend to manage payroll (not just admin)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can manage payroll" ON payroll;
DROP POLICY IF EXISTS "Admin and backend can manage payroll" ON payroll;
CREATE POLICY "Admin and backend can manage payroll"
  ON payroll FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

-- ------------------------------------------------------------
-- 3. EMPLOYEES: allow backend to view employees
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can manage employees" ON employees;
DROP POLICY IF EXISTS "Admin can manage employees" ON employees;
CREATE POLICY "Admin can manage employees"
  ON employees FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Backend can view employees" ON employees;
CREATE POLICY "Backend can view employees"
  ON employees FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'backend')
  );

-- ------------------------------------------------------------
-- 4. ATTENDANCE: allow backend to manage attendance
-- ------------------------------------------------------------
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage attendance" ON attendance;
DROP POLICY IF EXISTS "Admin and backend can manage attendance" ON attendance;
CREATE POLICY "Admin and backend can manage attendance"
  ON attendance FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

DROP POLICY IF EXISTS "Employees can view own attendance" ON attendance;
CREATE POLICY "Employees can view own attendance"
  ON attendance FOR SELECT
  USING (
    exists (SELECT 1 FROM employees WHERE id = employee_id AND profile_id = auth.uid())
  );
