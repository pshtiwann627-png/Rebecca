# مرحله ۱: ساخت بک‌اند Go
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN bash scripts/build_binary.sh

# مرحله ۲: ساخت فرانت‌اند React
FROM node:20 AS frontend-builder
WORKDIR /app
COPY dashboard/ dashboard/
RUN cd dashboard && npm ci && VITE_BASE_API=/api/ npm run build -- --outDir=build --assetsDir=statics

# مرحله ۳: تصویر نهایی (سبک و بدون مشکل tmp)
FROM debian:bullseye-slim AS final
WORKDIR /opt/rebecca

# به‌جای RUN یکجا، از RUN --mount=type=cache برای کش استفاده کن
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/dist/ ./dist/
COPY --from=builder /app/scripts/ ./scripts/
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/
COPY .env.example .env
RUN chmod +x ./dist/rebecca-server ./dist/rebecca-cli

# نصب Xray (با کش جداگانه)
RUN --mount=type=cache,target=/var/cache/apt \
    curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install

EXPOSE 8000
CMD ["./dist/rebecca-server"]
