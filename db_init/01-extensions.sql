-- Database initialization script
-- This runs automatically when PostgreSQL container starts with empty data directory
-- It ensures all required extensions and indexes are properly set up

-- Enable required extensions for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;

-- Note: This script runs BEFORE any data restoration
-- The Ruby application will skip extension creation if functions already exist