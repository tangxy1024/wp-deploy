# wparse

该 Helm Chart 用于将 WarpParse 的 `limbic-host` 示例部署到 Kubernetes。Chart 结构基于 `k8s/helm-chart`，并补充了 WarpParse 所需的配置文件、Secret、运行态目录和 Service 接线。

## 目录结构

```text
k8s/wparse/
  Chart.yaml
  values.yaml
  templates/
  wparse-config/
    conf/
    connectors/
    topology/
    models/
```

## 配置文件

`wparse-config/` 下的文件会通过 Helm 的 `.Files.Glob` 渲染到 ConfigMap 中：

```text
wparse-config/conf
wparse-config/connectors
wparse-config/topology
wparse-config/models
```

Pod 内会恢复成以下目录：

```text
/app/config/conf
/app/config/connectors
/app/config/topology
/app/config/models
```

`conf/wparse.toml` 和 `conf/wpgen.toml` 保留为文件，不再从 `values.yaml` 生成。

实现方式：ConfigMap 会先挂载到只读目录 `/config-src`，initContainer 再把内容复制到可写的 `/app/config`。因此 wparse 运行时可以在 `/app/config` 下创建 `data`、`.run` 等运行态目录。

`wparse.workDir` 控制工作目录，同时用于启动参数 `--work-root` 和容器挂载目录：

```yaml
wparse:
  workDir: /app/config
```

## 安装

```bash
helm upgrade --install limbic-host ./k8s/wparse
```

如果需要查看渲染结果：

```bash
helm template limbic-host ./k8s/wparse
```

## Service

Chart 会创建两个 Service：

- 主 Service：暴露 `service.ports` 中配置的业务端口，默认是 `19002`。
- Admin Service：默认创建，暴露 `19090`。Admin 模块是否真正开启只由 `wparse-config/conf/wparse.toml` 中的 `[admin_api].enabled` 控制。

默认配置：

```yaml
service:
  type: ClusterIP
  primaryPort: 19002
  ports:
    - name: tcp
      port: 19002
      containerPort: 19002
      targetPort: tcp
      protocol: TCP

adminService:
  type: ClusterIP
  port: 19090
```

如果要额外暴露端口，在 `service.ports` 中追加即可。

## Admin Token

WarpParse 的 admin token 不放入 ConfigMap，而是通过 Kubernetes Secret 挂载。

默认情况下，Chart 会从 chart 内置文件读取 admin token 并创建 Secret：

```yaml
warpParseSecret:
  existingSecret: ""
  create: true
  tokenPath: .warp_parse/admin_api.token
```

请把 token 内容写入：

```text
k8s/wparse/.warp_parse/admin_api.token
```

容器内挂载路径为：

```text
/root/.warp_parse/admin_api.token
```

该路径需要和 `wparse-config/conf/wparse.toml` 中的配置保持一致：

```toml
[admin_api.auth]
mode = "bearer_token"
token_file = "/root/.warp_parse/admin_api.token"
```

Secret volume 使用 `defaultMode: 0400`，因为 WarpParse 会拒绝 group 或 others 可读的 token 文件。

## 使用已有 Secret

如果不希望 Chart 自动创建 Secret，可以先手动创建：

```bash
kubectl create secret generic wparse-admin \
  --from-literal=admin_api.token='123456'
```

然后安装：

```bash
helm upgrade --install limbic-host ./k8s/wparse \
  --set warpParseSecret.create=false \
  --set warpParseSecret.existingSecret=wparse-admin
```

已有 Secret 至少需要包含这个 key：

```text
admin_api.token
```

## TLS 证书

如果启用 admin TLS，需要修改 `wparse-config/conf/wparse.toml`：

```toml
[admin_api.tls]
enabled = true
cert_file = "/root/.warp_parse/tls/server.crt"
key_file = "/root/.warp_parse/tls/server.key"
```

Chart 默认从专用目录读取 TLS 文件：

```text
k8s/wparse/.warp_parse/tls/server.crt
k8s/wparse/.warp_parse/tls/server.key
```

启用 TLS 时，设置：

```yaml
warpParseSecret:
  tls:
    enabled: true
    crtPath: .warp_parse/tls/server.crt
    keyPath: .warp_parse/tls/server.key
```

这里的 `crtPath` 和 `keyPath` 必须是 chart 内路径，不能是本机任意绝对路径。

使用已有 Secret 时，Secret 需要包含：

```text
admin_api.token
tls.crt
tls.key
```

示例：

```bash
kubectl create secret generic wparse-admin \
  --from-literal=admin_api.token='123456' \
  --from-file=tls.crt=./server.crt \
  --from-file=tls.key=./server.key
```

安装：

```bash
helm upgrade --install limbic-host ./k8s/wparse \
  --set warpParseSecret.create=false \
  --set warpParseSecret.existingSecret=wparse-admin
```

## 运行态目录

ConfigMap 本身是只读的，不能直接作为可写工作目录使用。Chart 使用 initContainer 将 `/config-src` 中的 ConfigMap 内容复制到可写 `emptyDir`：

```text
/config-src -> /app/config
```

initContainer 会同时创建运行态目录：

```text
/app/config/data/rescue
/app/config/data/logs
/app/config/data/out_dat
/app/config/.run
```

这些目录用于日志、rescue、file sink 输出和 project remote 状态文件。

## 容器用户

容器默认以 root 运行：

```yaml
securityContext:
  runAsUser: 0
  runAsGroup: 0
```

因此 admin token 和 TLS 证书默认挂载到：

```text
/root/.warp_parse
```

TLS 文件会挂载到：

```text
/root/.warp_parse/tls/server.crt
/root/.warp_parse/tls/server.key
```

如果调整容器用户，需要同步修改：

- `wparse.warpParseSecretPath`
- `wparse-config/conf/wparse.toml` 中的 `token_file`
- `wparse-config/conf/wparse.toml` 中的 `cert_file` 和 `key_file`

## 常见问题

### token file permissions 644 are too permissive

原因是 Secret 文件权限过宽。Chart 已设置：

```yaml
defaultMode: 0400
```

如果你改成自定义 volume，需要保留 owner-only 权限。

### stat token file failed

通常是 `wparse.toml` 中的 `token_file` 和 Secret 挂载路径不一致。

检查：

```bash
kubectl exec -it <pod> -- ls -la /root/.warp_parse
```

确认存在：

```text
/root/.warp_parse/admin_api.token
```

### No such file or directory (os error 2)

如果 `wparse.toml` 已经加载成功，但随后报该错误，通常是运行态目录缺失或不可写。

检查：

```bash
kubectl exec -it <pod> -- ls -la /app/config
kubectl exec -it <pod> -- ls -la /app/config/data
kubectl exec -it <pod> -- ls -la /app/config/.run
```

确认 initContainer 已成功完成，并且 `/app/config` 是可写目录。

## 验证 Chart

```bash
helm lint ./k8s/wparse
helm template limbic-host ./k8s/wparse >/dev/null
```
