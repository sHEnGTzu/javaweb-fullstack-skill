# Common Full-Stack Bugs Catalog

> 40+ common bugs in Java Web full-stack projects (Spring Boot / MyBatis / JPA / etc.), organized by **where in the chain the bug manifests**.
> Each entry: Symptom → Root Cause → How to Detect in Verification → Fix

---

## Category A: 全链路断裂（请求发不出去或收不到响应）

### A01 — 前端请求 URL 与后端路径不匹配

**症状**: 浏览器 Network 面板看到请求 404，或请求根本没发到正确的地址

**常见原因**:
1. 后端 `@RequestMapping` 写的是 `/articles`，但前端请求的是 `/api/articles`
2. 后端有 `context-path: /api`，前端 HTTP 客户端 `baseURL` 中又写了 `/api`，结果实际请求为 `/api/api/articles`
3. 前端 API 路径写死了 `/articles`，但开发时 Vite proxy 映射到了 `/api/articles`

**检测方式（全链路验证—网络层）**:
```
打开浏览器 F12 → Network → 执行操作 → 查看请求 URL
→ 确认 URL 是否与后端 @RequestMapping + context-path 拼接后完全一致
```

**修复**:
- HTTP 客户端 `baseURL` 设为 `/api`，后端 `context-path: /api`，前端 API 路径写 `/articles`
- 最终 URL 为：`/api/articles`

### A02 — 请求方法与后端不匹配

**症状**: 浏览器看到 `405 Method Not Allowed`

**常见原因**:
- 前端用 GET 方式但后端是 `@PostMapping`
- 前端用 POST 方式但后端是 `@GetMapping`

**检测方式（全链路验证—网络层）**:
```
→ 检查 Network 面板的 Method 列
→ 与后端 @GetMapping/@PostMapping/@PutMapping/@DeleteMapping 对比
```

### A03 — 请求 Body 字段名与后端 DTO 不匹配

**症状**: 后端收到请求但 DTO 中部分或全部字段为 null

**常见原因**:
- 前端发 `{ "userName": "xxx" }`，后端 DTO 是 `username`
- 前端发 `{ "createAt": "..." }`，后端 DTO 是 `create_time`（未配置 Jackson 驼峰映射）
- 前端发 FormData，后端用 `@RequestBody` 或反之

**检测方式（全链路验证—网络层 + 后端日志）**:
```
→ Network 面板查看 Request Payload 字段名
→ 后端日志查看接收到的 DTO 字段
→ 两边对比
```

### A04 — CORS 预检失败

**症状**: 浏览器 Console 显示 CORS 错误，Network 看到 OPTIONS 请求返回 403/404

**常见原因**:
- 后端没有全局 CORS 配置
- 后端有 `@CrossOrigin` 但只配了一个 Controller，其他 Controller 跨域失败
- 后端 CORS 不允许前端 Origin

**检测方式（全链路验证—网络层）**:
```
→ Network 面板过滤 OPTIONS 请求
→ 确认 OPTIONS 请求返回了正确的 CORS 头
→ 如果后端根本没收到 OPTIONS 请求，说明是前端（Vite proxy）层面拦截了
```

**修复**: 全局 CORS 配置类，而不是 `@CrossOrigin` 散在各 Controller

### A05 — 请求未到达后端（前端拦截器阻止了请求）

**症状**: 点击按钮后 Network 面板看不到任何请求，或请求被 cancel

**常见原因**:
- HTTP 请求拦截器中 token 为 null 直接 reject
- 路由守卫（beforeEach）拦截了跳转，页面没渲染所以没发请求
- 请求拦截器中抛出了未捕获的异常

**检测方式（全链路验证—前端 HTTP 客户端层）**:
```
→ Network 面板确认是否有请求发出
→ 如果没有，在请求拦截器/封装层加日志排查
→ 如果是路由跳转后才发的请求，检查路由守卫是否阻挡了跳转
```

### A06 — HTTP 响应拦截器（或统一处理逻辑）未正确解包

**症状**: 前端代码中到处都在手动解后端返回的数据，如 `res.data.data.field` 或 `response.data.field`

**常见原因**:
- 响应拦截器（Axios response interceptor / fetch wrapper 等）返回了完整 response 而不是解包后的数据
- 前后端沟通不一致，后端换了包装结构但前端没更新

**检测方式（全链路验证—返回链路）**:
```
→ 在页面代码中搜索 ".data.data" 或 "response.data"
→ 如果很多地方都在手动解包，说明统一解包没做好
```

**修复**: 在 HTTP 客户端封装层统一解包（以 Axios 为例）：
```typescript
// 响应拦截器统一处理
http.interceptors.response.use(
  (response) => {
    const res = response.data  // { code, message, data }
    if (res.code !== 200) { /* 错误处理 */ return Promise.reject(res) }
    return res.data  // 在这里解包，后续代码直接拿到 data
  }
)
// 使用 fetch 的话同理封装一层：
async function request(url, options) {
  const res = await fetch(url, options)
  const json = await res.json()
  if (json.code !== 200) throw new Error(json.message)
  return json.data
}
```

### A07 — @RequestBody 参数前没加 @Valid

**症状**: DTO 上的 `@NotBlank`、`@Size` 等校验注解不生效

**常见原因**: `@RequestBody` 后面缺少 `@Valid` 或 `@Validated`

```java
// ❌ 校验不生效
public Result<Void> create(@RequestBody ArticleDTO dto)

// ✅ 校验生效
public Result<Void> create(@Valid @RequestBody ArticleDTO dto)
```

**检测方式（全链路验证—后端 Controller 层）**:
```
→ 提交空表单，看看返回的是 400 还是 200
→ 如果是 200 但数据存进去了，说明 @Valid 没加
```

---

## Category B: 前端 UI Bug（数据变了但界面没变）

### B00 — 前端按钮未绑定正确的函数（最常见！）

**症状**: 点击页面上的按钮没有任何反应，或点完后报 JS 错误（如 `xxx is not a function`）

**常见原因**:
1. 模板 `@click="handleCreate"` 但 `<script>` 里函数名是 `handleAdd`
2. 忘记在 `<script setup>` 中定义函数，或函数被写在了 `export default {}` 外部
3. `v-for` 循环中传参写错：`@click="handleDelete(item.id)"` 但 item 作用域不对
4. 引入的 API 模块路径写错（如 `import { listArticle } from '@/api/article'` 但实际导出是 `listArticles`）

**检测方式（全链路验证—前端模板层）**:
```
→ 打开浏览器点击按钮
→ Network 面板：有请求发出？→ 无请求 → 说明按钮没有绑定到函数
→ 浏览器控制台（F12 Console）：有 JS 报错？
→ 检查模板: 找到按钮的 @click 绑定的函数名
→ 检查 script: 该函数名是否定义且导出了？
→ 检查 API 模块: 调用的函数名是否与导出的一致？
```

**修复**: 确保模板 `@click` 绑定的函数名与 `<script>` 中定义的名字完全一致
```vue
<!-- ✅ 正确 -->
<el-button @click="handleCreate">新增</el-button>
<script setup>
const handleCreate = async () => { ... }
</script>

<!-- ❌ 错误: 函数名不匹配 -->
<el-button @click="handleCreate">新增</el-button>
<script setup>
const handleAdd = async () => { ... }   // handleCreate 不存在！
</script>
```

### B01 — 新增/修改/删除后列表不刷新（最常见！）

**症状**: 操作后 URL 变了，数据也写进数据库了，但列表显示的还是旧数据，需要手动刷新页面

**常见原因**:
```
新增页面 -> 调用 createApi() 成功 -> 跳转到列表页 -> 列表页没有重新 fetchData()
删除/修改 -> 调用 API 成功 -> 列表页没有重新 fetchData()
```

**检测方式（全链路验证—UI 更新层）**:
```
→ 打开数据库确认数据已变更
→ 打开前端 DevTools 确认列表页的 data 没有更新
→ 在 fetchData() 调用处加 console.log 确认是否被调用
```

**修复**: 操作成功后立即调用列表刷新：
```typescript
// 新增成功跳转前
await articleApi.create(form)
ElMessage.success('Created successfully')
router.push('/articles')  // 如果列表页用了 onMounted(fetchData)，需要确保每次进入都触发

// 删除成功后
await articleApi.delete(id)
ElMessage.success('Deleted successfully')
fetchArticles()  // 或 pageNum.value = 1; fetchArticles()
```

### B02 — 操作成功但用户看不到反馈

**症状**: 点了保存按钮，页面静悄悄，用户不确定是不是成功了

**常见原因**: 成功后没有调用 `ElMessage.success()` / `ElMessage.info()`

**检测方式**: 每个写操作后检查是否有用户可感知的反馈

**修复**:
```typescript
try {
  await api.create(data)
  ElMessage.success('创建成功')  // ✅ 必须有
} catch { /* 错误由 interceptor 处理 */ }
```

### B03 — 表单重复提交

**症状**: 用户快速点击提交按钮，创建了多条相同的数据

**常见原因**: 提交按钮在 API 请求期间没有 disabled

**检测方式**:
```
→ 快速双击提交按钮
→ 检查数据库是否有两条相同数据
```

**修复**:
```typescript
const submitting = ref(false)
const submitForm = async () => {
  submitting.value = true
  try { ... } finally { submitting.value = false }
}
```
```html
<el-button :loading="submitting" :disabled="submitting">提交</el-button>
```

### B04 — 不该出现的 UI 元素没有被隐藏

**症状**: 页面上显示了不应该出现的元素
- 已发布文章显示"发布"按钮
- 草稿文章显示"下架"按钮
- 普通用户看到管理员才有的"删除"按钮

**常见原因**: 没有使用 `v-if` 根据数据状态控制元素显示

**检测方式（全链路验证—UI 更新层）**:
```
→ 针对每个 UI 元素，问：什么条件下它不应该显示？
→ 检查对应的 v-if / v-show 条件
```

**修复**:
```html
<!-- 只有草稿才显示"发布"按钮 -->
<el-button v-if="article.status === 0" @click="publish(article.id)">发布</el-button>

<!-- 只有已发布才显示"下架"按钮 -->
<el-button v-if="article.status === 1" @click="unpublish(article.id)">下架</el-button>

<!-- 只有管理员才看到删除 -->
<el-button v-if="user.role === 'admin'" @click="remove(article.id)">删除</el-button>
```

### B05 — 空数据页面空白或只显示表头

**症状**: 列表没有数据时，只显示表格的列头，下面空空如也

**常见原因**: 没有使用 `v-if="data.length === 0"` 单独处理空状态

**检测方式**: 清空所有数据，看列表页显示什么

**修复**:
```html
<div v-if="loading">加载中...</div>
<div v-else-if="error">错误: {{ error }} <el-button @click="fetchData">重试</el-button></div>
<el-empty v-else-if="data.length === 0" description="暂无数据" />
<el-table v-else :data="data">...</el-table>
```

### B06 — Vue 响应式丢失

**症状**: 数据变了但 UI 不更新，或者 API 返回了数据但模板中访问不到字段

**常见原因**:
```typescript
// ❌ reactive 对象被整体赋值
const form = reactive({...})
form = newForm  // 失去了响应式

// ❌ ref 在模板中忘了 .value
const count = ref(0)
count++  // 模板中仍然是 0

// ❌ 直接修改数组元素
const list = ref([{...}])
list.value[0] = newItem  // 不触发更新
```

**检测方式**: 操作后检查 Vue DevTools 中对应变量的值

**修复**:
```typescript
// reactive → 修改属性而不是替换引用
Object.assign(form, newForm)

// ref → 始终使用 .value
count.value++

// 数组 → 使用 splice 或重新赋值
list.value.splice(index, 1, newItem)
// 或 list.value = [...list.value.slice(0, index), newItem, ...list.value.slice(index+1)]
```

### B07 — 路由跳转后目标页面空白

**症状**: URL 变了但页面空白，控制台没有明显报错

**常见原因**:
- `component: () => import('@/views/Xxx.vue')` 路径不正确
- 目标组件 `export default` 写成了 `export` 或忘记写
- 路径大小写不匹配（Windows 开发没问题，Linux 部署报错）

**检测方式**:
```
→ 直接访问目标 URL
→ 打开控制台看是否有 404 资源加载错误
```

**修复**: 每个新路由添加后，实际访问确认。使用精确路径匹配真实文件路径。

---

## Category C: 后端常见陷阱

### C01 — 声明式事务不回滚

**症状**: 发生异常但数据被部分提交

**原因**: 很多框架默认只对 `RuntimeException` 回滚，检查异常（如 `Exception` 或自定义业务异常）不会触发

**检测方式**: 强制抛出一个检查异常（如 `throw new Exception("test")`），检查数据是否回滚

**修复**: 指定回滚所有异常类型
```java
// Spring
@Transactional(rollbackFor = Exception.class)

// 或手动管理事务
try {
    // ... 业务操作
    transactionManager.commit(status);
} catch (Exception e) {
    transactionManager.rollback(status);
    throw e;
}
```

### C02 — ORM 更新操作无法将字段设为 null

**症状**: 想将某个字段清空（设为 null），调用通用 update 方法后该字段值不变

**原因**: 很多 ORM 框架默认策略是只更新非 null 字段，null 字段不会出现在 UPDATE SET 中
- MyBatis-Plus: `updateById()` 默认策略 `NOT_NULL`
- JPA: 只更新变更字段（dirty checking），除非显式设置

**修复**:
```java
// MyBatis-Plus: 用 UpdateWrapper 显式设置 null
LambdaUpdateWrapper<User> wrapper = Wrappers.lambdaUpdate();
wrapper.set(User::getEmail, null);
wrapper.eq(User::getId, id);
userMapper.update(null, wrapper);

// JPA: 用 @Column 注解或自定义 @Query
@Query("UPDATE User u SET u.email = NULL WHERE u.id = :id")
void clearEmail(@Param("id") Long id);
```

### C03 — Entity 直接暴露给前端

**症状**: 前端拿到了密码、is_deleted 等不该暴露的字段，或序列化时无限递归（如 Jackson StackOverflow）

**检测方式**: 检查 Controller 方法返回类型是 Entity 还是 DTO/VO

**修复**: 始终用 DTO/VO 返回，不在 Controller 层直接返回 Entity
```java
// ❌ Entity 直接暴露（危险）
public Result<User> getById(Long id)

// ✅ 用 VO 隔离
public Result<UserVO> getById(Long id)
```

### C04 — 参数化查询使用不当导致 SQL 注入

**症状**: 安全扫描发现问题，或用户输入特殊字符导致 SQL 报错

**原因**: 字符串拼接 SQL 而非参数化查询

**检测方式**: 搜索代码中的字符串拼接 SQL 模式：
```
// 搜索关键字: + "where" , + "and" , ${} , Statement
```

**修复**: 始终使用参数化查询
```java
// MyBatis: #{} 安全，${} 危险
// ✅ SELECT * FROM users WHERE name = #{name}
// ❌ SELECT * FROM users WHERE name = '${name}'

// JPA: 参数绑定安全
// ✅ @Query("SELECT u FROM User u WHERE u.name = :name")
// ❌ @Query("SELECT u FROM User u WHERE u.name = '" + name + "'")

// JDBC: PreparedStatement 安全
// ✅ preparedStatement.setString(1, name)
// ❌ statement.executeQuery("SELECT * FROM users WHERE name = '" + name + "'")
```

### C05 — 新增/更新后 Controller 返回了旧数据

**症状**: 新增成功后页面拿到了 id 为 null 的对象，或修改后返回的是修改前的数据

**原因**: 
- ORM 插入后没有自动回填自增主键（未配置 `useGeneratedKeys` / `@GeneratedValue`）
- Service 返回了入参的 DTO 而不是从数据库查询或 ORM 回填后的完整对象

**检测方式**: 检查 Service 的 create/update 方法是否返回了完整数据（id 不为 null）

**修复**: Service 方法返回 VO，确保包含数据库回填的字段（如自增 id、自动填充的时间戳）

### C06 — 分页查询返回了全部数据

**症状**: 传了 page/size 参数，但查询结果没有分页，返回了全部数据

**原因**:
- 分页插件没有正确配置或注册（如 MyBatis-Plus 缺少 `PaginationInnerInterceptor` / JPA 没传 `Pageable`）
- 查询方法返回类型写成了 `List<T>` 而不是 `Page<T>` / `IPage<T>`

**检测方式**: 检查后端 SQL 日志，看有没有 `LIMIT` / `OFFSET` / `FETCH NEXT` 语句

**修复**: 确认分页插件已配置，查询方法返回分页类型而不是 List

### C07 — 请求参数必填导致 400

**症状**: 请求返回 400 Bad Request，但 URL 看起来没问题

**原因**: Controller 参数默认是必填的（`required = true`），而前端没传该参数

**检测方式**: Network 面板看请求 URL 参数是否完整

**修复**: 可选参数设 `required = false`（或 Java Optional 类型）
```java
// Spring
@RequestParam(required = false) String keyword

// JAX-RS
@QueryParam("keyword") Optional<String> keyword
```

---

## Category D: 数据库 Bug

### D01 — 软删除条件未加

**症状**: 已删除的数据出现在列表页或查询结果中

**原因**: 部分查询没有自动或手动追加软删除过滤条件（`is_deleted = 0` / `deleted_at IS NULL`）

**检测方式**: `SELECT * FROM table WHERE is_deleted = 1` 看是否有数据，然后对比前端展示

**修复**: 
- ORM 层面统一配置（如 MyBatis-Plus `@TableLogic` / JPA `@Where(clause="is_deleted = 0")` / Hibernate `@SQLRestriction`）
- 手写 SQL 时每次都要追加软删除条件
- 如果用了多种查询方式（ORM + 原生 SQL），确保所有路径都覆盖

### D02 — JOIN 查询没有索引

**症状**: 数据量增大后页面加载缓慢，数据库 CPU 升高

**检测方式**:
```sql
EXPLAIN SELECT ... FROM a LEFT JOIN b ON a.fk = b.id
-- 看 type 列如果为 ALL（全表扫描）则需要加索引
```

**修复**: 外键列和 JOIN 条件列加索引

### D03 — 批量操作没有事务

**症状**: 批量插入/更新过程中出错，部分数据已写入无法回滚

**修复**: Service 方法加声明式事务并指定回滚所有异常类型

---

## 快速排查指南

当遇到问题时，根据症状选择排查路径：

| 症状 | 优先排查 | 相关 Bug |
|------|---------|---------|
| 点击按钮没反应 | Network 面板看有没有请求发出 | **B00**, A05 |
| 点击按钮报 JS 错误 | 检查 @click 绑定的函数名是否与 script 中的定义一致 | **B00** |
| 请求 404 | URL 是否正确？context-path 是否匹配？ | A01 |
| 请求 405 | 请求方法是否正确？ | A02 |
| 请求 400 | Body 字段名是否正确？参数是否缺失？ | A03, C07 |
| 请求 500 | 看后端日志 | C01, C06 |
| CORS 错误 | OPTIONS 预检请求 | A04 |
| 数据改了 UI 没变 | 列表是否重新 fetch？ | B01, B06 |
| 操作成功没提示 | 是否调了 ElMessage.success？ | B02 |
| 重复数据 | 按钮是否防重复？ | B03 |
| 页面上多了不该有的按钮 | v-if 条件？ | B04 |
| 空列表没提示 | empty 状态处理？ | B05 |
| 页面跳转后空白 | router import 路径？ | B07 |
| 传入 null 的字段没更新 | ORM null 字段策略 | C02 |
