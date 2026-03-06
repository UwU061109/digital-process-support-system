-- Digital Process Support – Internal Systems
-- Database Schema (MySQL / MariaDB compatible)
-- Author: Panagiotis Zois, MSc ICT | Business Analyst 

-- =========================
-- 1) Create Database
-- =========================
CREATE DATABASE IF NOT EXISTS digital_process_support
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE digital_process_support;

-- =========================
-- 2) Drop tables (safe re-run)
-- =========================
DROP TABLE IF EXISTS approvals;
DROP TABLE IF EXISTS requests;
DROP TABLE IF EXISTS statuses;
DROP TABLE IF EXISTS users;

-- =========================
-- 3) Users
-- =========================
CREATE TABLE users (
  user_id      INT AUTO_INCREMENT PRIMARY KEY,
  full_name    VARCHAR(120) NOT NULL,
  email        VARCHAR(160) NOT NULL UNIQUE,
  role         ENUM('STUDENT','SECRETARIAT','ADMIN') NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================
-- 4) Statuses
-- =========================
CREATE TABLE statuses (
  status_id    INT AUTO_INCREMENT PRIMARY KEY,
  status_name  VARCHAR(40) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- =========================
-- 5) Requests
-- =========================
CREATE TABLE requests (
  request_id       INT AUTO_INCREMENT PRIMARY KEY,
  user_id          INT NOT NULL,
  request_type     ENUM('CERTIFICATE','ABSENCE','GRADE_APPEAL','OTHER') NOT NULL,
  description      TEXT NULL,
  submission_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_id        INT NOT NULL,

  CONSTRAINT fk_requests_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_requests_status
    FOREIGN KEY (status_id) REFERENCES statuses(status_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  INDEX idx_requests_user (user_id),
  INDEX idx_requests_status (status_id),
  INDEX idx_requests_submission_date (submission_date)
) ENGINE=InnoDB;

-- =========================
-- 6) Approvals (Audit Trail)
-- =========================
CREATE TABLE approvals (
  approval_id    INT AUTO_INCREMENT PRIMARY KEY,
  request_id     INT NOT NULL,
  approved_by    INT NOT NULL, -- user_id of SECRETARIAT or ADMIN
  decision       ENUM('APPROVED','REJECTED') NOT NULL,
  decision_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  comments       TEXT NULL,

  CONSTRAINT fk_approvals_request
    FOREIGN KEY (request_id) REFERENCES requests(request_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_approvals_approved_by
    FOREIGN KEY (approved_by) REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  INDEX idx_approvals_request (request_id),
  INDEX idx_approvals_approved_by (approved_by),
  INDEX idx_approvals_decision_date (decision_date)
) ENGINE=InnoDB;

-- =========================
-- 7) Seed Data
-- =========================
INSERT INTO statuses (status_name)
VALUES ('PENDING'), ('APPROVED'), ('REJECTED');

INSERT INTO users (full_name, email, role) VALUES
('John Student', 'student1@uni.example', 'STUDENT'),
('Maria Secretariat', 'secretariat@uni.example', 'SECRETARIAT'),
('Alex Admin', 'admin@uni.example', 'ADMIN');

-- Create a sample request (PENDING)
INSERT INTO requests (user_id, request_type, description, status_id)
VALUES (
  1,
  'CERTIFICATE',
  'Requesting enrollment certificate for internship application.',
  (SELECT status_id FROM statuses WHERE status_name='PENDING')
);

-- Add an approval record (APPROVED) and update request status
INSERT INTO approvals (request_id, approved_by, decision, comments)
VALUES (
  1,
  2,
  'APPROVED',
  'Approved. Certificate will be issued within 24 hours.'
);

UPDATE requests
SET status_id = (SELECT status_id FROM statuses WHERE status_name='APPROVED')
WHERE request_id = 1;

-- =========================
-- 8) Useful Queries (Demo)
-- =========================

-- 8.1 View all requests with user + current status
SELECT
  r.request_id,
  u.full_name AS student,
  u.email,
  r.request_type,
  r.submission_date,
  s.status_name AS current_status
FROM requests r
JOIN users u ON u.user_id = r.user_id
JOIN statuses s ON s.status_id = r.status_id
ORDER BY r.submission_date DESC;

-- 8.2 Approval history for a specific request
SELECT
  a.approval_id,
  a.request_id,
  a.decision,
  a.decision_date,
  approver.full_name AS approved_by,
  a.comments
FROM approvals a
JOIN users approver ON approver.user_id = a.approved_by
WHERE a.request_id = 1
ORDER BY a.decision_date ASC;

-- 8.3 KPIs: average time (hours) from submission to latest decision
-- Note: Uses MAX(decision_date) per request (latest decision).
SELECT
  AVG(TIMESTAMPDIFF(HOUR, r.submission_date, last_dec.last_decision_date)) AS avg_hours_to_decision
FROM requests r
JOIN (
  SELECT request_id, MAX(decision_date) AS last_decision_date
  FROM approvals
  GROUP BY request_id
) last_dec ON last_dec.request_id = r.request_id;

-- 8.4 Count of requests by status
SELECT s.status_name, COUNT(*) AS total
FROM requests r
JOIN statuses s ON s.status_id = r.status_id
GROUP BY s.status_name
ORDER BY total DESC;