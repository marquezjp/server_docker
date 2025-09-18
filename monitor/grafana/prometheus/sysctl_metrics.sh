#!/usr/bin/env bash
# Gera /opt/node-exporter-textfile/sysctl.prom com métricas dos sysctl desejados
OUT="/opt/node-exporter-textfile/sysctl.prom"
TMP="$(mktemp)"
metric() {
  # $1 nome_metrica  $2 valor  $3 help  $4 type (gauge)
  echo "# HELP $1 $3" >> "$TMP"
  echo "# TYPE $1 ${4:-gauge}" >> "$TMP"
  echo "$1 $2" >> "$TMP"
}

read_sysctl() { sysctl -n "$1" 2>/dev/null || echo ""; }

# --- VM ---
metric sysctl_vm_swappiness          "$(read_sysctl vm.swappiness)"          "vm.swappiness"
metric sysctl_vm_overcommit_memory   "$(read_sysctl vm.overcommit_memory)"   "vm.overcommit_memory"
metric sysctl_vm_max_map_count       "$(read_sysctl vm.max_map_count)"       "vm.max_map_count"

# --- NET ---
metric sysctl_net_ipv4_ip_forward                "$(read_sysctl net.ipv4.ip_forward)" "net.ipv4.ip_forward"
metric sysctl_net_bridge_nf_call_iptables        "$(read_sysctl net.bridge.bridge-nf-call-iptables)" "net.bridge.bridge-nf-call-iptables"

# --- ORACLE / IPC ---
metric sysctl_kernel_shmmax          "$(read_sysctl kernel.shmmax)"          "kernel.shmmax"
metric sysctl_kernel_shmall          "$(read_sysctl kernel.shmall)"          "kernel.shmall"

# kernel.sem retorna "SEMMSL SEMMNS SEMOPM SEMMNI" -> exportar cada campo
SEM="$(read_sysctl kernel.sem)"
if [ -n "$SEM" ]; then
  read -r SEMMSL SEMMNS SEMOPM SEMMNI <<< "$SEM"
  metric sysctl_kernel_sem_semsl "$SEMMSL" "kernel.sem SEMMSL"
  metric sysctl_kernel_sem_semmns "$SEMMNS" "kernel.sem SEMMNS"
  metric sysctl_kernel_sem_semopm "$SEMOPM" "kernel.sem SEMOPM"
  metric sysctl_kernel_sem_semmni "$SEMMNI" "kernel.sem SEMMNI"
fi

# --- Feito ---
mv "$TMP" "$OUT"
