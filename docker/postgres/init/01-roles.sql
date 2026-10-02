\getenv migrator_password PERFIN_MIGRATOR_PASSWORD
\getenv app_password PERFIN_APP_PASSWORD
CREATE ROLE perfin_migrator LOGIN CREATEDB PASSWORD :'migrator_password'; -- CREATEDB: Prisma shadow DB
CREATE ROLE perfin_app      LOGIN PASSWORD :'app_password';
CREATE DATABASE perfin OWNER perfin_migrator;
\connect perfin
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO perfin_app;
ALTER DEFAULT PRIVILEGES FOR ROLE perfin_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO perfin_app;
ALTER DEFAULT PRIVILEGES FOR ROLE perfin_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO perfin_app;
