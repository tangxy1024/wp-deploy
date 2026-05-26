#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

NAMESPACE="${NAMESPACE:-default}"
TIMEOUT="${TIMEOUT:-10m}"
DRY_RUN="${DRY_RUN:-0}"
TMP_DIR=""

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1" >&2
    exit 1
  fi
}

prompt_path() {
  local prompt="$1"
  local default_value="$2"
  local input=""

  read -r -p "${prompt} [${default_value}]: " input
  if [ -z "${input}" ]; then
    input="${default_value}"
  fi

  if [[ "${input}" != /* ]]; then
    input="${PACKAGE_ROOT}/${input}"
  fi

  mkdir -p -- "${input}"
  (cd -- "${input}" && pwd -P)
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_wparse_values() {
  local file="$1"
  local config_path="$2"
  local node_name="$3"

  cat >"${file}" <<EOF
wparse:
  config:
    type: hostpath
    path: "$(yaml_escape "${config_path}")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"
EOF
}

write_wp_monitor_values() {
  local file="$1"
  local persistence_root="$2"
  local node_name="$3"

  cat >"${file}" <<EOF
victoriaMetrics:
  persistence:
    enabled: true
    type: hostpath
    path: "$(yaml_escape "${persistence_root}/victoria-metrics")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"

victoriaLogs:
  persistence:
    enabled: true
    type: hostpath
    path: "$(yaml_escape "${persistence_root}/victoria-logs")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"

wpMonitor:
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"
EOF
}

write_wp_station_values() {
  local file="$1"
  local default_configs_path="$2"
  local persistence_root="$3"
  local node_name="$4"

  cat >"${file}" <<EOF
station:
  defaultConfigs:
    type: hostpath
    path: "$(yaml_escape "${default_configs_path}")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"

postgres:
  persistence:
    type: hostpath
    path: "$(yaml_escape "${persistence_root}/postgres")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"

gitea:
  persistence:
    type: hostpath
    path: "$(yaml_escape "${persistence_root}/gitea")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"
EOF
}

helm_upgrade() {
  local release="$1"
  local chart="$2"
  local values_file="$3"
  shift 3

  echo "部署 ${release} -> ${chart}"
  helm upgrade --install "${release}" "${chart}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}" \
    "$@"
}

main() {
  require_cmd helm
  require_cmd hostname
  require_cmd sed

  local wparse_chart="${PACKAGE_ROOT}/helm/wparse"
  local wp_monitor_chart="${PACKAGE_ROOT}/helm/wp-monitor"
  local wp_station_chart="${PACKAGE_ROOT}/helm/wp-station"

  for chart in "${wparse_chart}" "${wp_monitor_chart}" "${wp_station_chart}"; do
    if [ ! -f "${chart}/Chart.yaml" ]; then
      echo "找不到 Helm Chart: ${chart}" >&2
      echo "请确认 deploy-hostpath.sh 与 helm/、wparse/、default-configs/ 位于同一目录。" >&2
      exit 1
    fi
  done

  local node_name
  node_name="$(hostname)"

  echo "当前 Kubernetes nodeSelector 主机名: ${node_name}"
  echo "部署 namespace: ${NAMESPACE}"

  local wparse_path default_configs_path persistence_root
  wparse_path="$(prompt_path "wparse 使用的 hostPath 位置" "${PACKAGE_ROOT}/wparse")"
  default_configs_path="$(prompt_path "default-configs 使用的 hostPath 位置" "${PACKAGE_ROOT}/default-configs")"
  persistence_root="$(prompt_path "持久化根目录" "/data")"

  mkdir -p -- \
    "${persistence_root}/postgres" \
    "${persistence_root}/gitea" \
    "${persistence_root}/victoria-metrics" \
    "${persistence_root}/victoria-logs"

  TMP_DIR="$(mktemp -d)"
  trap 'if [ -n "${TMP_DIR}" ]; then rm -rf "${TMP_DIR}"; fi' EXIT

  local wparse_values="${TMP_DIR}/wparse-values.yaml"
  local wp_monitor_values="${TMP_DIR}/wp-monitor-values.yaml"
  local wp_station_values="${TMP_DIR}/wp-station-values.yaml"

  write_wparse_values "${wparse_values}" "${wparse_path}" "${node_name}"
  write_wp_monitor_values "${wp_monitor_values}" "${persistence_root}" "${node_name}"
  write_wp_station_values "${wp_station_values}" "${default_configs_path}" "${persistence_root}" "${node_name}"

  local helm_args=()
  if [ "${DRY_RUN}" = "1" ]; then
    helm_args+=(--dry-run)
  else
    helm_args+=(--wait --timeout "${TIMEOUT}")
  fi

  helm_upgrade wp-monitor "${wp_monitor_chart}" "${wp_monitor_values}" "${helm_args[@]}"
  helm_upgrade wparse "${wparse_chart}" "${wparse_values}" "${helm_args[@]}"
  helm_upgrade wp-station "${wp_station_chart}" "${wp_station_values}" "${helm_args[@]}"

  echo "部署完成"
  echo "wparse hostPath: ${wparse_path}"
  echo "default-configs hostPath: ${default_configs_path}"
  echo "持久化根目录: ${persistence_root}"
}

main "$@"
