# syntax=docker/dockerfile:1

# -----------------------------
# Build stage: compile Vue app
# -----------------------------
FROM node:18-alpine AS build

WORKDIR /app

# Install dependencies first (better layer caching)
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
# Prefer npm; adapt if lockfile exists
RUN \
    if [ -f package-lock.json ]; then npm ci; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f pnpm-lock.yaml ]; then npm i -g pnpm && pnpm i --frozen-lockfile; \
    else npm i; fi

# Copy source
COPY . .

# Build-time configurable API base URL for Vite
# Vite exposes VITE_* at build time; default to "/" (use dev proxy semantics)
ARG VITE_API_BASE_URL=/
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# Build production assets
RUN npm run build

# --------------------------------
# Runtime stage: serve via Nginx
# --------------------------------
FROM nginx:alpine AS runtime

# Labels
LABEL org.opencontainers.image.title="TodoList Vue Frontend" \
    org.opencontainers.image.description="Minimal Vue 3 app for TodoList API, served with Nginx" \
    org.opencontainers.image.source="todolist/todolist-vue" \
    org.opencontainers.image.licenses="MIT"

# Copy built assets
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=build /app/static /usr/share/nginx/html/static

# Replace default server config with SPA-friendly config
RUN rm -f /etc/nginx/conf.d/default.conf
RUN printf '%s\n' \
    'server {' \
    '  listen       80;' \
    '  server_name  _;' \
    '  root         /usr/share/nginx/html;' \
    '  index        index.html;' \
    '' \
    '  # Serve static assets directly' \
    '  location / {' \
    '    try_files $uri $uri/ /index.html;' \
    '  }' \
    '' \
    '  # Optional: if you choose to reverse-proxy API via Nginx, add a location and upstream here.' \
    '  # By default, this image only serves the static SPA; API should be hosted separately.' \
    '}' \
    > /etc/nginx/conf.d/spa.conf

EXPOSE 80

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
