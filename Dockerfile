# مرحله ۱: ساخت فرانت‌اند React
FROM node:20 AS frontend-builder
WORKDIR /app
COPY dashboard/ dashboard/
RUN cd dashboard && \
    npm ci && \
    VITE_BASE_API=/api/ npm run build -- --outDir=build --assetsDir=statics

# مرحله ۲: ساخت بک‌اند Go با Python و pipx
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/

# نصب Python، pipx
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv pipx && \
    rm -rf /var/lib/apt/lists/*

# نصب uv از طریق pipx و اطمینان از PATH
RUN pipx install uv && pipx ensurepath

# اجرای uv از طریق pipx run (مطمئن‌ترین روش)
RUN pipx run uv sync --group build

# اجرای اسکریپت بیلد
RUN bash scripts/build_binary.sh

# مرحله ۳: تصویر نهایی
FROM debian:bullseye-slim
WORKDIR /opt/rebecca

RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/dist/ ./dist/
COPY --from=builder /app/scripts/ ./scripts/
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/

# متغیرهای محیطی
ENV SUDO_USERNAME=admin
ENV SUDO_PASSWORD=admin123
ENV SQLALCHEMY_DATABASE_URL=sqlite:///var/lib/rebecca/rebecca.db
ENV UVICORN_HOST=0.0.0.0
ENV UVICORN_PORT=8000
ENV REBECCA_GATEWAY_ADDR=0.0.0.0:8000

RUN chmod +x ./dist/rebecca-server ./dist/rebecca-cli
RUN curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install

EXPOSE 8000
CMD ["./dist/rebecca-server"]
