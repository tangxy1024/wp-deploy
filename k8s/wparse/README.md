# wparse Helm Chart Values

本文档只说明 `k8s/wparse/values.yaml` 中可覆盖的配置项，以及这些配置项在模板中的实际作用。

## 安装

```bash
helm upgrade --install limbic-host ./k8s/wparse
```

使用自定义 values 文件：

```bash
helm upgrade --install limbic-host ./k8s/wparse -f my-values.yaml
```

渲染检查：

```bash
helm lint ./k8s/wparse
helm template limbic-host ./k8s/wparse >/dev/null
```

## Values配置

- `replicaCount` 只在 `wparse.autoscaling.enabled=false` 时生效。
- `wparse.workDir` 同时决定 initContainer 复制配置的目标目录、主容器挂载目录，以及默认启动参数中的 `--work-root`。
- `wparse.service.ports` 是主业务 Service 的端口列表，`wparse.service.primaryPort` 则用于 `Ingress`、`HTTPRoute` 和 chart 测试连接。
- `wparse.adminService` 始终单独创建一个 Service，但 admin API 是否真正可用仍取决于 `wparse-config/conf/wparse.toml`。
- `wparse.warpParseSecret.existingSecret` 为空时，chart 会尝试从 `k8s/wparse/.warp_parse/` 下的文件自动创建 Secret。

## 全局 Values 配置

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `replicaCount` | `1` | 主 Pod 副本数；关闭 HPA 时生效。 |
| `imagePullSecrets` | `[]` | 传递给 Pod 的 `imagePullSecrets`。 |
| `nameOverride` | `""` | 覆盖 chart 名称。 |
| `fullnameOverride` | `""` | 覆盖完整资源名。 |
| `serviceAccount.create` | `true` | 是否创建专用 ServiceAccount。 |
| `serviceAccount.automount` | `true` | 是否自动挂载 ServiceAccount Token。 |
| `serviceAccount.annotations` | `{}` | ServiceAccount 注解。 |
| `serviceAccount.name` | `""` | 指定已有 ServiceAccount 名称；为空时按模板生成。 |

## `wparse` Values

### 镜像与启动

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.image.repository` | `ghcr.io/wp-labs/warp-parse` | 主容器镜像仓库。 |
| `wparse.image.tag` | `0.23.8-alpha` | 主容器镜像标签。 |
| `wparse.image.pullPolicy` | `IfNotPresent` | 主容器拉取策略。 |
| `wparse.initImage.repository` | `busybox` | initContainer 镜像仓库。 |
| `wparse.initImage.tag` | `1.36` | initContainer 镜像标签。 |
| `wparse.initImage.pullPolicy` | `IfNotPresent` | initContainer 拉取策略。 |
| `wparse.command` | `['wparse']` | 覆盖容器入口命令。 |
| `wparse.args` | `['deamon', '--work-root', '/data/config']` | 覆盖容器启动参数。当前默认值与 `wparse.workDir` 不一致，如需统一请一起修改。 |
| `wparse.workDir` | `/data/config` | 配置目录和工作目录挂载点。 |
| `wparse.warpParseSecretPath` | `/root/.warp_parse` | admin token / TLS Secret 挂载目录。 |

### 环境与运行时

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.envFrom` | `[]` | 追加 `envFrom`。适合注入 ConfigMap / Secret。 |
| `wparse.timezone.enabled` | `true` | 是否注入 `TZ` 环境变量。 |
| `wparse.timezone.name` | `Asia/Shanghai` | `TZ` 的值。 |
| `wparse.podAnnotations` | `{}` | Pod 注解。 |
| `wparse.podLabels` | `{}` | Pod 额外标签。 |
| `wparse.podSecurityContext` | `{}` | Pod 级安全上下文。 |
| `wparse.securityContext.runAsUser` | `0` | 容器运行用户。 |
| `wparse.securityContext.runAsGroup` | `0` | 容器运行用户组。 |
| `wparse.resources` | `{}` | 容器资源限制与请求。 |
| `wparse.livenessProbe` | `{}` | 主容器存活探针。 |
| `wparse.readinessProbe` | `{}` | 主容器就绪探针。 |
| `wparse.volumes` | `[]` | 追加 Pod `volumes`。 |
| `wparse.volumeMounts` | `[]` | 追加主容器 `volumeMounts`。 |
| `wparse.nodeSelector` | `{}` | 节点选择器。 |
| `wparse.tolerations` | `[]` | 容忍配置。 |
| `wparse.affinity` | `{}` | 亲和性配置。 |

`values.yaml` 中默认未启用 `wparse.env`，但模板已支持直接添加环境变量列表，格式与 Kubernetes 原生 `env` 一致。

### 主业务 Service

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.service.type` | `ClusterIP` | 主业务 Service 类型。 |
| `wparse.service.primaryPort` | `19002` | `Ingress`、`HTTPRoute`、连通性测试使用的主端口。 |
| `wparse.service.ports` | 见 `values.yaml` | Service 暴露端口列表；每一项包含 `name`、`port`、`containerPort`、`targetPort`、`protocol`、`nodePort`。 |

当 `wparse.service.type=NodePort` 时，只有 `ports[]` 中显式设置的 `nodePort` 才会渲染到 Service。

### Admin Service

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.adminService.type` | `ClusterIP` | Admin Service 类型。 |
| `wparse.adminService.port` | `19090` | Admin Service 暴露端口。 |
| `wparse.adminService.nodePort` | `null` | 当 Service 类型为 `NodePort` 时使用。 |

### Ingress 与 Gateway API

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.ingress.enabled` | `false` | 是否创建 Ingress。 |
| `wparse.ingress.className` | `""` | IngressClass 名称。 |
| `wparse.ingress.annotations` | `{}` | Ingress 注解。 |
| `wparse.ingress.hosts` | `chart-example.local` | Ingress 主机名与路径列表。 |
| `wparse.ingress.tls` | `[]` | Ingress TLS 配置。 |
| `wparse.httpRoute.enabled` | `false` | 是否创建 Gateway API `HTTPRoute`。 |
| `wparse.httpRoute.annotations` | `{}` | `HTTPRoute` 注解。 |
| `wparse.httpRoute.parentRefs` | `[{name: gateway, sectionName: http}]` | 绑定的 Gateway Listener。 |
| `wparse.httpRoute.hostnames` | `['chart-example.local']` | `HTTPRoute` 主机名。 |
| `wparse.httpRoute.rules` | 见 `values.yaml` | `HTTPRoute` 路由规则。 |

### HPA

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.autoscaling.enabled` | `false` | 是否创建 HPA。 |
| `wparse.autoscaling.minReplicas` | `1` | HPA 最小副本数。 |
| `wparse.autoscaling.maxReplicas` | `100` | HPA 最大副本数。 |
| `wparse.autoscaling.targetCPUUtilizationPercentage` | `80` | CPU 平均利用率目标。 |
| `wparse.autoscaling.targetMemoryUtilizationPercentage` | 未设置 | 内存平均利用率目标；取消注释后模板会渲染内存指标。 |

### Secret

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `wparse.warpParseSecret.existingSecret` | `""` | 指定已有 Secret；设置后不再读取 chart 内 `.warp_parse` 文件。 |

自动建 Secret 的规则：

- `existingSecret` 为空且存在 `k8s/wparse/.warp_parse/admin_api.token` 时，自动创建 Secret 并写入 `admin_api.token`。
- 同时存在 `k8s/wparse/.warp_parse/tls/server.crt` 和 `k8s/wparse/.warp_parse/tls/server.key` 时，会额外写入 `tls.crt` 和 `tls.key`。
- 只存在其中一个 TLS 文件时，`helm lint` / `helm template` 会直接失败。

## 覆盖示例

### 1. 调整镜像和工作目录

```yaml
wparse:
  image:
    tag: 0.23.8
  workDir: /app/config
  args:
    - deamon
    - --work-root
    - /app/config
```

### 2. 暴露 NodePort

```yaml
wparse:
  service:
    type: NodePort
    primaryPort: 19002
    ports:
      - name: tcp
        port: 19002
        containerPort: 19002
        targetPort: tcp
        protocol: TCP
        nodePort: 31902
  adminService:
    type: NodePort
    port: 19090
    nodePort: 31990
```

### 3. 使用已有 admin Secret

```yaml
wparse:
  warpParseSecret:
    existingSecret: wparse-admin
```
