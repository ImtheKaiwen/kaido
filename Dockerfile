# ─────────────────────────────────────────────
# Stage 1: Build React Frontend
# ─────────────────────────────────────────────
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci --silent

COPY frontend/ ./
RUN npm run build


# ─────────────────────────────────────────────
# Stage 2: Build Express Backend
# ─────────────────────────────────────────────
FROM node:20-alpine AS backend-builder

# Prisma requires openssl on Alpine
RUN apk add --update --no-cache openssl

WORKDIR /app/backend

COPY backend/package*.json ./
RUN npm ci --silent

COPY backend/ ./
RUN npx prisma generate
RUN npm run build


# ─────────────────────────────────────────────
# Stage 3: Production Image
# ─────────────────────────────────────────────
FROM node:20-alpine AS production

# Prisma requires openssl on Alpine
RUN apk add --update --no-cache openssl

WORKDIR /app

# Copy compiled backend
COPY --from=backend-builder /app/backend/dist ./backend/dist
COPY --from=backend-builder /app/backend/node_modules ./backend/node_modules
COPY --from=backend-builder /app/backend/package.json ./backend/package.json
COPY --from=backend-builder /app/backend/prisma ./backend/prisma

# Copy built frontend into correct relative path backend expects
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# No local database volume needed as we are using a remote PostgreSQL DB

WORKDIR /app/backend

# Run migrations then start the server
CMD npx prisma migrate deploy && node dist/index.js

EXPOSE 5000
