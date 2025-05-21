#!/bin/bash

# Configurações
CONTAINER_NAME="fopag"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS="jquest"
DUMP_DIR="./dump"

# Verificar se o diretório de dump existe
if [ ! -d "$DUMP_DIR" ]; then
    echo "❌ Diretório $DUMP_DIR não encontrado."
    exit 1
fi

# Listar arquivos de dump
DUMP_FILES=$(find "$DUMP_DIR" -type f \( -name "*.sql" -o -name "*.dmp" \) | sort)

if [ -z "$DUMP_FILES" ]; then
    echo "❌ Nenhum arquivo .sql ou .dmp encontrado em $DUMP_DIR."
    exit 1
fi

echo "🚀 Iniciando carregamento dos arquivos de dump no container $CONTAINER_NAME..."

# Loop sobre os arquivos
for FILE in $DUMP_FILES; do
    BASENAME=$(basename "$FILE")
    echo "📥 Carregando: $BASENAME..."

    docker exec -i "$CONTAINER_NAME" /bin/bash -c \
      "PGPASSWORD=$DB_PASS psql --username=$DB_USER $DB_NAME" < "$FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Sucesso: $BASENAME"
    else
        echo "❌ Erro ao carregar: $BASENAME"
        # Você pode usar `exit 1` aqui para abortar ao primeiro erro se preferir
    fi
done

echo "✅ Todos os arquivos processados."
