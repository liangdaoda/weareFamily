# WeAreFamily - 家庭保单 AI 可视化管家

## 项目目标
- 前端：Flutter 跨端（移动端 + Web/桌面端）
- 后端：Node.js + PostgreSQL/MySQL（二选一）
- 用户类型：B 端保险经纪人 + C 端普通家庭用户
- 交付模式：SaaS + Docker 私有化部署（面向 B 端售卖）

## 仓库结构
```text
apps/
  api/          # Node.js + Fastify + Knex
  flutter_app/  # Flutter 前端骨架（B/C 角色入口）
docker-compose.yml
docker-compose.mysql.yml
```

## 快速启动（后端 + PostgreSQL）
1. 安装依赖：
   ```bash
   npm install
   ```
2. 启动容器：
   ```bash
   docker compose up --build
   ```
3. 健康检查：
   - `GET http://localhost:3000/health`

## 启动 MySQL 方案
```bash
docker compose -f docker-compose.yml -f docker-compose.mysql.yml up --build
```

## API 角色与租户
- 通过请求头传入：
  - `x-user-id`
  - `x-user-role`: `broker | consumer | admin`
  - `x-tenant-id`
- `TENANT_MODE`:
  - `saas`：多租户
  - `private`：私有化单租户

## Flutter 说明
- 当前仓库提供 Flutter 业务源码骨架（`apps/flutter_app/lib`）。
- 若本机尚未安装 Flutter，请先安装后执行：
  ```bash
  cd apps/flutter_app
  flutter pub get
  flutter run -d chrome
  ```

