# validar config e regras
docker exec -it prometheus promtool check config /etc/prometheus/prometheus.yml
docker exec -it prometheus sh -lc 'promtool check rules /etc/prometheus/rules/*.yml'

# health do UI (via subpath no NGINX)
curl -sI https://mrqz.me/coletor/-/ready | head -n1

# targets sobem?
curl -s https://mrqz.me/coletor/api/v1/targets | jq '.data.activeTargets | length'

curl -s https://mrqz.me/coletor/api/v1/targets | jq '.data.activeTargets.labels.job'
