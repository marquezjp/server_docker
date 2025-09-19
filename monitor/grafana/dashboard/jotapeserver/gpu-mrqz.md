# Dashboard para avaliar uso da RTX 4070 em cargas de IA via dcgm-exporter

Capacidade & Gargalo (utilização da GPU/SM, uso de memória em GiB e %)
Saúde & Limites (temperatura, potência, clocks, throttling PCIe)
(opcional) métricas de profiling PROF_… se você habilitar no dcgm-exporter

## 1) Indicadores essenciais (mínimo viável para IA)

### Utilização de GPU (SM)

GPU Util (%) – quão ocupadas as SMs estão.
```promql
DCGM_FI_DEV_GPU_UTIL{instance=~"$instance", gpu=~"$gpu"}
```

SM Occupancy (%) (se profiling habilitado) – ocupação efetiva das SMs.
```promql
DCGM_FI_PROF_SM_OCCUPANCY{instance=~"$instance", gpu=~"$gpu"}
```

## Memória

VRAM Usada (GiB)
```promql
DCGM_FI_DEV_FB_USED{instance=~"$instance", gpu=~"$gpu"}
```

VRAM Usada (%)
```promql
100 * DCGM_FI_DEV_FB_USED{instance=~"$instance",gpu=~"$gpu"}
    / DCGM_FI_DEV_FB_TOTAL{instance=~"$instance",gpu=~"$gpu"}

100 * DCGM_FI_DEV_FB_USED{instance=~"$instance", gpu=~"$gpu"}
    / (   DCGM_FI_DEV_FB_USED{instance=~"$instance", gpu=~"$gpu"}
        + DCGM_FI_DEV_FB_FREE{instance=~"$instance", gpu=~"$gpu"}
      )
```

BAR1 Usado (útil para checar mapeamento host↔GPU em cargas específicas):
```promql
DCGM_FI_DEV_BAR1_USED{instance=~"$instance", gpu=~"$gpu"}
```

### Throughput de memória / cópias

Mem Copy Util (%) – indica cópia de/para VRAM (pode sinalizar gargalo de input pipeline).
```promql
DCGM_FI_DEV_MEM_COPY_UTIL{instance=~"$instance", gpu=~"$gpu"}
```

### Temperatura / Potência / Clocks

Temperatura (°C)
```promql
DCGM_FI_DEV_GPU_TEMP{instance=~"$instance", gpu=~"$gpu"}
```

Potência (W) e % do limite
```promql
DCGM_FI_DEV_POWER_USAGE{instance=~"$instance", gpu=~"$gpu"}                                   # W
100 * DCGM_FI_DEV_POWER_USAGE{instance=~"$instance",gpu=~"$gpu"}
    / DCGM_FI_DEV_POWER_MGMT_LIMIT_MAX{instance=~"$instance",gpu=~"$gpu"}                     # %
```

Clocks (SM/MEM)
```promql
DCGM_FI_DEV_SM_CLOCK{instance=~"$instance", gpu=~"$gpu"}   # Hz
DCGM_FI_DEV_MEM_CLOCK{instance=~"$instance", gpu=~"$gpu"}  # Hz
```

### PCIe

PCIe RX/TX (B/s) – atenção quando o pipeline depende fortemente de carregamento de dados.
```promql
DCGM_FI_DEV_PCIE_RX_THROUGHPUT{instance=~"$instance", gpu=~"$gpu"}
DCGM_FI_DEV_PCIE_TX_THROUGHPUT{instance=~"$instance", gpu=~"$gpu"}
```

### Qualidade/Erros (quando disponíveis)

Xid Errors (graves, indicam falhas do driver/hardware):
```promql
increase(DCGM_FI_DEV_XID_ERRORS{instance=~"$instance",gpu=~"$gpu"}[15m])
```

Páginas aposentadas (ECC/instabilidade) — pode não existir em 4070:
```promql
DCGM_FI_DEV_RETIRED_PENDING{instance=~"$instance", gpu=~"$gpu"}
```

## 2) Indicadores “de IA” via Profiling (opcionais, mas valiosos)

### Requer habilitar o grupo de coletores de profiling no dcgm-exporter.

Tensor Core Active (%)
```promql
DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{instance=~"$instance", gpu=~"$gpu"}
```

FP16/TF32/FP32 Active (%) – mix de precisão:
```promql
DCGM_FI_PROF_PIPE_FP16_ACTIVE{instance=~"$instance", gpu=~"$gpu"}
DCGM_FI_PROF_PIPE_TF32_ACTIVE{instance=~"$instance", gpu=~"$gpu"}
DCGM_FI_PROF_PIPE_FP32_ACTIVE{instance=~"$instance", gpu=~"$gpu"}
```

DRAM Active (%) – atividade na memória global:
```promql
DCGM_FI_PROF_DRAM_ACTIVE{instance=~"$instance", gpu=~"$gpu"}
```

L2 Throughput (se exposto no seu collector de profiling):
```promql
DCGM_FI_PROF_L2_TEX_READ_BYTES{...}, DCGM_FI_PROF_L2_TEX_WRITE_BYTES{...}
```

## 3) Dashboard simples (layout sugerido)

### Variáveis:

```promql
$instance = label_values(DCGM_FI_DEV_GPU_UTIL, instance) (All por padrão)
```promql

```promql
$gpu = label_values(DCGM_FI_DEV_GPU_UTIL{instance=~"$instance"}, gpu) (All por padrão)

### Linha 1 – Visão executiva

Gauge: GPU Util %
```promql
DCGM_FI_DEV_GPU_UTIL{instance=~"$instance", gpu=~"$gpu"}
```

Gauge: VRAM %
```promql
100 * DCGM_FI_DEV_FB_USED{...} / DCGM_FI_DEV_FB_TOTAL{...}
```

Gauge: Mem Copy Util %
```promql
DCGM_FI_DEV_MEM_COPY_UTIL{...}
```

Gauge: Temp (°C)
```promql
DCGM_FI_DEV_GPU_TEMP{...}
```

### Linha 2 – Série temporal

Timeseries: GPU Util / MemCopy / (Tensor, se houver)
```promql
DCGM_FI_DEV_GPU_UTIL{...}, DCGM_FI_DEV_MEM_COPY_UTIL{...}, DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{...}
```

Timeseries: VRAM usada vs total
```promql
DCGM_FI_DEV_FB_USED{...}, DCGM_FI_DEV_FB_TOTAL{...}
```

Timeseries: Potência (W) & Limite
```promql
DCGM_FI_DEV_POWER_USAGE{...}, DCGM_FI_DEV_POWER_MGMT_LIMIT_MAX{...}
```

### Linha 3 – I/O e Clocks

Timeseries: PCIe RX/TX (B/s)
```promql
DCGM_FI_DEV_PCIE_RX_THROUGHPUT{...}, ...TX...
```

Timeseries: Clocks SM/MEM
```promql
DCGM_FI_DEV_SM_CLOCK{...}, DCGM_FI_DEV_MEM_CLOCK{...}
```

### Linha 4 – Saúde / Inventário

Stat/Table: Xid Errors (Δ 15m)
```promql
increase(DCGM_FI_DEV_XID_ERRORS{...}[15m])
```

Table: GPU Info (labels modelName, uuid, hostname) — puxe de qualquer métrica DCGM e transforme labels em colunas.

## 4) Alertas sugeridos (Prometheus)

GPU Util > 95% por 5 min (quente):
```promql
avg_over_time(DCGM_FI_DEV_GPU_UTIL{instance=~"$instance"}[5m]) > 95
```

VRAM > 95% por 5 min (pode estourar OOM):
```promql
100 * DCGM_FI_DEV_FB_USED{...} / DCGM_FI_DEV_FB_TOTAL{...} > 95
```

Temp > 83 °C por 2 min (limiar típico de boost/thermal throttling):
```promql
DCGM_FI_DEV_GPU_TEMP{...} > 83
```

Potência > 95% do limite por 2 min (power cap atingindo com frequência):
```promql
100 * DCGM_FI_DEV_POWER_USAGE{...} / DCGM_FI_DEV_POWER_MGMT_LIMIT_MAX{...} > 95
```

Xid Errors (Δ15m) > 0 (falha/instabilidade):
```promql
increase(DCGM_FI_DEV_XID_ERRORS{...}[15m]) > 0
```
