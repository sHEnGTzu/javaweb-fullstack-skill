---
name: javaweb-fullstack
description: This skill should be used when building a Java Web full-stack project with a frontend-backend separation architecture. Uses a per-feature vertical slice workflow (逐个功能垂直切分): implement one complete feature end-to-end (DB → Backend → Frontend), then verify it (curl → SQL → browser click → auto-refresh check) before moving to the next feature. Technology-agnostic core with specific examples (Spring Boot / MyBatis / JPA / Vue 3 / React etc.).
---

# Java Web Full-Stack Development Skill

## ⚠️ 黄金法则（每次使用前必须读一遍）

```
法则 1: 一个功能做到底，再做下一个功能
         不要在 Phase 2 把全部功能的后端实现完才开始做前端！
         
法则 2: 每实现一个功能的增/删/改/查，立刻做全链路验证
         不打开浏览器实际测试过，就不算写完！

法则 3: 不满足以下条件不得做下一个功能
         ✅ 前端按钮点击 → 后端收到请求 → 数据库更新 → 前端自动刷新
         ✅ 如果做不到以上任意一环，停下排查，不要继续写新功能
```

---

## 核心工作流：逐个功能垂直切分

**不要一次实现所有功能！** 把需求分析里识别出的每个功能（如：车位管理、车辆管理、收费规则管理、停车记录管理）作为独立单元，逐个完成。

对**每一个功能**，按以下流程执行完整周期后再做下一个：

```
┌─────────────────────────────────────────────────────────────┐
│  功能 N（如「车位管理」）                                     │
│                                                              │
│  Phase 2-N: 实现该功能（替换 N 为当前功能编号）               │
│  ├─ Step 1: 该功能的数据表设计 + SQL                          │
│  ├─ Step 2: 该功能的后端 (Entity → Mapper → Service → Ctrl) │
│  ├─ Step 3: 该功能的前端 (API 模块 + 页面)                    │
│                                                              │
│  Phase 3-N: 验证该功能 ← 不通过绝不做下一个！                │
│  ├─ 第 1 层: curl 测 API（增/删/改/查 + 边界条件）           │
│  ├─ 第 2 层: SQL 查数据库确认变更                            │
│  ├─ 第 3 层: 打开浏览器，实际点击按钮操作                     │
│  │   └─ 确认前端自动刷新显示最新数据                         │
│  └─ 第 4 层: TypeScript + Vite 构建检查                      │
│                                                              │
│  → 全部通过才能开始「Phase 2-(N+1) + Phase 3-(N+1)」        │
└─────────────────────────────────────────────────────────────┘
```

**为什么必须这样做？** 如果先把全部后端写完再写全部前端再统一验证：
- 一旦出问题，你不知道是哪个功能的哪一层断掉了
- 前端调了 `/api/parking/spaces` 但后端只有 `/parkingSpaces`，等你发现时已经写了 5 个功能
- 每个功能逐个做，问题立刻暴露、立刻修复

---

## Phase 1: 需求分析（一次性完成全部功能的分析）

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

## Phase 2-N: 实现「功能 N」

选择一个功能（从 Phase 1 的分析中），对这个功能的每一层做到底。**做完并通过 Phase 3-N 验证后，才能做下一个功能。**

> **编号规则**: 第一个功能是 Phase 2-1，第二个是 Phase 2-2，以此类推。
> 如果需求分析有"车位管理、车辆管理、收费规则管理"三个功能：
>   - Phase 2-1 + Phase 3-1: 车位管理
>   - Phase 2-2 + Phase 3-2: 车辆管理
>   - Phase 2-3 + Phase 3-3: 收费规则管理

每一层的规范如下，对**当前这个功能**逐层实现：

### Step 1: 该功能的数据库
- 编写该功能所需的 DDL 脚本（CREATE TABLE）
- 确保有 `id` 主键、软删除标记、`created_at`/`updated_at` 时间戳
- 外键列建立索引

### Step 2: 该功能的 Entity + 数据访问层
- Entity 类映射数据库表（如 JPA `@Entity` / MyBatis-Plus `@TableName`）
- 主键标注（如 JPA `@Id` / MyBatis-Plus `@TableId`）
- 数据访问接口（如 JPA `JpaRepository<T, ID>` / MyBatis-Plus `BaseMapper<T>`）
- 软删除配置（如 JPA `@Where` / MyBatis-Plus `@TableLogic`）

### Step 3: 该功能的 DTO + VO
- `XxxDTO`：接收前端请求参数，添加校验注解
- `XxxVO`：返回给前端的数据结构，不包含数据库内部字段

### Step 4: 该功能的 Service
- 接口定义业务方法，Impl 实现具体逻辑
- 涉及写操作的方法加声明式事务（如 `@Transactional(rollbackFor = Exception.class)`）
- Entity ↔ VO 转换在 Service 层完成

### Step 5: 该功能的 Controller
- REST 控制器定义端点
- 参数校验：`@Valid @RequestBody`
- 返回统一格式包装（Result<T>）

### Step 6: 该功能的前端 API 模块
- 在 `src/api/` 下创建该功能的 API 模块文件
- 每个方法标注 TypeScript 返回类型，与后端 VO 对应
- ⚠️ 确认 API 路径与后端 Controller 的 `@RequestMapping` + `context-path` 拼接后完全一致

### Step 7: 该功能的前端页面（最关键步骤！）

**列表页必须覆盖四个状态：**
```vue
<div v-if="loading">加载中...</div>
<div v-else-if="error">错误: {{ error }} <button @click="fetchData">重试</button></div>
<el-empty v-else-if="data.length === 0" description="暂无数据" />
<el-table v-else :data="data">...</el-table>
```

**写操作后的自动刷新（最常出错！必须做到）：**
```typescript
// ✅ 新增成功 → 跳转列表页并刷新
const handleCreate = async () => {
  submitting.value = true
  try {
    await api.create(form.value)
    ElMessage.success('新增成功')
    router.push('/articles')        // 跳转回列表
    // 注意：列表页的 onMounted/fetchData() 必须正确触发
  } finally { submitting.value = false }
}

// ✅ 删除成功 → 当前页重新拉取数据
const handleDelete = async (id: number) => {
  await api.delete(id)
  ElMessage.success('删除成功')
  fetchData()  // ← 必须调用！不是等列表页自己刷新
}

// ✅ 修改成功 → 当前页重新拉取数据
const handleUpdate = async () => {
  submitting.value = true
  try {
    await api.update(id.value, form.value)
    ElMessage.success('修改成功')
    fetchData()  // ← 必须调用！
  } finally { submitting.value = false }
}
```

**提交按钮防重复：**
```vue
<el-button :loading="submitting" :disabled="submitting">提交</el-button>
```

```typescript
const submitting = ref(false)
const submitForm = async () => {
  submitting.value = true
  try { ... } finally { submitting.value = false }
}
```

### ⚠️ 环境搭建（只在 Phase 2-1 时做一次，后续功能无需重复）

```bash
# 数据库
sudo apt-get install -y mysql-server || echo "可用 H2 替代"
sudo service mysql start

# Java 运行时
java -version 2>&1 || sudo apt-get install -y openjdk-17-jdk

# Node.js
node --version || (curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs)

# Maven
mvn --version 2>&1 || sudo apt-get install -y maven

# 初始化数据库（只一次）
mysql -u root -e "CREATE DATABASE IF NOT EXISTS your_db;"
mysql -u root your_db < backend/src/main/resources/schema.sql

# 编译并启动后端
cd backend && mvn spring-boot:run > backend.log 2>&1 &
sleep 15
curl -s http://localhost:8080/api/health

# 安装前端依赖并启动
cd frontend && npm install && npm run dev > frontend.log 2>&1 &
```

---

## Phase 3: 逐个功能全链路验证

实现完一个功能后，找到对应编号的验证子阶段执行。**全部通过才能做下一个功能。**

验证子阶段编号与 Phase 2 功能的实现顺序一一对应。如果需求分析中有 4 个功能：
- Phase 2-1 → Phase 3-1（验证功能 1）
- Phase 2-2 → Phase 3-2（验证功能 2）
- ...

每个验证子阶段都包含相同的 **4 层检查**，执行时把其中的 `xxx` 替换为当前功能名即可。

---

### Phase 3-1: 验证「功能 A」（如：车位管理）

```
□ 实现完成 → 进入验证
```

#### 第 1 层：API 验证（curl）
```bash
# 新增
curl -s -X POST http://localhost:8080/api/xxx \
  -H "Content-Type: application/json" \
  -d '{"field1":"值1","field2":"值2"}'
# ✅ 预期: {"code":200,"data":{"id":1,...}}
# ❌ 404 → URL 不匹配  ❌ 400 → 字段名不对  ❌ 500 → 看后端日志

# 列表查询
curl -s "http://localhost:8080/api/xxx?pageNum=1&pageSize=10"
# ✅ 预期: records 包含刚才新增的记录

# 更新
curl -s -X PUT http://localhost:8080/api/xxx/1 \
  -H "Content-Type: application/json" \
  -d '{"field1":"新值"}'
# ✅ 预期: code 200

# 删除
curl -s -X DELETE http://localhost:8080/api/xxx/1
# ✅ 预期: code 200

# 边界：缺必填字段
curl -s -X POST http://localhost:8080/api/xxx \
  -H "Content-Type: application/json" \
  -d '{}'
# ✅ 预期: 返回 400

# 边界：无效 ID
curl -s http://localhost:8080/api/xxx/99999
# ✅ 预期: 返回错误提示，不是 500
```

#### 第 2 层：数据库验证（SQL）
```bash
mysql -u root your_db -e "SELECT id, field1, field2, created_at FROM xxx ORDER BY id DESC LIMIT 1;"
mysql -u root your_db -e "SELECT id, is_deleted FROM xxx ORDER BY id DESC LIMIT 1;"
```

#### 第 3 层：前端浏览器验证
用浏览器打开前端页面，执行以下操作。**每项操作成功后确认页面自动刷新显示最新数据，不依赖手动刷新。**

| # | 操作 | 预期结果 |
|---|------|---------|
| 1 | 点击"新增"按钮 | 跳转到新增表单页 |
| 2 | 填写表单并提交 | 弹 success toast → 自动跳转回列表 → 列表包含新数据 |
| 3 | 点击"编辑"，修改字段后提交 | 弹 success toast → 列表显示修改后的数据 |
| 4 | 点击"删除"，确认 | 弹 success toast → 列表不再显示该数据 |
| 5 | 搜索框输入关键词 | 列表仅显示匹配的结果 |
| 6 | 清空所有数据 | 显示"暂无数据"占位图 |

同时打开浏览器 Network 面板，确认：请求有发出、URL 和方法正确、Body 字段名与后端一致。

#### 第 4 层：前端构建检查
```bash
cd frontend && npx vue-tsc --noEmit && npx vite build
```

#### ✅ 功能 A 验证通过清单
```
□ POST 新增 → curl 200 + data.id 不为 null → 数据库查到记录 → 浏览器操作成功
□ GET 查询 → curl 返回分页数据 → 浏览器列表显示数据
□ PUT 更新 → curl 200 → 数据库字段已变更 → 浏览器显示更新后数据
□ DELETE 删除 → curl 200 → 数据库 is_deleted=1 → 浏览器不再显示
□ 缺字段 → curl 返回 400
□ 无效 ID → curl 返回错误提示
□ TypeScript 编译无报错
□ Vite 构建成功
```

**全部 ☑ 后才能开始 Phase 2-3 或 Phase 3-2。** 如有失败，修复后重新跑所有检查项。

---

### Phase 3-2: 验证「功能 B」（如：车辆管理）

```
□ 功能 A 已完整验证通过 → 开始验证功能 B
```

#### 第 1 层：API 验证（curl）
```bash
# 新增
curl -s -X POST http://localhost:8080/api/yyy \
  -H "Content-Type: application/json" \
  -d '{"field1":"值1","field2":"值2"}'
# ✅ 预期: {"code":200,"data":{"id":1,...}}

# 列表查询
curl -s "http://localhost:8080/api/yyy?pageNum=1&pageSize=10"

# 更新
curl -s -X PUT http://localhost:8080/api/yyy/1 \
  -H "Content-Type: application/json" \
  -d '{"field1":"新值"}'

# 删除
curl -s -X DELETE http://localhost:8080/api/yyy/1

# 边界：缺必填字段
curl -s -X POST http://localhost:8080/api/yyy \
  -H "Content-Type: application/json" \
  -d '{}'

# 边界：无效 ID
curl -s http://localhost:8080/api/yyy/99999
```

#### 第 2 层：数据库验证（SQL）
```bash
mysql -u root your_db -e "SELECT id, field1, field2, created_at FROM yyy ORDER BY id DESC LIMIT 1;"
mysql -u root your_db -e "SELECT id, is_deleted FROM yyy ORDER BY id DESC LIMIT 1;"
```

#### 第 3 层：前端浏览器验证
用浏览器逐项操作，确认每个操作成功后前端自动刷新。

| # | 操作 | 预期结果 |
|---|------|---------|
| 1 | 点击"新增" | 跳转表单页 |
| 2 | 提交表单 | toast → 自动跳转 → 列表更新 |
| 3 | 编辑提交 | toast → 列表更新 |
| 4 | 删除确认 | toast → 列表更新 |
| 5 | 搜索 | 过滤列表 |
| 6 | 空数据 | 显示空状态 |

#### 第 4 层：前端构建检查
```bash
cd frontend && npx vue-tsc --noEmit && npx vite build
```

#### ✅ 功能 B 验证通过清单
```
□ POST 新增 → curl 200 + data.id → 数据库查到 → 浏览器操作成功
□ GET 查询 → curl 分页 → 浏览器显示
□ PUT 更新 → curl 200 → 数据库变更 → 浏览器更新
□ DELETE 删除 → curl 200 → 数据库 is_deleted=1 → 浏览器消失
□ 缺字段 → curl 400
□ 无效 ID → curl 错误提示
□ TypeScript 编译通过
□ Vite 构建成功
```

**全部 ☑ 后才能做下一个功能。如有失败，修复后重新跑所有检查项。**

---

### Phase 3-3: 验证「功能 C」（如：收费规则管理）

重复上述模式，替换 API 路径和数据库表名为功能 C 对应的名称。

#### ✅ 功能 C 验证通过清单
```
□ 增 □ 删 □ 改 □ 查 □ 边界 □ 编译 □ 构建
```

---

### Phase 3-4: 验证「功能 D」（如：停车记录管理）

重复上述模式，替换 API 路径和数据库表名为功能 D 对应的名称。

#### ✅ 功能 D 验证通过清单
```
□ 增 □ 删 □ 改 □ 查 □ 边界 □ 编译 □ 构建
```

---

### Phase 3-N: 验证更多功能

按需添加，模式同上。

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

## Phase 3-N 验证示例（以「文章管理」为例说明）

以下是**一个功能**做完后的完整验证过程（对应 Phase 2-N → Phase 3-N）。每个功能都应按此流程验证：

```bash
# ========== 第 1 步：API 验证 ==========
# 新增 → 确认 id 回填
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"title":"测试","content":"内容","author":"admin"}'
# ✅ 看到 {"code":200,"data":{"id":1,"title":"测试",...}}

# 列表 → 确认包含刚才新增
curl -s "http://localhost:8080/api/articles?pageNum=1&pageSize=10"
# ✅ 看到 records 中有刚才新增的记录

# 边界 → 缺字段校验
curl -s -X POST http://localhost:8080/api/articles \
  -H "Content-Type: application/json" \
  -d '{"content":"无标题","author":"admin"}'
# ✅ 返回 400

# ========== 第 2 步：数据库验证 ==========
mysql -u root your_db -e "SELECT id, title, content FROM articles ORDER BY id DESC LIMIT 1;"
# ✅ 看到刚才插入的数据

# ========== 第 3 步：前端浏览器验证 ==========
# 用 OpenHands 浏览器打开前端页面
# 点击"新增"→ 填数据 → 提交
# ✅ 弹 success toast
# ✅ 自动跳转回列表
# ✅ 列表显示新数据

# ========== 第 4 步：前端构建 ==========
cd frontend && npx vue-tsc --noEmit && npx vite build
# ✅ 编译通过，构建成功
```

**缺少任何一步，不能做下一个功能。**

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
