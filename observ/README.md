# README — Observabilidade do JotaPeServer (Ubuntu 24.04)

## Visão geral

**Objetivo:** expor serviços por **subpaths** via NGINX, coletar **métricas** (Prometheus + exporters), **dashboards** (Grafana) e **logs** (Loki + Promtail).

**Pilha principal**
- **Reverse proxy:** NGINX (`/infra` Portainer, `/painel` Grafana, `/coletor` Prometheus, `/logs` Loki)
- **Métricas:** Prometheus, cAdvisor, Node Exporter, DCGM Exporter (GPU), APC UPSD Exporter, NGINX Exporter
- **Dashboards:** Grafana (anônimo com role Viewer)
- **Logs:** Loki (single-tenant) + Promtail (host + Docker)
- **Admin containers:** Portainer
- **Admin host:** Cockpit (fora do proxy, porta 9090)

**URLs**
- Cockpit: `https://cockpit.mrqz.me:9090`
- Grafana: `https://mrqz.me/painel`
- Portainer: `https://mrqz.me/infra`
- Prometheus: `https://mrqz.me/coletor`
- Loki (API via proxy): `https://mrqz.me/logs/…` (ex.: `/logs/metrics`)

---

## 1) Pré-requisitos

- Docker & Docker Compose instalados.
- Network externa Docker criada: `proxy-network`.
- DNS local/arquivo `hosts` apontando `*.mrqz.me` para o IP do servidor.
- **CA interna** instalada nos clientes (Windows/Linux) — ver seção Certificados.
- Volumes Docker persistentes:
  - `portainer-data`, `grafana-data`, `prometheus-data`, `loki-data`.

---

## 2) Estrutura de diretórios

```
observ/
├─ docker-compose.yml
├─ nginx/
│  ├─ conf.d/
│  │  ├─ 00-default.conf
│  │  ├─ mrqz.me.conf
│  │  ├─ map.conf
│  │  └─ nginx-status.conf
│  ├─ snippets/
│  │  ├─ proxy-common.conf
│  │  └─ ssl-mrqz.conf
│  ├─ certs/
│  │  ├─ ca.crt
│  │  ├─ mrqz.me.key
│  │  └─ mrqz.me.fullchain.crt
│  └─ site/ (index.html + assets)
├─ prometheus/
│  ├─ prometheus.yml
│  └─ rules/
│     ├─ linux-alerts.yml
│     ├─ prometheus-alerts.yml
│     └─ nginx-alerts.yml
├─ grafana/
│  └─ provisioning/
│     └─ datasources/
│        └─ loki.yml
├─ loki/
│  └─ config.yml
└─ promtail/
   └─ config.yml
```

---

## 3) Certificados (CA própria)

### Gerar / revisar
```bash
chmod +x ./nginx/certs/gerar-ca-cert.sh
./nginx/certs/gerar-ca-cert.sh -d mrqz.me --wildcard --san "DNS:mrqz.me"
```

### Instalar CA no cliente
- **Windows (Admin PowerShell):**
```powershell
Import-Certificate -FilePath "P:\Projetos\JotaPeServer\certs\ca.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
```
- **Ubuntu (cliente):**
```bash
sudo cp ca.crt /usr/local/share/ca-certificates/mrqz-ca.crt
sudo update-ca-certificates
```

---

## 4) Deploy / Redeploy

```bash
# dentro de observ/
docker compose pull
docker compose up -d

# validar e recarregar NGINX
docker exec -it nginx nginx -t
docker exec -it nginx nginx -s reload
```

> Se mudou **subpaths** ou **certificados**, limpe cache DNS/navegador:
> - Chrome: `chrome://net-internals/#dns` → Clear host cache
> - Windows: `ipconfig /flushdns`

---

## 5) Checks rápidos (one-liners)

### NGINX (proxy e subpaths)
```bash
curl -I https://mrqz.me/             | head -n1   # 200
curl -I https://mrqz.me/infra/       | head -n1   # 200/302 (login Portainer)
curl -I https://mrqz.me/painel/      | head -n1   # 200/302 (/painel/login)
curl -I https://mrqz.me/coletor/-/ready           # 200
curl -I https://mrqz.me/logs/metrics              # 200
```

### Backends diretos (rede Docker)
```bash
docker exec -it nginx curl -sI http://grafana:3000/ | head -n1
docker exec -it nginx curl -sI http://prometheus:9090/-/ready | head -n1
docker exec -it nginx curl -s http://loki:3100/ready
```

### Exporters
```bash
curl -s http://localhost:9113/metrics | head   # nginx-exporter (se porta mapeada)
docker exec -it nginx curl -s http://nginx:8080/metrics | head  # stub_status/metrics interno
```

---

## 6) Parâmetros importantes (onde ajustar)

- **NGINX**
  - `nginx/conf.d/mrqz.me.conf`  
    - Blocos `location ^~ /infra/`, `/painel/`, `/coletor/`, `/logs/`  
    - **Não** coloque `/` no final do `proxy_pass` para Grafana/Prometheus (mantém subpath)!
    - `proxy_redirect` ajustando URLs absolutas.
  - `nginx/snippets/ssl-mrqz.conf`  
    - `mrqz.me.fullchain.crt` = **cert + intermediárias** (SEM CA raiz).
    - `ssl_trusted_certificate` aponta para `ca.crt` (validação OCSP/chain).

- **Grafana (subpath + anônimo)**
  - `GF_SERVER_ROOT_URL=https://mrqz.me/painel/`
  - `GF_SERVER_SERVE_FROM_SUB_PATH=true`
  - `GF_AUTH_ANONYMOUS_ENABLED=true` / `GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer`

- **Prometheus (subpath)**
  - `--web.external-url=https://mrqz.me/coletor`
  - `--web.route-prefix=/coletor`
  - Em `prometheus.yml`, o **próprio** scrape usa `metrics_path: /coletor/metrics`.

- **Loki + Promtail**
  - Loki: `auth_enabled: false` (single-tenant), retenção em `limits_config.retention_period`.
  - Promtail: volumes **obrigatórios**:
    - `/var/log` (host)
    - `/var/lib/docker/containers` (logs JSON)
    - `/var/run/docker.sock` (descoberta dinâmica)
  - Jobs `linux-varlog`, `docker`, `docker_sd` (com `relabel_configs`).

---

## 7) Operação diária

- **Status rápido:**
  - Prometheus Targets: `https://mrqz.me/coletor/targets`
  - Grafana Explore (Prometheus/Loki) via `https://mrqz.me/painel/explore`
- **Logs:**
  - Loki métricas: `https://mrqz.me/logs/metrics`
  - Explore (Loki) → `Label browser` deve listar `job, container_name, compose_service…`
- **Dashboards:**
  - Importar/versão de dashboards no Grafana (pastas + uids).
- **Alertas:**
  - Regras em `prometheus/rules/*.yml`.
  - Para notificações externas (Discord/Slack/Email), habilitar **Alertmanager** (fora do escopo aqui).

---

## 8) Rotina de upgrade

```bash
# salvar versão: git commit dos yml/conf
docker compose pull
docker compose up -d
# checar breaking changes nas notas de versão (Grafana/Prometheus/Loki)
```

> **Ordem sugerida:** Loki → Promtail → Exporters → Prometheus → Grafana → NGINX → Portainer.  
> (Sempre valide subpaths / datasources após subir Grafana.)

---

## 9) Backup & Restore

**Persistência:**
- Prometheus: `prometheus-data:/prometheus` (TSDB — não copie “quente” por muito tempo).
- Grafana: `grafana-data:/var/lib/grafana` (SQLite, snapshots consistentes).
- Loki: `loki-data:/loki` (chunks + index boltdb-shipper).

**Backups simples (snapshot frio):**
1. `docker compose down` (ou parar serviço individual na janela de manutenção).
2. `docker run --rm -v <volume>:/data -v $PWD:/backup alpine tar czf /backup/<vol>.tgz -C / data`
3. `docker compose up -d`

**Restore:** inverso do tar.

> Para Prometheus, preferir **retenção** controlada do TSDB (já configurada em 30d) em vez de backups frequentes.

---

## 10) Segurança

- **Senhas admin** fortes (Grafana/Portainer) — mesmo com anônimo no Grafana.
- **CA privada** só em dispositivos confiáveis.
- Considere **auth básica** no `/logs/` (Loki) se for expor para terceiros.
- Restrinja acesso ao endpoint `nginx-status.conf` (já com `allow/deny`).

---

## 11) Troubleshooting (erros comuns)

- **ERR_TOO_MANY_REDIRECTS** em `/painel` ou `/coletor`  
  → Garantir:
  - Grafana: `GF_SERVER_ROOT_URL=https://mrqz.me/painel/` (barra final!)
  - `proxy_pass http://grafana:3000` **sem** `/` no final.
  - Prometheus com `--web.external-url` + `--web.route-prefix` coerentes.
  - Recarregar NGINX e limpar cache DNS/navegador.

- **Loki “no org id”** no Explore  
  → Quando usa proxy `/logs/`, defina `proxy_set_header X-Scope-OrgID "1";` no bloco `/logs/` (como no `mrqz.me.conf`).  
  → Confirme que **datasource Loki** está provisionado (`grafana/provisioning/datasources/loki.yml`).

- **Loki só mostra `job` e `filename`**  
  → Verificar mounts do promtail: `/var/lib/docker/containers` e `/var/run/docker.sock`.  
  → Conferir `job_name: docker_sd` com `docker_sd_configs` e `relabel_configs`.

- **NGINX Exporter não coleta**  
  → Confirmar servidor interno `nginx-status.conf` ouvindo `8080` e `--nginx.scrape-uri=http://nginx:8080/metrics`.

- **Targets DOWN no Prometheus**  
  → `https://mrqz.me/coletor/targets` para ver erro de scrape.  
  → Testar direto do container Prometheus:
  ```bash
  docker exec -it prometheus sh -lc 'apk add --no-cache curl >/dev/null 2>&1 || true; curl -sI http://nginx-exporter:9113/metrics | head -n1'
  ```

---

## 12) Como (re)criar do zero — checklist rápido

1. Criar `proxy-network` (se não existir): `docker network create proxy-network`.
2. Gerar CA e wildcard `mrqz.me` → instalar CA nos clientes.
3. Colocar arquivos conforme estrutura (seção 2).
4. `docker compose up -d`.
5. Validar subpaths (seção 5).
6. Entrar no Grafana (`/painel`) → conferir datasources (Prometheus + Loki).
7. Abrir Explore (Prometheus/Loki) e rodar testes:
   - PromQL: `up`
   - LogQL: `{job="docker"}`.
8. Importar/ajustar dashboards e alertas conforme necessidade.

---

## 13) Notas de ajuste fino (quando necessário)

- **Retenção de logs** (Loki): `limits_config.retention_period` (p.ex. 7d → 30d).
- **Retenção de métricas** (Prometheus): `--storage.tsdb.retention.time`.
- **Thresholds de alertas** (`rules/*.yml`): CPU/mem/disk conforme perfil do servidor.
- **Subpaths extras**: copiar blocos `location` em `mrqz.me.conf`, manter padrão de `proxy_pass` e `proxy_redirect`.
