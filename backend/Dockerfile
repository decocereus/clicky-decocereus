FROM oven/bun:1.3.5

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY backend/package.json ./
COPY backend/bun.lock ./
RUN bun install --production --frozen-lockfile

COPY backend/ ./

ENV NODE_ENV=production
EXPOSE 8080

CMD ["sh", "-c", "PORT=${PORT:-8080} bun src/server.ts"]
