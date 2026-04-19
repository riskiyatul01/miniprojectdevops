# --- Tahap 1: Build (Dependency stage) ---
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package file saja untuk optimasi cache layer Docker
COPY package*.json ./

# Install hanya production dependencies (lebih cepat & kecil)
RUN npm ci --omit=dev

# --- Tahap 2: Runtime (Production stage) ---
FROM node:20-alpine

# Set Environment Variables
ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Install 'tini' (Init process standar industri untuk handle signal Linux dengan benar)
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]

# Copy node_modules dari tahap builder (Image jadi jauh lebih kecil)
COPY --from=builder /app/node_modules ./node_modules
# Copy source code dengan hak akses user 'node' (Security: Least Privilege)
COPY --chown=node:node . .

# Healthcheck: Nilai plus untuk operasional (Automation)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

# Ekspos port aplikasi
EXPOSE 3000

# Security: Jangan jalankan container sebagai 'root'
USER node

# Jalankan aplikasi
CMD ["node", "app.js"]
