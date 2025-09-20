# dentro do host
docker exec -it nginx nginx -t && docker exec -it nginx nginx -s reload

# checar upstreams via container do nginx
docker exec -it nginx sh -lc 'apk add --no-cache curl >/dev/null 2>&1 || true; \
  echo "[HTTPS] /healthz:"; curl -sSf --cacert /etc/nginx/certs/ca.crt https://mrqz.me/healthz || echo "FAIL"
  echo "Portainer:";  curl -s http://portainer:9000/ >/dev/null 2>&1 && echo "OK"; \
  echo "Grafana:";  curl -s http://grafana:3000/api/health && echo "" | head -n5; \
  echo "Prometheus:"; curl -sf http://prometheus:9090/coletor/-/ready | head -n2; \
  echo "Loki:"; curl -s http://loki:3100/ready | head -n1'

docker exec -it nginx sh -lc 'curl -sSf --cacert /etc/nginx/certs/ca.crt https://mrqz.me/healthz'
docker exec -it nginx sh -lc 'curl -s http://portainer:9000/ >/dev/null 2>&1 && echo "OK";'
docker exec -it nginx sh -lc 'curl -s http://grafana:3000/api/health'
docker exec -it nginx sh -lc 'curl -sf http://prometheus:9090/coletor/-/ready'
docker exec -it nginx sh -lc 'curl -s http://loki:3100/ready'

# HTTP(S) externo
curl -sI https://mrqz.me/healthz | head -n1
curl -sI https://mrqz.me/infra/ | head -n1
curl -sI https://mrqz.me/painel/ | head -n1
curl -sI https://mrqz.me/coletor/-/ready | head -n1
curl -s  https://mrqz.me/logs/ready
