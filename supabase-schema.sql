-- IEHP Healthcare Portal - Supabase Database Schema
-- Generated based on analysis of Next.js application structure
-- Includes all entities: Users, Appointments, Prescriptions, Messages, Lab Results, etc.

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.settings.jwt_secret" TO 'your-jwt-secret-here';

-- Create custom types
CREATE TYPE user_gender AS ENUM ('male', 'female', 'other');
CREATE TYPE appointment_type AS ENUM ('in-person', 'telehealth');
CREATE TYPE appointment_status AS ENUM ('upcoming', 'completed', 'cancelled', 'no-show');
CREATE TYPE prescription_status AS ENUM ('active', 'completed', 'expired', 'canceled', 'pending_refill');
CREATE TYPE lab_result_status AS ENUM ('completed', 'pending', 'in-progress');
CREATE TYPE message_type AS ENUM ('text', 'file', 'image', 'lab_result', 'prescription');
CREATE TYPE delivery_method AS ENUM ('pickup', 'delivery', 'mail');
CREATE TYPE urgency_level AS ENUM ('routine', 'urgent', 'emergency');
CREATE TYPE contact_method AS ENUM ('phone', 'email', 'portal');
CREATE TYPE verification_method AS ENUM ('email', 'sms');
CREATE TYPE insurance_provider AS ENUM (
  'aetna', 'anthem', 'blue-cross', 'cigna', 'humana', 
  'kaiser', 'medicare', 'medicaid', 'molina', 'united', 'iehp', 'other'
);
CREATE TYPE user_role AS ENUM ('patient', 'provider', 'admin', 'staff', 'super_admin');
CREATE TYPE provider_role AS ENUM ('doctor', 'nurse', 'physician_assistant', 'nurse_practitioner', 'specialist');
CREATE TYPE admin_role AS ENUM ('system_admin', 'billing_admin', 'facility_admin', 'staff_admin');

-- =============================================
-- CORE USER MANAGEMENT
-- =============================================

-- Users table (extends Supabase auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  date_of_birth DATE,
  gender user_gender,
  phone VARCHAR(20),
  profile_complete BOOLEAN DEFAULT FALSE,
  member_id VARCHAR(50) UNIQUE, -- IEHP member ID
  emergency_medical_info TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User addresses
CREATE TABLE user_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  street VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(50) NOT NULL,
  zip_code VARCHAR(10) NOT NULL,
  is_primary BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Emergency contacts
CREATE TABLE emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  relationship VARCHAR(50) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insurance information
CREATE TABLE insurance_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider insurance_provider NOT NULL,
  provider_name VARCHAR(100), -- For 'other' provider
  policy_number VARCHAR(100) NOT NULL,
  group_number VARCHAR(100),
  subscriber_name VARCHAR(100),
  subscriber_date_of_birth DATE,
  relationship_to_subscriber VARCHAR(50),
  is_primary BOOLEAN DEFAULT TRUE,
  card_image_url TEXT,
  effective_date DATE,
  expiration_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Medical conditions
CREATE TABLE medical_conditions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL UNIQUE,
  description TEXT,
  icd_10_code VARCHAR(10),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User medical conditions (many-to-many)
CREATE TABLE user_medical_conditions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  condition_id UUID NOT NULL REFERENCES medical_conditions(id) ON DELETE CASCADE,
  diagnosed_date DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, condition_id)
);

-- User allergies
CREATE TABLE user_allergies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  allergen VARCHAR(100) NOT NULL,
  reaction_type VARCHAR(100),
  severity VARCHAR(50), -- mild, moderate, severe
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- HEALTHCARE PROVIDERS
-- =============================================

-- Healthcare facilities/hospitals
CREATE TABLE healthcare_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  address VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(50) NOT NULL,
  zip_code VARCHAR(10) NOT NULL,
  phone VARCHAR(20),
  fax VARCHAR(20),
  email VARCHAR(255),
  website_url TEXT,
  facility_type VARCHAR(100), -- hospital, clinic, urgent_care, etc.
  parking_info TEXT,
  accessibility_info TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Departments within facilities
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES healthcare_facilities(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  floor_location VARCHAR(50),
  suite_number VARCHAR(20),
  phone VARCHAR(20),
  email VARCHAR(255),
  specialty VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Healthcare providers/doctors
CREATE TABLE healthcare_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  title VARCHAR(20), -- Dr., NP, PA, etc.
  specialty VARCHAR(100) NOT NULL,
  sub_specialty VARCHAR(100),
  license_number VARCHAR(50),
  npi_number VARCHAR(10),
  phone VARCHAR(20),
  email VARCHAR(255),
  bio TEXT,
  image_url TEXT,
  years_experience INTEGER,
  education TEXT,
  certifications TEXT,
  languages_spoken TEXT[],
  is_accepting_patients BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Provider-facility relationships (doctors can work at multiple facilities)
CREATE TABLE provider_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES healthcare_facilities(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id),
  is_primary BOOLEAN DEFAULT FALSE,
  office_phone VARCHAR(20),
  office_hours JSONB, -- Store schedule as JSON
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(provider_id, facility_id, department_id)
);

-- =============================================
-- APPOINTMENTS
-- =============================================

-- Appointments
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id),
  facility_id UUID REFERENCES healthcare_facilities(id),
  department_id UUID REFERENCES departments(id),
  appointment_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  duration_minutes INTEGER DEFAULT 30,
  type appointment_type NOT NULL,
  status appointment_status DEFAULT 'upcoming',
  reason VARCHAR(255),
  symptoms TEXT[],
  instructions TEXT,
  notes TEXT,
  provider_notes TEXT,
  check_in_time TIME,
  estimated_wait_time INTEGER, -- in minutes
  copay_amount DECIMAL(10,2),
  authorization_number VARCHAR(100),
  confirmation_number VARCHAR(50) UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Telehealth session details
CREATE TABLE telehealth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  platform VARCHAR(100) DEFAULT 'IEHP Secure Video',
  join_link TEXT,
  test_link TEXT,
  meeting_id VARCHAR(100),
  requirements TEXT[],
  technical_requirements TEXT,
  session_started_at TIMESTAMPTZ,
  session_ended_at TIMESTAMPTZ,
  connection_quality VARCHAR(20), -- excellent, good, fair, poor
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Appointment preparation checklist
CREATE TABLE appointment_preparations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  preparation_item TEXT NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- PRESCRIPTIONS & MEDICATIONS
-- =============================================

-- Pharmacies
CREATE TABLE pharmacies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  chain_name VARCHAR(100), -- CVS, Walgreens, IEHP, etc.
  address VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(50) NOT NULL,
  zip_code VARCHAR(10) NOT NULL,
  phone VARCHAR(20),
  fax VARCHAR(20),
  email VARCHAR(255),
  hours_of_operation JSONB,
  services TEXT[], -- delivery, 24hr, drive-thru, etc.
  is_preferred BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Medications database
CREATE TABLE medications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  generic_name VARCHAR(200),
  brand_name VARCHAR(200),
  drug_class VARCHAR(100),
  dosage_forms TEXT[], -- tablet, capsule, liquid, etc.
  strength_options TEXT[], -- 10mg, 20mg, etc.
  ndc_number VARCHAR(50),
  manufacturer VARCHAR(100),
  is_controlled_substance BOOLEAN DEFAULT FALSE,
  controlled_substance_schedule INTEGER, -- I, II, III, IV, V
  common_side_effects TEXT[],
  serious_side_effects TEXT[],
  contraindications TEXT[],
  drug_interactions TEXT[],
  food_interactions TEXT[],
  pregnancy_category VARCHAR(10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prescriptions
CREATE TABLE prescriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id),
  medication_id UUID REFERENCES medications(id),
  medication_name VARCHAR(200) NOT NULL, -- Store as text for flexibility
  dosage VARCHAR(100) NOT NULL,
  route VARCHAR(50) NOT NULL, -- oral, topical, injection, etc.
  frequency VARCHAR(100) NOT NULL,
  quantity_prescribed INTEGER NOT NULL,
  refills_remaining INTEGER DEFAULT 0,
  total_refills_authorized INTEGER DEFAULT 0,
  prescribed_date DATE NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  instructions TEXT,
  status prescription_status DEFAULT 'active',
  is_controlled_substance BOOLEAN DEFAULT FALSE,
  ndc_number VARCHAR(50),
  pharmacy_id UUID REFERENCES pharmacies(id),
  prescriber_notes TEXT,
  patient_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prescription refill requests
CREATE TABLE prescription_refill_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_quantity INTEGER NOT NULL,
  delivery_method delivery_method DEFAULT 'pickup',
  preferred_pharmacy_id UUID REFERENCES pharmacies(id),
  urgency urgency_level DEFAULT 'routine',
  contact_method contact_method DEFAULT 'portal',
  contact_info VARCHAR(255),
  special_instructions TEXT,
  request_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, denied, filled
  processed_by UUID REFERENCES healthcare_providers(id),
  processed_at TIMESTAMPTZ,
  processing_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prescription requests (new prescriptions)
CREATE TABLE prescription_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES healthcare_providers(id),
  medication_requested VARCHAR(200) NOT NULL,
  condition_being_treated VARCHAR(200),
  symptoms_description TEXT,
  current_medications TEXT,
  allergies TEXT,
  doctor_preference VARCHAR(100),
  pharmacy_preference UUID REFERENCES pharmacies(id),
  urgency urgency_level DEFAULT 'routine',
  request_reason TEXT,
  medical_history_relevant TEXT,
  request_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, denied, prescribed
  processed_by UUID REFERENCES healthcare_providers(id),
  processed_at TIMESTAMPTZ,
  processing_notes TEXT,
  resulting_prescription_id UUID REFERENCES prescriptions(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- LAB RESULTS
-- =============================================

-- Lab tests catalog
CREATE TABLE lab_tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  test_code VARCHAR(50) UNIQUE,
  category VARCHAR(100), -- blood, urine, imaging, etc.
  description TEXT,
  normal_range_text TEXT,
  preparation_instructions TEXT,
  fasting_required BOOLEAN DEFAULT FALSE,
  estimated_turnaround_time INTEGER, -- in hours
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lab results
CREATE TABLE lab_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id),
  test_id UUID REFERENCES lab_tests(id),
  test_name VARCHAR(200) NOT NULL,
  ordered_date DATE NOT NULL,
  collected_date DATE,
  completed_date DATE,
  status lab_result_status DEFAULT 'pending',
  result_value VARCHAR(100),
  result_unit VARCHAR(50),
  reference_range VARCHAR(100),
  is_abnormal BOOLEAN DEFAULT FALSE,
  abnormal_flag VARCHAR(20), -- HIGH, LOW, CRITICAL
  provider_notes TEXT,
  interpretation TEXT,
  follow_up_required BOOLEAN DEFAULT FALSE,
  follow_up_instructions TEXT,
  report_url TEXT, -- Link to full PDF report
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- MESSAGING SYSTEM
-- =============================================

-- Conversations
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES healthcare_providers(id),
  subject VARCHAR(255),
  is_archived BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL, -- Could be user_id or provider_id
  sender_type VARCHAR(20) NOT NULL, -- 'user' or 'provider'
  content TEXT NOT NULL,
  message_type message_type DEFAULT 'text',
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent
  related_appointment_id UUID REFERENCES appointments(id),
  related_prescription_id UUID REFERENCES prescriptions(id),
  related_lab_result_id UUID REFERENCES lab_results(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Message attachments
CREATE TABLE message_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  file_size INTEGER,
  file_type VARCHAR(100),
  file_url TEXT NOT NULL,
  is_image BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- BILLING & PAYMENTS
-- =============================================

-- Billing accounts
CREATE TABLE billing_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_number VARCHAR(50) UNIQUE,
  outstanding_balance DECIMAL(10,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bills/invoices
CREATE TABLE bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  billing_account_id UUID NOT NULL REFERENCES billing_accounts(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES appointments(id),
  bill_number VARCHAR(50) UNIQUE,
  bill_date DATE NOT NULL,
  due_date DATE NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) DEFAULT 0.00,
  total_amount DECIMAL(10,2) NOT NULL,
  amount_paid DECIMAL(10,2) DEFAULT 0.00,
  balance_due DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending', -- pending, paid, overdue, disputed
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bill line items
CREATE TABLE bill_line_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  service_description VARCHAR(255) NOT NULL,
  service_code VARCHAR(50), -- CPT code, etc.
  quantity INTEGER DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- SYSTEM TABLES
-- =============================================

-- Audit log for sensitive operations
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(100),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- System notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL, -- appointment, prescription, lab_result, billing, etc.
  priority VARCHAR(20) DEFAULT 'normal',
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  action_url TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User preferences
CREATE TABLE user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email_notifications BOOLEAN DEFAULT TRUE,
  sms_notifications BOOLEAN DEFAULT FALSE,
  push_notifications BOOLEAN DEFAULT TRUE,
  appointment_reminders BOOLEAN DEFAULT TRUE,
  prescription_reminders BOOLEAN DEFAULT TRUE,
  lab_result_notifications BOOLEAN DEFAULT TRUE,
  marketing_communications BOOLEAN DEFAULT FALSE,
  preferred_communication_method contact_method DEFAULT 'email',
  timezone VARCHAR(50) DEFAULT 'America/Los_Angeles',
  language VARCHAR(10) DEFAULT 'en',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- =============================================
-- ROLE MANAGEMENT & AUTHENTICATION
-- =============================================

-- User roles (extends the base users table)
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'patient',
  is_active BOOLEAN DEFAULT TRUE,
  assigned_by UUID REFERENCES users(id),
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- Provider profiles (for healthcare providers)
CREATE TABLE provider_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  provider_role provider_role NOT NULL DEFAULT 'doctor',
  can_prescribe BOOLEAN DEFAULT FALSE,
  can_order_labs BOOLEAN DEFAULT FALSE,
  can_view_all_patients BOOLEAN DEFAULT FALSE,
  supervisor_id UUID REFERENCES provider_profiles(id),
  department_access UUID[] DEFAULT '{}', -- Array of department IDs they can access
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Admin profiles (for administrative users)
CREATE TABLE admin_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  admin_role admin_role NOT NULL DEFAULT 'staff_admin',
  facility_access UUID[] DEFAULT '{}', -- Array of facility IDs they can manage
  permissions JSONB DEFAULT '{}', -- Flexible permissions object
  supervisor_id UUID REFERENCES admin_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Provider-patient assignments (for care teams)
CREATE TABLE provider_patient_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assignment_type VARCHAR(50) NOT NULL, -- primary, consulting, referring, etc.
  is_active BOOLEAN DEFAULT TRUE,
  assigned_by UUID REFERENCES users(id),
  assigned_date DATE DEFAULT CURRENT_DATE,
  end_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(provider_id, patient_id, assignment_type)
);

-- =============================================
-- PROVIDER WORKFLOW TABLES
-- =============================================

-- Provider schedules
CREATE TABLE provider_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES healthcare_facilities(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0 = Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  break_start_time TIME,
  break_end_time TIME,
  max_appointments_per_hour INTEGER DEFAULT 2,
  appointment_duration_minutes INTEGER DEFAULT 30,
  effective_date DATE DEFAULT CURRENT_DATE,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Provider time off/unavailability
CREATE TABLE provider_unavailability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  reason VARCHAR(100), -- vacation, sick, conference, etc.
  is_recurring BOOLEAN DEFAULT FALSE,
  recurrence_pattern JSONB, -- For recurring unavailability
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Provider tasks/workflows
CREATE TABLE provider_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES healthcare_providers(id) ON DELETE CASCADE,
  task_type VARCHAR(100) NOT NULL, -- review_lab, approve_prescription, follow_up, etc.
  title VARCHAR(255) NOT NULL,
  description TEXT,
  priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent
  status VARCHAR(50) DEFAULT 'pending', -- pending, in_progress, completed, cancelled
  related_patient_id UUID REFERENCES users(id),
  related_appointment_id UUID REFERENCES appointments(id),
  related_prescription_id UUID REFERENCES prescriptions(id),
  related_lab_result_id UUID REFERENCES lab_results(id),
  due_date DATE,
  completed_at TIMESTAMPTZ,
  completed_by UUID REFERENCES users(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ADMIN WORKFLOW TABLES
-- =============================================

-- System settings
CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  setting_type VARCHAR(50) NOT NULL, -- string, number, boolean, json, etc.
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE, -- Whether patients can see this setting
  modified_by UUID REFERENCES users(id),
  modified_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Facility schedules and hours
CREATE TABLE facility_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES healthcare_facilities(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  open_time TIME,
  close_time TIME,
  is_closed BOOLEAN DEFAULT FALSE,
  special_hours_date DATE, -- For holiday hours, etc.
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insurance verification tracking
CREATE TABLE insurance_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID NOT NULL REFERENCES insurance_policies(id) ON DELETE CASCADE,
  verification_date DATE NOT NULL,
  verified_by UUID REFERENCES users(id),
  verification_status VARCHAR(50) NOT NULL, -- verified, pending, denied, expired
  coverage_details JSONB,
  copay_amount DECIMAL(10,2),
  deductible_amount DECIMAL(10,2),
  coverage_percentage DECIMAL(5,2),
  effective_date DATE,
  expiration_date DATE,
  verification_notes TEXT,
  next_verification_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Patient registration queue (for staff to review)
CREATE TABLE patient_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  registration_data JSONB NOT NULL, -- Store the complete signup form data
  registration_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected, needs_review
  assigned_to UUID REFERENCES users(id), -- Staff member reviewing
  review_notes TEXT,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejected_reason TEXT,
  priority VARCHAR(20) DEFAULT 'normal',
  source VARCHAR(50), -- online, phone, walk-in, etc.
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ENHANCED SECURITY & AUDIT
-- =============================================

-- Enhanced audit log with admin context
CREATE TABLE admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  target_user_id UUID REFERENCES users(id), -- Patient being affected
  table_name VARCHAR(100),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  reason TEXT, -- Why the admin made this change
  ip_address INET,
  user_agent TEXT,
  session_id VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Login sessions for enhanced security
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token VARCHAR(255) UNIQUE NOT NULL,
  ip_address INET,
  user_agent TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  expires_at TIMESTAMPTZ NOT NULL,
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- REPORTING & ANALYTICS TABLES
-- =============================================

-- Report definitions (for admin dashboards)
CREATE TABLE report_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  report_type VARCHAR(50) NOT NULL, -- patient_volume, billing, appointments, etc.
  sql_query TEXT NOT NULL,
  parameters JSONB DEFAULT '{}',
  chart_config JSONB DEFAULT '{}',
  access_roles user_role[] DEFAULT ARRAY['admin'],
  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report executions and caching
CREATE TABLE report_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES report_definitions(id) ON DELETE CASCADE,
  executed_by UUID NOT NULL REFERENCES users(id),
  parameters_used JSONB DEFAULT '{}',
  execution_time_ms INTEGER,
  result_data JSONB,
  status VARCHAR(50) DEFAULT 'completed', -- pending, completed, failed
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ADDITIONAL INDEXES FOR ADMIN/PROVIDER WORKFLOWS
-- =============================================

-- Role and access indexes
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role);
CREATE INDEX idx_provider_profiles_user_id ON provider_profiles(user_id);
CREATE INDEX idx_provider_profiles_provider_id ON provider_profiles(provider_id);
CREATE INDEX idx_admin_profiles_user_id ON admin_profiles(user_id);
CREATE INDEX idx_provider_patient_assignments_provider_id ON provider_patient_assignments(provider_id);
CREATE INDEX idx_provider_patient_assignments_patient_id ON provider_patient_assignments(patient_id);

-- Provider workflow indexes
CREATE INDEX idx_provider_schedules_provider_id ON provider_schedules(provider_id);
CREATE INDEX idx_provider_schedules_facility_day ON provider_schedules(facility_id, day_of_week);
CREATE INDEX idx_provider_unavailability_provider_id ON provider_unavailability(provider_id);
CREATE INDEX idx_provider_unavailability_dates ON provider_unavailability(start_date, end_date);
CREATE INDEX idx_provider_tasks_provider_id ON provider_tasks(provider_id);
CREATE INDEX idx_provider_tasks_status ON provider_tasks(status);
CREATE INDEX idx_provider_tasks_due_date ON provider_tasks(due_date);

-- Admin workflow indexes
CREATE INDEX idx_patient_registrations_status ON patient_registrations(registration_status);
CREATE INDEX idx_patient_registrations_assigned_to ON patient_registrations(assigned_to);
CREATE INDEX idx_insurance_verifications_policy_id ON insurance_verifications(policy_id);
CREATE INDEX idx_insurance_verifications_status ON insurance_verifications(verification_status);

-- Session and security indexes
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active, expires_at);
CREATE INDEX idx_admin_audit_logs_admin_user ON admin_audit_logs(admin_user_id);
CREATE INDEX idx_admin_audit_logs_target_user ON admin_audit_logs(target_user_id);
CREATE INDEX idx_admin_audit_logs_action ON admin_audit_logs(action);

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_medical_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_allergies ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE telehealth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_refill_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_patient_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view own addresses" ON user_addresses FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own emergency contacts" ON emergency_contacts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own insurance" ON insurance_policies FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own medical conditions" ON user_medical_conditions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own allergies" ON user_allergies FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own appointments" ON appointments FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own prescriptions" ON prescriptions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own prescription requests" ON prescription_refill_requests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own lab results" ON lab_results FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own conversations" ON conversations FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own billing" ON billing_accounts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own notifications" ON notifications FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own preferences" ON user_preferences FOR ALL USING (auth.uid() = user_id);

-- Messages policy (users can see messages in their conversations)
CREATE POLICY "Users can view messages in their conversations" ON messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversations 
    WHERE conversations.id = messages.conversation_id 
    AND conversations.user_id = auth.uid()
  )
);

-- Provider access policies
CREATE POLICY "Providers can view assigned patients" ON users FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM provider_patient_assignments ppa
    JOIN provider_profiles pp ON pp.provider_id = ppa.provider_id
    WHERE ppa.patient_id = users.id 
    AND pp.user_id = auth.uid()
    AND ppa.is_active = true
  )
);

CREATE POLICY "Providers can view patient appointments" ON appointments FOR SELECT USING (
  provider_id IN (
    SELECT pp.provider_id FROM provider_profiles pp WHERE pp.user_id = auth.uid()
  )
  OR user_id = auth.uid()
);

CREATE POLICY "Providers can view patient prescriptions" ON prescriptions FOR SELECT USING (
  provider_id IN (
    SELECT pp.provider_id FROM provider_profiles pp WHERE pp.user_id = auth.uid()
  )
  OR user_id = auth.uid()
);

CREATE POLICY "Providers can view patient lab results" ON lab_results FOR SELECT USING (
  provider_id IN (
    SELECT pp.provider_id FROM provider_profiles pp WHERE pp.user_id = auth.uid()
  )
  OR user_id = auth.uid()
);

-- Admin access policies
CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM user_roles ur 
    WHERE ur.user_id = auth.uid() 
    AND ur.role IN ('admin', 'super_admin', 'staff')
    AND ur.is_active = true
  )
);

CREATE POLICY "Admins can view all appointments" ON appointments FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM user_roles ur 
    WHERE ur.user_id = auth.uid() 
    AND ur.role IN ('admin', 'super_admin', 'staff')
    AND ur.is_active = true
  )
);

-- Provider task policies
CREATE POLICY "Providers can view own tasks" ON provider_tasks FOR ALL USING (
  provider_id IN (
    SELECT pp.provider_id FROM provider_profiles pp WHERE pp.user_id = auth.uid()
  )
);

-- Patient registration policies
CREATE POLICY "Staff can view patient registrations" ON patient_registrations FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_roles ur 
    WHERE ur.user_id = auth.uid() 
    AND ur.role IN ('admin', 'super_admin', 'staff')
    AND ur.is_active = true
  )
);

-- Public read access for reference data
CREATE POLICY "Anyone can read medical conditions" ON medical_conditions FOR SELECT USING (true);
CREATE POLICY "Anyone can read healthcare facilities" ON healthcare_facilities FOR SELECT USING (true);
CREATE POLICY "Anyone can read departments" ON departments FOR SELECT USING (true);
CREATE POLICY "Anyone can read healthcare providers" ON healthcare_providers FOR SELECT USING (true);
CREATE POLICY "Anyone can read pharmacies" ON pharmacies FOR SELECT USING (true);
CREATE POLICY "Anyone can read medications" ON medications FOR SELECT USING (true);
CREATE POLICY "Anyone can read lab tests" ON lab_tests FOR SELECT USING (true);

-- =============================================
-- FUNCTIONS & TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_insurance_policies_updated_at BEFORE UPDATE ON insurance_policies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_healthcare_facilities_updated_at BEFORE UPDATE ON healthcare_facilities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_healthcare_providers_updated_at BEFORE UPDATE ON healthcare_providers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_prescriptions_updated_at BEFORE UPDATE ON prescriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_lab_results_updated_at BEFORE UPDATE ON lab_results FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_billing_accounts_updated_at BEFORE UPDATE ON billing_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bills_updated_at BEFORE UPDATE ON bills FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update conversation last_message_at when new message is added
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations 
    SET last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_conversation_last_message_trigger 
    AFTER INSERT ON messages 
    FOR EACH ROW 
    EXECUTE FUNCTION update_conversation_last_message();

-- Function to calculate bill balance
CREATE OR REPLACE FUNCTION calculate_bill_balance()
RETURNS TRIGGER AS $$
BEGIN
    NEW.balance_due = NEW.total_amount - NEW.amount_paid;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_bill_balance_trigger 
    BEFORE INSERT OR UPDATE ON bills 
    FOR EACH ROW 
    EXECUTE FUNCTION calculate_bill_balance();

-- =============================================
-- INITIAL DATA SEEDING
-- =============================================

-- Insert sample medical conditions
INSERT INTO medical_conditions (name, description, icd_10_code) VALUES
('Hypertension', 'High blood pressure', 'I10'),
('Type 2 Diabetes', 'Diabetes mellitus type 2', 'E11'),
('Hyperlipidemia', 'High cholesterol', 'E78.5'),
('Asthma', 'Chronic respiratory condition', 'J45'),
('Depression', 'Major depressive disorder', 'F32'),
('Anxiety', 'Generalized anxiety disorder', 'F41.1'),
('Arthritis', 'Joint inflammation', 'M19.9'),
('Migraine', 'Chronic headache disorder', 'G43');

-- Insert sample healthcare facilities
INSERT INTO healthcare_facilities (name, address, city, state, zip_code, phone, facility_type) VALUES
('IEHP Medical Center - Riverside', '10800 Magnolia Ave', 'Riverside', 'CA', '92505', '(951) 788-3000', 'hospital'),
('IEHP Health Center - San Bernardino', '303 E Vanderbilt Way', 'San Bernardino', 'CA', '92408', '(909) 890-2000', 'clinic'),
('IEHP Urgent Care - Fontana', '17051 Sierra Lakes Pkwy', 'Fontana', 'CA', '92336', '(909) 854-5000', 'urgent_care');

-- Insert sample departments
INSERT INTO departments (facility_id, name, floor_location, phone, specialty) VALUES
((SELECT id FROM healthcare_facilities WHERE name = 'IEHP Medical Center - Riverside'), 'Cardiology Department', '3rd Floor', '(951) 788-3100', 'Cardiology'),
((SELECT id FROM healthcare_facilities WHERE name = 'IEHP Health Center - San Bernardino'), 'Primary Care', '1st Floor, Suite 101', '(909) 890-2100', 'Family Medicine'),
((SELECT id FROM healthcare_facilities WHERE name = 'IEHP Medical Center - Riverside'), 'Emergency Department', 'Ground Floor', '(951) 788-3911', 'Emergency Medicine');

-- Insert sample healthcare providers
INSERT INTO healthcare_providers (first_name, last_name, title, specialty, phone, email, bio) VALUES
('Sarah', 'Wilson', 'Dr.', 'Cardiology', '(555) 123-4567', 'sarah.wilson@iehp.com', 'Board-certified cardiologist with 15 years of experience.'),
('Mike', 'Johnson', 'Dr.', 'Primary Care', '(555) 987-6543', 'mike.johnson@iehp.com', 'Family medicine physician focused on preventive care.'),
('Emily', 'Chen', 'Dr.', 'Dermatology', '(555) 555-0123', 'emily.chen@iehp.com', 'Dermatologist specializing in medical and cosmetic dermatology.');

-- Insert sample pharmacies
INSERT INTO pharmacies (name, chain_name, address, city, state, zip_code, phone) VALUES
('IEHP Pharmacy - Riverside', 'IEHP', '10800 Magnolia Ave', 'Riverside', 'CA', '92505', '(951) 788-3000'),
('IEHP Pharmacy - San Bernardino', 'IEHP', '303 E Vanderbilt Way', 'San Bernardino', 'CA', '92408', '(909) 890-2000'),
('CVS Pharmacy #1234', 'CVS', '123 Main St', 'Riverside', 'CA', '92501', '(951) 555-0123'),
('Walgreens #5678', 'Walgreens', '456 Oak Street', 'Riverside', 'CA', '92502', '(951) 555-0456');

-- Insert sample medications
INSERT INTO medications (name, generic_name, brand_name, drug_class, dosage_forms, strength_options, is_controlled_substance) VALUES
('Atorvastatin', 'Atorvastatin', 'Lipitor', 'Statin', ARRAY['tablet'], ARRAY['10mg', '20mg', '40mg', '80mg'], false),
('Lisinopril', 'Lisinopril', 'Prinivil', 'ACE Inhibitor', ARRAY['tablet'], ARRAY['5mg', '10mg', '20mg', '40mg'], false),
('Metformin', 'Metformin', 'Glucophage', 'Biguanide', ARRAY['tablet', 'extended-release tablet'], ARRAY['500mg', '850mg', '1000mg'], false),
('Amoxicillin', 'Amoxicillin', 'Amoxil', 'Penicillin Antibiotic', ARRAY['capsule', 'tablet', 'suspension'], ARRAY['250mg', '500mg', '875mg'], false),
('Hydrocodone/Acetaminophen', 'Hydrocodone/Acetaminophen', 'Vicodin', 'Opioid Analgesic', ARRAY['tablet'], ARRAY['5/325mg', '7.5/325mg', '10/325mg'], true);

-- Insert sample lab tests
INSERT INTO lab_tests (name, test_code, category, description, fasting_required) VALUES
('Complete Blood Count', 'CBC', 'Blood', 'Comprehensive blood cell analysis', false),
('Lipid Panel', 'LIPID', 'Blood', 'Cholesterol and triglyceride levels', true),
('Thyroid Function Test', 'TSH', 'Blood', 'Thyroid stimulating hormone levels', false),
('Vitamin D Level', 'VIT_D', 'Blood', '25-hydroxyvitamin D levels', false),
('HbA1c', 'A1C', 'Blood', 'Average blood glucose over 2-3 months', false);

-- Create comment on schema
COMMENT ON SCHEMA public IS 'IEHP Healthcare Portal Database Schema - Comprehensive healthcare management system supporting patients, providers, appointments, prescriptions, lab results, messaging, and billing.';
