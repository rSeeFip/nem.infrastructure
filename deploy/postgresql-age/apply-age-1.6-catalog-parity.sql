\set ON_ERROR_STOP on

-- Local repair entry point.  Keep the vendor update and this supplement in one
-- transaction so any failed guard or DDL statement rolls back the whole update.
BEGIN;

DO $guard$
DECLARE
    extension_owner oid;
    installed_version text;
    is_superuser boolean;
BEGIN
    IF pg_catalog.current_setting('server_version_num')::integer / 10000 <> 16 THEN
        RAISE EXCEPTION 'AGE catalog repair requires PostgreSQL 16';
    END IF;

    SELECT e.extowner, e.extversion
      INTO extension_owner, installed_version
      FROM pg_catalog.pg_extension AS e
      JOIN pg_catalog.pg_namespace AS n ON n.oid = e.extnamespace
     WHERE e.extname = 'age'
       AND n.nspname = 'ag_catalog';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'AGE extension in schema ag_catalog is required';
    END IF;
    IF installed_version <> '1.5.0' THEN
        RAISE EXCEPTION 'expected AGE 1.5.0 before official update, found %', installed_version;
    END IF;

    SELECT r.rolsuper
      INTO STRICT is_superuser
      FROM pg_catalog.pg_roles AS r
     WHERE r.rolname = current_user;

    IF pg_catalog.to_regrole(current_user) <> extension_owner AND NOT is_superuser THEN
        RAISE EXCEPTION 'current user must be the AGE extension owner or a superuser';
    END IF;

    PERFORM pg_catalog.set_config(
        'age_catalog_repair.official_upgrade',
        '1.5.0-to-1.6.0-local-v1',
        true
    );
END
$guard$;

-- This resolves to the installed, unmodified vendor age--1.5.0--1.6.0.sql.
-- New vendor objects must inherit the extension owner's ownership and default
-- ACLs, not those of the superuser launching this transaction.
SELECT pg_catalog.format('SET LOCAL ROLE %I', owner_role.rolname)
  FROM pg_catalog.pg_extension AS e
  JOIN pg_catalog.pg_roles AS owner_role ON owner_role.oid = e.extowner
 WHERE e.extname = 'age'
\gexec

ALTER EXTENSION age UPDATE TO '1.6.0';

\ir age-1.6-catalog-parity-repair.sql

COMMIT;
