CREATE DATABASE  IF NOT EXISTS `tdms` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `tdms`;
-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: tdms
-- ------------------------------------------------------
-- Server version	5.7.43-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activity_logs`
--

DROP TABLE IF EXISTS `activity_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `activity_logs_user_id_foreign` (`user_id`),
  KEY `activity_logs_action_index` (`action`),
  KEY `activity_logs_created_at_index` (`created_at`),
  CONSTRAINT `activity_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `activity_logs`
--

LOCK TABLES `activity_logs` WRITE;
/*!40000 ALTER TABLE `activity_logs` DISABLE KEYS */;
INSERT INTO `activity_logs` VALUES (1,1,'center.created','Created assessment center: Cagayan State University - Carig','127.0.0.1','2026-07-30 06:59:40','2026-07-30 06:59:40'),(2,1,'center.created','Created assessment center: Cagayan State University - Carig Campus','127.0.0.1','2026-07-30 07:00:24','2026-07-30 07:00:24'),(3,1,'center.created','Created training center: Cagayan State University - Carig Campus','127.0.0.1','2026-07-30 07:02:19','2026-07-30 07:02:19'),(4,NULL,'login','User logged in: TVET Coordinator (coordinator@tvet.gov)','127.0.0.1','2026-07-30 07:43:04','2026-07-30 07:43:04'),(5,1,'center.updated','Updated assessment center: Cagayan State University - Carig','127.0.0.1','2026-07-30 08:14:29','2026-07-30 08:14:29'),(6,1,'user.created','Created user account: Jhun (jgumiran21@gmail.com)','127.0.0.1','2026-07-30 08:15:16','2026-07-30 08:15:16'),(7,1,'assessee.created','Added assessee: Gumiran, Jhun Casilana to center Cagayan State University - Carig','127.0.0.1','2026-07-30 08:49:18','2026-07-30 08:49:18'),(8,1,'assessee.updated','Updated assessee: Gumiran, Jhun Casilana','127.0.0.1','2026-07-30 09:01:47','2026-07-30 09:01:47'),(9,1,'assessee.updated','Updated assessee: Gumiran, Jhun Casilana','127.0.0.1','2026-07-30 09:07:55','2026-07-30 09:07:55'),(10,1,'assessee.updated','Updated assessee: Gumiran, Jhun Casilana','127.0.0.1','2026-07-30 09:10:58','2026-07-30 09:10:58'),(11,1,'assessee.deleted','Deleted assessee: Gumiran, Jhun Casilana','127.0.0.1','2026-07-30 09:11:07','2026-07-30 09:11:07'),(12,1,'assessee.created','Added assessee: Gumiran, Jhun Casilana to center Cagayan State University - Carig','127.0.0.1','2026-07-30 09:11:58','2026-07-30 09:11:58'),(13,1,'document.created','Created document TVET-25273-2026-001 (Internal Communication)','127.0.0.1','2026-07-31 00:02:15','2026-07-31 00:02:15'),(14,1,'document.created','Created document TVET-25273-2026-002 (Internal Communication)','127.0.0.1','2026-07-31 00:02:46','2026-07-31 00:02:46'),(15,1,'document.created','Created document TVET-25273-2026-003 (Internal Communication)','127.0.0.1','2026-07-31 00:03:31','2026-07-31 00:03:31'),(16,1,'user.updated','Updated user account: CHARMIE S. CALVO, DIT (coordinator@tvet.gov)','127.0.0.1','2026-07-31 01:40:14','2026-07-31 01:40:14'),(17,1,'user.updated','Updated user account: Jhun (jgumiran21@gmail.com)','127.0.0.1','2026-07-31 01:40:40','2026-07-31 01:40:40'),(18,1,'user.updated','Updated user account: JHUN C. GUMIRAN (jgumiran21@gmail.com)','127.0.0.1','2026-07-31 01:40:54','2026-07-31 01:40:54'),(19,1,'user.created','Created user account: ANTHONY JAMES D. CABAÑA (anthonyjamescabana@gmail.com)','127.0.0.1','2026-07-31 01:42:59','2026-07-31 01:42:59'),(20,1,'center.audit_completed','Marked audit completed for assessment center: Cagayan State University - Carig','127.0.0.1','2026-07-31 02:23:31','2026-07-31 02:23:31'),(21,NULL,'login','User logged in: CHARMIE S. CALVO, DIT (coordinator@tvet.gov)','127.0.0.1','2026-07-31 02:29:20','2026-07-31 02:29:20'),(22,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-07-31 02:33:46','2026-07-31 02:33:46'),(23,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-07-31 02:42:30','2026-07-31 02:42:30'),(24,1,'payment_slip.deleted','Deleted payment slip for , ','127.0.0.1','2026-07-31 02:47:20','2026-07-31 02:47:20'),(25,1,'payment_slip.deleted','Deleted payment slip for , ','127.0.0.1','2026-07-31 02:48:29','2026-07-31 02:48:29'),(26,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-07-31 02:48:38','2026-07-31 02:48:38'),(27,1,'payment_slip.deleted','Deleted payment slip for , ','127.0.0.1','2026-07-31 02:53:31','2026-07-31 02:53:31'),(28,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-07-31 02:53:40','2026-07-31 02:53:40'),(29,1,'payment_slip.deleted','Deleted payment slip for , ','127.0.0.1','2026-07-31 02:56:28','2026-07-31 02:56:28'),(30,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-07-31 02:56:34','2026-07-31 02:56:34'),(31,1,'document.deleted','Deleted document TVET-25273-2026-003','127.0.0.1','2026-08-01 00:49:29','2026-08-01 00:49:29'),(32,1,'document.deleted','Deleted document TVET-25273-2026-002','127.0.0.1','2026-08-01 00:49:33','2026-08-01 00:49:33'),(33,1,'document.deleted','Deleted document TVET-25273-2026-001','127.0.0.1','2026-08-01 00:49:37','2026-08-01 00:49:37'),(34,1,'payment_slip.deleted','Deleted payment slip for , ','127.0.0.1','2026-08-01 00:52:32','2026-08-01 00:52:32'),(35,1,'payment_slip.created','Created payment slip for ,  ()','127.0.0.1','2026-08-01 00:52:39','2026-08-01 00:52:39'),(36,1,'document.deleted','Deleted document TVET-25270-CA-2026-001','127.0.0.1','2026-08-01 00:54:13','2026-08-01 00:54:13'),(37,1,'document.created','Created document TVET-25270-CA-2026-001 (Certificate of Appearance)','127.0.0.1','2026-08-01 01:30:33','2026-08-01 01:30:33'),(38,1,'document.created','Created document TVET-RAP-2026-001 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 06:29:52','2026-08-01 06:29:52'),(39,1,'document.generated','Generated document TVET-RAP-2026-002 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 07:23:57','2026-08-01 07:23:57'),(40,1,'document.generated','Generated document TVET-RAP-2026-003 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 07:32:32','2026-08-01 07:32:32'),(41,1,'document.generated','Generated document TVET-RAP-2026-004 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 07:46:19','2026-08-01 07:46:19'),(42,1,'document.generated','Generated document TVET-RAP-2026-005 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 07:55:33','2026-08-01 07:55:33'),(43,1,'document.generated','Generated document TVET-PEI-2026-001 (Performance Evaluation Instrument)','127.0.0.1','2026-08-01 07:56:48','2026-08-01 07:56:48'),(44,1,'document.generated','Generated document TVET-RAP-2026-006 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 08:01:29','2026-08-01 08:01:29'),(45,1,'document.generated','Generated document TVET-RAP-2026-007 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 08:03:18','2026-08-01 08:03:18'),(46,1,'document.generated','Generated document TVET-RAP-2026-008 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 08:07:29','2026-08-01 08:07:29'),(47,1,'document.generated','Generated document TVET-RAP-2026-009 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 08:09:18','2026-08-01 08:09:18'),(48,1,'document.generated','Generated document TVET-RAP-2026-010 (Report on Assessment Proceedings)','127.0.0.1','2026-08-01 08:11:46','2026-08-01 08:11:46'),(49,1,'document.generated','Generated document TVET-PEI-2026-002 (Performance Evaluation Instrument)','127.0.0.1','2026-08-01 08:12:27','2026-08-01 08:12:27'),(50,1,'document.generated','Generated document TVET-PEI-2026-003 (Performance Evaluation Instrument)','127.0.0.1','2026-08-02 12:41:10','2026-08-02 12:41:10');
/*!40000 ALTER TABLE `activity_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assessee_trainees`
--

DROP TABLE IF EXISTS `assessee_trainees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `assessee_trainees` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `assessment_center_id` bigint(20) unsigned NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthday` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `age` int(11) DEFAULT NULL,
  `uli` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reference_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_school_attended` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `registration_form` tinyint(1) NOT NULL DEFAULT '0',
  `medical_certificate` tinyint(1) NOT NULL DEFAULT '0',
  `brgy_indigency` tinyint(1) NOT NULL DEFAULT '0',
  `brgy_clearance` tinyint(1) NOT NULL DEFAULT '0',
  `tor_form137_138` tinyint(1) NOT NULL DEFAULT '0',
  `qualification` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `competency` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'not_yet_competent',
  `assessment_fee_paid` tinyint(1) NOT NULL DEFAULT '0',
  `processing_fee_paid` tinyint(1) NOT NULL DEFAULT '0',
  `official_receipt` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `receipt_date` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assessor` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assessment_date` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `assessees_assessment_center_id_foreign` (`assessment_center_id`),
  KEY `assessees_assessment_date_index` (`assessment_date`),
  KEY `assessees_assessor_index` (`assessor`),
  CONSTRAINT `assessees_assessment_center_id_foreign` FOREIGN KEY (`assessment_center_id`) REFERENCES `centers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assessee_trainees`
--

LOCK TABLES `assessee_trainees` WRITE;
/*!40000 ALTER TABLE `assessee_trainees` DISABLE KEYS */;
INSERT INTO `assessee_trainees` VALUES (2,1,'Gumiran, Jhun Casilana','Gumiran','Jhun','Casilana','2001-06-11',25,NULL,NULL,NULL,NULL,NULL,0,0,0,0,0,'Electrical Installation and Maintenance NCII','Pending',1,1,'CSU-554515','2026-07-23',NULL,'2026-07-31','2026-07-30 09:11:58','2026-07-30 09:11:58');
/*!40000 ALTER TABLE `assessee_trainees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assessors`
--

DROP TABLE IF EXISTS `assessors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `assessors` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `center_id` bigint(20) unsigned DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `qualifications` json DEFAULT NULL,
  `accreditation_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `assessors_center_id_foreign` (`center_id`),
  CONSTRAINT `assessors_center_id_foreign` FOREIGN KEY (`center_id`) REFERENCES `centers` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assessors`
--

LOCK TABLES `assessors` WRITE;
/*!40000 ALTER TABLE `assessors` DISABLE KEYS */;
/*!40000 ALTER TABLE `assessors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `centers`
--

DROP TABLE IF EXISTS `centers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `centers` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `accreditation_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'assessment',
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assessment_fee` decimal(12,2) NOT NULL DEFAULT '0.00',
  `training_fee` decimal(12,2) NOT NULL DEFAULT '0.00',
  `qualifications` text COLLATE utf8mb4_unicode_ci,
  `expiration_date` date DEFAULT NULL,
  `audit_date` date DEFAULT NULL,
  `audit_completed_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `centers`
--

LOCK TABLES `centers` WRITE;
/*!40000 ALTER TABLE `centers` DISABLE KEYS */;
INSERT INTO `centers` VALUES (1,'Cagayan State University - Carig',NULL,'assessment','Carig Sur, Tuguegarao City',1849.00,0.00,'[\"Electrical Installation and Maintenance NCII\"]','2027-07-31','2026-07-31','2026-07-31 10:23:31','2026-07-30 06:59:40','2026-07-31 02:23:31'),(2,'Cagayan State University - Carig Campus',NULL,'assessment','Carig Sur, Tuguegarao City',1231.00,0.00,'[\"Hilot (Wellness Massage) NCII\"]',NULL,NULL,NULL,'2026-07-30 07:00:24','2026-07-30 07:00:24'),(3,'Cagayan State University - Carig Campus',NULL,'training','Carig Sur, Tuguegarao City',0.00,6649.00,'[\"Hilot (Wellness Massage) NCII\"]',NULL,NULL,NULL,'2026-07-30 07:02:19','2026-07-30 07:02:19');
/*!40000 ALTER TABLE `centers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `document_records`
--

DROP TABLE IF EXISTS `document_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `document_records` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `year` int(11) NOT NULL,
  `document_type_id` bigint(20) unsigned NOT NULL,
  `template_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `payload` json NOT NULL,
  `file_path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `received_at` timestamp NULL DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'saved',
  `received_by_office` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `special_order_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `special_order_date` datetime DEFAULT NULL,
  `voucher_received` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `document_records_code_unique` (`code`),
  KEY `idx_document_records_year` (`year`),
  KEY `idx_document_records_code` (`code`),
  KEY `idx_document_records_document_type_id` (`document_type_id`),
  KEY `document_records_template_id_fk` (`template_id`),
  KEY `document_records_user_id_fk` (`user_id`),
  CONSTRAINT `document_records_document_type_id_fk` FOREIGN KEY (`document_type_id`) REFERENCES `document_types` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_records_template_id_fk` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_records_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `document_records`
--

LOCK TABLES `document_records` WRITE;
/*!40000 ALTER TABLE `document_records` DISABLE KEYS */;
INSERT INTO `document_records` VALUES (8,'TVET-25270-CA-2026-001',2026,4,1,1,'{\"code\": \"TVET-25270-CA-2026-001\", \"date\": \"August 1, 2026\", \"year\": 2026, \"purpose\": \"Wowskjfhdsfkjdbskjdsfbsdkjb kjfh skjfahs fkjldshfdlskfhs kjshfdskjghdskjfdshfkjdshgdskj hkjsghskjd hsdkjhsd kjfh dskjgh dskjg hdskjghds kjghskjdgh dskjgh dskjgh dskjghdskjghds kjghds kjshg dskj ghdskjgh dskjsdhgdskjl gdhsklg hdsgkldhg dskl ghdxlkg hdxkjlg hdxkjlgdxh gkjdx ghdxkjgh dkjh dxkjgh dkjghds kjhdsgkj hdsgkj\", \"issued_at\": \"Cagayan State University - Carig Campus\", \"issued_day\": \"18th\", \"campus_name\": \"Cagayan State University - Carig Campus\", \"recipient_name\": \"Jhun Gumiran\", \"appearance_date\": \"July 18, 2026\", \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"recipient_office\": \"CSU\", \"issued_month_year\": \"July, 2026\"}','','',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 01:30:33','2026-08-01 01:30:33'),(9,'TVET-RAP-2026-001',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-001\", \"date\": \"August 01, 2026\", \"year\": 2026, \"narrative\": null, \"centerName\": \"Cagayan State University - Carig\", \"assessorName\": null, \"preparedDate\": \"August 01, 2026\", \"assessmentDate\": null, \"preparedByName\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','','',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 06:29:52','2026-08-01 06:29:52'),(10,'TVET-RAP-2026-002',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-002\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"ff\", \"accreditationNumber\": \"vv\"}','generated/TVET-RAP-2026-002-1785569037.docx','/api/v1/documents/10/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 07:23:57','2026-08-01 07:23:57'),(11,'TVET-RAP-2026-003',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-003\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"xffxg\", \"accreditationNumber\": \"vcvgh\"}','generated/TVET-RAP-2026-003-1785569552.docx','/api/v1/documents/11/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 07:32:32','2026-08-01 07:32:32'),(12,'TVET-RAP-2026-004',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-004\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Hilot (Wellness Massage) NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-004-1785570379.docx','/api/v1/documents/12/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 07:46:19','2026-08-01 07:46:19'),(13,'TVET-RAP-2026-005',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-005\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-005-1785570933.docx','/api/v1/documents/13/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 07:55:33','2026-08-01 07:55:33'),(14,'TVET-PEI-2026-001',2026,9,3,1,'{\"code\": \"TVET-PEI-2026-001\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": \"dd\", \"finalRating1\": null, \"finalRating2\": null, \"qualification\": \"Electrical Installation and Maintenance NCII\", \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"respondentName1\": null, \"respondentName2\": null, \"coordinatorTitle\": \"TVET Coordinator\", \"dateAccomplished1\": null, \"dateAccomplished2\": null, \"evaluatorRemarks1\": null, \"evaluatorRemarks2\": null}','generated/TVET-PEI-2026-001-1785571008.docx','/api/v1/documents/14/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 07:56:48','2026-08-01 07:56:48'),(15,'TVET-RAP-2026-006',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-006\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-006-1785571289.docx','/api/v1/documents/15/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:01:29','2026-08-01 08:01:29'),(16,'TVET-RAP-2026-007',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-007\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-007-1785571398.docx','/api/v1/documents/16/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:03:18','2026-08-01 08:03:18'),(17,'TVET-RAP-2026-008',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-008\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-008-1785571649.docx','/api/v1/documents/17/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:07:29','2026-08-01 08:07:29'),(18,'TVET-RAP-2026-009',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-009\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-009-1785571758.docx','/api/v1/documents/18/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:09:18','2026-08-01 08:09:18'),(19,'TVET-RAP-2026-010',2026,8,2,1,'{\"code\": \"TVET-RAP-2026-010\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": null, \"assessmentDate\": null, \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"coordinatorTitle\": \"TVET Coordinator\", \"numberOfCandidates\": null, \"qualificationTitle\": \"Electrical Installation and Maintenance NCII\", \"accreditationNumber\": null}','generated/TVET-RAP-2026-010-1785571906.docx','/api/v1/documents/19/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:11:46','2026-08-01 08:11:46'),(20,'TVET-PEI-2026-002',2026,9,3,1,'{\"code\": \"TVET-PEI-2026-002\", \"date\": \"August 01, 2026\", \"year\": 2026, \"assessorName\": \"dfd\", \"finalRating1\": null, \"finalRating2\": null, \"qualification\": \"Electrical Installation and Maintenance NCII\", \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"respondentName1\": null, \"respondentName2\": null, \"coordinatorTitle\": \"TVET Coordinator\", \"dateAccomplished1\": null, \"dateAccomplished2\": null, \"evaluatorRemarks1\": null, \"evaluatorRemarks2\": null, \"accreditationNumber\": null}','generated/TVET-PEI-2026-002-1785571947.docx','/api/v1/documents/20/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-01 08:12:27','2026-08-01 08:12:27'),(21,'TVET-PEI-2026-003',2026,9,3,1,'{\"code\": \"TVET-PEI-2026-003\", \"date\": \"August 02, 2026\", \"year\": 2026, \"assessorName\": \"Lorenzo Macabbaadbda\", \"finalRating1\": null, \"finalRating2\": null, \"qualification\": \"Electrical Installation and Maintenance NCII\", \"coordinatorName\": \"CHARMIE S. CALVO, DIT\", \"respondentName1\": null, \"respondentName2\": null, \"coordinatorTitle\": \"TVET Coordinator\", \"dateAccomplished1\": null, \"dateAccomplished2\": null, \"evaluatorRemarks1\": null, \"evaluatorRemarks2\": null, \"accreditationNumber\": null}','generated/TVET-PEI-2026-003-1785674470.docx','/api/v1/documents/21/download',NULL,'saved',NULL,NULL,NULL,0,'2026-08-02 12:41:10','2026-08-02 12:41:10');
/*!40000 ALTER TABLE `document_records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `document_sequences`
--

DROP TABLE IF EXISTS `document_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `document_sequences` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `document_type_id` bigint(20) unsigned NOT NULL,
  `year` int(11) NOT NULL,
  `next_number` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_sequences_type_year` (`document_type_id`,`year`),
  CONSTRAINT `document_sequences_document_type_id_fk` FOREIGN KEY (`document_type_id`) REFERENCES `document_types` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `document_sequences`
--

LOCK TABLES `document_sequences` WRITE;
/*!40000 ALTER TABLE `document_sequences` DISABLE KEYS */;
INSERT INTO `document_sequences` VALUES (1,4,2026,2,'2026-07-29 00:19:51','2026-08-01 01:30:33'),(2,5,2026,4,'2026-07-29 00:19:51','2026-08-01 00:50:19'),(3,6,2026,1,'2026-07-29 00:19:51','2026-07-29 00:19:51'),(7,7,2026,1,'2026-07-30 05:06:29','2026-07-30 05:06:29'),(8,8,2026,11,'2026-08-01 06:28:10','2026-08-01 08:11:46'),(9,9,2026,4,'2026-08-01 06:28:10','2026-08-02 12:41:10');
/*!40000 ALTER TABLE `document_sequences` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `document_templates`
--

DROP TABLE IF EXISTS `document_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `document_templates` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `document_type_id` bigint(20) unsigned NOT NULL,
  `original_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mime_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_document_templates_document_type_id` (`document_type_id`),
  CONSTRAINT `document_templates_document_type_id_fk` FOREIGN KEY (`document_type_id`) REFERENCES `document_types` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `document_templates`
--

LOCK TABLES `document_templates` WRITE;
/*!40000 ALTER TABLE `document_templates` DISABLE KEYS */;
INSERT INTO `document_templates` VALUES (1,4,'certificate_of_appearance.docx','certificate_of_appearance.docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document','templates/certificate_of_appearance.docx',1,'2026-07-29 00:18:22','2026-07-29 00:18:22'),(2,8,'report_on_assessment_proceedings.docx','report_on_assessment_proceedings.docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document','templates/report_on_assessment_proceedings.docx',1,'2026-08-01 05:52:30','2026-08-01 05:52:30'),(3,9,'performance_evaluation_instrument.docx','performance_evaluation_instrument.docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document','templates/performance_evaluation_instrument.docx',1,'2026-08-01 06:15:13','2026-08-01 06:15:13');
/*!40000 ALTER TABLE `document_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `document_types`
--

DROP TABLE IF EXISTS `document_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `document_types` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `slug` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `prefix` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `padding` tinyint(3) unsigned NOT NULL DEFAULT '3',
  `active_year` smallint(5) unsigned DEFAULT NULL,
  `active_template_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  UNIQUE KEY `active_template_id` (`active_template_id`),
  KEY `idx_document_types_slug` (`slug`),
  CONSTRAINT `document_types_active_template_id_fk` FOREIGN KEY (`active_template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `document_types`
--

LOCK TABLES `document_types` WRITE;
/*!40000 ALTER TABLE `document_types` DISABLE KEYS */;
INSERT INTO `document_types` VALUES (4,'certificate-of-appearance','Certificate of Appearance','TVET-252701-CA',3,NULL,1,'2026-07-29 00:18:22','2026-08-02 12:39:32'),(5,'internal-communication','Internal Communication','TVET-25270-IC',3,NULL,NULL,'2026-07-29 00:18:22','2026-08-02 12:39:25'),(6,'external-communication','External Communication','TVET-25270-EC',3,NULL,NULL,'2026-07-29 00:18:22','2026-08-02 12:39:28'),(7,'endorsement-communication','Endorsement','TVET-25270-END',3,NULL,NULL,'2026-07-30 04:43:57','2026-08-02 12:39:30'),(8,'report-on-assessment-proceedings','Report on Assessment Proceedings','TVET-RAP',3,NULL,2,'2026-08-01 05:52:30','2026-08-01 05:52:30'),(9,'performance-evaluation-instrument','Performance Evaluation Instrument','TVET-PEI',3,NULL,3,'2026-08-01 06:15:13','2026-08-01 06:15:13');
/*!40000 ALTER TABLE `document_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (1,'2024_01_01_000000_create_tvet_tables',1),(2,'2026_07_29_071521_add_received_at_to_document_records',2),(3,'2026_07_29_073245_add_unique_code_to_document_records',3),(4,'2026_07_29_101500_add_code_format_to_document_types',4),(5,'2026_07_30_000001_create_centers_and_assessees_tables',5),(6,'2026_07_30_000002_update_centers_and_assessees_tables',6),(7,'2026_07_30_000003_create_activity_logs_table',7),(8,'2026_07_30_161258_add_expiration_and_audit_dates_to_centers_table',8),(9,'2026_07_30_163135_rename_assessees_to_assessee_trainees_table',9),(10,'2026_07_30_164323_remove_assessor_fee_document_type',10),(11,'2026_07_30_165543_add_status_workflow_to_document_records_table',11),(12,'2026_07_31_000001_add_audit_completed_at_to_centers_table',12),(13,'2026_07_31_000002_create_payment_slips_table',12),(14,'2026_07_31_000003_add_extension_name_and_designations_to_users_table',13),(15,'2026_07_31_000004_add_accreditation_number_to_centers_table',14),(16,'2026_07_31_000005_create_assessors_table',14),(17,'2026_07_31_000006_add_reference_number_and_uli_to_assessees_table',15),(18,'2026_07_31_000007_add_mobile_number_to_assessors_table',16),(19,'2026_07_31_000008_add_center_id_to_assessors_table',17),(20,'2026_07_31_000009_make_payment_slip_fields_nullable',18),(21,'2026_07_31_000010_add_officer_fields_to_payment_slips',19);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `offices`
--

DROP TABLE IF EXISTS `offices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `offices` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `coordinator_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `coordinator_title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'TVET Coordinator',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_offices_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `offices`
--

LOCK TABLES `offices` WRITE;
/*!40000 ALTER TABLE `offices` DISABLE KEYS */;
INSERT INTO `offices` VALUES (1,'Main TVET Office','MAIN','Juan Dela Cruz','TVET Coordinator','2026-07-28 08:52:50','2026-07-28 08:52:50'),(2,'TVET Main Office',NULL,'Engr. Juan Dela Cruz','TVET Coordinator','2026-07-29 00:18:22','2026-07-29 00:18:22');
/*!40000 ALTER TABLE `offices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payment_slips`
--

DROP TABLE IF EXISTS `payment_slips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_slips` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `student_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `course` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `section` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `officer_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `officer_designations` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `items` json NOT NULL,
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `printed_count` int(11) NOT NULL DEFAULT '0',
  `released_count` int(11) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payment_slips`
--

LOCK TABLES `payment_slips` WRITE;
/*!40000 ALTER TABLE `payment_slips` DISABLE KEYS */;
INSERT INTO `payment_slips` VALUES (6,NULL,NULL,NULL,NULL,NULL,NULL,'ANTHONY JAMES D. CABAÑA LPT','Processing Officer','[{\"amount\": 1231, \"qualification\": \"Hilot (Wellness Massage) NCII (Assessment)\"}]',1231.00,0,0,'2026-08-01 00:52:39','2026-08-01 00:52:39');
/*!40000 ALTER TABLE `payment_slips` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `key` (`key`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `settings`
--

LOCK TABLES `settings` WRITE;
/*!40000 ALTER TABLE `settings` DISABLE KEYS */;
INSERT INTO `settings` VALUES (1,'DEFAULT_COORDINATOR_NAME','CHARMIE S. CALVO, DIT','2026-07-29 00:18:22','2026-07-29 03:17:22'),(2,'DEFAULT_CAMPUS_NAME','Cagayan State University - Carig Campus','2026-07-29 03:07:19','2026-07-29 03:07:19'),(3,'DEFAULT_ISSUED_AT','Cagayan State University - Carig Campus','2026-07-29 03:07:19','2026-07-29 03:07:19'),(4,'DEFAULT_COORDINATOR_TITLE','TVET Coordinator','2026-07-29 03:15:53','2026-07-29 03:15:53');
/*!40000 ALTER TABLE `settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `extension_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `designations` json DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `api_token` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'STAFF',
  `office_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `api_token` (`api_token`),
  KEY `idx_users_office_id` (`office_id`),
  CONSTRAINT `users_office_id_fk` FOREIGN KEY (`office_id`) REFERENCES `offices` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'CHARMIE S. CALVO, DIT',NULL,'[\"TVET Coordinator\", \"University TVET Director\", \"University CICS Dean\", \"Carig Campus Dean\", \"DTC Manager\", \"AC Manager\"]','coordinator@tvet.gov','$2y$12$l7ITZEQIKo5MD6SWIXIgxu1w8cwtevgr986Li89T5oD57O/NLHaRK','RXVdZCjvb51dzB1kSgXgqaf0qMoSNxmi3K1vOePWMrxm2p4hCl7hwSjhl86DNZEochXdQHKGCZ717tss','coordinator',2,'2026-07-28 08:52:50','2026-07-31 02:29:20'),(2,'JHUN C. GUMIRAN',NULL,'[\"TVET Staff\", \"DTC Staff\", \"Registrar\"]','jgumiran21@gmail.com','$2y$12$vFgfEarwzmUKLwNhIvi6KeM4vIOSriQtfA/YeBtnCsNXLhgbDRtpu',NULL,'admin',NULL,'2026-07-30 08:15:16','2026-07-31 01:40:54'),(3,'ANTHONY JAMES D. CABAÑA','LPT','[\"Processing Officer\", \"TVET Staff\", \"TVI Coordinator\"]','anthonyjamescabana@gmail.com','$2y$12$m3n57dix49tD.HQjGyDOMOGqCqg4XhZh/9jc2u7UE2M7p5VcP1Oni',NULL,'admin',NULL,'2026-07-31 01:42:59','2026-07-31 01:42:59');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'tdms'
--

--
-- Dumping routines for database 'tdms'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-08-02 20:51:19
