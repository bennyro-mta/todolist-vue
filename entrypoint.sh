#!/usr/bin/env sh
# Entrypoint script to inject API_BASE_URL into a runtime config.js for the Vue app.
# This allows setting the TodoList API base URL at container start via environment variables.

set -eu

HTML_DIR=${HTML_DIR:-/usr/share/nginx/html}
CONFIG_JS_PATH="${HTML_DIR}/config.js"
INDEX_HTML_PATH="${HTML_DIR}/index.html"

# Read API_BASE_URL from environment, default to "/" (use dev-proxy-like path semantics)
API_BASE_URL=${API_BASE_URL:-/}

echo "Initializing runtime configuration..."
echo "API_BASE_URL=${API_BASE_URL}"
echo "HTML_DIR=${HTML_DIR}"

# Generate config.js with the runtime API base
cat > "${CONFIG_JS_PATH}" <<EOF
// Runtime configuration generated at container start.
// Do NOT edit manually inside the running container; modify the entrypoint instead.
(function () {
  window.APP_CONFIG = window.APP_CONFIG || {};
  window.APP_CONFIG.API_BASE_URL = ${API_BASE_URL:+\"$API_BASE_URL\"};
})();
EOF

# Ensure index.html loads config.js (robust insertion in <head>, before main.js if present)
if [ -f "${INDEX_HTML_PATH}" ]; then
  # Inject config.js script tag if missing
  if ! grep -q 'src="/config.js"' "${INDEX_HTML_PATH}"; then
    echo "Injecting <script src=\"/config.js\"></script> into index.html"
    if grep -q '<script[^>]*src="/src/main.js"[^>]*></script>' "${INDEX_HTML_PATH}"; then
      # Insert the config script tag before the main module script tag (POSIX sed)
      sed -i '/<script[^>]*src="\/src\/main.js"[^>]*><\/script>/i \
      \ \ \ \ <script src="/config.js"></script>' "${INDEX_HTML_PATH}"
    else
      # Fallback: insert at end of <head> before closing </head>
      sed -i 's#</head>#  <script src="/config.js"></script>\n</head>#' "${INDEX_HTML_PATH}"
    fi
  else
    echo "index.html already includes config.js"
  fi

  # Add meta fallback with API base if meta is absent (used by runtime script)
  if ! grep -q '<meta name="api-base-url"' "${INDEX_HTML_PATH}"; then
    echo "Injecting <meta name=\"api-base-url\" content=\"${API_BASE_URL}\"> into <head>"
    sed -i 's#<meta[^>]*name="viewport"[^>]*>#&\n    <meta name="api-base-url" content="'"${API_BASE_URL}"'">#' "${INDEX_HTML_PATH}"
  fi
else
  echo "Warning: ${INDEX_HTML_PATH} not found; skipping HTML injection. Ensure your SPA loads /config.js before /src/main.js."
fi

# Print a preview of the generated config.js for diagnostics
echo "Generated ${CONFIG_JS_PATH}:"
head -n 10 "${CONFIG_JS_PATH}" || true

# Start Nginx in the foreground
echo "Starting Nginx..."
exec nginx -g 'daemon off;'
