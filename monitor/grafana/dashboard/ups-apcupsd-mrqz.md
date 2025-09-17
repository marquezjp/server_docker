# DASHBOARD UPS (APCUPSD) — VERSÃO DOCUMENTADA (APENAS LEITURA).

Organização (mental model)

Linha 1 (visão executiva): Status + Bateria + Autonomia + Carga

Linha 2 (elétrico): Tensão de entrada vs nominal + Tensão da bateria

Linha 3 (ambiente & inventário): Temperatura + Tabela com modelo/hostname/potência

variáveis: só instance (evitar usar labels que nem sempre existem, como hostname).
anotação: ONBATT para investigar quedas.
unidades corretas em cada painel (%, m, V, °C).

## Metadados (uid, title, tags, schemaVersion)

dentificação e versão do dashboard.

```json
{
  "title": "APC UPS (APCUPSD) - MRQZ (doc)",
  "uid": "ups-apcupsd-v3-doc",
  "tags": ["ups","doc"],
  "timezone": "browser",
  "schemaVersion": 38,
  "version": 3,
  "style": "dark",
  "editable": true,
  "refresh": "10s"
 }
```

## Inputs/Requires - Dependências (datasource Prometheus no exemplo).

Declara que este dashboard precisa de um datasource Prometheus.

```json
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
```

## Lista de componentes necessários (painéis e datasource).

```json
  "__requires": [
    { "type": "grafana","id": "grafana","name": "Grafana","version": "9.5.0" },
    { "type": "datasource","id": "prometheus","name": "Prometheus","version": "2.9.0" },
    { "type": "panel","id": "stat","name": "Stat","version": "" },
    { "type": "panel","id": "gauge","name": "Gauge","version": "" },
    { "type": "panel","id": "timeseries","name": "Time series","version": "" },
    { "type": "panel","id": "table","name": "Table","version": "" }
  ],
```

## Anotações 

Eventos automáticos ou manuais na timeline.

Anotação interna do Grafana (alertas etc.) — fica oculta.

Anotação automática sempre que apcupsd_ups_status==ONBATT (queda de energia).

```json
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      },
      {
        "name": "ONBATT events",
        "type": "tags",
        "datasource": "${DS_PROMETHEUS}",
        "enable": true,
        "expr": "apcupsd_ups_status{status=\"ONBATT\",instance=~\"$instance\"} == 1",
        "iconColor": "rgba(255, 96, 96, 1)",
        "titleFormat": "UPS em bateria (ONBATT)",
        "textFormat": "UPS entrou em ONBATT"
      }
    ]
  },
```

## Variável

Dropdowns para filtrar instâncias, jobs, hosts etc.

Variável para escolher o datasource Prometheus.

Variável principal — filtra por instance (ex.: apcupsd:9162). Usa All= .* por padrão.

```json
  "templating": {
    "list": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "label": "Datasource",
        "query": "prometheus",
        "current": { "selected": true },
        "hide": 0
      },
      {
        "name": "instance",
        "type": "query",
        "label": "Instance",
        "datasource": "${DS_PROMETHEUS}",
        "includeAll": true,
        "multi": false,
        "query": "label_values(apcupsd_ups_info, instance)",
        "refresh": 1,
        "sort": 1,
        "current": { "selected": true, "text": "All", "value": ".*" }
      }
    ]
  },
```

## Time/Timepicker - Intervalo padrão e refresh.

```json
  "time": { "from": "now-6h", "to": "now" },
  "timepicker": { "refresh_intervals": ["5s","10s","15s","30s","1m","5m"] },
```

## Paines

Gráficos, gauges, stats. Cada painel tem type, title, targets (queries) e fieldConfig.

```json
  "panels": [
  ]
```

### BLOCO SUPERIOR — visão rápida de saúde do UPS
```json
    {
      "title": "UPS Status",
      "type": "stat",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
      "targets": [
        {
          "expr": "max by (status) (apcupsd_ups_status{instance=~\"$instance\"} == 1)",
          "legendFormat": "{{status}}",
          "refId": "A"
        }
      ],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"], "values": false }, "textMode": "name", "graphMode": "none" }
    },
    {
      "title": "Bateria (%)",
      "type": "gauge",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 6, "w": 6, "x": 6, "y": 0 },
      "targets": [ { "expr": "apcupsd_battery_charge_percent{instance=~\"$instance\"}", "refId": "A" } ],
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "max": 100 } }
    },
    {
      "title": "Autonomia (min)",
      "type": "gauge",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 6, "w": 6, "x": 12, "y": 0 },
      "targets": [ { "expr": "apcupsd_battery_time_left_seconds{instance=~\"$instance\"} / 60", "refId": "A" } ],
      "fieldConfig": { "defaults": { "unit": "m", "min": 0 } }
    },
    {
      "title": "Carga do UPS (%)",
      "type": "gauge",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 6, "w": 6, "x": 18, "y": 0 },
      "targets": [ { "expr": "apcupsd_ups_load_percent{instance=~\"$instance\"}", "refId": "A" } ],
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "max": 100 } }
    }
```

### BLOCO MÉDIO — elétrico

```json
    {
      "title": "Tensão de entrada (V)",
      "type": "timeseries",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 6 },
      "targets": [
        { "expr": "apcupsd_line_volts{instance=~\"$instance\"}", "legendFormat": "LINEV", "refId": "A" },
        { "expr": "apcupsd_line_nominal_volts{instance=~\"$instance\"}", "legendFormat": "NOMINAL", "refId": "B" }
      ],
      "fieldConfig": { "defaults": { "unit": "volt", "decimals": 1 } }
    },
    {
      "title": "Tensão da bateria (V)",
      "type": "timeseries",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 6 },
      "targets": [ { "expr": "apcupsd_battery_volts{instance=~\"$instance\"}", "legendFormat": "BATTV", "refId": "A" } ],
      "fieldConfig": { "defaults": { "unit": "volt", "decimals": 1 } }
    }
```

### BLOCO INFERIOR — ambiente e inventário

```json
    {
      "title": "Temperatura da bateria (°C)",
      "type": "timeseries",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 14 },
      "targets": [ { "expr": "apcupsd_battery_temperature_celsius{instance=~\"$instance\"}", "legendFormat": "TEMP", "refId": "A" } ],
      "fieldConfig": { "defaults": { "unit": "celsius", "decimals": 1 } }
    },
    {
      "title": "Informações do UPS",
      "type": "table",
      "datasource": "${DS_PROMETHEUS}",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 14 },
      "targets": [
        { "expr": "apcupsd_ups_info{instance=~\"$instance\"}", "refId": "A", "format": "table" },
        { "expr": "apcupsd_apcupsd_nominal_power_watts{instance=~\"$instance\"}", "refId": "B", "format": "table" }
      ],
      "transformations": [
        { "id": "labelsToFields", "options": {} },
        { "id": "merge", "options": {} },
        { "id": "organize", "options": { "renameByName": { "model": "Modelo", "hostname": "Hostname", "ups_name": "UPS Name", "apcupsd_apcupsd_nominal_power_watts": "Potência Nominal (W)" } } }
      ]
    }
```