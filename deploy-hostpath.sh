#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

NAMESPACE="${NAMESPACE:-default}"
TIMEOUT="${TIMEOUT:-30s}"
DRY_RUN="${DRY_RUN:-0}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
TMP_DIR=""
HELM_KUBE_ARGS=()

if [ -n "${KUBECONFIG_PATH}" ]; then
  HELM_KUBE_ARGS+=(--kubeconfig "${KUBECONFIG_PATH}")
fi

usage() {
  cat <<EOF
Usage: $0 [install|uninstall]

Commands:
  install     部署 wp-monitor、wparse、wp-station（默认）
  uninstall   卸载 wp-station、wparse、wp-monitor，不删除 hostPath 数据目录

Environment:
  NAMESPACE   Kubernetes namespace，默认 default
  TIMEOUT     Helm 等待超时，默认 30s
  DRY_RUN     设置为 1 时只渲染/打印操作，不实际部署或卸载
  KUBECONFIG_PATH  kubeconfig 文件路径；也可以直接使用 Helm 原生 KUBECONFIG 环境变量
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1" >&2
    exit 1
  fi
}

validate_kubeconfig() {
  if [ -n "${KUBECONFIG_PATH}" ] && [ ! -f "${KUBECONFIG_PATH}" ]; then
    echo "找不到 kubeconfig: ${KUBECONFIG_PATH}" >&2
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
    type: hostpath
    path: "$(yaml_escape "${persistence_root}/victoria-metrics")"
  nodeSelector:
    "kubernetes.io/hostname": "$(yaml_escape "${node_name}")"

victoriaLogs:
  persistence:
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
  helm "${HELM_KUBE_ARGS[@]}" upgrade --install "${release}" "${chart}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}" \
    "$@"
}

helm_uninstall() {
  local release="$1"

  if [ "${DRY_RUN}" = "1" ]; then
    echo "DRY_RUN: helm ${HELM_KUBE_ARGS[*]} uninstall ${release} --namespace ${NAMESPACE}"
    return 0
  fi

  if helm "${HELM_KUBE_ARGS[@]}" status "${release}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "卸载 ${release}"
    helm "${HELM_KUBE_ARGS[@]}" uninstall "${release}" --namespace "${NAMESPACE}"
  else
    echo "跳过 ${release}: release 不存在"
  fi
}

uninstall() {
  require_cmd helm
  validate_kubeconfig

  echo "卸载 namespace: ${NAMESPACE}"
  helm_uninstall wp-station
  helm_uninstall wparse
  helm_uninstall wp-monitor
  echo "卸载完成；hostPath 数据目录不会被删除。"
}

install() {
  require_cmd helm
  require_cmd hostname
  require_cmd sed
  validate_kubeconfig

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
  persistence_root="$(prompt_path "持久化根目录" "${PACKAGE_ROOT}/data")"

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

main() {
  local command="${1:-install}"

  case "${command}" in
    install)
      install
      ;;
    uninstall)
      uninstall
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "未知命令: ${command}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
