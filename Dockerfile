FROM postgres:18-alpine

# Create a non-superuser account used by Spring; the POSTGRES_USER account stays for migrations/admin.
COPY --chmod=755 database/init/00-create-app-role.sh /docker-entrypoint-initdb.d/00-create-app-role.sh

# L'immagine ufficiale esegue queste migrazioni al primo avvio del volume.
COPY database/migrations/ /docker-entrypoint-initdb.d/
