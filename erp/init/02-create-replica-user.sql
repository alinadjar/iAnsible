-- Simple working version without all the fancy RAISE notices

\echo 'Setting up replica user...'

-- Create role
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_ro_role') THEN
        CREATE ROLE app_ro_role WITH INHERIT NOCREATEDB NOCREATEROLE;
    END IF;
END
$$;

-- Grant cluster-wide read access
GRANT pg_read_all_data TO app_ro_role;

-- Create user
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replica_user') THEN
        CREATE USER replica_user WITH PASSWORD '123456';
    ELSE
        ALTER USER replica_user WITH PASSWORD '123456';
    END IF;
END
$$;

-- Apply restrictions
ALTER USER replica_user WITH NOCREATEDB NOCREATEROLE CONNECTION LIMIT 50;

-- Grant role
GRANT app_ro_role TO replica_user;

-- Grant connect to all databases
DO $$
DECLARE
    db_record RECORD;
BEGIN
    FOR db_record IN 
        SELECT datname 
        FROM pg_database 
        WHERE datistemplate = false 
          AND datname NOT IN ('postgres', 'template0', 'template1')
    LOOP
        EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_ro_role', db_record.datname);
    END LOOP;
END
$$;

\echo '✅ Read-only user setup complete!'

