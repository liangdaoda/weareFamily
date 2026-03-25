# Build stage with full dependencies.
ARG NODE_BASE_IMAGE=docker.m.daocloud.io/library/node:20-alpine
FROM ${NODE_BASE_IMAGE} AS base
ARG NPM_REGISTRY=https://registry.npmmirror.com

WORKDIR /app

COPY package.json package-lock.json* ./
COPY apps/api/package.json apps/api/

RUN npm config set registry ${NPM_REGISTRY} \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm install --no-audit --no-fund

COPY apps/api ./apps/api

RUN npm --workspace apps/api run build

# Runtime stage with production dependencies only.
FROM ${NODE_BASE_IMAGE} AS runtime
ARG NPM_REGISTRY=https://registry.npmmirror.com

WORKDIR /app

COPY package.json package-lock.json* ./
COPY apps/api/package.json apps/api/

RUN npm config set registry ${NPM_REGISTRY} \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm install --omit=dev --no-audit --no-fund

COPY --from=base /app/apps/api/dist ./apps/api/dist

EXPOSE 3000

CMD ["npm", "--workspace", "apps/api", "run", "start"]
