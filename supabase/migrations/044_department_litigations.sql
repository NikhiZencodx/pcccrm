-- Department litigation tracking system

-- Add dept_fund column to departments (manually updated balance)
ALTER TABLE departments ADD COLUMN IF NOT EXISTS dept_fund NUMERIC(12,2) DEFAULT 0;

-- Create department_litigations table
CREATE TABLE IF NOT EXISTS department_litigations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  sub_section_id UUID REFERENCES department_sub_sections(id) ON DELETE SET NULL,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  student_name TEXT NOT NULL,
  father_name TEXT,
  phone TEXT,
  litigation_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE department_litigations ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Authenticated users can view litigations"
  ON department_litigations FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage litigations"
  ON department_litigations FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_litigation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER litigation_updated_at
  BEFORE UPDATE ON department_litigations
  FOR EACH ROW EXECUTE FUNCTION update_litigation_updated_at();
