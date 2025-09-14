#!/usr/bin/env bash
set -euo pipefail

# gerar-ca-cert.sh
#
# Gera (ou reutiliza) uma CA local e emite um certificado TLS para um host/serviço específico
# com Subject Alternative Names (SAN). Útil para Nginx Proxy Manager (NPM) com HTTPS local.
#
# Exemplos de uso:
#   ./gerar-ca-cert.sh -d jupyter.mrqz.me
#   ./gerar-ca-cert.sh -d ollama.mrqz.me --san "DNS:api.mrqz.me,IP:192.168.1.10"
#   ./gerar-ca-cert.sh -d portainer.mrqz.me --wildcard
#
# Saídas principais (em -o, padrão ./certs):
#   ca.key                # chave privada da CA (mantenha segura)
#   ca.crt                # certificado da CA (instale nos clientes como Raiz confiável)
#   <host>.key            # chave privada do host (ex.: jupyter.mrqz.me.key)
#   <host>.crt            # certificado do host assinado pela CA
#   <host>.fullchain.crt  # cadeia = host + CA
#   <host>.csr            # CSR gerado
#   <host>.openssl.cnf    # config OpenSSL usada (contém SANs)
#
# Instalar CA nos clientes:
#   Linux (Debian/Ubuntu):
#     sudo cp ca.crt /usr/local/share/ca-certificates/local-ca.crt && sudo update-ca-certificates
#   Windows:
#     Import-Certificate -FilePath "P:\Projetos\JotaPeServer\certs\ca.crt" -CertStoreLocation "Cert:\LocalMachine\Root"

DOMAIN=""
OUT_DIR="./certs"
COUNTRY="BR"
ORG="Local Dev Lab"
CA_NAME="Laboratory Server MRQZ CA"
DAYS_CA=3650
DAYS_CERT=825
EXTRA_SANS=""
WILDCARD=false
FORCE_NEW_CA=false
FORCE_OVERWRITE=false

usage() {
  cat <<EOF
Uso: $0 -d <dominio> [opções]

Obrigatório:
  -d, --domain <dominio>        FQDN do serviço (ex.: server.mrqz.me)

Opções:
  -o, --out-dir <dir>           Diretório de saída (padrão: ./certs)
      --country <CC>            País do DN (padrão: BR)
      --org <ORG>               Organização do DN (padrão: "Local Dev Lab")
      --ca-name <NOME>          CN da CA (padrão: "Laboratory Server MRQZ CA")
      --days-ca <N>             Validade da CA em dias (padrão: 3650)
      --days-cert <N>           Validade do certificado em dias (padrão: 825)
      --san "<itens>"           SAN extras (ex.: "DNS:api.mrqz.me,IP:192.168.1.10")
      --wildcard                Adiciona SAN "*.DOMINIO"
      --force-new-ca            Força RECRIAR a CA
      --force-overwrite         Sobrescreve arquivos do host
  -h, --help                    Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="$2"; shift 2 ;;
    -o|--out-dir) OUT_DIR="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --ca-name) CA_NAME="$2"; shift 2 ;;
    --days-ca) DAYS_CA="$2"; shift 2 ;;
    --days-cert) DAYS_CERT="$2"; shift 2 ;;
    --san) EXTRA_SANS="$2"; shift 2 ;;
    --wildcard) WILDCARD=true; shift ;;
    --force-new-ca) FORCE_NEW_CA=true; shift ;;
    --force-overwrite) FORCE_OVERWRITE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${DOMAIN}" ]]; then
  echo "Erro: --domain é obrigatório" >&2
  usage
  exit 1
fi

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

CA_KEY="ca.key"
CA_CRT="ca.crt"

if [[ "${FORCE_NEW_CA}" == "true" ]]; then
  rm -f "${CA_KEY}" "${CA_CRT}" ca.srl
fi

if [[ ! -f "${CA_KEY}" || ! -f "${CA_CRT}" ]]; then
  echo ">> Criando CA: ${CA_NAME}"
  openssl genrsa -out "${CA_KEY}" 4096
  openssl req -x509 -new -sha256 -days "${DAYS_CA}" \
    -key "${CA_KEY}" -out "${CA_CRT}" \
    -subj "/C=${COUNTRY}/O=${ORG}/CN=${CA_NAME}"
else
  echo ">> Reutilizando CA existente"
fi

HOST="${DOMAIN}"
HOST_KEY="${HOST}.key"
HOST_CSR="${HOST}.csr"
HOST_CRT="${HOST}.crt"
HOST_FULLCHAIN="${HOST}.fullchain.crt"
HOST_CONF="${HOST}.openssl.cnf"

if [[ -f "${HOST_KEY}" && "${FORCE_OVERWRITE}" != "true" ]]; then
  echo "Erro: já existem arquivos do host em $(pwd). Use --force-overwrite."
  exit 1
fi

SANS="DNS:${HOST}"
if [[ "${WILDCARD}" == "true" ]]; then
  SANS="${SANS},DNS:*.${HOST}"
fi
if [[ -n "${EXTRA_SANS}" ]]; then
  EXTRA="$(echo "${EXTRA_SANS}" | tr -d ' ')"
  SANS="${SANS},${EXTRA}"
fi

cat > "${HOST_CONF}" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C  = ${COUNTRY}
O  = ${ORG}
CN = ${HOST}

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = ${SANS}
EOF

openssl genrsa -out "${HOST_KEY}" 2048
openssl req -new -key "${HOST_KEY}" -out "${HOST_CSR}" -config "${HOST_CONF}"
openssl x509 -req -in "${HOST_CSR}" -CA "${CA_CRT}" -CAkey "${CA_KEY}" -CAcreateserial \
  -out "${HOST_CRT}" -days "${DAYS_CERT}" -sha256 -extfile "${HOST_CONF}" -extensions v3_req

cat "${HOST_CRT}" "${CA_CRT}" > "${HOST_FULLCHAIN}"

echo "Certificado gerado em: $(pwd)"
echo "  - CA:            ${CA_CRT}"
echo "  - Host Key:      ${HOST_KEY}"
echo "  - Host Cert:     ${HOST_CRT}"
echo "  - Fullchain:     ${HOST_FULLCHAIN}"
