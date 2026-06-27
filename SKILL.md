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

---

## Phase 3: 全链路验证（最关键）

### Why This Phase Exists

大多数 Bug 不是因为代码写不出来，而是因为**某层之间的连接断了**：
- 前端调了 `/api/articles` 但后端只配了 `/articles`
- 前端的 DTO 字段名和后端的 `@RequestBody` 字段不匹配
- 后端返回了数据但前端 response interceptor 没有正确 unwrap
- 新增数据成功但列表没有重新请求接口
- 页面路径配了但 router 忘记 import

### The Full Chain: From Click to DB and Back

每个功能实现后，按照以下链条逐层验证：

```
[浏览器]
    ↓ 用户点击按钮 → 检查浏览器 Network 面板
    ↓ 是否有正确的 HTTP 请求发出？
    ↓ 请求方法（GET/POST/PUT/DELETE）是否正确？
    ↓ 请求 URL 是否完整（包含 context-path）？
    ↓ 请求 Body 字段名是否和后端 DTO 一致？

[前端 HTTP 客户端]
    ↓ 是否经过了配置的 baseURL（或代理）？
    ↓ Token/认证头是否已附加？
    ↓ 响应拦截器（或统一处理逻辑）是否正确解包了后端返回的数据？

[后端 Controller]
    ↓ 请求是否到达了正确的 @RequestMapping？
    ↓ @RequestBody 是否成功反序列化为 DTO？
    ↓ @Valid 校验是否触发？（参数错误会返回 400）
    ↓ @PathVariable / @RequestParam 参数是否匹配？

[后端 Service]
    ↓ 声明式事务是否生效？（如 Spring @Transactional）
    ↓ 业务逻辑是否正确？（状态转换、计算、权限判断）
    ↓ Entity ↔ VO 转换是否正确？（字段名、类型）

[数据访问层 / ORM]
    ↓ SQL 是否正确拼接？（动态条件是否生效？）
    ↓ 参数传递方式是否正确？（防 SQL 注入）
    ↓ 返回的列名和 Entity 字段是否映射正确？

[数据库]
    ↓ SQL 是否真正执行了？（检查日志或数据库直连查询）
    ↓ 受影响的行数是否符合预期？
    ↓ 数据变更是否正确？（新增了一行？更新了字段？删除了？）

[返回链路]
    ↓ 后端返回的 Result.code 是否为 200？
    ↓ 返回的数据结构是否和前端 TypeScript 类型一致？
    ↓ 前端 HTTP 客户端是否正确解包了数据？
    ↓ 前端是否用了解包后的数据更新页面？

[UI 更新]
    ↓ 列表是否重新请求并刷新？
    ↓ 操作成功后是否有用户提示？
    ↓ 是否有不应该显示的 UI 元素被隐藏了？
    ↓ 页面 URL 是否正确跳转？
```

### Concrete Verification Steps (Checklist)

#### 1. 网络层验证
- [ ] 打开浏览器 F12 → Network 面板，执行操作
- [ ] 确认有请求发出，检查：URL ✅ / Method ✅ / Status 200 ✅
- [ ] 检查请求 Body 字段名是否和后端 DTO 一致
- [ ] 检查请求 Headers：Content-Type ✅ / Authorization ✅

#### 2. 后端日志验证
- [ ] 确认后端控制台/日志打印了 SQL 或数据访问日志
- [ ] 确认 SQL 语句正确、参数正确
- [ ] 确认没有异常堆栈（如有，先解决异常）

#### 3. 数据库验证
- [ ] 对于新增操作：`SELECT * FROM xxx WHERE id = ?` 确认数据已插入
- [ ] 对于更新操作：确认字段已更新
- [ ] 对于删除操作：确认软删除标记已更新或记录已删除

#### 4. 前端 UI 验证
- [ ] 新增/修改/删除后，数据是否自动刷新？（不需要手动刷新页面）
- [ ] 是否有多余的 UI 元素没有隐藏？（比如管理员按钮普通用户也能看到）
- [ ] 列表页是否覆盖了四种状态：loading / error / empty / data
- [ ] 操作失败时是否显示了正确的错误信息
- [ ] 操作成功后是否显示了成功提示

#### 5. 边界条件验证
- [ ] 提交空表单是否提示必填字段？
- [ ] 输入超长内容是否被截断或提示？
- [ ] 连续快速点击提交按钮是否会重复提交？
- [ ] 搜索无结果时是否显示空状态？
- [ ] 网络断开时是否有错误提示？

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

## 全链路验证示例（以「新增文章」为例）

假设实现了 Article 的新增功能，验证过程：

```
1. 打开浏览器 → Network 面板 → 点击"新增"按钮
   ✅ 看到 POST /api/articles 请求
   ✅ 状态码 200
   ✅ Body 包含 { title, content, author }

2. 看后端日志
   ✅ SQL: INSERT INTO articles (title, content, author, ...) VALUES (..., ..., ..., ...)
   ✅ 参数值正确

3. 验证数据库
   ✅ SELECT * FROM articles ORDER BY id DESC LIMIT 1 → 数据已插入

4. 验证前端 UI
   ✅ 页面自动跳转到列表页
   ✅ 列表显示了新数据（不需要手动刷新）
   ✅ 顶部出现绿色 toast: "Created successfully"

5. 边界验证
   ✅ 不填标题点提交 → 提示"Title is required"
   ✅ 快速点两次提交 → 只创建了一条
```

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
