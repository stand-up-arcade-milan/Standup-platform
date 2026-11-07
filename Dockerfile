FROM postgres:18-alpine

# L'immagine ufficiale esegue queste migrazioni al primo avvio del volume.
COPY database/migrations/ /docker-entrypoint-initdb.d/
