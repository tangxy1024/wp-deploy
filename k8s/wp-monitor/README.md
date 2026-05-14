# wp-monitor Helm Chart Values

本文档聚焦 `k8s/wp-monitor/values.yaml`，说明每个 values 分组控制的资源和默认行为。

## 安装

```bash
helm upgrade --install monitor ./k8s/wp-monitor -n default
```

使用自定义 values 文件：

```bash
helm upgrade --install monitor ./k8s/wp-monitor -n default -f my-values.yaml
```

渲染检查：

```bash
helm lint ./k8s/wp-monitor
helm template monitor ./k8s/wp-monitor >/dev/null
```

## Values 使用方式

- `global.retentionPeriod` 同时作用于 `victoria-metrics` 和 `victoria-logs`。
- `global.timezone` 同时注入到 `victoria-metrics` 和 `victoria-logs` 容器的 `TZ` 环境变量。
- `wpMonitor.enabled`、`victoriaMetrics.enabled`、`victoriaLogs.enabled` 可以分别关闭组件；但 `wp-monitor` 的配置文件始终会引用 metrics 和 logs 的 Service 名称，因此如果关闭后端组件，需要自行保证地址可达。
- `wpMonitor.ingress` 只为 `wp-monitor` Web UI 创建入口，不影响 `victoria-metrics` 和 `victoria-logs`。

## 通用 Values

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `nameOverride` | `""` | 覆盖 chart 名称。 |
| `fullnameOverride` | `""` | 覆盖完整资源名。 |
| `global.timezone` | `Asia/Shanghai` | Victoria 组件容器时区。 |
| `global.retentionPeriod` | `15d` | VictoriaMetrics / VictoriaLogs 数据保留时间。 |

## `victoriaMetrics`

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `victoriaMetrics.enabled` | `true` | 是否部署 `victoria-metrics`。 |
| `victoriaMetrics.image.repository` | `victoriametrics/victoria-metrics` | 镜像仓库。 |
| `victoriaMetrics.image.tag` | `v1.133.0` | 镜像标签。 |
| `victoriaMetrics.image.pullPolicy` | `IfNotPresent` | 拉取策略。 |
| `victoriaMetrics.service.type` | `ClusterIP` | Service 类型。 |
| `victoriaMetrics.service.port` | `8428` | HTTP 服务端口。 |
| `victoriaMetrics.persistence.enabled` | `true` | 是否创建 PVC 并挂载 `/storage`。 |
| `victoriaMetrics.persistence.accessModes` | `['ReadWriteOnce']` | PVC 访问模式。 |
| `victoriaMetrics.persistence.size` | `20Gi` | PVC 大小。 |
| `victoriaMetrics.persistence.storageClassName` | `""` | 指定 StorageClass；为空时使用集群默认值。 |
| `victoriaMetrics.resources` | `{}` | 容器资源限制与请求。 |

## `victoriaLogs`

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `victoriaLogs.enabled` | `true` | 是否部署 `victoria-logs`。 |
| `victoriaLogs.image.repository` | `victoriametrics/victoria-logs` | 镜像仓库。 |
| `victoriaLogs.image.tag` | `v1.43.0` | 镜像标签。 |
| `victoriaLogs.image.pullPolicy` | `IfNotPresent` | 拉取策略。 |
| `victoriaLogs.service.type` | `ClusterIP` | Service 类型。 |
| `victoriaLogs.service.port` | `9428` | HTTP 服务端口。 |
| `victoriaLogs.persistence.enabled` | `true` | 是否创建 PVC 并挂载 `/storage`。 |
| `victoriaLogs.persistence.accessModes` | `['ReadWriteOnce']` | PVC 访问模式。 |
| `victoriaLogs.persistence.size` | `50Gi` | PVC 大小。 |
| `victoriaLogs.persistence.storageClassName` | `""` | 指定 StorageClass；为空时使用集群默认值。 |
| `victoriaLogs.maxDiskSpaceUsageBytes` | `50GiB` | 传给 `--retention.maxDiskSpaceUsageBytes` 的值。 |
| `victoriaLogs.resources` | `{}` | 容器资源限制与请求。 |

## `wpMonitor`

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wpMonitor.enabled` | `true` | 是否部署 `wp-monitor`。 |
| `wpMonitor.replicaCount` | `1` | `wp-monitor` 副本数。 |
| `wpMonitor.image.repository` | `ghcr.io/wp-labs/wp-monitor` | 镜像仓库。 |
| `wpMonitor.image.tag` | `v0.7.1-alpha` | 镜像标签。 |
| `wpMonitor.image.pullPolicy` | `IfNotPresent` | 拉取策略。 |
| `wpMonitor.service.type` | `NodePort` | Web Service 类型。 |
| `wpMonitor.service.nodePort` | `38080` | 仅当 Service 类型为 `NodePort` 时生效。 |
| `wpMonitor.service.port` | `18080` | Web Service 端口，同时也是容器暴露端口。 |
| `wpMonitor.resources` | `{}` | 容器资源限制与请求。 |
| `wpMonitor.podAnnotations` | `{}` | Pod 注解。 |
| `wpMonitor.podLabels` | `{}` | Pod 标签。 |
| `wpMonitor.nodeSelector` | `{}` | 节点选择器。 |
| `wpMonitor.tolerations` | `[]` | 容忍配置。 |
| `wpMonitor.affinity` | `{}` | 亲和性配置。 |
| `wpMonitor.ingress.enabled` | `false` | 是否创建 Ingress。 |
| `wpMonitor.ingress.className` | `""` | IngressClass 名称。 |
| `wpMonitor.ingress.annotations` | `{}` | Ingress 注解。 |
| `wpMonitor.ingress.hosts` | `wp-monitor.local` | Ingress 主机名与路径列表。 |
| `wpMonitor.ingress.tls` | `[]` | Ingress TLS 配置。 |

## 覆盖示例

### 1. 缩短数据保留时间

```yaml
global:
  retentionPeriod: 7d
```

### 2. 调整 PVC 大小

```yaml
victoriaMetrics:
  persistence:
    size: 10Gi

victoriaLogs:
  persistence:
    size: 20Gi
    maxDiskSpaceUsageBytes: 20GiB
```

### 3. 改为 Ingress 暴露 UI

```yaml
wpMonitor:
  service:
    type: ClusterIP
    port: 18080
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: wp-monitor.local
        paths:
          - path: /
            pathType: Prefix
```

### 4. 关闭内置后端，只部署 UI

```yaml
victoriaMetrics:
  enabled: false

victoriaLogs:
  enabled: false
```

如果这样使用，需要自行保证 `wp-monitor` 最终能访问到可用的 metrics / logs 地址；否则页面请求会失败。
