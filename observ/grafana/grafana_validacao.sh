# 1) Subiu ok no subpath?
curl -sI https://mrqz.me/painel/ | head -n1

# 2) Datasources provisionados?
docker logs grafana 2>&1 | grep -i "provision" | head

# 3) API: listar datasources
docker exec -it grafana sh -lc \
 'apk add --no-cache curl >/dev/null 2>&1 || true; \
  curl -s -u admin:jquest http://127.0.0.1:3000/api/datasources'

# 4) Dashboard carregado?
# Veja no UI: Folder "Lab - JotaPeServer" -> "JotaPeServer - Infra Starter"
# ou pela API (exige auth):
# curl -s -u admin:$GF_SECURITY_ADMIN_PASSWORD http://127.0.0.1:3000/api/search?query=Starter

docker exec -it grafana sh -lc 'apk add --no-cache curl >/dev/null 2>&1 || true; \
  curl -sS http://prometheus:9090/coletor/api/v1/status/buildinfo | head'