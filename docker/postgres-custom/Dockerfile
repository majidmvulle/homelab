FROM ghcr.io/cloudnative-pg/postgresql:17

USER root

# 1. Install prerequisites for adding repositories
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    lsb-release \
    ca-certificates

# 2. Add TimescaleDB Repository
# Timescale often requires its own repo.
# We use the 'debian/bookworm' codename (standard for CNPG images).
RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list

# 3. Install Extensions
# - postgresql-17-postgis-3 -> PostGIS
# - postgresql-17-pgvector -> pgvector
# - postgresql-17-pgaudit -> pgAudit
# - timescaledb-2-postgresql-17 -> TimescaleDB
# - postgresql-contrib-17 -> Includes: pg_trgm, pgcrypto, uuid-ossp, hstore, pg_stat_statements
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    postgresql-17-postgis-3 \
    postgresql-17-postgis-3-scripts \
    postgresql-17-pgvector \
    postgresql-17-pgaudit \
    timescaledb-2-postgresql-17 \
    postgresql-contrib-17; \
    # Cleanup to keep image size down
    rm -fr /var/lib/apt/lists/*

# 4. Switch back to postgres user
USER postgres
