#!/bin/bash
set -euo pipefail
#==============================================================#
# File      :   initdb.sh
# Mtime     :   2020-04-07
# Desc      :   initdb.sh
# Path      :   /pg/bin/initdb.sh
# Depend    :   CentOS 7
# Author    :   Vonng(fengruohang@outlook.com)
# Note      :   Run this as dbsu (postgres)
#==============================================================#
PROG_NAME="$(basename $0))"
PROG_DIR="$(cd $(dirname $0) && pwd)"


#==============================================================#
function log() {
    printf "[$(date "+%Y-%m-%d %H:%M:%S")][$HOSTNAME][INITDB] $*\n" >> /pg/log/initdb.log
}
#==============================================================#

log "init postgres: $@"

# create default roles, users and business database {{ biz_db | default(cluster) }}
psql postgres <<- EOF
	-- replication user (rewind user too)
	CREATE USER "{{ repl_user | default('replicator') }}";
	ALTER USER  {{ repl_user | default('replicator') }} REPLICATION PASSWORD '{{ repl_pass | default('replicator') }}';
	GRANT EXECUTE ON function pg_catalog.pg_ls_dir(text, boolean, boolean) TO "{{ repl_user | default('replicator') }}";
	GRANT EXECUTE ON function pg_catalog.pg_stat_file(text, boolean) TO "{{ repl_user | default('replicator') }}";
	GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text) TO "{{ repl_user | default('replicator') }}";
	GRANT EXECUTE ON function pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO  "{{ repl_user | default('replicator') }}";

	-- default roles
	CREATE ROLE dbrole_readonly;
	CREATE ROLE dbrole_readwrite;
	CREATE ROLE dbrole_monitor;
	CREATE ROLE dbrole_admin;
	ALTER ROLE dbrole_readonly NOLOGIN NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;
	ALTER ROLE dbrole_readwrite NOLOGIN NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;
	ALTER ROLE dbrole_monitor NOLOGIN NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;
	ALTER ROLE dbrole_admin NOLOGIN NOSUPERUSER INHERIT CREATEROLE CREATEDB NOREPLICATION BYPASSRLS;
	GRANT dbrole_readonly TO dbrole_readwrite;
	GRANT dbrole_readonly TO dbrole_monitor;
	GRANT dbrole_readwrite TO dbrole_admin;

	-- monitor user
	CREATE USER "{{ mon_user | default('dbuser_monitor') }}";
	GRANT pg_monitor TO "{{ mon_user | default('dbuser_monitor') }}";
	GRANT dbrole_readonly TO "{{ mon_user | default('dbuser_monitor') }}";
	ALTER USER "{{ mon_user | default('dbuser_monitor') }}" LOGIN NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOREPLICATION BYPASSRLS;
	ALTER USER "{{ mon_user | default('dbuser_monitor') }}" PASSWORD '{{ mon_pass | default('dbuser_monitor') }}' CONNECTION LIMIT 5;

	-- business database & users
	CREATE USER "{{ biz_user | default(cluster) }}";
	GRANT dbrole_admin TO "{{ biz_user | default(cluster) }}";
	ALTER USER "{{ biz_user | default(cluster) }}" LOGIN NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOREPLICATION BYPASSRLS;
	ALTER USER "{{ biz_user | default(cluster) }}" PASSWORD '{{ biz_user | default(cluster) }}';

	CREATE DATABASE "{{ biz_db | default(cluster) }}";
	ALTER DATABASE "{{ biz_db  | default(cluster) }}" OWNER TO "{{ biz_user  | default(cluster) }}";
EOF


log "create replication user {{ repl_user | default('replicator') }}"
log "create monitor user: {{ mon_user | default('dbuser_monitor') }}"
log "create business user: {{ biz_user | default(cluster) }}"
log "create business database: {{ biz_db | default(cluster) }}"


# set privilege for database {{ biz_db | default(cluster) }}
psql {{ biz_db | default(cluster) }} <<- EOF
	-- readonly:
	ALTER DEFAULT PRIVILEGES GRANT USAGE ON SCHEMAS TO dbrole_readonly;
	ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO dbrole_readonly;
	ALTER DEFAULT PRIVILEGES GRANT SELECT ON SEQUENCES TO dbrole_readonly;
	ALTER DEFAULT PRIVILEGES GRANT EXECUTE ON FUNCTIONS TO dbrole_readonly;

	-- readwrite : INSERT, UPDATE, DELETE, USING seq
	ALTER DEFAULT PRIVILEGES GRANT INSERT, UPDATE, DELETE ON TABLES TO dbrole_readwrite;
	ALTER DEFAULT PRIVILEGES GRANT USAGE, UPDATE ON SEQUENCES TO dbrole_readwrite;

	-- admin: TRUNCATE, REFERENCE, TRIGGER, etc...
	ALTER DEFAULT PRIVILEGES GRANT TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbrole_admin;
	ALTER DEFAULT PRIVILEGES GRANT CREATE ON SCHEMAS TO dbrole_admin;
	ALTER DEFAULT PRIVILEGES GRANT USAGE ON TYPES TO dbrole_admin;

	-- monitor schema
	CREATE SCHEMA IF NOT EXISTS monitor;
	CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA monitor;
	REVOKE USAGE ON SCHEMA monitor FROM dbrole_readonly;
	GRANT USAGE ON SCHEMA monitor TO "{{ mon_user | default('dbuser_monitor') }}";
	ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO  "{{ mon_user | default('dbuser_monitor') }}";
EOF

log "setup business database {{ biz_db | default(cluster) }} default privileges"

# add entry to .pgpass
cat > ~/.pgpass  <<- EOF
	# postgres://{{ repl_user | default('replicator') }}:{{ repl_pass | default('replicator') }}@:/postgres
	# postgres://{{ mon_user | default('dbuser_monitor') }}:{{ mon_pass | default('dbuser_monitor') }}@:/postgres
	# postgres://{{ biz_user | default(cluster) }}:{{ biz_pass | default(cluster) }}@:/{{ biz_db | default(cluster) }}
	*:*:*:{{ repl_user | default('replicator') }}:{{ repl_pass | default('replicator') }}
	*:*:*:{{ mon_user | default('dbuser_monitor') }}:{{ mon_pass | default('dbuser_monitor') }}
	*:*:{{ biz_db | default(cluster) }}:{{ biz_user | default(cluster) }}:{{ biz_pass | default(cluster) }}
EOF
chmod 0600 ~/.pgpass

log "create .pgpass @ ${HOME}/.pgpass"
log "initdb.sh completed!"


