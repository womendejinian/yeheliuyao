# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS builder

WORKDIR /app

# 国内服务器如果拉取 npm 依赖较慢，可取消下一行注释使用国内镜像源
# RUN npm config set registry https://registry.npmmirror.com

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# 清理构建期专用的 Cloudflare 本地模拟器二进制包，减小镜像体积
RUN rm -rf node_modules/cf node_modules/@cloudflare node_modules/workerd

# ================= 运行阶段 =================
FROM node:22-bookworm-slim AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
ENV SQLITE_DB_PATH=/app/data/liuyao.db

RUN mkdir -p /app/data

COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/lib/dev ./lib/dev
COPY --from=builder /app/migrations ./migrations

EXPOSE 3000

CMD ["node", "scripts/next.mjs", "start", "-H", "0.0.0.0", "-p", "3000"]
