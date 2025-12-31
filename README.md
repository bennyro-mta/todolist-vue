# TodoList Vue Frontend

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
