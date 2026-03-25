# WeAreFamily - Family Policy AI Steward

## Product Baseline
- Requirements baseline (for intent alignment and future expansion):
  - `docs/PRODUCT_REQUIREMENTS.md`

## Goals
- Frontend: Flutter (mobile + web/desktop)
- Backend: Node.js + PostgreSQL/MySQL (either)
- Users: Broker (B-side) + Consumer family (C-side)
- Delivery: SaaS + Docker private deployment for brokers

## Repo Structure
```text
apps/
  api/          # Node.js + Fastify + Knex
  flutter_app/  # Flutter app
docker-compose.yml
docker-compose.mysql.yml
```

## Quick Start (PostgreSQL)
1. Install dependencies:
   ```bash
   npm install
   ```
2. Start stack:
   ```bash
   npm run codex:run
   ```
3. Health check:
   - `GET http://localhost:3000/health`

## Quick Start (MySQL)
```bash
npm run codex:run:mysql
```

## Codex Commands
- Start stack (PostgreSQL): `npm run codex:run`
- Start stack (MySQL): `npm run codex:run:mysql`
- Start backend + Flutter (Edge, save-to-hot-reload): `npm run dev:full`
- Stop stack: `npm run stack:down`
- API logs: `npm run stack:logs`

## Demo Accounts
- Email: `broker@example.com`
- Email: `consumer@example.com`
- Password: `demo1234`

## Authentication and Tenancy
- `AUTH_REQUIRED=true` requires `Authorization: Bearer <token>`
- Public endpoints:
  - `/health`
  - `/api/v1/auth/login`
  - `/api/v1/auth/register`
  - `/api/v1/auth/sso/callback`
- `TENANT_MODE=saas` expects `tenantId` during login/SSO
- `TENANT_MODE=private` forces `DEFAULT_TENANT_ID`

## AI Scan (PDF)
- Default uses heuristic extraction (no external AI needed).
- To use external AI, set:
  - `AI_SCAN_PROVIDER=external`
  - `AI_SCAN_URL=https://your-ai-endpoint`
  - `AI_SCAN_TIMEOUT_MS=15000`
- External service should return JSON fields:
  - `policyNo`, `insurerName`, `productName`, `premium`, `currency`, `startDate`, `endDate`, `aiRiskScore`, `aiNotes`

## Income Benchmark Source
- Default provider is National Bureau of Statistics (China):
  - `BENCHMARK_PROVIDER=nbs`
  - `BENCHMARK_NBS_ENDPOINT=https://data.stats.gov.cn/easyquery.htm`
  - `BENCHMARK_NBS_DB_CODE=hgnd`
  - `BENCHMARK_NBS_INDICATOR=A0A0101`
- Default snapshot source tag:
  - `BENCHMARK_SOURCE=nbs-hgnd-a0a0101`
- Optional legacy URL mode:
  - `BENCHMARK_PROVIDER=url`
  - `BENCHMARK_INCOME_URL=https://your-endpoint`

## Family and PDF APIs
- List families:
  - `GET /api/v1/families`
- List members:
  - `GET /api/v1/families/:familyId/members`
- Add member:
  - `POST /api/v1/families/:familyId/members`
- List documents:
  - `GET /api/v1/families/:familyId/documents`
- Upload policy PDF form (AI scan + create policy):
  - `POST /api/v1/families/:familyId/documents` (multipart `file`)
- Download document:
  - `GET /api/v1/families/:familyId/documents/:documentId/download`

## Flutter
- Run app:
  ```bash
  cd apps/flutter_app
  flutter pub get
  flutter run -d edge --dart-define=API_BASE_URL=http://localhost:3000
  ```
- UI includes:
  - 仪表盘
  - 保单列表
  - 家庭中心（成员 + PDF导入）
