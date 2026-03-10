# WeAreFamily - Family Policy AI Steward

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
  - `/api/v1/auth/sso/callback`
- `TENANT_MODE=saas` expects `tenantId` during login/SSO
- `TENANT_MODE=private` forces `DEFAULT_TENANT_ID`

## Family and PDF APIs
- List families:
  - `GET /api/v1/families`
- List members:
  - `GET /api/v1/families/:familyId/members`
- Add member:
  - `POST /api/v1/families/:familyId/members`
- List documents:
  - `GET /api/v1/families/:familyId/documents`
- Upload policy PDF form:
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
- UI now includes:
  - Dashboard
  - Policies
  - Family Center (members + PDF import)

  
4. 登录
用演示账号：

broker@example.com / consumer@example.com
密码： demo1234