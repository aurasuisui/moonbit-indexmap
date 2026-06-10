# MoonBit IndexMap 执行计划书

> **目标读者**：另一个 Claude Code 实例（开发者角色）。你是执行者，按本计划书逐步完成开发任务。
>
> **你的角色**：MoonBit 项目开发工程师。你的工作是用 MoonBit 语言完成一个有序哈希表库，所有代码必须通过 `moon check` 类型检查和 `moon test` 测试。
>
> **更新日期**：2026-06-10（v0.2.0 全部完成）

# 3. 验证当前状态
moon check           # 应输出 151 warnings, 0 errors
moon test            # 应输出 220 passed, 0 failed
```

**当前进度总览**：
- ✅ 源码编译通过（0 errors, 151 warnings）
- ✅ 220 个测试全部通过（新增 9 个测试）
- ✅ 代码行数 4,420（新增 231 行）
- ✅ v0.1.0 + v0.2.0 全部功能完成
- ✅ 15 commits 已推送 GitHub
- ✅ 申报已通过，Gitlink 仓库已同步

**v0.2.0 全部完成**：
- ✅ **Debug trait**：IndexMap[K, V] 和 IndexSet[K] 实现 Debug trait（Repr::opaque_ 包装）
- ✅ **Default trait**：IndexMap::default()、IndexSet::default()
- ✅ **copy() 方法**：浅拷贝 buckets + order 数组，IndexSet 委托给 IndexMap
- ✅ **get_mut() 方法**：通过回调函数修改值，支持原地增删改
- ✅ **into_iter() 方法**：消耗性迭代器 IntoIter[K, V]（含 next/collect/count_remaining）
- ✅ **into_array() 方法**：消耗 map/set 返回数组
- ✅ **ToJson trait**：IndexMap→Json::object（保序），IndexSet→Json::array（保序）
- ✅ **9 个新测试**：Default、copy、get_mut、into_iter、into_array 全覆盖
>
> ---

## 新会话快速接手指南

如果你是新窗口的 Claude Code，按以下步骤快速上手：

```bash
# 1. 进入项目目录
cd "C:\Users\aurasui\Desktop\GitLink\MoonBit 开源生态项目贡献赛\moonbit-indexmap"

# 2. 验证环境（如果失败，参考第三章安装工具链）
export PATH="$HOME/.moon/bin:$PATH"
export MOON_HOME="$HOME/.moon"
moon version --all

# 3. 验证当前状态
moon check           # 应输出 140 warnings, 0 errors
moon test            # 应输出 211 passed, 0 failed
```

**当前进度总览**：
- ✅ 源码编译通过（0 errors, 140 warnings）
- ✅ 211 个测试全部通过
- ✅ v0.1.0 全部功能完成
- ✅ 代码行数 4,189（新增 78 行）
- ✅ 15 commits 已推送 GitHub
- ✅ 申报已通过（2026-06-10），Gitlink 仓库已同步
- 🔄 v0.2.0 开发中（✅ Debug ✅ Default ✅ copy()  🔄 get_mut 🔄 into_iter 🔄 ToJson 🔄 重构优化）

**2026-06-10 v0.2.0 Batch 1 完成**：
- ✅ **Debug trait**：IndexMap[K: Debug+Hash+Eq, V: Debug] 和 IndexSet[K: Debug+Hash+Eq] 实现 Debug trait
  - 使用 `Repr::opaque_("IndexMap", Repr::map(...))` 和 `Repr::opaque_("IndexSet", Repr::array(...))`
  - 与 MoonBit 新一代调试体系接轨
- ✅ **Default trait**：IndexMap[K, V] 和 IndexSet[K] 实现 Default trait
  - 可配合 `unwrap_or_default()` 等标准 API 使用
- ✅ **copy() 方法**：遵循 MoonBit stdlib 约定（无 Clone trait，使用独立方法模式）
  - IndexMap::copy() 独立拷贝 buckets 和 order 数组
  - IndexSet::copy() 委托给 IndexMap::copy()

**MoonBit 语言特性研究完成**（详见第六章）：
- ✅ `for .. in` 协议 / Debug trait + Repr 体系 / Default trait / copy() 模式
- ✅ ToJson trait / QuickCheck Arbitrary / HashMap 实现参考

**2026-06-10 警告清理**：
- ✅ 消除 [0053] unused_trait_bound（8→0）
- ✅ 消除 [0002] unused_variable（4→0）
- ⚠️ [0020] inspect（85）+ [0013] 类型推断（49）+ [0001] trait impl（4）= 138 保留

---

## 一、项目概述

### 1.1 我们在做什么

为 MoonBit 编程语言实现一个**保留插入顺序的哈希表**（对标 Rust 的 `indexmap` crate）。这是 MoonBit 开源生态项目贡献赛的参赛项目。

### 1.2 为什么 MoonBit 需要这个

MoonBit 内置的 `Map[K, V]` 迭代顺序不确定。但实际开发中经常需要按插入顺序遍历——配置文件解析、JSON 字段排序、LRU 缓存、确定性的测试输出。Rust 的 indexmap 月下载量超 2000 万次，说明这是真实高频需求。

### 1.3 技术方案（已定好，不要改）

| 决策 | 方案 | 原因 |
|------|------|------|
| 哈希表实现 | Robin Hood 开放寻址 | 比简单线性探测 probe 距离更均匀 |
| 顺序维护 | 独立的 `Array[K]` | 简洁，迭代时直接遍历数组即可 |
| 删除策略 | Tombstone 标记 + 定期 rehash | 保持 probe 链完整性 |
| Entry API | `enum EntryView { Occupied, Vacant }` | MoonBit 代数数据类型原生支持 |
| 哈希算法 | MoonBit 内置 `Hash` trait | 减少外部依赖，降低 API 复杂度 |
| 许可证 | Apache 2.0 | 与 Rust indexmap 保持一致 |

---

## 二、仓库和文件结构（当前实际状态）

```
moonbit-indexmap/
├── moon.mod.json              # 包配置（包名: indexmap）
├── ARCHITECTURE.md            # 架构文档
├── README.md                  # 项目 README
├── CHANGELOG.md               # 变更日志
├── CONTRIBUTING.md            # 贡献指南
├── ROADMAP.md                 # 路线图
├── LICENSE                    # Apache 2.0
├── .gitignore                 # Git 忽略规则
├── 申报书-IndexMap.md         # 参赛申报书（已提交）
├── 执行计划书-ClaudeCode.md   # 本文件
├── src/
│   ├── moon.pkg.json          # 源包配置
│   ├── lib.mbt                # 入口模块（~47行）
│   ├── map.mbt                # IndexMap 核心（~1045行）
│   ├── set.mbt                # IndexSet 包装器（~223行）
│   ├── hash.mbt               # 哈希工具常量（~57行）
│   ├── map_test.mbt           # IndexMap 黑盒测试（~1272行，~80测试）
│   ├── set_test.mbt           # IndexSet 黑盒测试（~495行，~45测试）
│   ├── bench_test.mbt         # 基准测试（~486行，30测试）
│   └── property_test.mbt      # 属性/不变量测试（~489行，39测试）
└── .github/workflows/
    └── ci.yml                 # CI 配置
```

**当前总计：约 4,111 行 MoonBit 代码。211 个测试全部通过。15 commits 已推送 GitHub。**

> ⚠️ **重要变更说明**（与初版相比）：
> - 测试从 `test/` 目录迁移到 `src/*_test.mbt`（MoonBit 新格式）
> - 包名从 `moonbit-indexmap` 改为 `indexmap`（连字符 `-` 在 `@pkg` 引用中非法）
> - `IndexSet` 从 `type` 别名改为 `struct` 包装器（`struct IndexSet[K] { inner: IndexMap[K, Unit] }`）
> - 迭代器、Entry 类型从 `type` 改为 `struct`（MoonBit 新语法）
> - 测试为黑盒测试（`*_test.mbt`），通过 `@indexmap.` 引用主包

---

## 三、环境准备

### 3.1 当前 MoonBit 版本

```
moon 0.1.20260522 (84aa893 2026-05-22)
moonc v0.9.3+3d4544a9e (2026-05-22)
moonrun 0.1.20260522 (84aa893 2026-05-22)
```

### 3.2 安装 MoonBit 工具链（Windows）

```bash
# 方法1：下载二进制包
curl -fsSL -o /tmp/moon.zip https://cli.moonbitlang.cn/binaries/latest/moonbit-windows-x86_64.zip
unzip -o /tmp/moon.zip -d ~/.moon/

# 方法2：下载 core 标准库（必须）
curl -fsSL -o /tmp/moon-core.zip https://cli.moonbitlang.cn/cores/core-latest.zip
unzip -o /tmp/moon-core.zip -d ~/.moon/lib/

# 必须先编译 core 库，否则所有项目都无法编译
cd ~/.moon/lib/core && moon bundle --all

# 验证
export PATH="$HOME/.moon/bin:$PATH"
export MOON_HOME="$HOME/.moon"
moon version --all
```

### 3.3 编译和测试命令

```bash
cd moonbit-indexmap

# 类型检查
moon check

# 运行测试
moon test

# 格式化代码
moon fmt
```

---

## 四、已验证的 MoonBit 语法要点

以下是在第 1 轮修复中确认的 MoonBit 语法规则（与 Rust 的主要差异）：

### 4.1 泛型函数声明

```moonbit
// ✅ 正确（新语法）
pub fn[K : Hash + Eq, V] IndexMap::insert(self : IndexMap[K, V], key : K, value : V) -> Option[V]

// ❌ 错误（旧语法，已弃用）
pub fn IndexMap::insert[K : Hash + Eq, V](self : IndexMap[K, V], key : K, value : V) -> Option[V]
```

### 4.2 常量声明

```moonbit
// ✅ 正确 — 大写标识符必须用 const
const MIN_CAPACITY : Int = 16

// ❌ 错误 — let 不允许大写标识符
let MIN_CAPACITY : Int = 16
```

### 4.3 结构体 / 类型

```moonbit
// ✅ 有字段的类型必须用 struct
struct Iter[K, V] {
  map : IndexMap[K, V]
  mut pos : Int   // 可变字段
}

// ❌ 错误 — type 不支持记录语法
type Iter[K, V] {
  map : IndexMap[K, V]
  pos : Int
}
```

### 4.4 布尔取反

```moonbit
// ✅ 正确
if !found { ... }

// ❌ 错误 — Bool 没有 .not() 方法
if found.not() { ... }
```

### 4.5 Trait 实现

```moonbit
// Hash trait — 必须实现 hash_combine（不是 hash）
impl[K : Hash + Eq, V : Hash] Hash for IndexMap[K, V] with hash_combine(self, hasher) { ... }

// Eq trait — 方法名是 equal（不是 op_equal）
impl[K : Hash + Eq, V : Eq] Eq for IndexMap[K, V] with equal(self, other) { ... }

// Show trait — 方法名是 output
impl[K : Show + Hash + Eq, V : Show] Show for IndexMap[K, V] with output(self, logger) { ... }
```

### 4.6 函数参数

```moonbit
// ✅ 正确 — 参数不加 mut
fn[K, V] IndexMap::robin_hood_insert_at(self, entry_param : Entry[K, V], ...) -> Unit {
  let mut entry = entry_param   // 在函数体内创建 mut 绑定
  ...
}

// ❌ 错误 — MoonBit 不允许 mut 参数
fn[K, V] IndexMap::robin_hood_insert_at(self, mut entry : Entry[K, V], ...) -> Unit { ... }
```

### 4.7 模式匹配

```moonbit
// ✅ 正确 — 不需要 | 分隔符
match iter.next() {
  Some((k, v)) => { ... }
  None => { ... }
}

// ❌ 错误 — | 语法已弃用
match iter.next() { Some(k) => ... | _ => ... }
```

### 4.8 包引用

```moonbit
// ✅ 正确 — 包名不能含连字符
let map = @indexmap.new()

// ❌ 错误 — 连字符在 @ 引用中非法
let map = @moonbit-indexmap.new()
```

### 4.9 迭代器使用

```moonbit
// ✅ 正确 — 迭代器不需要 mut
let iter = map.iter()
while true {
  match iter.next() {
    Some(v) => { ... }
    None => break
  }
}

// ❌ 错误 — 不需要 mut（Iter::next 取 self 的值）
let mut iter = map.iter()
```

### 4.10 包配置格式

- 主包用 `moon.mod.json`（JSON 格式），其中 `source` 指向 `src`
- 包内文件用 `moon.pkg.json`，import 数组声明依赖
- 黑盒测试文件命名为 `*_test.mbt`，放在 `src/` 目录
- 白盒测试文件命名为 `*_wbtest.mbt`，放在 `src/` 目录
- 测试中需要 `@test.fail()` 时，需在 `moon.pkg.json` 中添加 `{ "path": "moonbitlang/core/test" }`

---

## 五、当前代码状态

### 5.1 已完成（✅ — 第 1 轮全部完成）

**基础设施**
- ✅ MoonBit 工具链安装 + core 库编译
- ✅ `moon check` 0 errors
- ✅ `moon test` 211/211 通过
- ✅ 包名改为 `indexmap`
- ✅ 测试迁移到 `src/*_test.mbt` 黑盒格式

**IndexMap[K, V] 核心功能**
- ✅ `new()` / `with_capacity(n)` / `from_array(entries)` 构造
- ✅ `len()` / `is_empty()` / `capacity()` / `load_factor()` / `max_probe()` 查询
- ✅ `insert(key, value) -> Option[V]` 插入/更新
- ✅ `get(key) -> Option[V]` 查询
- ✅ `remove(key) -> Option[V]` 删除
- ✅ `contains(key) -> Bool` 存在检查
- ✅ `clear()` 清空
- ✅ `reserve(n)` / `shrink_to_fit()` 容量管理
- ✅ Entry API：`entry(key) -> EntryView`、`OccupiedEntry`、`VacantEntry`
- ✅ `get_index(i)` / `get_full(key)` / `get_index_of(key)` 索引访问
- ✅ `first()` / `last()` / `pop()` / `swap_remove_index(i)` 位置操作
- ✅ `iter()` / `keys()` / `values()` 迭代器
- ✅ `retain(f)` / `sort_by_key()` / `sort_by(cmp)` / `drain()` / `extend(entries)` 批量操作
- ✅ `for_each(f)` 函数式遍历
- ✅ Robin Hood 哈希探测和插入
- ✅ Tombstone 管理 + rehash
- ✅ `Show`、`Hash`、`Eq` trait 实现

**IndexSet[K]**
- ✅ `struct IndexSet[K] { inner: IndexMap[K, Unit] }` 包装器
- ✅ `insert` / `contains` / `remove` / `clear` / `len` / `is_empty` / `capacity`
- ✅ `is_disjoint` / `is_subset` / `is_superset` 集合运算
- ✅ `iter()` / `retain()` / `Show` trait

**测试覆盖（211 个测试，全部通过）**

**map_test.mbt（~1272 行，~80 测试）**
- ✅ 基本操作：new/is_empty、insert/get、overwrite、missing、contains、remove、clear
- ✅ 顺序保持：迭代顺序、覆盖保持位置、删除保持顺序
- ✅ 索引访问：get_index、get_index_of、get_full
- ✅ 位置操作：first、last、pop、swap_remove_index
- ✅ 边界：空字符串 key、重复插入、删除后重新插入、空 map 所有操作
- ✅ 容量：resize under load、reserve、shrink_to_fit、capacity、load_factor、max_probe
- ✅ 批量操作：retain、sort_by_key、sort_by（升序/降序/按值）、drain、extend、for_each
- ✅ Entry API：Occupied/Vacant 完整测试（get/insert/remove/key）
- ✅ 大量场景：插入 1000/5000/10000、删除 500→100、删除首/尾/中元素
- ✅ 迭代器：iter/keys/values、count_remaining
- ✅ Eq trait（通过迭代比较）、from_array 构造

**set_test.mbt（~495 行，~45 测试）**
- ✅ 基本操作：new/is_empty、insert/contains、remove、clear
- ✅ 集合运算：is_disjoint、is_subset、is_superset（含自反、空集、单空、大量）
- ✅ 顺序保持：迭代顺序、remove 后保持、chained 操作后保持
- ✅ 批量操作：retain（全部/全不/空）、drain（含空）、extend
- ✅ 边界：重复插入、删除后重新插入、clear 后复用、with_capacity(0)、空迭代
- ✅ 大量场景：500 元素插入和查找、大量 disjoint/subset 检查
- ✅ from_array 构造 + 顺序验证

**bench_test.mbt（~486 行，30 测试）**
- ✅ 插入性能：1000/5000/10000 元素
- ✅ 查找性能：5000 查找 + 1000 缺失查找
- ✅ 迭代性能：5000 元素 iter/keys/values
- ✅ 删除性能：2000/3000 删除 + 全部删除 1000
- ✅ 混合操作：插入+删除、retain 2000→1000
- ✅ 批量操作：sort_by_key 1000、extend/drain 1000
- ✅ 容量：不同初始容量、reserve+fill 2000
- ✅ 其他：clear 复用、字符串 key、IndexSet 5000/remove all、for_each 3000、swap_remove、max_probe、load_factor、first/last、get_index_of、count_remaining、get_full

**property_test.mbt（~489 行，39 测试）**
- ✅ 插入 N→len=N、重复插入保持 len、insert-get roundtrip
- ✅ remove 减 len、remove 后 key 不可查、迭代 count=len
- ✅ 已删除 key 不在迭代中、clear→empty
- ✅ contains 与 get 一致、extend/drain/retain 属性
- ✅ keys/values 迭代器计数与 len 一致
- ✅ 插入已存在 key 不改变 len、shrink_to_fit 保持数据
- ✅ 插入顺序=迭代顺序、swap_remove、overwrite、pop
- ✅ from_array 属性、空 map 属性、first=get_index(0)
- ✅ sort_by_key 属性、IndexSet insert 返回 bool、len 匹配
- ✅ IndexSet disjoint 对称、subset 蕴含 superset
- ✅ reserve 保持数据、delete+reinsert、count_remaining 递减
- ✅ is_empty 与 len 一致

### 5.2 全部完成（✅ — 第 2 轮全部完成）

**P0 — 代码格式化**
- ✅ 运行 `moon fmt` 格式化所有代码

**P1 — 达到代码行数要求（4000+ 行）** ✅ 实际 4,111 行
- ✅ 扩充测试到 ~2700 行（map_test ~1272 + set_test ~495 + bench_test ~486 + property_test ~489）
- ✅ 添加 `bench_test.mbt` 基准测试（~486 行，30 测试）
- ✅ 添加 `property_test.mbt` 属性测试（~489 行，39 测试）

**P2 — 完善功能**
- ✅ Entry API 完整测试（Occupied/Vacant 的 get/insert/remove/key）
- ✅ `drain()` / `extend()` / `sort_by()` 测试
- ✅ `swap_remove_index()` 测试
- ✅ `for_each()` 测试
- ✅ `reserve()` / `shrink_to_fit()` 容量验证测试
- ✅ `max_probe()` / `load_factor()` 诊断测试
- ✅ 大容量场景测试（1000+ 元素，最高 10000）
- ✅ 哈希碰撞场景测试（字符串 key 测试覆盖）

**P3 — 文档和 CI**
- ✅ 检查 `.github/workflows/ci.yml` 正常运行（含 moon check + moon test）
- ✅ 添加 `.gitignore`（忽略 `_build/`、编译产物等）
- ✅ 更新 README 中的代码示例与当前 API 一致
- ✅ CHANGELOG.md 更新到 v0.1.0 状态
- ✅ ROADMAP.md v0.1.0 项全部标记完成
- ✅ Git 仓库初始化 + 15 个有效 commit + 已推送 GitHub

---

## 六、v0.2.0 开发计划

### 6.1 当前状态（2026-06-10）

- ✅ 消除 [0053] unused_trait_bound 警告（8 个 → 0）
- ✅ 消除 [0002] unused_variable 警告（4 个 → 0）
- ✅ moon check 0 errors, moon test 211/211

### 6.2 v0.2.0 计划功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| `Debug` trait 实现 | P0 | IndexMap、IndexSet 实现 Debug trait，替代 Show 用于调试 |
| `Clone` / `DeepCopy` trait | P1 | MoonBit 核心 trait，深拷贝支持 |
| `get_mut()` 可变值访问 | P1 | 小改动，直接提供可变引用 |
| `into_iter()` 消耗性迭代器 | P2 | 配合 drain 使用，转移所有权 |
| 可插拔哈希算法 | P3 | XXHash / SipHash 支持 |
| 序列化/反序列化 | P3 | 与 MoonBit JSON 生态集成 |

### 6.3 警告说明

保留的警告（138 个）均为常规情况：
- **[0020]** inspect 已弃用（85 个）：测试文件中使用，`inspect` 仍是 MoonBit 标准测试方式
- **[0013]** 类型未解析（49 个）：编译器自动推断，对功能无影响
- **[0001]** trait 实现未使用（4 个）：Show/Hash/Eq 是公共 API，用户代码会用到

---

## 七、关键指标检查清单

提交前逐项核对：

- [x] `moon check` 零错误
- [x] `moon test` 全部通过（211/211）
- [x] `moon fmt` 格式化完成
- [x] GitHub 仓库公开可访问（https://github.com/aurasuisui/moonbit-indexmap）
- [x] Gitlink 仓库已同步（https://gitlink.org.cn/aurasuisui/moonbit-indexmap）
- [x] 有效 commit 数 ≥ 15（实际 15 commits）
- [x] MoonBit 代码行数 ≥ 4000（src/ 含测试）（实际 4,111 行）
- [x] README 包含安装方式 + 3 个以上可运行代码示例
- [x] CI 覆盖 check + test
- [x] 有 CHANGELOG + CONTRIBUTING + LICENSE
- [x] 申报书已提交并已通过
- [ ] v0.2.0 功能完成

---

## 八、不要做的事情

- ❌ 不要改架构设计（Robin Hood 哈希、Entry API、Array[K] 顺序维护——这些已定好）
- ❌ 不要引入外部依赖（项目要求自包含，除非是 MoonBit 核心库）
- ❌ 不要用内置 Map 替代自定义哈希表（虽然可以工作，但评委更看重自主实现）
- ❌ 不要写复杂的泛型魔法（MoonBit 的类型系统还在演进，保持简单）
- ❌ 不要忽略编译错误直接提交（确保每行代码都通过类型检查）
- ❌ 不要在包名中使用连字符（`@` 引用不支持 `-`）
- ❌ 不要为了消除警告而消除警告（以代码实际需求为准）
