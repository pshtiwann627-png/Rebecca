# مرحله ۱: ساخت فرانت‌اند React
FROM node:20 AS frontend-builder
WORKDIR /app
COPY dashboard/ dashboard/
RUN cd dashboard && \
    npm ci && \
    VITE_BASE_API=/api/ npm run build -- --outDir=build --assetsDir=statics

# مرحله ۲: ساخت بک‌اند Go با Python و محیط مجازی
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install uv
RUN uv sync --group build
RUN bash scripts/build_binary.sh

# مرحله ۳: تصویر نهایی
FROM debian:bullseye-slim
WORKDIR /opt/rebecca

RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/dist/ ./dist/
COPY --from=builder /app/scripts/ ./scripts/
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/

# نصب دستی Xray (بدون systemd)
RUN curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip && \
    unzip /tmp/xray.zip -d /usr/local/bin/ && \
    rm /tmp/xray.zip && \
    chmod +x /usr/local/bin/xray

# متغیرهای محیطی
ENV SUDO_USERNAME=admin
ENV SUDO_PASSWORD=admin123
ENV SQLALCHEMY_DATABASE_URL=sqlite:///var/lib/rebecca/rebecca.db
ENV UVICORN_HOST=0.0.0.0
ENV UVICORN_PORT=8000
ENV REBECCA_GATEWAY_ADDR=0.0.0.0:8000

RUN chmod +x ./dist/rebecca-server ./dist/rebecca-cli

EXPOSE 8000
CMD ["./dist/rebecca-server"]
