# Common Full-Stack Bugs Catalog

> 40+ common bugs in Java Web full-stack projects, organized by **where in the chain the bug manifests**.
> Each entry: Symptom → Root Cause → How to Detect → How to Fix

Use this reference when Phase 3 verification fails or when you encounter a bug during development. Match your symptom to the categories below, then follow the detection and fix steps.

---

## Category A: 全链路断裂（请求发不出去或收不到响应）

### A01 — 前端请求 URL 与后端路径不匹配

**Symptom**: Browser Network shows 404, or request never reaches the right address

**Common causes**:
1. Backend `@RequestMapping` is `/articles` but frontend requests `/api/articles`
2. Backend has `context-path: /api` AND frontend HTTP client `baseURL` also has `/api` → double prefix, actual URL becomes `/api/api/articles`
3. Frontend path is hardcoded `/articles` but Vite proxy maps to `/api/articles`

**How to detect**: Open F12 → Network → perform action → examine request URL. Compare with backend `@RequestMapping` + `context-path` concatenated.

**How to fix**: Set HTTP client `baseURL=/api`, backend `context-path: /api`, frontend API paths as `/articles`. Final URL should be `/api/articles`.

### A02 — 请求方法与后端不匹配

**Symptom**: `405 Method Not Allowed`

**Common causes**: Frontend sends GET but backend is `@PostMapping`; frontend sends POST but backend is `@GetMapping`

**How to detect**: Check Network panel Method column vs backend `@GetMapping/@PostMapping/@PutMapping/@DeleteMapping`

**How to fix**: Change the frontend request method or backend mapping annotation to match.

### A03 — 请求 Body 字段名与后端 DTO 不匹配

**Symptom**: Backend receives the request but DTO fields are partially or all null

**Common causes**:
- Frontend sends `{ "userName": "xxx" }` but backend DTO has `username`
- Frontend sends `{ "createAt": "..." }` but backend DTO has `create_time` (Jackson camelCase mapping not configured)
- Frontend sends FormData but backend uses `@RequestBody`, or vice versa

**How to detect**: Compare Network → Request Payload field names with backend log showing received DTO fields.

**How to fix**: Align field names between frontend and backend. Configure Jackson `spring.jackson.property-naming-strategy` if needed.

### A04 — CORS 预检失败

**Symptom**: Browser Console shows CORS error; Network shows OPTIONS request returning 403/404

**Common causes**:
- Backend has no global CORS configuration
- Backend uses `@CrossOrigin` on only one Controller, others fail
- Backend CORS doesn't allow the frontend's Origin

**How to detect**: Filter Network by OPTIONS method. Confirm OPTIONS response has correct CORS headers (Access-Control-Allow-Origin, etc.). If backend never receives OPTIONS, Vite proxy is intercepting it.

**How to fix**: Create ONE global CORS config class. Do NOT use `@CrossOrigin` scattered across Controllers.

### A05 — 请求未到达后端（前端拦截器阻止了请求）

**Symptom**: Clicking the button shows no request in Network tab, or request is cancelled

**Common causes**:
- HTTP request interceptor rejects because token is null
- Route guard (beforeEach) blocks navigation, page never renders so request never fires
- Request interceptor throws an uncaught exception

**How to detect**: Check Network panel — if no request was sent, add console.log in the request interceptor or API wrapper to trace the issue.

**How to fix**: Fix the interceptor logic. Ensure token is available before sending requests, or allow unauthenticated requests to proceed.

### A06 — HTTP 响应拦截器（或统一处理逻辑）未正确解包

**Symptom**: Frontend code has `res.data.data.field` or `response.data.field` everywhere

**Common causes**: Response interceptor returns the full response object instead of unwrapped data. Backend changed wrapper structure but frontend didn't update.

**How to detect**: Search the codebase for `.data.data` or `response.data`. If many places manually unwrap, the interceptor isn't doing its job.

**How to fix**: Unwrap in the HTTP client layer (Axios interceptor or fetch wrapper):

```typescript
// Axios response interceptor — unwrap once, use everywhere
http.interceptors.response.use(
  (response) => {
    const res = response.data  // { code, message, data }
    if (res.code !== 200) {
      // Handle business error (show message, redirect to login, etc.)
      return Promise.reject(res)
    }
    return res.data  // Unwrap: views get data directly, no .data.data needed
  }
)

// fetch equivalent
async function request(url, options) {
  const res = await fetch(url, options)
  const json = await res.json()
  if (json.code !== 200) throw new Error(json.message)
  return json.data
}
```

### A07 — @RequestBody 参数前没加 @Valid

**Symptom**: Validation annotations (`@NotBlank`, `@Size`, `@Email`) on DTO don't work

**Common causes**: `@RequestBody` without `@Valid` or `@Validated`

**How to detect**: Submit an empty form — if it returns 200 and saves to DB, @Valid is missing

**How to fix**:
```java
// ❌ Validation does NOT work
public Result<Void> create(@RequestBody ArticleDTO dto)

// ✅ Validation works
public Result<Void> create(@Valid @RequestBody ArticleDTO dto)
```

---

## Category B: 前端 UI Bug（数据变了但界面没变）

### B01 — 新增/修改/删除后列表不刷新（最常见！）

**Symptom**: After create/update/delete, URL changes and data is in DB, but the list still shows old data. User has to manually refresh the page.

**Root cause**: List page doesn't call `fetchData()` after a write operation succeeds.

**How to detect**: Open DB to confirm data changed → Open DevTools to check if list component data updated → Add console.log in `fetchData()` to check if it's called.

**How to fix**: After every write operation, immediately refresh the list:
```typescript
// After create, before navigation
await articleApi.create(form)
ElMessage.success('创建成功')
router.push('/articles')  // Ensure list page fetches on mount

// After delete
await articleApi.delete(id)
ElMessage.success('删除成功')
fetchArticles()  // Or: pageNum.value = 1; fetchArticles()
```

### B02 — 操作成功但用户看不到反馈

**Symptom**: User clicks Save, nothing visibly happens. User doesn't know if it succeeded.

**Root cause**: No `ElMessage.success()` / `ElMessage.info()` called after success.

**How to detect**: Check every write operation handler for a toast/message call after the API call.

**How to fix**:
```typescript
try {
  await api.create(data)
  ElMessage.success('创建成功')
} catch { /* error handled by interceptor */ }
```

### B03 — 表单重复提交

**Symptom**: User double-clicks submit button, creating duplicate records.

**Root cause**: Submit button is not disabled during API call.

**How to detect**: Double-click the submit button quickly, then check DB for duplicate records.

**How to fix**:
```typescript
const submitting = ref(false)
const submitForm = async () => {
  submitting.value = true
  try {
    await api.create(form)
    ElMessage.success('创建成功')
  } finally {
    submitting.value = false
  }
}
```
```html
<el-button :loading="submitting" :disabled="submitting">提交</el-button>
```

### B04 — 不该出现的 UI 元素没有被隐藏

**Symptom**: Page shows elements that should be hidden:
- Published article shows "Publish" button
- Draft article shows "Unpublish" button
- Non-admin user sees "Delete" button

**Root cause**: Missing `v-if` or role-based condition on UI elements

**How to detect**: For each UI element, ask: "Under what condition should this NOT be shown?" Check the corresponding `v-if`/`v-show`.

**How to fix**:
```html
<!-- Only show for drafts -->
<el-button v-if="article.status === 0" @click="publish(article.id)">发布</el-button>

<!-- Only show for published -->
<el-button v-if="article.status === 1" @click="unpublish(article.id)">下架</el-button>

<!-- Only admins see delete -->
<el-button v-if="user.role === 'admin'" @click="remove(article.id)">删除</el-button>
```

### B05 — 空数据页面空白或只显示表头

**Symptom**: Empty list shows only column headers with no data below.

**Root cause**: No `v-if="data.length === 0"` handling for empty state

**How to detect**: Clear all data/ search with no results. Check what the page displays.

**How to fix**:
```html
<div v-if="loading">加载中...</div>
<div v-else-if="error">
  错误: {{ error }}
  <el-button @click="fetchData">重试</el-button>
</div>
<el-empty v-else-if="data.length === 0" description="暂无数据" />
<el-table v-else :data="data">...</el-table>
```

### B06 — Vue 响应式丢失

**Symptom**: Data changes but UI doesn't update. Or API returns data but template can't access fields.

**Common causes**:
```typescript
// ❌ Replacing a reactive object (breaks reactivity)
const form = reactive({...})
form = newForm

// ❌ Forgetting .value with ref
const count = ref(0)
count++  // template still shows 0

// ❌ Directly modifying array elements
const list = ref([{...}])
list.value[0] = newItem  // doesn't trigger update
```

**How to detect**: After operation, check Vue DevTools for the variable value.

**How to fix**:
```typescript
// reactive → modify properties, don't replace reference
Object.assign(form, newForm)

// ref → always use .value
count.value++

// array → use splice or reassign the whole array
list.value.splice(index, 1, newItem)
// Or: list.value = [...list.value.slice(0, index), newItem, ...list.value.slice(index+1)]
```

### B07 — 路由跳转后目标页面空白

**Symptom**: URL changes but page is blank. Console has no obvious errors.

**Root cause**: `component: () => import('@/views/Xxx.vue')` path is wrong; component `export default` is missing or wrong; case mismatch (works on Windows, fails on Linux).

**How to detect**: Directly navigate to the target URL. Check console for 404 resource loading errors.

**How to fix**: After adding each new route, visit the URL directly to confirm it renders. Ensure the import path matches the actual file path exactly.

---

## Category C: 后端常见陷阱

### C01 — 声明式事务不回滚

**Symptom**: Exception occurs but data is partially committed

**Root cause**: Default transaction management only rolls back on `RuntimeException`. Checked exceptions (like custom business exceptions) don't trigger rollback.

**How to detect**: Force a checked exception (`throw new Exception("test")`) inside a transactional method and check if data is rolled back.

**How to fix**:
```java
// Spring — explicitly declare rollback for all exceptions
@Transactional(rollbackFor = Exception.class)

// Manual transaction management
try {
    // business operations
    transactionManager.commit(status);
} catch (Exception e) {
    transactionManager.rollback(status);
    throw e;
}
```

### C02 — ORM 更新操作无法将字段设为 null

**Symptom**: Setting a field to null via a generic update method doesn't work — the field retains its old value.

**Root cause**: ORM frameworks default to updating only non-null fields:
- MyBatis-Plus: `updateById()` strategy is `NOT_NULL` by default
- JPA: Dirty checking only updates changed fields unless explicitly set

**How to fix**:
```java
// MyBatis-Plus: use UpdateWrapper to explicitly set null
LambdaUpdateWrapper<User> wrapper = Wrappers.lambdaUpdate();
wrapper.set(User::getEmail, null);
wrapper.eq(User::getId, id);
userMapper.update(null, wrapper);

// JPA: use @Query to set null explicitly
@Query("UPDATE User u SET u.email = NULL WHERE u.id = :id")
void clearEmail(@Param("id") Long id);
```

### C03 — Entity 直接暴露给前端

**Symptom**: Frontend receives sensitive fields (passwords, `is_deleted`, internal IDs). Or serialization causes infinite recursion (Jackson StackOverflow).

**How to detect**: Check Controller method return types — if they return `Result<Entity>` instead of `Result<VO>`, this bug exists.

**How to fix**: ALWAYS return DTO/VO from Controller. NEVER return Entity directly.
```java
// ❌ DANGEROUS — exposes Entity fields
public Result<User> getById(Long id)

// ✅ SAFE — uses VO to isolate internal fields
public Result<UserVO> getById(Long id)
```

### C04 — 参数化查询使用不当导致 SQL 注入

**Symptom**: Security scan flags SQL injection risk. Special characters in user input cause SQL errors.

**Root cause**: String concatenation for SQL instead of parameterized queries

**How to detect**: Search codebase for string concatenation patterns: `+ "where"`, `+ "and"`, `${}`, `Statement`

**How to fix**: Always use parameterized queries:
```java
// MyBatis: #{} is safe, ${} is DANGEROUS
// ✅ SELECT * FROM users WHERE name = #{name}
// ❌ SELECT * FROM users WHERE name = '${name}'

// JPA: parameter binding is safe
// ✅ @Query("SELECT u FROM User u WHERE u.name = :name")
// ❌ @Query("SELECT u FROM User u WHERE u.name = '" + name + "'")

// JDBC: PreparedStatement is safe
// ✅ preparedStatement.setString(1, name)
// ❌ statement.executeQuery("SELECT * FROM users WHERE name = '" + name + "'")
```

### C05 — 新增/更新后 Controller 返回了旧数据

**Symptom**: After create, frontend receives object with null id. After update, frontend gets old values.

**Root cause**: ORM didn't auto-fill generated keys (missing `useGeneratedKeys`/`@GeneratedValue`). Service returned the input DTO instead of the complete object from DB.

**How to detect**: Check if Service create/update methods return a complete object (id is not null)

**How to fix**: Service should return VO with all DB-populated fields (auto-increment id, auto-filled timestamps).

### C06 — 分页查询返回了全部数据

**Symptom**: Sending page/size params but query returns all records, not a page.

**Root cause**: Pagination plugin not configured (MyBatis-Plus missing `PaginationInnerInterceptor`; JPA didn't receive `Pageable`). Query method returns `List<T>` instead of `Page<T>`/`IPage<T>`.

**How to detect**: Check backend SQL logs for `LIMIT`/`OFFSET`/`FETCH NEXT` clauses — if absent, pagination is broken.

**How to fix**: Register the pagination plugin. Ensure query method returns paginated type, not `List`.

### C07 — 请求参数必填导致 400

**Symptom**: Request returns 400 Bad Request but the URL looks fine.

**Root cause**: Controller params default to `required = true`, but frontend didn't send that param.

**How to detect**: Network panel: examine request URL params vs Controller method signatures.

**How to fix**: Mark optional params with `required = false` or use `Optional<>` type:
```java
// Spring
@RequestParam(required = false) String keyword

// JAX-RS
@QueryParam("keyword") Optional<String> keyword
```

---

## Category D: 数据库 Bug

### D01 — 软删除条件未加

**Symptom**: Deleted records appear in lists or query results.

**Root cause**: Some queries don't filter by soft-delete condition (`is_deleted = 0` / `deleted_at IS NULL`).

**How to detect**: Run `SELECT * FROM table WHERE is_deleted = 1` — if results exist, compare with frontend display.

**How to fix**:
- ORM level: configure globally (MyBatis-Plus `@TableLogic` / JPA `@Where(clause="is_deleted = 0")` / Hibernate `@SQLRestriction`)
- Raw SQL: ALWAYS append the soft-delete condition manually
- If using mixed approaches (ORM + native SQL), ensure ALL paths are covered

### D02 — JOIN 查询没有索引

**Symptom**: Page loads slowly as data grows. Database CPU increases.

**How to detect**:
```sql
EXPLAIN SELECT ... FROM a LEFT JOIN b ON a.fk = b.id
-- If type column shows 'ALL' (full table scan), index is needed
```

**How to fix**: Add indexes on foreign key columns and JOIN condition columns.

### D03 — 批量操作没有事务

**Symptom**: Batch insert/update fails midway, partial data is committed.

**How to fix**: Add `@Transactional(rollbackFor = Exception.class)` on the Service method.


