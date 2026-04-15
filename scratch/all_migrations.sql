-- Profiles table (extends auth.users)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role text not null check (role in ('admin', 'telecaller', 'backend', 'finance')),
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS
alter table profiles enable row level security;

create policy "Users can view all active profiles"
  on profiles for select
  using (auth.uid() is not null);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);

create policy "Admins can manage all profiles"
  on profiles for all
  using (
    exists (
      select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'
    )
  );
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists sub_courses (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table courses enable row level security;
alter table sub_courses enable row level security;

create policy "Authenticated users can view courses"
  on courses for select using (auth.uid() is not null);

create policy "Admins can manage courses"
  on courses for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Authenticated users can view sub_courses"
  on sub_courses for select using (auth.uid() is not null);

create policy "Admins can manage sub_courses"
  on sub_courses for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  email text,
  city text,
  state text,
  course_id uuid references courses(id) on delete set null,
  sub_course_id uuid references sub_courses(id) on delete set null,
  status text not null default 'new' check (status in (
    'new','contacted','interested','counselled','application_sent','converted','cold','lost'
  )),
  source text not null check (source in (
    'website','walk_in','referral','whatsapp','phone','excel_import','social_media','other'
  )),
  assigned_to uuid references profiles(id) on delete set null,
  assigned_at timestamptz,
  next_followup_date date,
  total_fee numeric(12,2),
  amount_paid numeric(12,2) not null default 0,
  converted_at timestamptz,
  import_batch_id text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table leads enable row level security;

create policy "Admin and backend can view all leads"
  on leads for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend'))
  );

create policy "Telecaller can view own leads"
  on leads for select
  using (
    auth.uid() = assigned_to or auth.uid() = created_by
  );

create policy "Telecaller and admin can insert leads"
  on leads for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','telecaller','backend'))
  );

create policy "Admin and telecaller can update own leads"
  on leads for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
    or auth.uid() = assigned_to
  );
create table if not exists lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  activity_type text not null check (activity_type in (
    'created','status_changed','assigned','transferred','note_added',
    'followup_set','payment_received','converted','document_uploaded','call_made'
  )),
  old_value text,
  new_value text,
  note text,
  performed_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table lead_activities enable row level security;

create policy "Users with lead access can view activities"
  on lead_activities for select
  using (auth.uid() is not null);

create policy "Users can insert activities"
  on lead_activities for insert
  with check (auth.uid() is not null);
create table if not exists lead_column_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  column_key text not null,
  is_visible boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, column_key)
);

alter table lead_column_preferences enable row level security;

create policy "Users manage own preferences"
  on lead_column_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references leads(id) on delete set null,
  student_id uuid,  -- will add FK after students table created
  amount numeric(12,2) not null check (amount > 0),
  payment_mode text not null check (payment_mode in ('cash','upi','card','neft','rtgs','cheque','other')),
  payment_date date not null,
  receipt_number text,
  notes text,
  recorded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table payments enable row level security;

create policy "Admin, backend, finance can view payments"
  on payments for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend','finance'))
  );

create policy "Backend and admin can insert payments"
  on payments for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend'))
  );
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references leads(id) on delete set null unique,
  enrollment_number text not null unique default 'ENR-' || floor(random() * 900000 + 100000)::text,
  full_name text not null,
  phone text not null,
  email text,
  city text,
  course_id uuid references courses(id) on delete set null,
  sub_course_id uuid references sub_courses(id) on delete set null,
  assigned_counsellor uuid references profiles(id) on delete set null,
  total_fee numeric(12,2),
  amount_paid numeric(12,2) not null default 0,
  enrollment_date date,
  status text not null default 'active' check (status in ('active','completed','dropped','on_hold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add FK from payments to students
alter table payments add constraint payments_student_id_fkey
  foreign key (student_id) references students(id) on delete set null;

alter table students enable row level security;

create policy "Admin and backend can view all students"
  on students for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend','finance'))
  );

create policy "Admin and backend can manage students"
  on students for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend'))
  );
create table if not exists student_documents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  doc_type text not null check (doc_type in (
    '10th_marksheet','12th_marksheet','graduation','passport',
    'sop','lor','ielts_scorecard','pte_scorecard','offer_letter','visa','other'
  )),
  status text not null default 'pending' check (status in ('pending','received','verified','rejected')),
  file_url text,
  notes text,
  expiry_date date,
  uploaded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, doc_type)
);

alter table student_documents enable row level security;

create policy "Admin and backend can manage documents"
  on student_documents for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend'))
  );
create table if not exists student_exams (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  exam_type text not null check (exam_type in (
    'ielts','pte','toefl','practical','final_exam','mock_test','other'
  )),
  exam_name text not null,
  exam_date date,
  centre text,
  hall_ticket_number text,
  admit_card_url text,
  score text,
  is_passed boolean,
  remarks text,
  created_at timestamptz not null default now()
);

alter table student_exams enable row level security;

create policy "Admin and backend can manage exams"
  on student_exams for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend'))
  );
create table if not exists employees (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade unique,
  employee_code text not null unique default 'EMP-' || floor(random() * 90000 + 10000)::text,
  department text,
  designation text,
  joining_date date,
  basic_salary numeric(12,2) default 0,
  hra numeric(12,2) default 0,
  allowances numeric(12,2) default 0,
  incentive numeric(12,2) default 0,
  pf_deduction numeric(12,2) default 0,
  tds_deduction numeric(12,2) default 0,
  other_deductions numeric(12,2) default 0,
  bank_account text,
  bank_ifsc text,
  bank_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table employees enable row level security;

create policy "Admins can manage employees"
  on employees for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Employees can view own record"
  on employees for select
  using (profile_id = auth.uid());
create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  date date not null,
  status text not null check (status in ('present','absent','half_day','late','leave','holiday')),
  clock_in time,
  clock_out time,
  notes text,
  marked_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (employee_id, date)
);

alter table attendance enable row level security;

create policy "Admins can manage attendance"
  on attendance for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Employees can view own attendance"
  on attendance for select
  using (
    exists (select 1 from employees where id = employee_id and profile_id = auth.uid())
  );
create table if not exists leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  leave_type text not null check (leave_type in ('sick','casual','earned','unpaid','other')),
  from_date date not null,
  to_date date not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table leave_requests enable row level security;

create policy "Admins can manage leave requests"
  on leave_requests for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Employees can manage own leave"
  on leave_requests for all
  using (
    exists (select 1 from employees where id = employee_id and profile_id = auth.uid())
  );
create table if not exists payroll (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  month integer not null check (month between 1 and 12),
  year integer not null,
  basic numeric(12,2) not null default 0,
  hra numeric(12,2) not null default 0,
  allowances numeric(12,2) not null default 0,
  incentive numeric(12,2) not null default 0,
  gross numeric(12,2) not null default 0,
  pf numeric(12,2) not null default 0,
  tds numeric(12,2) not null default 0,
  other_deductions numeric(12,2) not null default 0,
  net numeric(12,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','processed','paid')),
  payment_date date,
  created_at timestamptz not null default now(),
  unique (employee_id, month, year)
);

alter table payroll enable row level security;

create policy "Admins can manage payroll"
  on payroll for all
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Employees can view own payroll"
  on payroll for select
  using (
    exists (select 1 from employees where id = employee_id and profile_id = auth.uid())
  );
create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in (
    'rent','utilities','marketing','travel','salary','vendor','misc','other'
  )),
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  expense_date date not null,
  payment_mode text,
  bill_url text,
  notes text,
  submitted_by uuid references profiles(id) on delete set null,
  approved_by uuid references profiles(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table expenses enable row level security;

create policy "Finance and admin can view all expenses"
  on expenses for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','finance'))
  );

create policy "All staff can submit expenses"
  on expenses for insert
  with check (auth.uid() is not null);

create policy "Finance and admin can update expenses"
  on expenses for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','finance'))
  );
-- Auto updated_at
create extension if not exists moddatetime schema extensions;

create trigger set_updated_at_profiles
  before update on profiles
  for each row execute procedure moddatetime(updated_at);

create trigger set_updated_at_leads
  before update on leads
  for each row execute procedure moddatetime(updated_at);

create trigger set_updated_at_students
  before update on students
  for each row execute procedure moddatetime(updated_at);

create trigger set_updated_at_employees
  before update on employees
  for each row execute procedure moddatetime(updated_at);

-- Lead conversion → auto-create student
create or replace function handle_lead_conversion()
returns trigger as $$
begin
  if NEW.status = 'converted' and OLD.status != 'converted' then
    insert into students (
      lead_id, full_name, phone, email,
      course_id, sub_course_id, assigned_counsellor,
      total_fee, amount_paid, enrollment_date
    ) values (
      NEW.id, NEW.full_name, NEW.phone, NEW.email,
      NEW.course_id, NEW.sub_course_id, NEW.assigned_to,
      NEW.total_fee, NEW.amount_paid, current_date
    )
    on conflict (lead_id) do nothing;
    NEW.converted_at = now();
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_lead_converted
  before update on leads
  for each row execute procedure handle_lead_conversion();

-- Payment insert → update amount_paid on leads and students
create or replace function handle_payment_insert()
returns trigger as $$
begin
  if NEW.lead_id is not null then
    update leads set
      amount_paid = (select coalesce(sum(amount),0) from payments where lead_id = NEW.lead_id)
    where id = NEW.lead_id;
  end if;

  if NEW.lead_id is not null then
    update students set
      amount_paid = (select coalesce(sum(amount),0) from payments where lead_id = NEW.lead_id)
    where lead_id = NEW.lead_id;
  end if;

  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_payment_inserted
  after insert on payments
  for each row execute procedure handle_payment_insert();

-- Auto-log lead created
create or replace function log_lead_created()
returns trigger as $$
begin
  insert into lead_activities (lead_id, activity_type, new_value, performed_by)
  values (NEW.id, 'created', NEW.status, NEW.created_by);
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_lead_created
  after insert on leads
  for each row execute procedure log_lead_created();

-- Auto-log lead status/assignment change
create or replace function log_lead_status_change()
returns trigger as $$
begin
  if OLD.status != NEW.status then
    insert into lead_activities (lead_id, activity_type, old_value, new_value, performed_by)
    values (NEW.id, 'status_changed', OLD.status, NEW.status, auth.uid());
  end if;
  if OLD.assigned_to is distinct from NEW.assigned_to then
    insert into lead_activities (lead_id, activity_type, old_value, new_value, performed_by)
    values (NEW.id, 'assigned',
      (select full_name from profiles where id = OLD.assigned_to),
      (select full_name from profiles where id = NEW.assigned_to),
      auth.uid());
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_lead_updated
  after update on leads
  for each row execute procedure log_lead_status_change();
-- Performance indexes
create index if not exists idx_leads_status on leads(status);
create index if not exists idx_leads_assigned_to on leads(assigned_to);
create index if not exists idx_leads_created_at on leads(created_at desc);
create index if not exists idx_leads_next_followup on leads(next_followup_date);
create index if not exists idx_leads_import_batch on leads(import_batch_id);
create index if not exists idx_leads_phone on leads(phone);
create index if not exists idx_leads_source on leads(source);

create index if not exists idx_lead_activities_lead_id on lead_activities(lead_id);
create index if not exists idx_lead_activities_created_at on lead_activities(created_at desc);

create index if not exists idx_payments_lead_id on payments(lead_id);
create index if not exists idx_payments_student_id on payments(student_id);
create index if not exists idx_payments_payment_date on payments(payment_date desc);

create index if not exists idx_students_course_id on students(course_id);
create index if not exists idx_students_assigned_counsellor on students(assigned_counsellor);
create index if not exists idx_students_status on students(status);

create index if not exists idx_student_documents_student_id on student_documents(student_id);
create index if not exists idx_student_exams_student_id on student_exams(student_id);

create index if not exists idx_attendance_employee_date on attendance(employee_id, date);
create index if not exists idx_payroll_employee_month on payroll(employee_id, year, month);
create index if not exists idx_expenses_status on expenses(status);
create index if not exists idx_expenses_date on expenses(expense_date desc);
-- Add Frontend Skill Sikho course
INSERT INTO courses (name) VALUES ('Frontend Skill Sikho');

-- Add sub-courses for Frontend Skill Sikho
INSERT INTO sub_courses (course_id, name)
SELECT c.id, s.name
FROM courses c
CROSS JOIN (
  VALUES 
    ('React.js'),
    ('HTML & CSS'),
    ('JavaScript Fundamentals'),
    ('Next.js'),
    ('TypeScript')
) AS s(name)
WHERE c.name = 'Frontend Skill Sikho';
-- Create departments table
create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Create department sub-sections table (University/Board)
create table if not exists department_sub_sections (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references departments(id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Add columns to leads table
alter table leads 
add column if not exists department_id uuid references departments(id) on delete set null,
add column if not exists sub_section_id uuid references department_sub_sections(id) on delete set null;

-- Enable RLS
alter table departments enable row level security;
alter table department_sub_sections enable row level security;

-- Policies for departments
create policy "Authenticated users can view departments"
  on departments for select using (auth.uid() is not null);

create policy "Admins can manage departments"
  on departments for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

-- Policies for sub-sections
create policy "Authenticated users can view sub_sections"
  on department_sub_sections for select using (auth.uid() is not null);

create policy "Admins can manage sub_sections"
  on department_sub_sections for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );
-- Add 'updated' to the activity_type check constraint
alter table lead_activities drop constraint if exists lead_activities_activity_type_check;

alter table lead_activities add constraint lead_activities_activity_type_check 
check (activity_type in (
  'created','status_changed','assigned','transferred','note_added',
  'followup_set','payment_received','converted', 'document_uploaded', 'call_made', 'updated'
));
create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table sessions enable row level security;

create policy "Authenticated users can view sessions"
  on sessions for select using (auth.uid() is not null);

create policy "Admins can manage sessions"
  on sessions for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

-- Add column to leads table
alter table leads
add column if not exists session_id uuid references sessions(id) on delete set null;

-- Add incentive column to students table
alter table students 
add column if not exists incentive_amount numeric(10,2) default 0;
-- Migration: Auto backfill missing employees for profiles

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Backfill all existing profiles that don't have an employee record yet
    FOR r IN (
        SELECT id FROM profiles
        WHERE id NOT IN (SELECT profile_id FROM employees)
    ) LOOP
        INSERT INTO employees (profile_id)
        VALUES (r.id)
        ON CONFLICT (profile_id) DO NOTHING;
    END LOOP;
END;
$$;

-- Create the trigger function for future inserts
CREATE OR REPLACE FUNCTION auto_create_employee()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create an employee record if it doesn't already exist
    INSERT INTO employees (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if any (safety measure)
DROP TRIGGER IF EXISTS on_profile_created ON profiles;

-- Create the new trigger to fire right after a User profile is created
CREATE TRIGGER on_profile_created
AFTER INSERT ON profiles
FOR EACH ROW EXECUTE PROCEDURE auto_create_employee();
-- 1. Modify 'payments' table to let Finance team insert manual income.
drop policy if exists "Backend and admin can insert payments" on payments;
drop policy if exists "Staff can insert payments" on payments;

create policy "Staff can insert payments"
  on payments for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin','backend','finance'))
  );

-- 2. Add payroll_id reference to expenses to link them natively
alter table expenses add column if not exists payroll_id uuid references payroll(id) on delete set null;

-- 3. Trigger on payroll for auto-salary conversion to Expense Ledger
create or replace function handle_payroll_paid()
returns trigger as $$
declare
    emp_name text;
begin
    -- Whenever payroll status flips precisely to 'paid'
    if NEW.status = 'paid' and OLD.status != 'paid' then
        -- Grab employee actual name
        select full_name into emp_name from profiles
        where id = (select profile_id from employees where id = NEW.employee_id);
        
        insert into expenses (
            payroll_id,
            category,
            description,
            amount,
            expense_date,
            status,
            payment_mode
        ) values (
            NEW.id,
            'salary',
            'Salary Paid - ' || coalesce(emp_name, 'Employee') || ' - ' || NEW.month || '/' || NEW.year,
            NEW.net,
            (coalesce(NEW.payment_date, current_date))::date,
            'approved',
            'neft'
        );
    end if;
    return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists on_payroll_paid on payroll;
create trigger on_payroll_paid
after update on payroll
for each row execute procedure handle_payroll_paid();
-- 1. Backfill Past Payrolls into Expenses
DO $$
DECLARE
    r RECORD;
    emp_name text;
BEGIN
    FOR r IN (
        SELECT p.*, e.profile_id FROM payroll p
        JOIN employees e ON p.employee_id = e.id
        WHERE p.status = 'paid'
        AND NOT EXISTS (SELECT 1 FROM expenses WHERE payroll_id = p.id)
    ) LOOP
        -- Get profile name
        SELECT full_name INTO emp_name FROM profiles WHERE id = r.profile_id;
        
        INSERT INTO expenses (
            payroll_id,
            category,
            description,
            amount,
            expense_date,
            status,
            payment_mode
        ) VALUES (
            r.id,
            'salary',
            'Salary Paid - ' || coalesce(emp_name, 'Employee') || ' - ' || r.month || '/' || r.year,
            r.net,
            (coalesce(r.payment_date, current_date))::date,
            'approved',
            'neft'
        );
    END LOOP;
END;
$$;


-- 2. Backfill Past Admission Fees into Payments (Income)
-- If a student has 'amount_paid' > 0, but no payment records exist for them,
-- we generate a one-time "Backfilled Admission Fee" payment row to reflect in the Ledger.
DO $$
DECLARE
    s RECORD;
BEGIN
    FOR s IN (
        SELECT * FROM students 
        WHERE amount_paid > 0 
        AND NOT EXISTS (SELECT 1 FROM payments WHERE student_id = students.id OR lead_id = students.lead_id)
    ) LOOP
        INSERT INTO payments (
            lead_id,
            student_id,
            amount,
            payment_mode,
            payment_date,
            notes,
            recorded_by
        ) VALUES (
            s.lead_id,
            s.id,
            s.amount_paid,
            'cash', -- Defaulting to cash for old records without payment mode tracking
            s.enrollment_date,
            'Backfilled Admission Fee',
            (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1)
        );
    END LOOP;
END;
$$;
-- Add guardian_name to students
ALTER TABLE students ADD COLUMN IF NOT EXISTS guardian_name text;
-- Add DELETE policies for leads
create policy "Admins can delete any lead"
  on leads for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "Backend can delete any lead"
  on leads for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'backend')
  );

-- Note: We don't allow telecallers to delete leads usually, but if needed:
-- create policy "Telecallers can delete own leads"
--   on leads for delete
--   using (auth.uid() = assigned_to or auth.uid() = created_by);

-- Ensure students table has explicit delete policies if not already covered by 'ALL'
-- Existing policy in 007_students.sql:
-- create policy "Admin and backend can manage students" on students for all ...
-- This already covers DELETE.

-- Add DELETE policy for lead_activities just in case, though it has cascade delete from leads
create policy "Admins can delete activities"
  on lead_activities for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );
-- Add mode to leads
alter table leads add column if not exists mode text check (mode in ('attending', 'non-attending'));

-- Add fields to students
alter table students 
add column if not exists mode text check (mode in ('attending', 'non-attending')),
add column if not exists department_id uuid references departments(id) on delete set null,
add column if not exists sub_section_id uuid references department_sub_sections(id) on delete set null;
-- Add missing columns to leads table for department/sub-section
ALTER TABLE leads 
ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS sub_section_id uuid REFERENCES department_sub_sections(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS enrollment_date date;

-- Update handle_lead_conversion trigger to include new fields
CREATE OR REPLACE FUNCTION handle_lead_conversion()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'converted' AND OLD.status != 'converted' THEN
    INSERT INTO students (
      lead_id, full_name, phone, email,
      course_id, sub_course_id, assigned_counsellor,
      total_fee, amount_paid, enrollment_date,
      mode, department_id, sub_section_id
    ) VALUES (
      NEW.id, NEW.full_name, NEW.phone, NEW.email,
      NEW.course_id, NEW.sub_course_id, NEW.assigned_to,
      NEW.total_fee, NEW.amount_paid, COALESCE(NEW.enrollment_date, CURRENT_DATE),
      NEW.mode, NEW.department_id, NEW.sub_section_id
    )
    ON CONFLICT (lead_id) DO UPDATE SET
      mode = EXCLUDED.mode,
      department_id = EXCLUDED.department_id,
      sub_section_id = EXCLUDED.sub_section_id,
      enrollment_date = EXCLUDED.enrollment_date;
    
    NEW.converted_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Ensure new fields exist and are active in lead_form_fields
INSERT INTO lead_form_fields (field_key, label, field_type, is_required, is_active, is_system, display_order)
VALUES 
  ('mode', 'Mode (Attending/Non-attending)', 'select', false, true, true, 100),
  ('department_id', 'Department', 'select', false, true, true, 110),
  ('sub_section_id', 'University/Board', 'select', false, true, true, 120),
  ('enrollment_date', 'Expected Enrollment Date', 'date', false, true, true, 130)
ON CONFLICT (field_key) DO UPDATE SET 
  is_active = true,
  is_system = true;
-- Ensure amount_paid exists and is active in lead_form_fields
INSERT INTO lead_form_fields (field_key, label, field_type, is_required, is_active, is_system, display_order)
VALUES 
  ('total_fee', 'Total Fee', 'number', false, true, true, 200),
  ('amount_paid', 'Amount Paid', 'number', false, true, true, 210)
ON CONFLICT (field_key) DO UPDATE SET 
  is_active = true,
  is_system = true;
-- 1. Add DELETE policy for payments
CREATE POLICY "Admin and finance can delete payments"
  ON payments FOR DELETE
  USING (
    exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'finance'))
  );

-- 2. Update trigger to handle INSERT, UPDATE, and DELETE
CREATE OR REPLACE FUNCTION handle_payment_change()
RETURNS trigger AS $$
DECLARE
  target_id uuid;
BEGIN
  -- Determine which lead_id to update (NEW for insert/update, OLD for delete)
  target_id := COALESCE(NEW.lead_id, OLD.lead_id);
  
  IF target_id IS NOT NULL THEN
    -- Update amount_paid in leads
    UPDATE leads SET
      amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE lead_id = target_id)
    WHERE id = target_id;

    -- Update amount_paid in students
    UPDATE students SET
      amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE lead_id = target_id)
    WHERE lead_id = target_id;
  END IF;

  RETURN NULL; -- result is ignored for AFTER triggers
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Replace old insert-only trigger with the new one
DROP TRIGGER IF EXISTS on_payment_inserted ON payments;

CREATE TRIGGER on_payment_changed
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE PROCEDURE handle_payment_change();
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
-- Robust trigger to sync amount_paid from payments to leads and students
CREATE OR REPLACE FUNCTION handle_payment_change()
RETURNS trigger AS $$
DECLARE
    target_lead_id uuid;
    target_student_id uuid;
BEGIN
    -- Determine which lead/student to update
    IF TG_OP = 'DELETE' THEN
        target_lead_id := OLD.lead_id;
        target_student_id := OLD.student_id;
    ELSE
        target_lead_id := NEW.lead_id;
        target_student_id := NEW.student_id;
    END IF;

    -- Update Leads
    IF target_lead_id IS NOT NULL THEN
        UPDATE leads SET
            amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE lead_id = target_lead_id)
        WHERE id = target_lead_id;
    END IF;

    -- Update Students (by student_id or lead_id)
    IF target_student_id IS NOT NULL THEN
        UPDATE students SET
            amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE student_id = target_student_id)
        WHERE id = target_student_id;
    ELSIF target_lead_id IS NOT NULL THEN
        UPDATE students SET
            amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE lead_id = target_lead_id)
        WHERE lead_id = target_lead_id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-apply trigger to payments table
DROP TRIGGER IF EXISTS on_payment_inserted ON payments;
DROP TRIGGER IF EXISTS on_payment_changed ON payments;

CREATE TRIGGER on_payment_changed
AFTER INSERT OR UPDATE OR DELETE ON payments
FOR EACH ROW EXECUTE PROCEDURE handle_payment_change();

-- Backfill: Ensure all students/leads are synced
UPDATE students s SET amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE student_id = s.id OR lead_id = s.lead_id);
UPDATE leads l SET amount_paid = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE lead_id = l.id);
-- Add salary_cycle_start_day to employees table
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_cycle_start_day integer DEFAULT 1 CHECK (salary_cycle_start_day BETWEEN 1 AND 31);

-- Backfill existing employees to start on the 1st
UPDATE employees SET salary_cycle_start_day = 1 WHERE salary_cycle_start_day IS NULL;

-- Add leave_deduction to payroll
ALTER TABLE payroll ADD COLUMN IF NOT EXISTS leave_deduction numeric(12,2) DEFAULT 0;
-- Restructure roles: admin, lead, backend
-- 1. Update existing data
UPDATE profiles SET role = 'lead' WHERE role = 'telecaller';
UPDATE profiles SET role = 'backend' WHERE role = 'finance';

-- 2. Update check constraint on profiles table
-- First, find the name of the existing constraint if possible, but we can also just drop and recreate if we knew the name.
-- Alternatively, we can use a more generic approach:
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'lead', 'backend'));

-- 3. Update existing policies that might explicitly mention old roles (optional, but good for completeness)
-- Most policies use 'admin' which is unchanged.
-- Let's check if any use 'telecaller' or 'finance'.
-- Fix RLS policies in leads table to use 'lead' instead of 'telecaller'
DROP POLICY IF EXISTS "Telecaller and admin can insert leads" ON leads;
CREATE POLICY "Lead and admin can insert leads"
  ON leads FOR INSERT
  WITH CHECK (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'lead', 'backend'))
  );

DROP POLICY IF EXISTS "Admin and telecaller can update own leads" ON leads;
CREATE POLICY "Admin and lead can update own leads"
  ON leads FOR UPDATE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR auth.uid() = assigned_to
  );

DROP POLICY IF EXISTS "Telecaller can view own leads" ON leads;
CREATE POLICY "Lead can view own leads"
  ON leads FOR SELECT
  USING (
    auth.uid() = assigned_to OR auth.uid() = created_by
  );

-- Update students table RLS for consistency (removing old 'finance' role reference)
DROP POLICY IF EXISTS "Admin and backend can view all students" ON students;
CREATE POLICY "Admin, backend and lead can view students"
  ON students FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend', 'lead'))
  );

-- Fix profiles check constraint (ensuring it's up to date)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'lead', 'backend'));
-- Fix expenses RLS: replace 'finance' role (removed) with 'backend', add 'backend' to update policy
DROP POLICY IF EXISTS "Finance and admin can view all expenses" ON expenses;
CREATE POLICY "Admin and backend can view all expenses"
  ON expenses FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

DROP POLICY IF EXISTS "Finance and admin can update expenses" ON expenses;
CREATE POLICY "Admin and backend can update expenses"
  ON expenses FOR UPDATE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

-- Also allow all authenticated users to view their own submitted expenses
CREATE POLICY "Users can view own expenses"
  ON expenses FOR SELECT
  USING (submitted_by = auth.uid());

-- Allow admin and backend to delete expenses
CREATE POLICY "Admin and backend can delete expenses"
  ON expenses FOR DELETE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );
-- Allow backend role to manage payroll (view, update status)
DROP POLICY IF EXISTS "Admins can manage payroll" ON payroll;
CREATE POLICY "Admin and backend can manage payroll"
  ON payroll FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );
-- Allow backend to view and manage employees
DROP POLICY IF EXISTS "Admins can manage employees" ON employees;
CREATE POLICY "Admin can manage employees"
  ON employees FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Backend can view employees"
  ON employees FOR SELECT
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'backend')
  );

-- Allow backend to manage attendance
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage attendance" ON attendance;
CREATE POLICY "Admin and backend can manage attendance"
  ON attendance FOR ALL
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );

CREATE POLICY "Employees can view own attendance"
  ON attendance FOR SELECT
  USING (
    exists (SELECT 1 FROM employees WHERE id = employee_id AND profile_id = auth.uid())
  );
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
-- Add 'housekeeping' as a valid role
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'lead', 'backend', 'housekeeping'));
-- Fix leads RLS: allow backend to update/transfer leads + ensure telecaller sees assigned leads

-- 1. UPDATE policy: add backend role (currently only admin + assigned user can update)
DROP POLICY IF EXISTS "Admin and telecaller can update own leads" ON leads;
DROP POLICY IF EXISTS "Admin and lead can update own leads" ON leads;
CREATE POLICY "Admin and backend can update leads"
  ON leads FOR UPDATE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
    OR auth.uid() = assigned_to
  );

-- 2. SELECT: make sure lead role users can see their assigned leads
DROP POLICY IF EXISTS "Telecaller can view own leads" ON leads;
DROP POLICY IF EXISTS "Lead can view own leads" ON leads;
CREATE POLICY "Lead can view assigned leads"
  ON leads FOR SELECT
  USING (
    auth.uid() = assigned_to
  );

-- 3. DELETE: only admin/backend can delete leads
DROP POLICY IF EXISTS "Admin can delete leads" ON leads;
DROP POLICY IF EXISTS "Admin and backend can delete leads" ON leads;
CREATE POLICY "Admin and backend can delete leads"
  ON leads FOR DELETE
  USING (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend'))
  );
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
-- Migration 043: Update leads status CHECK constraint to include new status values
-- Old: 'new','contacted','interested','counselled','application_sent','converted','cold','lost'
-- New: adds 'document_received','dnp','switch_off','not_reachable' and removes 'application_sent','cold'

-- Step 1: Migrate existing rows with old status values
UPDATE leads SET status = 'document_received' WHERE status = 'application_sent';
UPDATE leads SET status = 'dnp' WHERE status = 'cold';

-- Step 2: Drop the old CHECK constraint
ALTER TABLE leads DROP CONSTRAINT IF EXISTS leads_status_check;

-- Step 3: Recreate with new valid status values
ALTER TABLE leads
  ADD CONSTRAINT leads_status_check CHECK (status IN (
    'new',
    'contacted',
    'interested',
    'counselled',
    'document_received',
    'converted',
    'lost',
    'dnp',
    'switch_off',
    'not_reachable'
  ));
-- Add guardian phone and relationship fields to students
ALTER TABLE students ADD COLUMN IF NOT EXISTS guardian_phone TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS guardian_relationship TEXT;
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
DO $$
DECLARE
    constraint_name text;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'leads'::regclass
      AND pg_get_constraintdef(oid) LIKE '%mode%';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE leads DROP CONSTRAINT ' || quote_ident(constraint_name);
    END IF;
END $$;

ALTER TABLE leads ADD CONSTRAINT leads_mode_check CHECK (mode IN ('attending', 'non-attending', 'regular', 'distance', 'online'));

DO $$
DECLARE
    constraint_name text;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'students'::regclass
      AND pg_get_constraintdef(oid) LIKE '%mode%';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE students DROP CONSTRAINT ' || quote_ident(constraint_name);
    END IF;
END $$;

ALTER TABLE students ADD CONSTRAINT students_mode_check CHECK (mode IN ('attending', 'non-attending', 'regular', 'distance', 'online'));
-- Litigation enhancements: record_type, refund, payment tracker, dropped students

-- Add record_type (litigation vs debt)
ALTER TABLE department_litigations ADD COLUMN IF NOT EXISTS record_type TEXT NOT NULL DEFAULT 'litigation';

-- Add amount_refunded
ALTER TABLE department_litigations ADD COLUMN IF NOT EXISTS amount_refunded NUMERIC(12,2) NOT NULL DEFAULT 0;

-- Add student_id link (for dropped students auto-pulled in)
ALTER TABLE department_litigations ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES students(id) ON DELETE SET NULL;

-- Add drop_reason to students
ALTER TABLE students ADD COLUMN IF NOT EXISTS drop_reason TEXT;

-- Create litigation payments table (individual payment history)
CREATE TABLE IF NOT EXISTS litigation_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  litigation_id UUID NOT NULL REFERENCES department_litigations(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  payment_mode TEXT,
  receipt_no TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE litigation_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view litigation payments" ON litigation_payments;
DROP POLICY IF EXISTS "Admins can manage litigation payments" ON litigation_payments;

CREATE POLICY "Authenticated users can view litigation payments"
  ON litigation_payments FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage litigation payments"
  ON litigation_payments FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
-- Add metadata column to leads table to store extra information from external sources like Meta
ALTER TABLE leads ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Create an index for better performance on jsonb queries if needed later
CREATE INDEX IF NOT EXISTS idx_leads_metadata ON leads USING gin (metadata);
-- Add 'counselor' as a valid role and update leads RLS
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'lead', 'backend', 'housekeeping', 'counselor'));

DROP POLICY IF EXISTS "Admin and backend can insert leads" ON leads;
CREATE POLICY "Admin, backend, lead, and counselor can insert leads"
  ON leads FOR INSERT
  WITH CHECK (
    exists (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'backend', 'lead', 'counselor'))
  );
