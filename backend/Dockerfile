FROM node:20-bookworm-slim

WORKDIR /app

COPY backend/package*.json ./
RUN npm ci

COPY backend/ ./

ENV NODE_ENV=production
EXPOSE 8080

CMD ["sh", "-c", "PORT=${PORT:-8080} npm start"]
