#!/usr/bin/env bash
set -euo pipefail

# Uso: ./gen-cert-simples.sh <dominio>
# Exemplo:
#   ./gen-cert-simples.sh jupyter.mrqz.me

if [ $# -lt 1 ]; then
  echo "Uso: $0 <dominio>"
  exit 1
fi

DOMAIN="$1"
OUT_DIR="./certs"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

CA_KEY="ca.key"
CA_CRT="ca.crt"

# Se não existir CA, cria
if [[ ! -f "${CA_KEY}" || ! -f "${CA_CRT}" ]]; then
  echo ">> Criando CA local..."
  openssl genrsa -out "${CA_KEY}" 4096
  openssl req -x509 -new -sha256 -days 3650 \
    -key "${CA_KEY}" -out "${CA_CRT}" \
    -subj "/C=BR/O=Local Dev/CN=Laboratory Server MRQZ CA"
else
  echo ">> Reutilizando CA existente"
fi

HOST_KEY="${DOMAIN}.key"
HOST_CSR="${DOMAIN}.csr"
HOST_CRT="${DOMAIN}.crt"
HOST_FULLCHAIN="${DOMAIN}.fullchain.crt"
HOST_CONF="${DOMAIN}.openssl.cnf"

# Config OpenSSL para incluir SAN
cat > "${HOST_CONF}" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = dn
req_extensions     = v3_req
prompt             = no

[ dn ]
CN = ${DOMAIN}

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:${DOMAIN}
EOF

echo ">> Gerando chave e certificado para ${DOMAIN}"
openssl genrsa -out "${HOST_KEY}" 2048
openssl req -new -key "${HOST_KEY}" -out "${HOST_CSR}" -config "${HOST_CONF}"
openssl x509 -req -in "${HOST_CSR}" -CA "${CA_CRT}" -CAkey "${CA_KEY}" -CAcreateserial \
  -out "${HOST_CRT}" -days 825 -sha256 -extfile "${HOST_CONF}" -extensions v3_req

cat "${HOST_CRT}" "${CA_CRT}" > "${HOST_FULLCHAIN}"

echo
echo "Certificados criados em $(pwd):"
echo "  - CA:        ${CA_CRT}"
echo "  - Host Key:  ${HOST_KEY}"
echo "  - Host Cert: ${HOST_CRT}"
echo "  - Fullchain: ${HOST_FULLCHAIN}"
echo
echo "Importe a CA (${CA_CRT}) nos clientes para confiar no certificado."
