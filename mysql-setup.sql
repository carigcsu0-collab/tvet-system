-- TVET Document Management System - MySQL Setup Script
-- Your database is `tdms` and the MySQL user is `tvet`.
-- Run this script while connected to the `tdms` database as `tvet` (or root).
-- If the `tdms` database does not exist yet, run the role/database creation
-- section below first while connected to the default `mysql` database:
--
-- CREATE DATABASE IF NOT EXISTS tdms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- CREATE USER IF NOT EXISTS 'tvet'@'%' IDENTIFIED BY 'tvetpass';
-- GRANT ALL PRIVILEGES ON tdms.* TO 'tvet'@'%';
-- FLUSH PRIVILEGES;
-- USE tdms;

-- ----------------------------------------------------------------------
-- 1. Tables
-- ----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS offices (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    code VARCHAR(255) DEFAULT NULL,
    coordinator_name VARCHAR(255) NOT NULL,
    coordinator_title VARCHAR(255) NOT NULL DEFAULT 'TVET Coordinator',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_offices_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    api_token VARCHAR(80) UNIQUE DEFAULT NULL,
    role VARCHAR(255) NOT NULL DEFAULT 'STAFF',
    office_id BIGINT UNSIGNED DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_office_id (office_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_types (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    prefix VARCHAR(255) NOT NULL,
    active_template_id BIGINT UNSIGNED DEFAULT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_document_types_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_templates (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_type_id BIGINT UNSIGNED NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(255) NOT NULL,
    path VARCHAR(255) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_document_templates_document_type_id (document_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_records (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(255) NOT NULL,
    year INT NOT NULL,
    document_type_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    payload JSON NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_document_records_year (year),
    INDEX idx_document_records_code (code),
    INDEX idx_document_records_document_type_id (document_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_sequences (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_type_id BIGINT UNSIGNED NOT NULL,
    year INT NOT NULL,
    next_number INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_document_sequences_type_year (document_type_id, year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `key` VARCHAR(255) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------
-- 2. Foreign keys (added after all tables exist to avoid circular issues)
-- ----------------------------------------------------------------------

ALTER TABLE users
    ADD CONSTRAINT users_office_id_fk
        FOREIGN KEY (office_id) REFERENCES offices(id) ON DELETE SET NULL;

ALTER TABLE document_types
    ADD CONSTRAINT document_types_active_template_id_fk
        FOREIGN KEY (active_template_id) REFERENCES document_templates(id) ON DELETE SET NULL;

ALTER TABLE document_templates
    ADD CONSTRAINT document_templates_document_type_id_fk
        FOREIGN KEY (document_type_id) REFERENCES document_types(id) ON DELETE CASCADE;

ALTER TABLE document_records
    ADD CONSTRAINT document_records_document_type_id_fk
        FOREIGN KEY (document_type_id) REFERENCES document_types(id) ON DELETE CASCADE,
    ADD CONSTRAINT document_records_template_id_fk
        FOREIGN KEY (template_id) REFERENCES document_templates(id) ON DELETE CASCADE,
    ADD CONSTRAINT document_records_user_id_fk
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE document_sequences
    ADD CONSTRAINT document_sequences_document_type_id_fk
        FOREIGN KEY (document_type_id) REFERENCES document_types(id) ON DELETE CASCADE;

-- ----------------------------------------------------------------------
-- 3. Sample seed data
-- ----------------------------------------------------------------------

INSERT IGNORE INTO offices (name, code, coordinator_name, coordinator_title)
VALUES ('Main TVET Office', 'MAIN', 'Juan Dela Cruz', 'TVET Coordinator');

INSERT IGNORE INTO users (name, email, password, role, office_id)
VALUES (
    'TVET Coordinator',
    'coordinator@tvet.gov',
    '$2y$12$dummyHashReplaceBeforeUseOrUseSeeder',
    'COORDINATOR',
    (SELECT id FROM offices WHERE name = 'Main TVET Office' LIMIT 1)
);

INSERT IGNORE INTO document_types (slug, name, prefix)
VALUES
    ('certificate-of-appearance', 'Certificate of Appearance', 'COA'),
    ('internal-communication', 'Internal Communication', 'IC'),
    ('external-communication', 'External Communication', 'EC'),
    ('endorsement-communication', 'Endorsement', 'TVET-END');

CREATE TABLE IF NOT EXISTS centers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(255) NOT NULL DEFAULT 'assessment',
    address VARCHAR(255) DEFAULT NULL,
    assessment_fee DECIMAL(12, 2) NOT NULL DEFAULT 0,
    training_fee DECIMAL(12, 2) NOT NULL DEFAULT 0,
    qualifications TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS assessee_trainees (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    assessment_center_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) DEFAULT NULL,
    first_name VARCHAR(255) DEFAULT NULL,
    middle_name VARCHAR(255) DEFAULT NULL,
    birthday VARCHAR(255) DEFAULT NULL,
    age INT DEFAULT NULL,
    uli VARCHAR(255) DEFAULT NULL,
    reference_number VARCHAR(255) DEFAULT NULL,
    contact_number VARCHAR(255) DEFAULT NULL,
    email VARCHAR(255) DEFAULT NULL,
    last_school_attended VARCHAR(255) DEFAULT NULL,
    qualification VARCHAR(255) DEFAULT NULL,
    competency VARCHAR(255) NOT NULL DEFAULT 'not_yet_competent',
    assessment_fee_paid TINYINT(1) NOT NULL DEFAULT 0,
    processing_fee_paid TINYINT(1) NOT NULL DEFAULT 0,
    official_receipt VARCHAR(255) DEFAULT NULL,
    receipt_date VARCHAR(255) DEFAULT NULL,
    assessor VARCHAR(255) DEFAULT NULL,
    assessment_date VARCHAR(255) DEFAULT NULL,
    registration_form TINYINT(1) NOT NULL DEFAULT 0,
    medical_certificate TINYINT(1) NOT NULL DEFAULT 0,
    brgy_indigency TINYINT(1) NOT NULL DEFAULT 0,
    brgy_clearance TINYINT(1) NOT NULL DEFAULT 0,
    tor_form137_138 TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_assessee_trainees_assessment_date (assessment_date),
    INDEX idx_assessee_trainees_assessor (assessor),
    CONSTRAINT assessee_trainees_assessment_center_id_fk
        FOREIGN KEY (assessment_center_id) REFERENCES centers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO document_templates (document_type_id, original_name, file_name, mime_type, path, is_active)
SELECT id, 'certificate_of_appearance.docx', 'certificate_of_appearance.docx',
       'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
       'templates/certificate_of_appearance.docx', 1
FROM document_types
WHERE slug = 'certificate-of-appearance';

UPDATE document_types dt
JOIN document_templates dtm ON dtm.document_type_id = dt.id
SET dt.active_template_id = dtm.id
WHERE dt.slug = 'certificate-of-appearance'
  AND dtm.path = 'templates/certificate_of_appearance.docx';
