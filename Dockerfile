# 设置默认的架构和操作系统参数
ARG ARCH="amd64"
ARG OS="linux"

# 使用Go语言的alpine版本作为构建阶段的基础镜像
FROM golang:1.22-alpine AS builder
# 安装构建所需的依赖工具，包括git、bash、gcc和musl-dev
RUN apk add --no-cache git bash gcc musl-dev
# 设置工作目录为 /app
WORKDIR /app
# 将当前目录的内容拷贝到工作目录中
COPY . .
# 设置Go语言的环境变量，启用CGO，并指定目标操作系统和架构
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64
# 安装最新版本的Delve调试工具
RUN go install github.com/go-delve/delve/cmd/dlv@latest
# 构建node_exporter二进制文件
RUN go build -o node_exporter .

# 使用最新版本的Alpine Linux作为运行时的基础镜像
FROM alpine:latest
# 安装必要的运行时依赖，如libc6-compat和util-linux
RUN apk add --no-cache libc6-compat util-linux
# 从构建阶段拷贝node_exporter二进制文件到运行时容器的 /bin 目录下
COPY --from=builder /app/node_exporter /bin/node_exporter
# 从构建阶段拷贝Delve调试工具到运行时容器
COPY --from=builder /go/bin/dlv .
# 从构建阶段拷贝自定义脚本到运行时容器指定路径
COPY --from=builder /app/cmd/shell /bin/shell
# 赋予node_exporter二进制文件可执行权限
RUN chmod +x /bin/node_exporter
# 暴露node_exporter的默认端口 9100
EXPOSE 9100
# 暴露Delve调试器的端口 2345
EXPOSE 2345
# 指定运行时的用户为root
USER root
# 设置容器启动时的默认命令，使用Delve调试器启动node_exporter
CMD ["./dlv", "exec", "/bin/node_exporter","--headless", "--listen=:2345", "--api-version=2", "--accept-multiclient", "--", "--collector.shellfile.directory=/bin/shell"]
