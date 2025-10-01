# ===============================
# 构建阶段
# ===============================
FROM --platform=linux/amd64 gcc:12 AS builder

# 这里 gcc:12 镜像已经有 gcc/g++/make，不需要再装
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl bash git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 安装 moonbit 工具链
RUN curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash

ENV PATH="/root/.moon/bin:$PATH"

WORKDIR /app

# 先复制依赖文件以利用缓存
COPY moon.* ./
RUN moon update || true

# 再复制源码并构建
COPY . .
RUN moon build --target native --release


# ===============================
# 运行阶段
# ===============================
FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/target/native/release/build/example/example.exe ./example

CMD ["./example"]
