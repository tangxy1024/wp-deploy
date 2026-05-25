## 使用指南

### 下载镜像包和helm包
此步骤，如果可以直接拉下来可以跳过此节。
1. 下载对应helm的镜像包
https://github.com/wp-labs/wp-deploy/releases
2. 加载进docker中：`gunzip -c wparse-amd64-images.tar.gz | docker load`。如果k8s有多个节点，需要在每台服务器上

3. 将本仓库中k8s目录下的helm包拷贝到服务器中。
```bash
.
├── wp-monitor
├── wp-station
└── wparse
```

### 部署wparse

**helm介绍**

本chart部署的关键资源如下，完整资源介绍请看`k8s/wparse/README.md`：
- configmap: wparse-config,他对应`wparse/wparse-config`目录中的内容。
- secret: wparse-warp-parse, 他对应`wparse/.warp_parse` 目录下的内容，一般包含密钥和tls证书。该secret最终会被挂载到`/root/.warp_parse`中。
- service: 
    - wparse: source相关端口的svc，如果source添加端口，需要在此svc也添加port。
    - wparse-admin: 提供给station的svc，一般是19090端口。

**部署**
```bash
helm install wparse ./wparse
```
会部署上面所述的关键资源。

### 部署wp-monitor

**helm介绍**

本chart部署的关键资源如下，完整资源介绍请看`k8s/wp-monitor/README.md`：
- configmap: wp-monitor-config, 会生成 `wp-monitor` 的 `app.toml` 配置，并默认指向集群内的 `victoria-metrics` 和 `victoria-logs` 服务。
- deployment:
    - victoria-metrics: 指标存储服务。
    - victoria-logs: 日志存储服务。
    - wp-monitor: 页面和查询接口服务。
- service:
    - wp-monitor-victoria-metrics: 提供指标写入和查询，默认是 `8428` 端口。
    - wp-monitor-victoria-logs: 提供日志写入和查询，默认是 `9428` 端口。
    - wp-monitor-wp-monitor: 提供页面访问，默认是 `18080` 端口，默认类型是 `NodePort`。
- pvc（默认不开启）:
    - wp-monitor-victoria-metrics-data: `victoria-metrics` 的持久化数据卷。
    - wp-monitor-victoria-logs-data: `victoria-logs` 的持久化数据卷。

**部署**
```bash
helm install wp-monitor ./wp-monitor
```

默认情况下会部署上述的deploy、svc、和configmap：
- `wp-monitor` 默认通过 `NodePort` 暴露，默认端口配置为30880。

### 部署wp-station

**helm介绍**

本chart部署的关键资源如下，完整资源介绍请看`k8s/wp-station/README.md`：
- configmap:
    - station-config: 生成 `wp-station` 主配置文件，对应`wp-station/wp-station-config/config`目录下的内容。
    - station-default-configs: 对应 `wp-station/station-config/default-configs` 目录中的内容。
    - postgres-initdb-config: 对应初始化数据库脚本。
- secret: station, 包含 `postgres` 和 `gitea` 的管理员密码，最终会分别注入到对应容器中。
- deployment:
    - station: 主应用服务。
    - postgres: 内置数据库服务。
    - gitea: 内置 git 服务。
- job:
    - gitea-init: 在 `gitea` 启动后初始化管理员账号。
- service:
    - station: 提供 `wp-station` 页面和接口访问，默认是 `8081` 端口。
    - postgres: 提供数据库访问，默认是 `5432` 端口。
    - gitea: 提供 git http/ssh 访问，默认是 `3000` 和 `22` 端口。
- pvc（默认不创建）:
    - postgres-data: `postgres` 的持久化数据卷。
    - gitea-data: `gitea` 的持久化数据卷。

**部署**
1. 在`wp-station/wp-station-config/config`中填入monitor的实际地址（宿主机ip+NodePort端口）。
```bash
helm install wp-station ./wp-station
```

默认情况下会部署上述的deploy、svc、configmap、secret：
- `station` 默认依赖 chart 内置的 `postgres` 和 `gitea`。
- `station` 默认通过 `ClusterIP` 暴露，默认端口是 `8081`。


### 开启TLS
目前wparse中内置了`wparse-admin`域名的证书，如果存在域名改动。需要使用提供的脚本进行生成。

