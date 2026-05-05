# SolarPeak Agent Run Instructions

## Default Runtime Mode

Use Docker Compose for the full stack unless the user explicitly asks for local processes.

Run:

- `docker compose up --build -d`
- `docker compose ps`

Stop:

- `docker compose down`

## Optional Hot-Reload Compose Mode

Use hot-reload mode only when bind mounts are known to work in the current Docker environment.

Run:

- `docker compose -f docker-compose.yml -f docker-compose.hotreload.yml up --build -d`
- `docker compose -f docker-compose.yml -f docker-compose.hotreload.yml ps`

Stop:

- `docker compose -f docker-compose.yml -f docker-compose.hotreload.yml down`

## Important Project-Specific Rules

- Do not add backend or frontend bind mounts in Compose for this environment.
- Keep default mode bind-mount free. Put bind mounts only in docker-compose.hotreload.yml.
- Keep frontend upstream as `NEXT_PUBLIC_API_URL=http://backend:3001` in Compose.
- Backend startup command in Compose should remain `bundle exec rails server -b 0.0.0.0 -p 3001`.
- Keep backend development host authorization allowing `backend` so frontend proxy requests are accepted.

## Validation Checklist

After startup, validate all of the following:

1. `docker compose ps` shows postgres, redis, backend, frontend as running (postgres/redis healthy).
2. Frontend proxy identity call succeeds:
   - `docker exec solarpeak-frontend-1 sh -lc "wget -T 10 -qO- 'http://127.0.0.1:3000/api/proxy/me' >/dev/null; echo $?"`
3. Frontend proxy solar call succeeds:
   - `docker exec solarpeak-frontend-1 sh -lc "wget -T 10 -qO- 'http://127.0.0.1:3000/api/proxy/solar/readings?start_date=2026-05-01&end_date=2026-05-02' >/dev/null; echo $?"`

Expected result for 2 and 3 is exit code `0`.

## If User Requests Local Runtime

If requested, run only postgres and redis via Compose and run backend/frontend directly in the workspace.

## Mode Selection Rule

- Default to compose-only stable mode.
- Use the hot-reload compose override only when the user asks for hot reload or code sync mounts.
- If hot-reload mode shows missing-file errors inside /app, switch back to stable mode immediately.
