
# Serviços de Monitoramento do Servidor JotaPeServer Ubuntu Server 24.04

## Arquivo docker-compose.yml

```yml
services:
  # Reverse proxy NGINX
  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/snippets:/etc/nginx/snippets:ro
      - ./nginx/certs:/etc/nginx/certs:ro
      - ./nginx/site:/var/www/mrqz.me:ro
    networks:
      - proxy-network

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    hostname: portainer
    restart: unless-stopped
#    ports:
#      - 8000:8000
#      - 9000:9000
#      - 9443:9443
    environment:
      ADMIN_PASSWORD: jquest
    command:
      # Se for publicar atrás de proxy via subpath 
      - '--base-url=/infra'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer-data:/data
    networks:
      - proxy-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
#    ports:
#      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=marquezjp
      - GF_SECURITY_ADMIN_PASSWORD=jquest
      - GF_USERS_ALLOW_SIGN_UP=false
      # Se for publicar atrás de proxy
      #- GF_SERVER_ROOT_URL=https://grafana.mrqz.me
      #- GF_SERVER_DOMAIN=grafana.mrqz.me
      # Se for publicar atrás de proxy via subpath 
      - GF_SERVER_ROOT_URL=https://mrqz.me/painel/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      # Habilita Usuário Anônimo
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana-data:/var/lib/grafana
    networks:
      - proxy-network

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
#    ports:
#      - "9091:9090"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9090/-/ready || exit 1"]
#      test: ["CMD-SHELL", "exit 0"]
      interval: 30s
      timeout: 10s
      retries: 3
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--log.level=warn'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      # Retenção mais segura para não crescer infinito (ajuste conforme disco)
      - '--storage.tsdb.retention.time=30d'
      # Se for publicar atrás de proxy via subpath 
      - '--web.external-url=https://mrqz.me/coletor'
      - '--web.route-prefix=/coletor'
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    networks:
      - proxy-network

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    devices:
      - /dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - proxy-network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    command:
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--path.procfs=/host/proc'
      - '--collector.processes'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
      - '--collector.filesystem.ignored-fs-types=^(autofs|proc|sysfs|cgroup.*|overlay|squashfs|tmpfs|devtmpfs|nsfs|tracefs)$$'
      - '--no-collector.ipvs'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - proxy-network

# Exporta /metrics do apcupsd (rodando no host)
  apcupsd:
    image: jangrewe/apcupsd-exporter:latest
    container_name: apcupsd
    restart: unless-stopped
    network_mode: "host"

  dcgm-exporter:
    image: nvidia/dcgm-exporter:4.4.0-4.5.0-ubuntu22.04
    container_name: dcgm-exporter
    hostname: dcgm-exporter
    restart: unless-stopped
    runtime: nvidia
    deploy:
        resources:
          reservations:
            devices:
              - capabilities: [gpu]
    cap_add:
      - SYS_ADMIN
#    ports:
#      - "9400:9400"
    environment:
      - DCGM_EXPORTER_LISTEN=0.0.0.0:9400
      - DCGM_EXPORTER_KUBERNETES=false
    networks:
      - proxy-network

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    restart: unless-stopped
    ports:
      - "9113:9113"
    command:
      - --nginx.scrape-uri=http://nginx:8080/metrics
      - --web.listen-address=:9113
    networks:
      - proxy-network

  loki:
    image: grafana/loki:2.9.8
    container_name: loki
    restart: unless-stopped
    command: [ "-config.file=/etc/loki/config/config.yml" ]
#    ports:
#      - "3100:3100"
    volumes:
      - ./loki/config.yml:/etc/loki/config/config.yml:ro
      - loki-data:/loki
    networks:
      - proxy-network

  promtail:
    image: grafana/promtail:2.9.8
    container_name: promtail
    restart: unless-stopped
    command: [ "-config.file=/etc/promtail/config.yml" ]
    volumes:
      # logs do Linux
      - /var/log:/host/var/log:ro
      # Descoberta Docker + leitura dos logs JSON dos containers
      # logs JSON dos containers Docker
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      # acesso ao Docker para service discovery
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # config do promtail
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
    networks:
      - proxy-network

volumes:
  portainer-data:
  prometheus-data:
  grafana-data:
  loki-data:

networks:
  proxy-network:
    external: true

# Gerar Autoridade Certificadora (CA) e Certificado Digital do Domínio
# chmod +x ~/docker/nginx/certs/gerar-ca-cert.sh
# ~/docker/nginx/certs/gerar-ca-cert.sh -d portainer.mrqz.me
# ~/docker/nginx/certs/gerar-ca-cert.sh -d mrqz.me --wildcard --san "DNS:mrqz.me"
# openssl s_client -connect portainer.mrqz.me:443 -servername portainer.mrqz.me </dev/null 2>/dev/null | openssl x509 -noout -text | grep -E 'Subject:|Issuer:|DNS:'

# Importar CA local no cliente Windows
# Import-Certificate -FilePath "P:\Projetos\JotaPeServer\certs\ca.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
# Win+R => mmc
# Importar CA local no cliente Ubuntu
# sudo cp ca.crt /usr/local/share/ca-certificates/mrqz-ca.crt
# sudo update-ca-certificates
# Validar o certificado
# curl -I https://portainer.mrqz.me
# curl -I https://portainer.mrqz.me --ssl-no-revoke
# curl -vk https://portainer.mrqz.me

# docker compose up -d
# docker compose logs -f nginx

# Validar & Recarregar NGINX
# docker exec -it nginx nginx -t
# docker exec -it nginx nginx -s reload
```

## Arquivo nginx/conf.d/mrqz.me.conf

```conf
# HTTP -> HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name mrqz.me www.mrqz.me;
    return 301 https://mrqz.me$request_uri;
}

# HTTPS - site estático
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;

    server_name mrqz.me;

    # TLS do site
    include /etc/nginx/snippets/ssl-mrqz.conf;

    # Raiz do site
    root /var/www/mrqz.me;
    index index.html;

    # Segurança leve (opcional)
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    # Cache estático simples
    location ~* \.(?:png|jpg|jpeg|gif|svg|webp|ico|css|js)$ {
        access_log off;
        expires 7d;
        add_header Cache-Control "public, max-age=604800, immutable";
        try_files $uri =404;
    }

    # HTML e demais (sem cache agressivo)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # PORTAINER: https://mrqz.me/infra
    location ^~ /infra/ {
        # Portainer com --base-url=/infra PRECISA que o proxy retire o prefixo
        # por isso usamos rewrite para o backend ver "/"
        rewrite ^/infra/(.*)$ /$1 break;
    
        proxy_pass http://portainer:9000/;
        include /etc/nginx/snippets/proxy-common.conf;
    
        proxy_set_header X-Forwarded-Prefix /infra;
        proxy_set_header X-Forwarded-Host   $host;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-Port   443;
    
        # Corrige Location de redirecionamentos
        proxy_redirect ~^http(s)?://[^/]+(/.*)$ https://$host/infra$2;
    }

    # GRAFANA: https://mrqz.me/painel
    # Redireciona /painel (sem /) para /painel/ para evitar loop
    location = /painel { return 308 /painel/; }
    
    location ^~ /painel/ {
        include /etc/nginx/snippets/proxy-common.conf;
    
        # Encaminha mantendo o subpath (Grafana já foi ajustado para servir sob /painel)
        # NÃO coloque barra no final => preserva /painel/... para o backend
        proxy_pass http://grafana:3000;
    
        # Cabeçalhos úteis
        proxy_set_header X-Forwarded-Prefix /painel;
        proxy_set_header X-Forwarded-Host   $host;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-Port   443;
    
        # Corrige redirecionamentos absolutos
        proxy_redirect ~^http(s)?://[^/]+(/.*)$ https://$host$2;
    }

    # PROMETHEUS: https://mrqz.me/coletor
    # Redireciona /coletor (sem /) para /coletor/ para evitar loop
    location = /coletor { return 308 /coletor/; }
    
    location ^~ /coletor/ {
        include /etc/nginx/snippets/proxy-common.conf;
    
        # Prometheus foi configurado c/ --web.external-url e --web.route-prefix /coletor
        # NÃO coloque barra no final => preserva /coletor/...
        proxy_pass http://prometheus:9090;
    
        # Segurança opcional (desabilitar frames, etc.)
        add_header X-Frame-Options SAMEORIGIN always;
    
        # Corrige redirecionamentos absolutos
        proxy_redirect ~^http(s)?://[^/]+(/.*)$ https://$host/coletor$2;
    }

    # redireciona /logs -> /logs/ (status 308 = redirect permanente preservando método)
    location = /logs { return 308 /logs/; }
    
    # proxy para Loki sob subpath /logs/
    location ^~ /logs/ {
      include /etc/nginx/snippets/proxy-common.conf;
    
      # envia para a raiz do Loki; o NGINX remove o prefixo /logs/ automaticamente
      proxy_pass http://loki:3100/;
    
      # Loki não usa redirects, então desligamos por segurança
      proxy_redirect off;
      proxy_set_header X-Scope-OrgID "1";
    
      # (opcional) proteção com Basic Auth
      # auth_basic "Logs Loki";
      # auth_basic_user_file /etc/nginx/.htpasswd;
    }


}
```

## Arquivo nginx/snippets/ssl-mrqz.conf

```conf
ssl_certificate           /etc/nginx/certs/mrqz.me.fullchain.crt;  # leaf (+ intermediária se existir), SEM root
ssl_certificate_key       /etc/nginx/certs/mrqz.me.key;
ssl_trusted_certificate   /etc/nginx/certs/ca.crt;                 # para OCSP/validação upstream
ssl_protocols             TLSv1.2 TLSv1.3;
```

## Arquivo nginx/snippets/proxy-common.conf

```conf
proxy_http_version 1.1;
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# WebSockets
proxy_set_header Upgrade   $http_upgrade;
proxy_set_header Connection $connection_upgrade;

# (Opcional) timeouts
proxy_read_timeout  300s;
proxy_send_timeout  300s;
```

## Arquivo nginx/conf.d/00-default.conf

```conf
# nginx/conf.d/00-default.conf
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl default_server;
  listen [::]:443 ssl default_server;
  include /etc/nginx/snippets/ssl-mrqz.conf;
  return 444;
}
```

## Arquivo nginx/conf.d/map.conf

```conf
map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}
```

## Arquivo nginx/conf.d/nginx-status.conf

```conf
# Endpoint interno para métricas (sem expor no host)
server {
  listen 8080;
  server_name _;

  location = /metrics {
    stub_status on;
    access_log off;

    # Libere redes internas conforme seu ambiente
    allow 127.0.0.1;
    allow 172.16.0.0/12;  # cobre 172.18.x da docker network
    allow 192.168.0.0/16; # sua LAN
    deny  all;
  }
}
```

## Arquivo promtail/config.yml

```yml
server:
  http_listen_port: 9080
  log_level: info

clients:
  - url: http://loki:3100/loki/api/v1/push
    # se você proteger o Loki no futuro com TLS/CA própria, ajustamos aqui

positions:
  filename: /tmp/positions.yaml

scrape_configs:
  # === Linux: /var/log ===
  - job_name: linux-varlog
    static_configs:
      - targets: [localhost]
        labels:
          job: linux-varlog
          host: ${HOSTNAME}
          __path__: /var/log/*.log

  # === Docker: containers ===
  # Lê arquivos JSON dos containers e usa docker_sd para rótulos úteis
  - job_name: docker
    pipeline_stages:
      - docker: {}    # decodifica o JSON de log padrão do Docker
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log

  # (opcional, mas recomendado) Descoberta dinâmica via Docker API
  # Isto injeta labels ricas, como compose_service, container_id/names, etc.
  - job_name: docker_sd
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    pipeline_stages:
      - docker: {}
    relabel_configs:
      # container_name legível (sem a barra inicial)
      - source_labels: ['__meta_docker_container_name']
        target_label: container_name
        regex: '/(.*)'
      # serviço do docker-compose, se existir
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: compose_service
      # stack do compose, se existir
      - source_labels: ['__meta_docker_container_label_com_docker_compose_project']
        target_label: compose_project
      # imagem e stream
      - source_labels: ['__meta_docker_container_image']
        target_label: image
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: stream
      # job consistente
      - target_label: job
        replacement: docker
```

## Arquivo loki/config.yml

```yml
server:
  http_listen_port: 3100

auth_enabled: false

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

# Esquema recomendado (boltdb-shipper)
schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

# Compactador + retenção (global)
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m

limits_config:
  retention_period: 168h   # 7 dias | ajuste conforme seu disco
  # limite de labels/streams para evitar cardinalidade explosiva (opcional)
  max_label_names_per_series: 30
  max_global_streams_per_user: 50000

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
```

## Arquivo prometheus/prometheus.yml

```yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - rules/*.yml

scrape_configs:
  - job_name: 'prometheus'
    # Se for publicar atrás de proxy via subpath 
    metrics_path: /coletor/metrics
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Docker Engine metrics (opcional, se habilitar no daemon.json)
  - job_name: 'docker'
    static_configs:
      - targets: ['172.17.0.1:9323']
    # /etc/docker/daemon.json
    # {
    #   "metrics-addr": "0.0.0.0:9323"
    # }
    # Dica: por segurança prefira "127.0.0.1:9323" e colete via host-gateway,
    # adicionando um endpoint do node-exporter textfile ou um socat local.

  - job_name: 'apcupsd'
    static_configs:
      - targets: ['172.17.0.1:9162']

  - job_name: 'dcgm-exporter'
    static_configs:
      - targets: ['dcgm-exporter:9400']
    metrics_path: /metrics
    scrape_timeout: 10s

  - job_name: 'nginx-exporter'
    static_configs:
      - targets: ['nginx-exporter:9113']
```

## Arquivo prometheus/rules/linux-alerts.yml

```yml
groups:
  - name: linux-alerts
    rules:
      # 1) Algum Target Caiu (qualquer job/instância)
      - alert: TargetDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Target DOWN (job={{ $labels.job }}, instance={{ $labels.instance }})"
          description: "O alvo {{ $labels.instance }} do job {{ $labels.job }} está indisponível há 2m."

      # 2) CPU Alta no Host
      # 100 * (1 - %idle) por instância
      - alert: HostHighCPU
        expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU alta no host ({{ $labels.instance }})"
          description: "Uso de CPU > 85% por 10m (valor: {{ printf \"%.1f\" $value }}%)."

      # 3) Memória Baixa no Host
      - alert: HostLowMemory
        expr: 100 * (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 10
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Memória livre baixa ({{ $labels.instance }})"
          description: "Memória disponível < 10% por 10m (valor: {{ printf \"%.1f\" $value }}%)."

      # 4) Disco Quase Cheio
      # Ignora fstype efêmeros; ajuste lista conforme necessário
      - alert: HostLowDiskSpace
        expr: 100 * (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs|nsfs|autofs"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|nsfs|autofs"}) < 10
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Espaço em disco crítico ({{ $labels.instance }} {{ $labels.mountpoint }})"
          description: "Menos de 10% livre em {{ $labels.mountpoint }} (valor: {{ printf \"%.1f\" $value }}%)."
```

## Arquivo prometheus/rules/prometheus-alerts.yml

```yml
groups:
  - name: prometheus-alerts
    rules:
      # 1) Falhas ao Avaliar Regras
      - alert: PrometheusRuleEvaluationFailures
        expr: increase(prometheus_rule_evaluation_failures_total[5m]) > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Falhas ao avaliar regras no Prometheus"
          description: "Houve falha(s) na avaliação de regras nos últimos 5m. Verifique logs/configuração."

      # 2) Prometheus sem Scrape de Targets
      - alert: PrometheusTargetMissing
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Target do Prometheus indisponível ({{ $labels.job }})"
          description: "O target {{ $labels.instance }} do job {{ $labels.job }} está DOWN há mais de 5m."

      # 3) Alto Número de Séries Temporais Ativas
      - alert: PrometheusHighSeriesCount
        expr: prometheus_tsdb_head_series > 1e6
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Número elevado de séries no Prometheus"
          description: "Prometheus está mantendo mais de 1 milhão de séries em memória por mais de 10m. Verifique jobs e labels."

      # 4) Alto Tempo de Scrape (Lento para coletar)
      - alert: PrometheusScrapeSlow
        expr: prometheus_target_interval_length_seconds{quantile="0.9"} > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Scrape lento do Prometheus"
          description: "90% dos scrapes do job {{ $labels.job }} estão levando mais de 10s por 5m."
```

## Arquivo prometheus/rules/nginx-alerts.yml

```yml
groups:
  - name: nginx-alerts
    rules:

    # Exporter/target fora do ar
    - alert: NginxExporterDown
      expr: up{job="nginx"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "NGINX exporter indisponível (job={{ $labels.job }})"
        description: "O alvo {{ $labels.instance }} do job {{ $labels.job }} está DOWN há 2 minutos."

    # Conexões ativas muito altas (ajuste o limiar à sua realidade)
    - alert: NginxActiveConnectionsHigh
      expr: nginx_connections_active{job="nginx"} > 200
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Muitas conexões ativas no NGINX"
        description: "nginx_connections_active={{ $value }} > 200 por 5m (ajuste o limite conforme sua carga)."

    # Sem tráfego (requests/s) por período — usa o que existir: http_requests_total OU requests_total
    - alert: NginxZeroRPS
      expr: (rate(nginx_http_requests_total{job="nginx"}[5m]) or rate(nginx_requests_total{job="nginx"}[5m])) == 0
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Sem requisições no NGINX"
        description: "Nenhuma requisição detectada pelo NGINX nos últimos 10 minutos."

    # Picos de leitura ou escrita (fila/latência no accept ou upstream)
    - alert: NginxReadingSpike
      expr: nginx_connections_reading{job="nginx"} > 20
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Muitas conexões em leitura (client -> NGINX)"
        description: "nginx_connections_reading={{ $value }} > 20 por 5m (ajuste o limite)."

    - alert: NginxWritingSpike
      expr: nginx_connections_writing{job="nginx"} > 50
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Muitas conexões em escrita (NGINX -> client)"
        description: "nginx_connections_writing={{ $value }} > 50 por 5m (ajuste o limite)."
```

## Arquivo prometheus/rules/docker-alerts.yml

```yml
groups:
  - name: docker-alerts
    rules:
      # 1) CPU Alta em Contêiner (cAdvisor)
      # rate(container_cpu_usage_seconds_total) ≈ cores usados.
      # Limiar >0.8 ~ >80% de 1 core por contêiner (ajuste conforme carga).
      - alert: ContainerHighCPU
        expr: sum by (instance, name) (rate(container_cpu_usage_seconds_total{image!=""}[5m])) > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU alta no contêiner ({{ $labels.name }})"
          description: "Uso de CPU > 0.8 core por 10m no contêiner {{ $labels.name }} (instância {{ $labels.instance }})."

      # 2) Uso de Memória Alto em Contêiner (cAdvisor)
      # (container_memory_usage_bytes{image!=""} / container_spec_memory_limit_bytes{image!=""}) > 0.9
      # Usando > 90% do limite de memória por 5m. (ajuste conforme carga).
      - alert: ContainerHighMemory
        expr: (container_memory_usage_bytes{image!=""} / container_spec_memory_limit_bytes{image!=""}) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memória alta no contêiner ({{ $labels.name }})"
          description: "Contêiner {{ $labels.name }} usando >90% do limite de memória por 5m."

      # 3) Contêiner Reiniciando Frequentemente (cAdvisor)
      # increase(container_restart_count_total[10m]) > 3
      # reiniciou mais de 3 vezes nos últimos 10m.
      - alert: ContainerRestartingFrequently
        expr: increase(container_restart_count_total[10m]) > 3
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Reinícios frequentes do contêiner ({{ $labels.name }})"
          description: "O contêiner {{ $labels.name }} reiniciou mais de 3 vezes nos últimos 10m. Verifique logs."
```

## Arquivo grafana/provisioning/datasources/loki.yml

```yml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    editable: true
```
