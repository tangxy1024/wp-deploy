## 项目需求
1. 根据wparse不同的部署方式，编排不同的docker-compose文件，提供一键部署的脚本。
2. 提供镜像的tar包，用户可以离线部署。

### Helm 镜像离线包 CI

仓库内置了一个 GitHub Actions workflow：`.github/workflows/release-helm-images.yaml`。

- 触发方式：推送 `v*` tag，或手动触发 `workflow_dispatch`
- 处理范围：`k8s/` 目录下每个包含 `Chart.yaml` 的 Helm chart
- 产物命名：`服务-amd64-images.tar.gz`、`服务-arm64-images.tar.gz`
- 发布位置：对应 GitHub Release 附件

CI 会使用 `helm template --include-tests` 渲染 chart，并提取渲染结果中实际引用的镜像，再分别按 `amd64` 和 `arm64` 拉取、打包、上传。


### 目录介绍
```sh
.
├── CONTRIBUTING.md
├── README.MD
├── docker            # docker-compose
│   ├── topology-name  # 部署的类型
│   │   ├── README.MD
│   │   ├── role-1-host     # 这种部署类型下，每个角色的配置
│   │   └── role-2-host
│   └── scripts
│       └── compose-common.sh
└── k8s
```
例子：
```sh
.
├── CONTRIBUTING.md
├── README.MD
├── docker
│   ├── aggregation-topology    # 以中心节点的部署方式
│   │   ├── README.MD           # 该部署方式的说明
│   │   └── centre-host          # 中心节点的配置
│   ├── disperse-topoloy        # 以分散节点的部署方式
│   │   ├── limbic-host         # 边缘节点的配置
│   │   ├── monitor-host        # 监控节点的配置
│   │   └── station-host        # 控制节点的配置
│   └── scripts
│       └── compose-common.sh
└── k8s
```
