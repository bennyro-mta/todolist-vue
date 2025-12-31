# TodoList Vue Frontend

## Subpath Deployment and BASE_PATH

This app supports being served under any URL prefix (e.g., `/webui`) without hardcoding paths into the image.

- Set `BASE_PATH` via environment variable on the frontend container:
  - Example: `BASE_PATH=/webui`
  - Default: `/`
- The server mounts static assets and the SPA under `BASE_PATH`, so all requests are correctly served relative to this prefix.
- All asset links in `index.html`, CSS, and client-side JavaScript are relative (e.g., `static/...`, `assets/...`, `config.js`, `src/main.js`) so the browser resolves them relative to the current page location under `BASE_PATH`.

API configuration:
- Set `API_BASE_URL` via environment variable to the **full API endpoint URL**. The frontend uses this directly for all API calls. Examples:
  - `API_BASE_URL=http://localhost:8080` (local development)
  - `API_BASE_URL=http://api-service:8080` (Kubernetes service)
  - `API_BASE_URL=https://api.example.com` (external origin)
  - `API_BASE_URL=/api` (same host, different path via ingress proxy)
- The frontend makes calls to `GET`, `POST`, `PATCH`, `DELETE` directly on `API_BASE_URL` with no additional path prefixes.

Ingress routing (no hardcoding in the image):
- Route SPA: `BASE_PATH` (e.g., `/webui`) to the frontend service, passing the prefix through unchanged.
- Route API: Map your API path (e.g., `/api`, `/todos`, or `/`) to the API service.
- Avoid rewriting `/webui/*` to `/`; the server handles prefixed paths directly.
- Ensure `API_BASE_URL` is set to the correct endpoint URL accessible from the browser.

Troubleshooting:
- 404s or HTML returned for JS/CSS (disallowed MIME type) typically indicate ingress rewriting paths incorrectly. Ensure `/webui/assets/*`, `/webui/static/*`, and `/webui/config.js` reach the frontend service unmodified.

A minimal Vue 3 + Vite frontend that retrieves, displays, creates, updates, and deletes todos via the TodoList REST API. The API base URL is configurable via the Vite environment variable `VITE_API_BASE_URL`.

## Prerequisites

- Node.js 18+ and npm
- The TodoList API running locally (default assumed: http://localhost:8080)

API repository path: `todolist/todolist-api`

Key endpoints:
- GET `/todos`
- GET `/todos/{id}`
- POST `/todos` (body: `{ "task": "..." }`)
- PUT/PATCH `/todos/{id}` (body: `{ "task"?: string, "status"?: "Todo" | "In Progress" | "Complete" }`)
- DELETE `/todos/{id}`
- GET `/livez`, `/readyz` (health)

## Quick Start

1. Install dependencies:
   ```
   cd todolist/todolist-vue
   npm install
   ```

2. Run the API locally (if not already running):
   - Ensure you have a MySQL instance accessible and set environment variables:
     - `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB`, `MYSQL_HOST`, `MYSQL_TABLE`
     - Optional: `PORT` (defaults to `8080`)
   - Start the API (from `todolist/todolist-api`):
     ```
     cd ../todolist-api
     go run .
     ```
   - Alternatively, run via Docker (see API README for details).

3. Start the Vue dev server:
   ```
   cd ../todolist-vue
   npm run dev
   ```
   - Open the printed local URL (typically http://localhost:5173).
   - Dev server is configured to proxy `/todos`, `/livez`, `/readyz` to `http://localhost:8080` to avoid CORS. You can override the API base by setting `VITE_API_BASE_URL` in a `.env` or `.env.local` file (for example, `VITE_API_BASE_URL=http://localhost:8080`).

## Build for Production

```
cd todolist/todolist-vue
npm run build
```

- Output will be generated in `dist/`.
- You can preview the production build locally:
  ```
  npm run preview
  ```
- In production, you will need to serve the built files with a static server and ensure the frontend can reach the API.
  - Option A: Host both behind the same domain and path, or configure your reverse proxy to route `/todos`, `/livez`, `/readyz` to the API.
  - Option B: If serving API on a different origin, configure CORS on the API and set `VITE_API_BASE_URL` to the full API base URL (e.g., `https://api.example.com`) before building.

## Configuration Notes

- Dev proxy is defined in `vite.config.js`:
  - Proxies `/todos`, `/livez`, `/readyz` to `http://localhost:8080`.
- The API base URL can be configured via `VITE_API_BASE_URL` (use `.env`/`.env.local`); if unset in development, the proxy is used.
- The frontend assumes the API returns tasks with fields: `id`, `task`, and optionally `status` (defaults to `Todo` if missing).
- Valid statuses: `Todo`, `In Progress`, `Complete`.

### Deploying behind a subpath (Ingress)

This app can be served from any subpath (e.g., `/webui`) without hardcoding that path. Key points:

- Build/runtime behavior
  - Built assets use a relative base (so asset/script URLs resolve under the current path).
  - The Node server serves:
    - `index.html` with normalized relative asset paths
    - `assets/*` and `static/*` from the build
    - `config.js` generated at runtime from environment variables
    - `favicon.ico` from `static/img/todolist.ico`
  - All of the above also work when requested under a prefix, e.g., `/webui/assets/*`, `/webui/static/*`, `/webui/config.js`, `/webui/favicon.ico`.

- Ingress routing (no hardcoded paths in the image)
  - Route SPA: `/webui` (path prefix) to the frontend service. Do not strip the prefix; pass the request path through unchanged.
  - Route API: `/todos` (and optionally `/livez`, `/readyz`) to the API service.
  - Avoid rewrite rules that force `/webui/*` to `/` — the server handles prefixed paths directly.

- Runtime environment (configure via container env, not baked in)
  - `API_BASE_URL` — where the frontend will call the API from the browser:
    - Example for ingress: `API_BASE_URL=/todos`
    - Example for external origin: `API_BASE_URL=https://api.example.com`
  - `USER` — optional; controls window title (`"<USER>'s TODOS"` if set).
  - `PORT` — optional; defaults to `8080`.

- Expected requests under `/webui`
  - `/webui/` → SPA index
  - `/webui/assets/*` → built JS/CSS/assets
  - `/webui/static/*` → static assets
  - `/webui/config.js` → runtime configuration
  - `/webui/favicon.ico` → favicon

- Troubleshooting subpath issues
  - 404s for `/assets/*` or `/config.js` at the root (e.g., `http://host/assets/...`):
    - Ensure ingress is routing `/webui/*` to the frontend (not rewriting to `/`).
    - The app references assets relatively; if ingress strips `/webui`, asset paths will break.
  - “Disallowed MIME type (text/html)” for JS/CSS:
    - Ensure `/webui/assets/*` and `/webui/static/*` are routed to the frontend service and not rewritten to the SPA index.
  - API calls failing:
    - Set `API_BASE_URL` to `/todos` (for same-ingress routing) or a full origin.
    - If cross-origin, enable CORS on the API.

## Troubleshooting

- Frontend shows “Failed to load todos”:
  - Confirm API is running and reachable at `http://localhost:8080`.
  - Check dev server logs and browser console for network errors.
  - Verify `vite.config.js` proxy settings and that you started the dev server via `npm run dev`.

- API readiness probes failing:
  - Check `GET /readyz` and database connectivity.
  - Verify MySQL credentials and that `MYSQL_TABLE` exists or is creatable.

- CORS errors in production:
  - Serve both apps under the same origin, or enable CORS on the API and point the frontend `axios` base URL to the API origin.

## Scripts

- `npm run dev` — Start Vite dev server (with proxy)
- `npm run build` — Build production assets
- `npm run preview` — Preview the production build

## Project Structure

- `index.html` — Minimal HTML with `#app` mount point
- `src/main.js` — Vue app (fetches, creates, updates, deletes todos with Axios)
- `vite.config.js` — Vue plugin and dev proxy config
- `package.json` — Dependencies and scripts
