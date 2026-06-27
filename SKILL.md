---
name: javaweb-fullstack
description: This skill should be used when building a Java Web full-stack project with a frontend-backend separation architecture. Covers requirements analysis, layered backend implementation, frontend views, and full-chain verification from browser click to database. Technology-agnostic core with specific examples (Spring Boot / MyBatis / JPA / Vue 3 / React etc.).
---

# Java Web Full-Stack Development Skill

## Three-Phase Workflow

Every feature must go through three phases **in order**:

```
Phase 1: 需求分析 (Requirements Analysis)
  ↓
Phase 2: 分层实现 (Layered Implementation)  
  ↓
Phase 3: 全链路验证 (Full-Chain Verification)  ← 最关键的环节
```

Do NOT skip to implementation before completing the analysis phase. Do NOT mark a feature as done before completing the verification phase.

---

## Phase 1: 需求分析

### Purpose
Before writing any code, produce a clear requirements analysis document. This prevents:
- Missing edge cases (空数据怎么办？权限怎么控制？)
- Unclear UI state transitions (新增后跳转还是留在当前页？)
- Incomplete API contracts (字段该传什么、返回什么？)

### What to Produce

For each feature, write a concise requirements analysis covering:

**1. 功能描述** — 一句话描述这个功能做什么

**2. 界面元素** — 列出页面上的所有交互元素及其行为
```
- 新增按钮: 点击跳转到 /articles/create
- 搜索框: 输入关键词回车触发搜索
- 表格: 展示文章列表，每行有编辑/删除操作
- 分页: 支持切换每页条数和翻页
- 状态标签: draft 显示灰色，published 显示绿色
```

**3. API 契约** — 明确每个接口的路径、方法、请求参数和响应格式
```
POST /api/articles
  Body: { title, content, summary?, status?, author }
  Response: { code, message, data: { id, title, ... } }

GET /api/articles
  Query: { pageNum, pageSize, keyword?, status?, author? }
  Response: { code, message, data: { records: [...], total, pageNum, pageSize } }
```

**4. 状态与边界**
```
- 列表为空: 显示空状态提示
- 加载中: 显示 loading 骨架屏
- 接口报错: 显示错误信息和重试按钮
- 新增成功: 跳转回列表页并显示成功提示
- 删除操作: 先弹确认框，成功后刷新列表
- 必填字段: title/content/author 不能为空
```

### Key Questions to Answer Before Implementation

- 新增/修改/删除成功后，页面如何变化？（跳转？刷新？弹窗？）
- 列表页的搜索条件是哪些？是否支持模糊搜索？
- 哪些字段是必填的？哪些字段有格式要求？
- 空数据时显示什么？加载失败时显示什么？
- 是否有权限控制？不同角色的展示不同？

---

## Phase 2: 分层实现

Implement each layer bottom-up:

```
  DB → Entity → 数据访问层 → Service → Controller → Frontend API → View
```

### Implementation Order for a CRUD Feature

**Step 1: 数据库**
- 编写 DDL 脚本（CREATE TABLE），包括字段类型、索引、默认值
- 确保有 `id` 主键、软删除标记、`created_at`/`updated_at` 时间戳
- 外键列建立索引

**Step 2: Entity + 数据访问层**
- Entity 类映射数据库表（如 JPA `@Entity` / MyBatis-Plus `@TableName` / 或直接编写 RowMapper）
- 主键标注（如 JPA `@Id` / MyBatis-Plus `@TableId`）
- 数据访问接口（如 JPA `JpaRepository<T, ID>` / MyBatis-Plus `BaseMapper<T>` / MyBatis XML Mapper / Spring Data JDBC Repository）
- 软删除配置（如 JPA `@Where` / MyBatis-Plus `@TableLogic` / 或手动过滤）

**Step 3: DTO + VO**
- `XxxDTO`：接收前端请求参数，添加校验注解（如 Jakarta Validation / Hibernate Validator）
- `XxxVO`：返回给前端的数据结构，不包含数据库内部字段
- `PageResult<T>`：统一分页返回格式

**Step 4: Service**
- 接口定义业务方法，Impl 实现具体逻辑
- 涉及写操作的方法加声明式事务（如 Spring `@Transactional` / Guice `@Transactional` / 或手动 try-with-commit）
- Entity ↔ VO 转换在 Service 层完成

**Step 5: Controller**
- REST 控制器定义端点（如 Spring `@RestController` / JAX-RS `@Path` / Micronaut `@Controller`）
- 参数校验：`@Valid @RequestBody`（Spring）或 `@Valid` + `@BeanParam`（JAX-RS）
- 返回统一格式包装

**Step 6: 前端 API 模块**
- 统一封装 HTTP 客户端（Axios / fetch / 或项目自带的请求库）
- 配置 baseURL、超时时间、请求/响应拦截器
- 每个方法标注返回类型，与后端 DTO/VO 对应

**Step 7: 前端页面**
- 列表页：loading / error / empty / data 四种状态
- 表单页：表单校验 + 提交中禁用按钮 + 成功后跳转或刷新
- 删除：确认对话框 + 成功后刷新列表
- 所有操作成功后必须有用户可感知的反馈（如 Element Plus `ElMessage.success` / Ant Design `message.success`）

### ⚠️ 验证前必须安装的环境依赖

Phase 2 代码实现完成后，**不要立即说"验证完成"**。必须先确保运行环境就绪：

```bash
# 必须安装的运行时（如果还没有）
# 数据库
sudo apt-get install -y mysql-server || echo "MySQL 安装可选，也可用 H2 替代"
# Java 运行时
java -version 2>&1 || sudo apt-get install -y openjdk-17-jdk
# Node.js
node --version || (curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs)
# Maven
mvn --version 2>&1 || sudo apt-get install -y maven
```

**只有环境就绪了，才能进入 Phase 3 真正做全链路验证。** 缺少运行环境而无法启动服务时，至少要用 `curl` 模拟请求或用代码审查 + 静态分析进行"离线验证"。

---

## Phase 3: 全链路验证（最关键）

### Why This Phase Exists

大多数 Bug 不是因为代码写不出来，而是因为**某层之间的连接断了**：
- 前端调了 `/api/articles` 但后端只配了 `/articles`
- 前端的 DTO 字段名和后端的 `@RequestBody` 字段不匹配
- 后端返回了数据但前端 response interceptor 没有正确 unwrap
- 新增数据成功但列表没有重新请求接口
- 页面路径配了但 router 忘记 import

### ⚠️ 核心要求：必须在真实环境中逐层验证

**不要只在代码层面检查**。必须启动数据库、启动后端、启动前端，用 `curl` / `浏览器` 发真实请求，用数据库客户端查真实数据，逐层验证整个链路。

下面的验证流程每一步都包含**在容器环境中可执行的命令**，直接照着做。

---

### 验证前置条件：搭建运行环境

在开始验证前，必须先确保环境就绪。按顺序执行：

```bash
# 1. 启动数据库（无 MySQL 则用 H2 内嵌数据库替代验证）
#    如果项目配置了 MySQL 但环境没有 → 临时改为 H2，或安装 MySQL
#    安装 MySQL:
sudo apt-get install -y mysql-server
sudo service mysql start

# 2. 执行 DDL 建表
mysql -u root -e "CREATE DATABASE IF NOT EXISTS your_db;"
mysql -u root your_db < backend/src/main/resources/schema.sql

# 3. 编译并启动后端（带 SQL 日志输出）
cd backend
mvn compile
# 在另一个终端或后台启动，确保控制台显示 SQL:
mvn spring-boot:run > backend.log 2>&1 &
# 等 10-15 秒让应用启动完成
sleep 15
curl -s http://localhost:8080/api/health  # 或任意一个简单接口确认后端已启动

# 4. 启动前端
cd frontend
npm install
npm run dev > frontend.log 2>&1 &
```

如果环境限制无法全部启动（比如没有浏览器），至少要完成 **API 层 + 数据库层** 的验证。

---

### 逐层验证（每一步都是可执行的命令）

#### 第 1 层：API 层 — 用 curl 代替浏览器 Network 面板

**不要等着去点浏览器**，直接用 `curl` 验证每个接口：

```bash
# === 1.1 新增操作 ===
echo "=== 1.1 POST 新增 ==="
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"title":"测试文章","content":"这是内容","author":"test"}'
# ✅ 预期: {"code":200,"message":"success","data":{"id":1,"title":"测试文章",...}}
# ❌ 如果返回 404 → URL 路径不匹配
# ❌ 如果返回 400 → 参数校验失败或字段名不对
# ❌ 如果返回 500 → 看后端日志

# === 1.2 列表查询（分页）===
echo "=== 1.2 GET 列表 ==="
curl -s "http://localhost:8080/api/articles?pageNum=1&pageSize=10"
# ✅ 预期: {"code":200,"data":{"records":[...],"total":1,"pageNum":1,"pageSize":10}}

# === 1.3 更新操作 ===
echo "=== 1.3 PUT 更新 ==="
curl -s -X PUT http://localhost:8080/api/articles/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"已更新","content":"新内容","author":"test"}'
# ✅ 预期: code 200

# === 1.4 删除操作 ===
echo "=== 1.4 DELETE 删除 ==="
curl -s -X DELETE http://localhost:8080/api/articles/1
# ✅ 预期: code 200

# === 1.5 再次查询确认删除 ===
echo "=== 1.5 验证删除 ==="
curl -s "http://localhost:8080/api/articles/1"
# ✅ 预期: 返回为空或 data 为 null（取决于设计）

# === 1.6 边界：必填字段校验 ===
echo "=== 1.6 空标题验证 ==="
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"content":"无标题","author":"test"}'
# ✅ 预期: 返回 400 或 code=400，提示标题不能为空

# === 1.7 边界：无效 ID ===
echo "=== 1.7 无效 ID ==="
curl -s http://localhost:8080/api/articles/99999
# ✅ 预期: 返回错误提示，而不是 500 或空数据
```

**验证要点（对应全链路图中的各个环节）**：

| 检查点 | 对应链路位置 | 怎么检查 |
|-------|------------|---------|
| URL 和 context-path 拼接正确？ | 浏览器 → HTTP 客户端 | curl 的 URL 就是前端实际请求的 URL |
| 请求方法正确？ | 浏览器 → HTTP 客户端 | `-X POST` / `-X PUT` / `-X DELETE` 是否对应后端注解 |
| Body 字段名和后端 DTO 匹配？ | HTTP 客户端 → Controller | 检查 curl 返回的 data 中字段名是否完整 |
| 后端返回了统一 Result 格式？ | Controller → 返回链路 | 检查返回的 JSON 是否有 `code`、`message`、`data` |
| 响应数据结构一致？ | 后端 → 前端 | 返回的 data 结构是否和前端 TypeScript 类型一致 |

#### 第 2 层：数据库层 — 用 SQL 验证数据变更

```bash
# === 2.1 新增后验证 ===
mysql -u root your_db -e "SELECT id, title, content, author, created_at FROM articles ORDER BY id DESC LIMIT 1;"
# ✅ 预期: 显示刚刚插入的数据

# === 2.2 更新后验证 ===
mysql -u root your_db -e "SELECT id, title, content FROM articles WHERE id=1;"
# ✅ 预期: 标题和内容已更新

# === 2.3 软删除后验证 ===
mysql -u root your_db -e "SELECT id, title, is_deleted FROM articles ORDER BY id DESC LIMIT 1;"
# ✅ 预期: is_deleted = 1

# === 2.4 列表查询 SQL 验证 ===
mysql -u root your_db -e "EXPLAIN SELECT * FROM articles WHERE author='test';"
# ✅ 检查 type 列，确保不是 ALL（全表扫描）
```

**验证要点**：

| 检查点 | 对应位置 | 怎么检查 |
|-------|---------|---------|
| SQL 真正执行了？ | 数据访问层 → 数据库 | mysql 命令行直查确认数据已写入 |
| 受影响行数正确？ | 数据库 | `ROW_COUNT()` 或看返回结果数量 |
| 软删除生效？ | 数据访问层 | `is_deleted` 字段是否正确标记 |
| 索引起作用？ | 数据库 | `EXPLAIN` 看 type 列 |

#### 第 3 层：前端层 — 构建 + 编译检查

```bash
# === 3.1 TypeScript 编译检查 ===
cd frontend
npx vue-tsc --noEmit
# ✅ 预期: 无错误输出，exit code 0
# ❌ 有类型错误 → 修复后再继续

# === 3.2 Vite 构建 ===
npx vite build
# ✅ 预期: 构建成功，生成 dist/ 目录
# ❌ 如果 Rolldown/Vite 报 resolve 错误 → @ 别名未配置或 import 路径错误

# === 3.3 （可选）启动 dev server 后用 curl 验证前端 HTML 是否能加载 ===
npm run dev > /tmp/frontend-dev.log 2>&1 &
sleep 3
curl -s http://localhost:5173 | head -20
# ✅ 预期: 返回 HTML，包含 <div id="app"> 等
```

#### 第 4 层：完整链路 — 若浏览器可用

```bash
# 如果环境支持 GUI（如 OpenHands 的浏览器工具）：
# 1. 浏览器打开前端页面
# 2. 打开 DevTools → Network 面板
# 3. 执行新增操作
# 4. 检查 Network 面板：请求 URL / Method / Status / Request Body
# 5. 检查页面：toast 提示 / 列表刷新 / URL 跳转
```

**验证要点**：

| 检查点 | 怎么检查 |
|-------|---------|
| 新增后列表自动刷新？ | 操作完成后看列表数据是否包含新条目 |
| 操作成功有 toast？ | 页面右上角是否有成功提示 |
| 空数据有提示？ | 清空条件搜索，看是否显示 `<el-empty>` |
| loading 状态？ | 刷新页面时是否有加载动画 |
| 多余按钮没隐藏？ | 检查 `v-if` 条件对应的元素是否在非条件下隐藏 |
| 路由跳转后正常渲染？ | 直接访问各路由 URL 看页面是否正常 |

---

### 验证失败时的排查路径

如果上面任何一步失败，按以下顺序排查（不要跳步）：

```
curl 返回 404
  → 检查 curl 中的 URL 是否与后端 @RequestMapping + context-path 一致
  → 检查后端是否真的启动了（journalctl 或 ps aux | grep java）

curl 返回 400
  → 检查请求 Body 的字段名是否与后端 DTO 字段名完全一致
  → 检查 DTO 上的 @NotBlank/@NotNull 是否把可选字段变成必填了

curl 返回 500
  → 看后端日志：tail -100 backend.log
  → 找 Exception 堆栈
  → 最常见的：SQL 语法错误、空指针、MyBatis 映射错误

curl 返回 200 但 data 为 null 或字段不对
  → 检查 Service 层 Entity → VO 转换
  → 检查 MyBatis resultMap 字段映射

curl 正确但前端页面空白/报错
  → 看浏览器控制台（或前端日志）
  → 检查 router import 路径是否正确
  → 检查 API 模块的调用路径是否和 curl 测试通过的路径一致
  → 检查 Axios response interceptor 是否正确解包
```

### 验证通过标准

一个功能只有同时满足以下条件，才算**真正完成**：

- [x] curl 新增 → 返回 200 + 包含 id 的数据
- [x] curl 查询 → 返回分页数据，包含刚才新增的记录
- [x] curl 更新 → 返回 200，数据库确认字段已变更
- [x] curl 删除 → 返回 200，数据库确认 is_deleted=1
- [x] curl 空标题 → 返回 400 或业务错误码
- [x] SQL 日志输出正常，无异常堆栈
- [x] TypeScript 编译无报错
- [x] Vite 构建成功
- [x] 前端列表显示了更新后的数据

**缺少任何一项，都不能说"验证完成"。**

---

## Common Frontend Display Bugs (Must Check)

以下是在 Vue 3 项目中最常出现的前端展示问题，每次实现后逐项排查：

### FR1 — 数据变更后 UI 不刷新
**症状**: 新增/修改/删除后，列表仍显示旧数据，需要手动刷新页面
**原因**: 
- 列表页的 `fetchData()` 在操作成功后没有调用
- Vue 响应式数据更新方式不对（直接赋值而不是用 `ref.value = newValue`）
**必须做到**: 每个写操作（create/update/delete）的 `.then()` / `try` 块中，操作成功后立即调用列表刷新方法

### FR2 — 多余 UI 元素未隐藏
**症状**: 页面上显示了不该出现的按钮/标签/区块（如普通用户看到"删除"按钮，已发布的文章显示"发布"按钮）
**原因**:
- 没有根据数据状态做条件渲染（`v-if` / `v-show`）
- 没有考虑角色/权限控制
**必须做到**: 所有 UI 元素都要问自己：这个元素在什么条件下不应该显示？然后用 `v-if` 控制

### FR3 — 操作成功无反馈
**症状**: 用户点了保存按钮，页面没任何变化，用户不确定是否保存成功
**原因**: 操作成功后没有调用 `ElMessage.success()` 或类似的 toast 提示
**必须做到**: 每个写操作成功后调用 `ElMessage.success('操作成功')`

### FR4 — 表单提交无防重复
**症状**: 用户快速点击提交按钮，创建了多条重复数据
**原因**: 提交按钮在 API 调用期间没有 disabled
**必须做到**: 表单页加 `submitting` ref，按钮绑定 `:disabled="submitting"`，`try { submitting=true } finally { submitting=false }`

### FR5 — 空数据无提示
**症状**: 列表没有数据时显示空白页面或「暂无数据」字样 表头
**原因**: 没有使用 `v-if="data.length === 0"` 处理空状态
**必须做到**: 列表页必须有 `<el-empty>` 或类似的空状态占位

### FR6 — 加载中无反馈
**症状**: 页面数据加载期间显示空白，用户以为页面卡了
**原因**: 没有使用 loading 状态和骨架屏
**必须做到**: 数据请求期间 `v-loading="loading"` 或显示加载指示器

### FR7 — 路由跳转后页面空白
**症状**: 点击链接后 URL 变了但页面空白
**原因**: router 配置中 `component: () => import(...)` 路径写错，或懒加载的组件 export default 没有
**必须做到**: 每个新路由添加后，在浏览器中实际访问确认能正常渲染

### FR8 — 接口返回错误无处理
**症状**: API 返回 500/403/404，页面没有错误提示
**原因**: HTTP 客户端（Axios/fetch 等）没有统一错误处理，或页面没有 catch 错误
**必须做到**: 统一处理 401（跳登录）/ 403（无权限）/ 500（服务器错误）+ 每个页面 catch 业务错误

---

## 全链路验证示例（以「新增文章」为例，含可执行命令）

假设实现了 Article 的新增功能，完整的验证过程应如下执行：

```bash
# ========== 第 1 步：启动环境 ==========
sudo service mysql start
cd backend && mvn spring-boot:run > backend.log 2>&1 &
sleep 15

# ========== 第 2 步：API 验证（用 curl） ==========
# 新增
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"title":"测试","content":"内容","author":"admin"}'
# ✅ 看到 {"code":200,"data":{"id":1,"title":"测试",...}}

# 列表
curl -s "http://localhost:8080/api/articles?pageNum=1&pageSize=10"
# ✅ 看到 records 中有刚才新增的记录

# ========== 第 3 步：数据库验证 ==========
mysql -u root your_db -e "SELECT id, title, content FROM articles ORDER BY id DESC LIMIT 1;"
# ✅ 看到刚才插入的数据

# ========== 第 4 步：前端验证 ==========
cd frontend && npx vue-tsc --noEmit && npx vite build
# ✅ 编译通过，构建成功

# ========== 第 5 步：边界验证 ==========
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"content":"无标题","author":"admin"}'
# ✅ 返回 400，提示标题必填
```

**缺少任何一步验证，都不能说"验证完成"。**

## Project Architecture

### Backend Layer Rules

| Layer | Responsibility | Must NOT |
|-------|---------------|----------|
| Controller | HTTP 请求处理、参数校验、路由 | 不能直接调用数据访问层，不能包含业务逻辑 |
| Service | 业务逻辑、事务管理、DTO/VO 转换 | 不能处理 HTTP 请求/响应对象 |
| 数据访问层 (Mapper/Repository/DAO) | 数据库操作（CRUD、分页、复杂查询） | 不能包含业务逻辑 |
| Entity | 数据库表映射 | 不能直接返回到 Controller |
| DTO/VO | 请求/响应数据结构 | 不能包含数据库实体注解 |

### Frontend Layer Rules

| Layer | Responsibility |
|-------|---------------|
| `src/api/xxx.ts` | 封装所有后端 API 调用 |
| `src/views/` | 页面级组件，组合业务功能 |
| `src/router/` | 路由配置，懒加载组件 |
| `src/utils/http.ts` | HTTP 客户端封装（请求/响应拦截器） |
| `src/types/` | TypeScript 类型定义 |

### Backend Bug Prevention

- B1: 声明式事务指定回滚所有异常（如 Spring 的 `@Transactional(rollbackFor = Exception.class)`），默认只回滚 RuntimeException
- B2: 参数绑定使用参数化方式（如 MyBatis `#{}` / JPA 参数绑定），防 SQL 注入
- B3: Controller 层参数校验（如 Spring 的 `@Valid @RequestBody` / JAX-RS 的 `@Valid`)
- B4: Entity ↔ DTO/VO 分离 — 不暴露内部字段
- B5: 全局异常处理（如 Spring `@RestControllerAdvice` / JAX-RS `ExceptionMapper`）
- B6: CORS 全局配置（一个 Config 类，不要分散在各 Controller）

### Frontend Bug Prevention

- F1: HTTP 客户端统一封装 + 响应拦截器 unwrap 后端返回数据
- F2: API 路径常量放在 `src/api/`，不硬编码在视图
- F3: 写操作后必须刷新列表 / 跳转
- F4: 表单提交按钮防重复
- F5: loading / error / empty / data 四种状态全覆盖

## Additional Resources

### Reference Files

- **`references/common-bugs.md`** — 全链路断裂 / 前端 UI bug / 后端陷阱 / 数据库 bug，含快速排查指南

### Scripts

- **`scripts/init-project.sh`** — 全栈项目脚手架生成器（以 Spring Boot + Vue 3 + TypeScript 为例）
- **`scripts/validate-project.py`** — 项目规则合规性扫描器（检查包结构、CORS、异常处理、HTTP 客户端封装等）
