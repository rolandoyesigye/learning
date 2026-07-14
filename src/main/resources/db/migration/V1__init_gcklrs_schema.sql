-- Ensure PostGIS is enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create Schema
CREATE SCHEMA IF NOT EXISTS nlis_staging;

-- Create Enums
CREATE TYPE user_role AS ENUM ('LC1_CHAIRPERSON', 'PARISH_CHIEF', 'SUBCOUNTY_OFFICIAL', 'MLHUD_ADMIN', 'READ_ONLY_VERIFIER');
CREATE TYPE admin_level AS ENUM ('DISTRICT', 'SUBCOUNTY', 'PARISH', 'LC1');
CREATE TYPE txn_type AS ENUM ('SALE', 'GIFT_INHERITANCE', 'KIBANJA_GRANT', 'KIBANJA_TRANSFER', 'BOUNDARY_DEMARCATION');
CREATE TYPE reg_status AS ENUM ('DRAFT', 'PENDING_PARISH', 'PENDING_SUBCOUNTY', 'APPROVED', 'REJECTED', 'CONFLICT_HOLD');
CREATE TYPE party_role AS ENUM ('SELLER', 'BUYER', 'WITNESS_1', 'WITNESS_2');

-- 2.2 administrative_units
CREATE TABLE administrative_units (
    unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_name VARCHAR(200) NOT NULL,
    unit_type admin_level NOT NULL,
    parent_unit_id UUID REFERENCES administrative_units(unit_id),
    district_name VARCHAR(100) NOT NULL,
    boundary_polygon GEOMETRY(POLYGON,4326),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_admin_units_gist ON administrative_units USING GiST(boundary_polygon);
CREATE INDEX idx_admin_units_parent ON administrative_units(parent_unit_id);

-- 2.1 users
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(200) NOT NULL,
    nin VARCHAR(14) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    admin_unit_id UUID NOT NULL REFERENCES administrative_units(unit_id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login_at TIMESTAMPTZ,
    failed_login_count INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    device_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by_user_id UUID REFERENCES users(user_id)
);
CREATE UNIQUE INDEX idx_users_nin ON users(nin);
CREATE INDEX idx_users_admin_unit ON users(admin_unit_id);

-- 2.3 land_registrations
CREATE TABLE land_registrations (
    registration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number VARCHAR(50) UNIQUE NOT NULL,
    transaction_type txn_type NOT NULL,
    transaction_date DATE NOT NULL,
    status reg_status NOT NULL DEFAULT 'DRAFT',
    lc1_unit_id UUID NOT NULL REFERENCES administrative_units(unit_id),
    parish_unit_id UUID NOT NULL REFERENCES administrative_units(unit_id),
    subcounty_unit_id UUID NOT NULL REFERENCES administrative_units(unit_id),
    parcel_description TEXT,
    land_use_type VARCHAR(50),
    parcel_area_sqm NUMERIC(14,4),
    parcel_area_acres NUMERIC(14,4),
    is_cross_boundary BOOLEAN NOT NULL DEFAULT false,
    submitted_by_user_id UUID NOT NULL REFERENCES users(user_id),
    parish_approved_by UUID REFERENCES users(user_id),
    parish_approved_at TIMESTAMPTZ,
    subcounty_approved_by UUID REFERENCES users(user_id),
    subcounty_approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    offline_queued BOOLEAN NOT NULL DEFAULT false,
    device_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    field_created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by_user_id UUID NOT NULL REFERENCES users(user_id)
);
CREATE UNIQUE INDEX idx_registrations_refnum ON land_registrations(reference_number);
CREATE INDEX idx_registrations_status ON land_registrations(status);
CREATE INDEX idx_registrations_lc1 ON land_registrations(lc1_unit_id);

-- 2.4 parcel_polygons
CREATE TABLE parcel_polygons (
    polygon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID UNIQUE NOT NULL REFERENCES land_registrations(registration_id),
    boundary_polygon GEOMETRY(POLYGON,4326) NOT NULL,
    centroid_lat NUMERIC(11,8) NOT NULL,
    centroid_lng NUMERIC(11,8) NOT NULL,
    coordinate_count INTEGER NOT NULL,
    gps_accuracy_metres NUMERIC(6,2),
    capture_method VARCHAR(20) NOT NULL DEFAULT 'GPS_WALK',
    is_server_validated BOOLEAN NOT NULL DEFAULT false,
    captured_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by_user_id UUID NOT NULL REFERENCES users(user_id)
);
CREATE INDEX idx_parcel_polygons_gist ON parcel_polygons USING GiST(boundary_polygon);
CREATE UNIQUE INDEX idx_parcel_polygons_reg ON parcel_polygons(registration_id);

-- 2.6 nin_verifications
CREATE TABLE nin_verifications (
    verification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nin_hash VARCHAR(64) NOT NULL,
    verification_mode VARCHAR(10) NOT NULL,
    verification_result VARCHAR(15) NOT NULL,
    nira_response_code VARCHAR(10),
    name_match BOOLEAN,
    photo_match_flag BOOLEAN,
    hash_table_version VARCHAR(20),
    response_time_ms INTEGER,
    verified_by_user_id UUID NOT NULL REFERENCES users(user_id),
    device_id VARCHAR(100),
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_nin_verif_hash ON nin_verifications(nin_hash);
CREATE INDEX idx_nin_verif_user ON nin_verifications(verified_by_user_id);

-- 2.5 transaction_parties
CREATE TABLE transaction_parties (
    party_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID NOT NULL REFERENCES land_registrations(registration_id),
    party_role party_role NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    nin VARCHAR(14) NOT NULL,
    nin_hash VARCHAR(64) NOT NULL,
    phone_number VARCHAR(20),
    physical_address TEXT,
    gender CHAR(1),
    is_deceased BOOLEAN NOT NULL DEFAULT false,
    nin_verified BOOLEAN NOT NULL DEFAULT false,
    nin_verification_id UUID REFERENCES nin_verifications(verification_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by_user_id UUID NOT NULL REFERENCES users(user_id)
);
CREATE INDEX idx_parties_registration ON transaction_parties(registration_id);
CREATE INDEX idx_parties_nin ON transaction_parties(nin);

-- 2.7 supporting_documents
CREATE TABLE supporting_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID NOT NULL REFERENCES land_registrations(registration_id),
    document_type VARCHAR(50) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    storage_path TEXT NOT NULL,
    sha256_hash VARCHAR(64) NOT NULL,
    uploaded_by_user_id UUID NOT NULL REFERENCES users(user_id),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_offline_queued BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX idx_docs_registration ON supporting_documents(registration_id);

-- 2.8 approval_workflow
CREATE TABLE approval_workflow (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID NOT NULL REFERENCES land_registrations(registration_id),
    step_number INTEGER NOT NULL,
    action VARCHAR(30) NOT NULL,
    actor_user_id UUID NOT NULL REFERENCES users(user_id),
    actor_role user_role NOT NULL,
    comments TEXT,
    from_status reg_status NOT NULL,
    to_status reg_status NOT NULL,
    actioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_workflow_registration ON approval_workflow(registration_id);
CREATE INDEX idx_workflow_actor ON approval_workflow(actor_user_id);

-- 2.9 fraud_detection_log
CREATE TABLE fraud_detection_log (
    check_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID NOT NULL REFERENCES land_registrations(registration_id),
    check_mode VARCHAR(10) NOT NULL,
    result VARCHAR(15) NOT NULL,
    overlapping_registration_ids UUID[],
    overlap_area_sqm NUMERIC(14,4),
    query_execution_ms INTEGER,
    checked_by_user_id UUID NOT NULL REFERENCES users(user_id),
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_fraud_log_registration ON fraud_detection_log(registration_id);
CREATE INDEX idx_fraud_log_result ON fraud_detection_log(result);

-- 2.10 land_certificates
CREATE TABLE land_certificates (
    certificate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id UUID UNIQUE NOT NULL REFERENCES land_registrations(registration_id),
    certificate_number VARCHAR(60) UNIQUE NOT NULL,
    certificate_hash VARCHAR(64) NOT NULL,
    status VARCHAR(15) NOT NULL DEFAULT 'ACTIVE',
    pdf_storage_path TEXT,
    issued_by_user_id UUID NOT NULL REFERENCES users(user_id),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_by_user_id UUID REFERENCES users(user_id),
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT
);
CREATE UNIQUE INDEX idx_certificates_number ON land_certificates(certificate_number);
CREATE UNIQUE INDEX idx_certificates_registration ON land_certificates(registration_id);
CREATE INDEX idx_certificates_status ON land_certificates(status);

-- 2.11 audit_log
CREATE TABLE audit_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    actor_user_id UUID REFERENCES users(user_id),
    actor_role user_role,
    target_table VARCHAR(60) NOT NULL,
    target_record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    device_id VARCHAR(100),
    event_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_actor ON audit_log(actor_user_id);
CREATE INDEX idx_audit_target ON audit_log(target_record_id);
CREATE INDEX idx_audit_event_at ON audit_log(event_at DESC);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_insert_only ON audit_log FOR INSERT WITH CHECK (true);

-- 2.13 offline_sync_queue
CREATE TABLE offline_sync_queue (
    sync_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(100) NOT NULL,
    batch_status VARCHAR(20) NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.14 nlis_staging.nlis_export_records
CREATE TABLE nlis_staging.nlis_export_records (
    export_record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gcklrs_registration_id UUID UNIQUE REFERENCES public.land_registrations(registration_id),
    gcklrs_certificate_number VARCHAR(60) NOT NULL,
    nlis_parcel_id VARCHAR(50),
    export_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    seller_nin VARCHAR(14) NOT NULL,
    buyer_nin VARCHAR(14) NOT NULL,
    boundary_polygon_wkt TEXT NOT NULL,
    district VARCHAR(100) NOT NULL,
    transaction_type_nlis VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL,
    export_batch_id UUID NOT NULL,
    exported_at TIMESTAMPTZ NOT NULL,
    nlis_confirmed_at TIMESTAMPTZ
);
