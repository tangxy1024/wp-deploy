## 使用指南

### 下载镜像包
此步骤，如果可以直接拉下来可以跳过此节。
1. 下载对应helm的镜像包
https://github.com/wp-labs/wp-deploy/releases
2. 加载进docker中：`gunzip -c wparse-amd64-images.tar.gz | docker load`。如果k8s有多个节点，需要在每台服务器上