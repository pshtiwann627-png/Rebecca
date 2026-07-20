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

# مرحله ۳: تصویر نهایی (بدون mount، کاملاً سازگار با Railway)
FROM debian:bullseye-slim
WORKDIR /opt/rebecca

# به‌روزرسانی و نصب curl در یک مرحله
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# کپی فایل‌های ساخته‌شده
COPY --from=builder /app/dist/ ./dist/
COPY --from=builder /app/scripts/ ./scripts/
COPY --from=frontend-builder /app/dashboard/build/ ./dashboard/build/
COPY .env.example .env

# دسترسی اجرایی
RUN chmod +x ./dist/rebecca-server ./dist/rebecca-cli

# نصب Xray
RUN curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install

# پورت پیش‌فرض
EXPOSE 8000

# دستور اجرا
CMD ["./dist/rebecca-server"]
