SET search_path TO arcade;

-- The API can register offer metadata before a document provider issues a real download URL.
ALTER TABLE documento_pratica ALTER COLUMN url DROP NOT NULL;
