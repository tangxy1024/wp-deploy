# wp-station Helm Chart Values

本文档聚焦 `k8s/wp-station/values.yaml`，用于说明各个 values 分组控制的组件、默认值和常见覆盖方式。

## 安装

```bash
helm upgrade --install station ./k8s/wp-station
```

使用自定义 values 文件：

```bash
helm upgrade --install station ./k8s/wp-station -f my-values.yaml
```

渲染检查：

```bash
helm lint ./k8s/wp-station
helm template station ./k8s/wp-station >/dev/null
```

## Values 使用方式

- `replicaCount` 只对主应用 `station` 生效，且仅在 `station.autoscaling.enabled=false` 时使用。
- `station`、`postgres`、`gitea` 是三个独立组件，分别有自己的镜像、资源和调度配置。
- `station.monitorUrl`、`postgres.*`、`gitea.*` 不只是文档字段，模板会将它们转成容器环境变量或初始化配置。
- `station.toolchainImage` 和 `station.initImage` 只用于 initContainer，不会影响主应用镜像。

## 全局 Values

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `replicaCount` | `1` | `station` 主应用副本数；关闭 HPA 时生效。 |
| `imagePullSecrets` | `[]` | 主应用 Pod 的 `imagePullSecrets`。 |
| `nameOverride` | `""` | 覆盖 chart 名称。 |
| `fullnameOverride` | `""` | 覆盖完整资源名。 |
| `serviceAccount.create` | `true` | 是否创建主应用 ServiceAccount。 |
| `serviceAccount.automount` | `true` | 是否自动挂载 ServiceAccount Token。 |
| `serviceAccount.annotations` | `{}` | ServiceAccount 注解。 |
| `serviceAccount.name` | `""` | 指定已有 ServiceAccount 名称；为空时按模板生成。 |

## `station`

### 镜像与核心配置

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `station.image.repository` | `ghcr.io/wp-labs/wp-station` | 主应用镜像仓库。 |
| `station.image.tag` | `v0.1.11-alpha` | 主应用镜像标签。 |
| `station.image.pullPolicy` | `IfNotPresent` | 主应用拉取策略。 |
| `station.toolchainImage.repository` | `ghcr.io/wp-labs/warp-parse` | toolchain initContainer 镜像仓库。 |
| `station.toolchainImage.tag` | `0.23.8-alpha` | toolchain initContainer 镜像标签。 |
| `station.toolchainImage.pullPolicy` | `IfNotPresent` | toolchain initContainer 拉取策略。 |
| `station.initImage.repository` | `busybox` | 等待依赖 / 初始化目录的 initContainer 镜像仓库。 |
| `station.initImage.tag` | `1.36` | initContainer 镜像标签。 |
| `station.initImage.pullPolicy` | `IfNotPresent` | initContainer 拉取策略。 |
| `station.web.host` | `0.0.0.0` | 注入 `WP_STATION_WEB__HOST`。 |
| `station.web.port` | `8081` | 注入 `WP_STATION_WEB__PORT`，同时作为主容器暴露端口。 |
| `station.log.level` | `debug` | 写入生成的 `config.toml`。 |
| `station.git.userName` | `WarpStation` | 启动时执行 `git config --global user.name`。 |
| `station.git.userEmail` | `station@warpparse.local` | 启动时执行 `git config --global user.email`。 |
| `station.configMountPath` | `/app/config/config.toml` | 主配置文件挂载路径。 |
| `station.defaultConfigsMountPath` | `/app/default_configs` | 默认配置目录挂载路径。 |
| `station.toolchainMountPath` | `/app/toolchain` | `wparse/wpgen/wproj` 工具链挂载目录。 |
| `station.monitorUrl` | `http://wp-monitor:18080/wp-monitor` | 注入 `WP_STATION_MONITOR_URL`。 |
| `station.assistBaseUrl` | `""` | 非空时注入 `WP_STATION_ASSIST_BASE_URL`。 |
| `station.projectRoot` | `project_root` | 注入 `WP_STATION_PROJECT_ROOT`。 |

### Service 与运行时

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `station.service.type` | `ClusterIP` | 主应用 Service 类型。 |
| `station.service.port` | `8081` | 主应用 Service 端口。 |
| `station.service.nodePort` | `null` | 当 Service 类型为 `NodePort` 时使用。 |
| `station.env` | `[]` | 追加环境变量。 |
| `station.envFrom` | `[]` | 追加 `envFrom`。 |
| `station.timezone.enabled` | `true` | 是否注入 `TZ` 环境变量。 |
| `station.timezone.name` | `Asia/Shanghai` | `TZ` 的值。 |
| `station.podAnnotations` | `{}` | Pod 注解。 |
| `station.podLabels` | `{}` | Pod 标签。 |
| `station.podSecurityContext` | `{}` | Pod 级安全上下文。 |
| `station.securityContext.runAsUser` | `0` | 容器运行用户。 |
| `station.securityContext.runAsGroup` | `0` | 容器运行用户组。 |
| `station.resources` | `{}` | 主容器资源限制与请求。 |
| `station.livenessProbe` | `{}` | 主容器存活探针。 |
| `station.readinessProbe` | `{}` | 主容器就绪探针。 |
| `station.volumes` | `[]` | 追加 Pod `volumes`。 |
| `station.volumeMounts` | `[]` | 追加主容器 `volumeMounts`。 |
| `station.nodeSelector` | `{}` | 节点选择器。 |
| `station.tolerations` | `[]` | 容忍配置。 |
| `station.affinity` | `{}` | 亲和性配置。 |

### HPA

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `station.autoscaling.enabled` | `false` | 是否创建 HPA。 |
| `station.autoscaling.minReplicas` | `1` | HPA 最小副本数。 |
| `station.autoscaling.maxReplicas` | `100` | HPA 最大副本数。 |
| `station.autoscaling.targetCPUUtilizationPercentage` | `80` | CPU 平均利用率目标。 |

## `postgres`

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `postgres.image.repository` | `postgres` | Postgres 镜像仓库。 |
| `postgres.image.tag` | `18.3` | Postgres 镜像标签。 |
| `postgres.image.pullPolicy` | `IfNotPresent` | 拉取策略。 |
| `postgres.service.port` | `5432` | Postgres Service / 容器端口。 |
| `postgres.user` | `postgres` | 数据库用户名。 |
| `postgres.password` | `123456` | 数据库密码，会写入 Secret。 |
| `postgres.databases.default` | `postgres` | 默认数据库名；也用于健康检查。 |
| `postgres.databases.gitea` | `gitea` | Gitea 使用的数据库名。 |
| `postgres.databases.station` | `wp-station` | Station 使用的数据库名。 |
| `postgres.persistence.enabled` | `true` | 是否为 Postgres 创建 PVC。 |
| `postgres.persistence.storageClassName` | `""` | 指定 StorageClass；为空时使用集群默认值。 |
| `postgres.persistence.size` | `10Gi` | PVC 大小。 |
| `postgres.persistence.accessModes` | `['ReadWriteOnce']` | PVC 访问模式。 |
| `postgres.podAnnotations` | `{}` | Pod 注解。 |
| `postgres.podLabels` | `{}` | Pod 标签。 |
| `postgres.podSecurityContext` | `{}` | Pod 级安全上下文。 |
| `postgres.securityContext` | `{}` | 容器级安全上下文。 |
| `postgres.resources` | `{}` | 容器资源限制与请求。 |
| `postgres.livenessProbe` | `{}` | 自定义存活探针；为空时使用模板默认 `pg_isready`。 |
| `postgres.readinessProbe` | `{}` | 自定义就绪探针；为空时使用模板默认 `pg_isready`。 |
| `postgres.volumes` | `[]` | 追加 `volumes`。 |
| `postgres.volumeMounts` | `[]` | 追加 `volumeMounts`。 |
| `postgres.nodeSelector` | `{}` | 节点选择器。 |
| `postgres.tolerations` | `[]` | 容忍配置。 |
| `postgres.affinity` | `{}` | 亲和性配置。 |

## `gitea`

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `gitea.image.repository` | `gitea/gitea` | Gitea 镜像仓库。 |
| `gitea.image.tag` | `latest` | Gitea 镜像标签。 |
| `gitea.image.pullPolicy` | `IfNotPresent` | 拉取策略。 |
| `gitea.service.type` | `ClusterIP` | Gitea Service 类型。 |
| `gitea.service.httpPort` | `3000` | Gitea HTTP 端口。 |
| `gitea.service.sshPort` | `22` | Gitea SSH 容器端口 / Service 端口。 |
| `gitea.adminUsername` | `gitea` | Hook Job 创建管理员时使用的用户名。 |
| `gitea.adminPassword` | `123456` | 管理员密码，会写入 Secret。 |
| `gitea.rootUrl` | `http://localhost:3000` | 写入 Gitea 配置的 `ROOT_URL`。 |
| `gitea.domain` | `localhost` | 写入 Gitea 配置的 `DOMAIN`。 |
| `gitea.sshDomain` | `localhost` | 写入 Gitea 配置的 `SSH_DOMAIN`。 |
| `gitea.sshExternalPort` | `222` | 写入 Gitea 配置的 `SSH_PORT`。 |
| `gitea.userUid` | `1000` | 注入 `USER_UID`。 |
| `gitea.userGid` | `1000` | 注入 `USER_GID`。 |
| `gitea.persistence.enabled` | `true` | 是否为 Gitea 创建 PVC。 |
| `gitea.persistence.storageClassName` | `""` | 指定 StorageClass；为空时使用集群默认值。 |
| `gitea.persistence.size` | `10Gi` | PVC 大小。 |
| `gitea.persistence.accessModes` | `['ReadWriteOnce']` | PVC 访问模式。 |
| `gitea.podAnnotations` | `{}` | Pod 注解。 |
| `gitea.podLabels` | `{}` | Pod 标签。 |
| `gitea.podSecurityContext` | `{}` | Pod 级安全上下文。 |
| `gitea.securityContext` | `{}` | 容器级安全上下文。 |
| `gitea.resources` | `{}` | 容器资源限制与请求。 |
| `gitea.livenessProbe` | `{}` | 自定义存活探针。 |
| `gitea.readinessProbe` | `{}` | 自定义就绪探针。 |
| `gitea.volumes` | `[]` | 追加 `volumes`。 |
| `gitea.volumeMounts` | `[]` | 追加 `volumeMounts`。 |
| `gitea.nodeSelector` | `{}` | 节点选择器。 |
| `gitea.tolerations` | `[]` | 容忍配置。 |
| `gitea.affinity` | `{}` | 亲和性配置。 |

## 覆盖示例

### 1. 调整站点外部地址

```yaml
station:
  monitorUrl: http://monitor-wp-monitor.default.svc.cluster.local:18080/wp-monitor

gitea:
  rootUrl: https://git.example.com
  domain: git.example.com
  sshDomain: git.example.com
  sshExternalPort: 22
```

### 2. 调整持久化容量

```yaml
postgres:
  persistence:
    size: 20Gi

gitea:
  persistence:
    size: 50Gi
```

### 3. 打开主应用 HPA

```yaml
station:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

### 4. 给主应用追加环境变量

```yaml
station:
  env:
    - name: RUST_LOG
      value: info
```
