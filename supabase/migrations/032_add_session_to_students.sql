-- Add session_id to students table
ALTER TABLE students 
ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES sessions(id) ON DELETE SET NULL;

-- Update handle_lead_conversion function to include session_id
CREATE OR REPLACE FUNCTION handle_lead_conversion()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'converted' AND OLD.status != 'converted' THEN
    INSERT INTO students (
      lead_id, full_name, phone, email,
      course_id, sub_course_id, assigned_counsellor,
      total_fee, amount_paid, enrollment_date,
      mode, department_id, sub_section_id, session_id
    ) VALUES (
      NEW.id, NEW.full_name, NEW.phone, NEW.email,
      NEW.course_id, NEW.sub_course_id, NEW.assigned_to,
      NEW.total_fee, NEW.amount_paid, COALESCE(NEW.enrollment_date, CURRENT_DATE),
      NEW.mode, NEW.department_id, NEW.sub_section_id, NEW.session_id
    )
    ON CONFLICT (lead_id) DO UPDATE SET
      mode = EXCLUDED.mode,
      department_id = EXCLUDED.department_id,
      sub_section_id = EXCLUDED.sub_section_id,
      enrollment_date = EXCLUDED.enrollment_date;
      -- session_id is usually set during initial insert, if updating we maintain it
    
    NEW.converted_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
