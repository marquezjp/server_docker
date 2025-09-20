# Prompt – Stack de Monitoramento

## Objetivo
Gerar todos os arquivos de configuração necessários para um stack completo de monitoramento, **compatível exatamente com o ambiente descrito em “Ambiente (imutável)”**, sem alterações ou variações não especificadas.  

Cada agente deve:  
1. Gerar seus arquivos de configuração completos e corretos.  
2. Entregar a saída em um **arquivo ZIP**, com a **estrutura de diretórios adequada** (`nginx/conf.d`, `prometheus/rules`, `grafana/provisioning/datasources`, etc.).  
3. Propor comandos de **validação unitária** para garantir que seu serviço sobe e responde corretamente.  
4. Fornecer documentação mínima de uso.  

Um agente dedicado (`Testes/Smoke`) será responsável por gerar os **testes de integração** para verificar a comunicação entre os serviços (ex.: Grafana acessando Prometheus, Loki recebendo logs do Promtail, Prometheus carregando regras, etc.).

---

## Ambiente (imutável)
- **Servidor**: Ubuntu Server 24.04  
- **Serviços**:  
  - **Cockpit** (instalado direto no host)  
  - **NGINX** (proxy reverso + site estático)  
  - **Portainer** (gestão de containers)  
  - **Grafana** (dashboards)  
  - **Prometheus** (coletor de métricas)  
  - **cAdvisor**, **node-exporter**, **apcupsd-exporter**, **dcgm-exporter**, **nginx-exporter**  
  - **Loki** + **Promtail** (logs centralizados)  

- **Padrões**:  
  - Publicação via **proxy reverso NGINX** usando **subpath** (`/infra`, `/painel`, `/coletor`, `/logs`)  
  - Certificados digitais usando **CA própria**  
  - Configurações baseadas em arquivos YAML, CONF ou similares  
  - Estrutura de diretórios conforme já validado no ambiente alvo  

---

## Agentes MCP

1. **Agente Docker Compose**  
   - Gera `docker-compose.yml` com todos os serviços configurados.  
   - Inclui volumes, redes, variáveis de ambiente e parâmetros de inicialização.  
   - **Validação**: `docker compose config` e `docker compose up -d` sem erros.

2. **Agente NGINX**  
   - Gera `conf.d/*.conf` e `snippets/*.conf`.  
   - Inclui certificados, proxy reverso, redirecionamentos, headers de segurança.  
   - **Validação**: `nginx -t` e `docker exec nginx curl -I https://mrqz.me`.

3. **Agente Prometheus**  
   - Gera `prometheus.yml` e `rules/*.yml`.  
   - Inclui jobs para todos os exporters e regras de alertas essenciais.  
   - **Validação**: `curl http://prometheus:9090/-/ready` deve retornar `200`.

4. **Agente Loki**  
   - Gera `loki/config.yml`.  
   - Configura retenção, compactor e paths corretos.  
   - **Validação**: `curl http://loki:3100/ready` → resposta `ready`.

5. **Agente Promtail**  
   - Gera `promtail/config.yml`.  
   - Inclui `linux-varlog` e `docker_sd` para enriquecer logs com labels.  
   - **Validação**: verificar `docker logs promtail` sem erros e labels em `/logs/loki/api/v1/labels`.

6. **Agente Grafana**  
   - Gera `provisioning/datasources/*.yml` e dashboards JSON básicos.  
   - Configura datasource Loki e Prometheus.  
   - **Validação**: painel acessível em `/painel` e datasources provisionados.

7. **Agente Testes/Smoke**  
   - Gera um script (`tests/smoke.sh`) com validações integradas:  
     - Grafana consegue listar datasources.  
     - Prometheus acessível em `/coletor/metrics`.  
     - Loki recebendo logs e labels de containers disponíveis.  
   - **Validação**: execução do script sem falhas.

---

## Formato de saída
- Cada agente deve fornecer sua contribuição em um **arquivo ZIP separado**, com a **estrutura de diretórios correta** já montada.  
- O agente `Testes/Smoke` gera também um ZIP com o script de integração.  
- Todos os arquivos devem estar prontos para uso imediato no ambiente alvo.  
