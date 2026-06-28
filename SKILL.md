---
name: javaweb-fullstack
description: Full-stack Java Web development with frontend-backend separation. Covers requirements analysis, layered backend (Spring Boot/MyBatis/JPA), frontend (Vue/React), and full-chain verification from browser to database.
triggers:
  - "java web"
  - "full-stack"
  - "fullstack"
  - "javaweb"
  - "spring boot + vue"
  - "spring boot + react"
  - "crud page"
  - "management module"
  - "backend + frontend"
  - "@requestmapping"
  - "@restcontroller"
  - "mybatis"
  - "element-plus"
---

# Java Web Full-Stack Development Skill

## Three-Phase Workflow

You MUST follow these three phases **in order** for every feature. Do NOT skip to Phase 2 before completing Phase 1. Do NOT mark any feature done before completing Phase 3.

```
Phase 1: 需求分析 — Analyze requirements, produce API contract and UI spec
Phase 2: 分层实现 — Implement bottom-up: DB → Entity → DAO → Service → Controller → Frontend
Phase 3: 全链路验证 — Verify every layer with real requests (curl + DB + browser)
```

---

## Phase 1: 需求分析

### What to produce (all required)

Before writing any code, produce a requirements analysis document covering all four parts below.

**1. 功能描述** — One sentence describing what this feature does.

**2. 界面元素** — List every interactive UI element and its behavior:
```
- 新增按钮: 点击跳转到 /articles/create
- 搜索框: 输入关键词回车触发搜索
- 表格: 展示文章列表，每行有编辑/删除操作
- 分页: 支持切换每页条数和翻页
```

**3. API 契约** — Define every endpoint with path, method, request params, and response:
```
POST /api/articles
  Body: { title, content, summary?, status?, author }
  Response: { code, message, data: { id, title, ... } }

GET /api/articles
  Query: { pageNum, pageSize, keyword?, status?, author? }
  Response: { code, message, data: { records: [...], total, pageNum, pageSize } }
```

**4. 状态与边界** — Define loading, empty, error, success states:
```
- 列表为空 → 空状态提示
- 加载中 → loading 骨架屏
- 接口报错 → 错误信息和重试按钮
- 新增成功 → 跳转回列表页 + 成功提示
- 必填字段 → title/content/author 非空校验
```

### Key questions you MUST answer before moving to Phase 2

- 新增/修改/删除成功后，页面如何变化？（跳转？刷新？弹窗？）
- 哪些字段是必填的？搜索是否支持模糊查询？
- 空数据时显示什么？加载失败时显示什么？
- 是否有权限控制？不同角色看到的内容不同？

✅ **Checkpoint**: Phase 1 complete when you have API contracts for all endpoints, UI behavior for every element, and all states (loading/empty/error/success) defined.

---

## Phase 2: 分层实现

### Before coding: run the project scanner

- **New project** → run `scripts/init-project.sh <project-name>` to generate the scaffold
- **Existing project** → run `scripts/validate-project.py <project-path>` to check compliance with the rules below

Then implement **bottom-up**. The correct order is:

```
DB → Entity → 数据访问层 → Service → Controller → 前端 API 封装 → 前端页面
```

### Implementation steps (execute in order)

**Step 1: 数据库**
- Write DDL (CREATE TABLE) with proper types, indexes, defaults
- Always include: `id` primary key (auto-increment), soft delete marker (`is_deleted`), `created_at`/`updated_at` timestamps
- Add indexes on foreign key columns and frequently queried columns

**Step 2: Entity + 数据访问层**
- Create Entity class mapping the DB table
  - JPA: `@Entity`, `@Id`, `@GeneratedValue`
  - MyBatis-Plus: `@TableName`, `@TableId`, `@TableLogic`
  - MyBatis XML: write resultMap
- Create data access interface:
  - JPA: extend `JpaRepository<T, ID>`
  - MyBatis-Plus: extend `BaseMapper<T>`
  - MyBatis: write XML mapper
- Configure soft delete filter if the framework supports it

**Step 3: DTO + VO**
- `XxxDTO` — receives frontend request params, add validation annotations (`@NotBlank`, `@Size`, `@Email` etc.)
- `XxxVO` — returned to frontend, does NOT include DB internal fields (like `is_deleted`)
- `PageResult<T>` — unified paginated response with `records`, `total`, `pageNum`, `pageSize`

**Step 4: Service**
- Interface defines business methods; Impl class implements them
- ALL write operations MUST have declarative transaction: `@Transactional(rollbackFor = Exception.class)`
- Entity ↔ VO conversion happens in Service layer, NOT in Controller

**Step 5: Controller**
- Use `@RestController` (Spring) or `@Path` (JAX-RS) for REST endpoints
- Parameter validation: `@Valid @RequestBody` for POST/PUT body; `@RequestParam` for query params
- Return unified `Result<T>` wrapper — NEVER return Entity directly
- Use `@RequestMapping` with the path prefix (e.g., `/users`)

**Step 6: 前端 API 模块** (`src/api/xxx.ts`)
- Wrap HTTP client (Axios/fetch) with baseURL, timeout, request/response interceptors
- Response interceptor MUST unwrap: return `response.data.data` so views get the data directly
- Each API method has typed parameters and return type matching backend DTO/VO

**Step 7: 前端页面**
- List page: loading / error / empty / data — all four states MUST be handled
- Form page: form validation + disable submit button during API call + success feedback
- Delete: confirmation dialog + refresh list after success
- Every write operation MUST call `ElMessage.success()` or equivalent after success
- After create/update/delete, the list page MUST re-fetch data automatically

### Code rules — the B1-B7 checklist (immediate rejection if violated)

| Rule | Requirement | Why |
|------|-------------|-----|
| **B1** | `@Transactional(rollbackFor = Exception.class)` | Default only rolls back RuntimeException |
| **B2** | Parameterized queries: `#{}` / `:name` / `PreparedStatement` | NEVER string-concatenate SQL |
| **B3** | `@Valid @RequestBody` on POST/PUT params | Without @Valid, DTO annotations don't work |
| **B4** | Entity ↔ DTO/VO separated; NEVER return Entity from Controller | Prevents data leaks + Jackson recursion |
| **B5** | ONE global exception handler (`@RestControllerAdvice` / `ExceptionMapper`) | Catches all unhandled exceptions centrally |
| **B6** | CORS in ONE global config class, NOT `@CrossOrigin` per Controller | Per-controller CORS causes inconsistent behavior |
| **B7** | Response interceptor unwraps `{ code, message, data }` → views get `data` | Views should NOT see `.data.data` |

### Frontend code rules — the F1-F5 checklist

| Rule | Requirement |
|------|-------------|
| **F1** | HTTP client response interceptor unwraps `response.data.data` once |
| **F2** | API paths in `src/api/*.ts`, NEVER hardcoded in views |
| **F3** | Every write operation triggers list refresh or navigation |
| **F4** | Submit button disabled during API call (`:disabled="submitting"`) |
| **F5** | Every view handles 4 states: loading / error / empty / data |

✅ **Checkpoint**: Phase 2 complete when all 7 steps are implemented. Now prepare the environment for Phase 3.

---

## Phase 3: 全链路验证（最关键 — DO NOT SKIP）

> Most bugs come from connections between layers breaking: wrong URL path, mismatched field names, response not unwrapped, list not refreshed, router import missing.

**You MUST verify in a real running environment, not just code review.**

### Step 0: Prepare running environment

```bash
# Ensure runtimes (skip if already installed)
sudo apt-get install -y mysql-server openjdk-17-jdk maven && sudo service mysql start

# Create DB and tables
mysql -u root -e "CREATE DATABASE IF NOT EXISTS your_db;"
mysql -u root your_db < backend/src/main/resources/schema.sql

# Start backend (compile, then run in background)
cd backend && mvn clean compile -q && mvn spring-boot:run > backend.log 2>&1 &
sleep 15
curl -s http://localhost:8080/api/health || { echo "Backend failed"; tail -50 backend.log; }

# Start frontend
cd frontend && npm install --silent && npm run dev > frontend.log 2>&1 &
```

If full environment is not available, at least verify **API layer + Database layer**.

---

### Step 1: Verify API layer (curl)

Replace `articles` with your actual endpoint. Run each in order — do NOT proceed past a failure:

```bash
BASE="http://localhost:8080/api"

# CRUD
curl -s -X POST "$BASE/articles" -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Content","author":"test"}'
# → 200: {"code":200,"data":{"id":1,...}} | 404=URL mismatch | 400=field mismatch | 500=check log

curl -s "$BASE/articles?pageNum=1&pageSize=10"
# → 200: paginated records

curl -s -X PUT "$BASE/articles/1" -H "Content-Type: application/json" \
  -d '{"title":"Updated","content":"New","author":"test"}'
# → 200

curl -s -X DELETE "$BASE/articles/1"
# → 200

# Boundaries
curl -s -X POST "$BASE/articles" -H "Content-Type: application/json" \
  -d '{"content":"No title","author":"test"}'
# → 400 with validation message

curl -s "$BASE/articles/99999"
# → error message, not 500, not empty

curl -s "$BASE/articles/1"
# → data is null/empty (already deleted)
```

---

### Step 2: Verify Database layer (SQL)

```bash
# Verify insert, update and soft delete
mysql -u root your_db -e "SELECT id, title, content, created_at FROM articles ORDER BY id DESC LIMIT 1;"
mysql -u root your_db -e "SELECT id, title, is_deleted FROM articles ORDER BY id DESC LIMIT 1;"

# Verify index: if type='ALL', add index
mysql -u root your_db -e "EXPLAIN SELECT * FROM articles WHERE author='test';"
```

---

### Step 3: Verify Frontend layer

```bash
cd frontend
npx vue-tsc --noEmit    # exit 0 = pass, else fix type errors
npx vite build           # succeeds → dist/ created, else fix @ alias / import path
npm run dev > /tmp/frontend.log 2>&1 & sleep 3
curl -s http://localhost:5173 | head -20  # → <div id="app">
```

### Step 4: Browser verification (if available)

Open page → DevTools Network → exercise CRUD → verify: toast appears, list refreshes, URL navigates correctly.

### Troubleshooting: decision tree

```
404 → curl URL matches @RequestMapping + context-path? backend started? (ps aux | grep java)
400 → Body fields match DTO exactly? Optional field accidentally marked @NotBlank?
500 → tail -50 backend.log; most common: SQL error, NPE, MyBatis mapping error
200 but data wrong → Service Entity→VO conversion; MyBatis resultMap mappings
curl OK, frontend blank → router import path; API call path vs curl path; interceptor unwrap
```

### Pass criteria (all 9 required)

- [ ] CREATE → 200 with id  |  [ ] LIST → paginated + new record  |  [ ] UPDATE → 200 + DB changed
- [ ] DELETE → 200 + `is_deleted=1`  |  [ ] Boundary: empty title → 400  |  [ ] No exceptions in backend log
- [ ] `vue-tsc --noEmit` exit 0  |  [ ] `vite build` succeeds  |  [ ] Frontend list shows updated data

**Do NOT say "done" until all 9 pass.**

---

## Appendix: Quick frontend bug checklist

After Phase 3 passes, verify frontend doesn't have these common bugs (full details in `references/common-bugs.md`):

- **FR1** List not refreshed after write → call `fetchData()` in `.then()`/`try`
- **FR2** Extra UI elements not hidden → `v-if` on role/status
- **FR3** No success feedback → `ElMessage.success()` after every write
- **FR4** Duplicate form submit → `:disabled="submitting"` + try/finally
- **FR5** Empty list no hint → `<el-empty>` when `data.length === 0`
- **FR6** No loading state → `v-loading` or skeleton
- **FR7** Blank page after navigation → verify `import()` path exists
- **FR8** API errors not handled → 401→login, 403→no perm, 500→server error in interceptor

---

## Additional Resources

- **`references/common-bugs.md`** — 40+ common bugs organized by layer, with detection and fix instructions
- **`scripts/init-project.sh`** — Full-stack project scaffold generator (Spring Boot + Vue 3 + TypeScript)
- **`scripts/validate-project.py`** — Project compliance scanner (checks structure, CORS, exception handling, etc.)
