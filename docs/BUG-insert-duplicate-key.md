# 缺陷报告:`insert` 对已存在键返回 `None` 并插入重复键(上线阻断级)

> 库:`aurasuisui/indexmap` v0.3.3 · 报告日期:2026-07-28 · 工具链 `moon 0.1.20260724`
> 发现方式:RELEASE_TEST_CHECKLIST Tier 1 "模型/状态化属性测试"(`src/model_wbtest.mbt`)与 Tier 1 "fuzzing"(`src/fuzz_wbtest.mbt`)。
> **本报告是修复的依据**;修复完成后,G1 模型测试的 2 条红与 G3 fuzz 的 1 条红应自动转绿。

---

## 1. 症状

`IndexMap::insert(k, v)` 对一个**已存在**的键 `k` 返回 `None`(把 `k` 当成新键),并往 `order` 里**追加一个重复键**,导致:

- `insert` 返回值错误(应是 `Some(旧值)`,实得 `None`);
- `order` 含重复键,`len` 比 `positions` 多 1(`order.length() != positions.length()`);
- 后续该键的查询/迭代/序列化行为不确定(取决于命中哪一份桶)。

这是**数据完整性破坏**,属上线阻断级。

## 2. 精确复现

### 2.1 一键复现命令

```bash
cd moonbit-indexmap
moon test -f "*8000*"          # 8000 步流,必现于第 6151 步 Insert(14, …)
moon test -f "fuzz*"           # fuzz seed-sweep,1 个种子在 ≤1500 步内复现
```

### 2.2 模型测试里的断言点

复现由 `src/model_wbtest.mbt` 的 `apply_op` 在 `Insert` 分支捕获:

```moonbit
Insert(k, v) => @test.assert_eq(m.insert(k, v), oracle_insert(oracle, k, v))
```

- 真结构 `m.insert(14, 41)` 返回 `None`;
- 朴素数组 oracle `oracle_insert(...)` 返回 `Some(3)`(键 14 此前的值);
- 失败信息:`None != Some(3)`(`8000` 步流)/ `None != Some(15)`(fuzz)。

### 2.3 触发前两侧状态完全一致(证明非 oracle bug)

在 8000 步复现的第 6151 步 `Insert(14,41)` **之前**,真结构与 oracle 的完整有序内容**逐对相等**:

```
before_real    = [(13,19),(17,45),(1,59),(19,26),(18,79),(14,3),(16,58),(11,74),(12,34),(5,39),(8,30),(7,23),(9,48),(2,35)]
before_oracle  = [(13,19),(17,45),(1,59),(19,26),(18,79),(14,3),(16,58),(11,74),(12,34),(5,39),(8,30),(7,23),(9,48),(2,35)]
contains(14) before = true   # 真结构也认为键 14 存在
```

两侧状态一致、真结构 `contains` 也为真,却返回 `None` → **库内部不一致**,非测试写错。

## 3. 根因(已定位到行)

库内部有两个键查找函数(`src/map.mbt`):

- `probe_find`(map.mbt:97)— **穷尽**线性探测,探到 `None` 才停。被 `get`/`contains`/`remove`/`get_mut` 使用。
- `robin_hood_find`(map.mbt:124)— 带 Robin Hood **提前终止**:当遇到一个"更富"(distance 更小)的占用项时,即 `entry.distance >= 0 && entry.distance < dist`,**提前返回"未找到"**(map.mbt:149–152)。被 `insert`/`entry` 使用。

**两个函数对同一张表、同一个键会给出不同答案**:

在第 6151 步插入键 14 **之前**,直接对真结构调用(白盒,见 `model_wbtest.mbt` 诊断):

```
key=14  hash=-546008905  home=23  (mask=31, cap=32)
probe_find     = (25, true)   # 找到,位于桶 25
robin_hood_find= (24, false)  # 未找到,提前终止于桶 24
```

对应的桶布局(插入前):

```
[23] key=18  home=22  dist=1
[24] key=7   home=24  dist=0     ← "富"键(distance 0)
[25] key=14  home=23  dist=2     ← 目标键,落在 24 之后
```

**机制**:从 home=23 探测键 14,经过桶 23(key18,dist=1)、桶 24(key7,**dist=0**)。此时 `robin_hood_find` 的探测距离 `dist` 已增至 1,而 key7 的 `distance` 为 0 < 1,提前终止条件 `entry.distance < dist` 命中 → 返回"未找到",**永远到不了桶 25 的键 14**。`probe_find` 不提前终止,继续探到桶 25 命中。

**本质**:表已进入**违反 Robin Hood 距离有序不变式**的状态 —— 一个 distance=2 的活键(桶 25)排在一个 distance=0 的键(桶 24)之后。Robin Hood 的提前终止优化依赖于"探测链上 distance 单调不减"这一不变式;该不变式一旦被破坏,`robin_hood_find` 就会漏键,`insert` 因此把已存在的键当新键插入,产生重复。

## 4. 距离不变式是何时被破坏的(待定位的具体路径)

不变式被破坏的**那次变更**尚未精确定位到单条指令。候选嫌疑(均涉及 distance 字段、墓碑复用、或重哈希):

- `robin_hood_insert_at`(map.mbt:166)的**墓碑复用捷径**(map.mbt:200–208):命中墓碑即就地写入并把 `tombstone_count--`,但其 distance 设为当前 `dist`,可能把一个 distance 较大的项放到一个本该由更小 distance 项占据的位置,破坏链上单调性。
- `rehash`(map.mbt:262)/`resize`:重建桶时用 Robin Hood 插入重放,若 `to_insert.distance` 与 `cur.distance` 比较分支(map.mbt:300–307)有偏差,可能落错位。
- `remove` 留墓碑后,某个跨越墓碑的后续插入跳过了应当"更穷"的项。

修复方需复盘这三条路径,找出哪一步把 distance=2 的项放到 distance=0 项之后。诊断方法:在 `robin_hood_insert_at` / `rehash` 末尾对每个活键断言"其 distance == 从 home 起探到它所越过的占用项的 distance 都 <= 它",最先违反的那次操作即破坏点。

## 5. 建议修复

### 方案 A(推荐,低风险,立即恢复正确性)

让 `robin_hood_find` **不再提前终止**,改为像 `probe_find` 一样**穷尽探测**(探到 `None` 才停),同时保留"首个墓碑作插入位"的记录用于 `insert`。

- 改动:删除 map.mbt:149–152 的提前终止分支(或改为只在命中 `None` 时停)。
- 正确性:`get`/`contains`/`remove` 本就用穷尽的 `probe_find`,只要 `insert`/`entry` 的探测也穷尽,二者不再分歧,**重复键消失**,返回值恢复正确。
- 代价:每次 `insert` 可能多探几步(负载 ≤0.75,有 `None` 终止,常数级)。距离有序不变式违反 thereafter **只影响探针距离最优性**(轻微性能),**不再影响正确性**。
- 兼容性:纯内部改动,无公开 API 变更,mbti 不变。
- 验证:本报告第 6 节。

### 方案 B(根治,更高风险)

保留提前终止优化,修好第 4 节中破坏距离有序不变式的那条具体路径。更侵入,需先定位破坏点。

### 推荐顺序

先上方案 A 恢复正确性(红测试转绿),再视性能压测决定是否做方案 B 找回最优探针距离。

## 6. 验证

修复后,以下测试应**全部转绿**(目前 3 条红):

```bash
moon test -f "model*"        # 2 条红转绿 + 其余已绿
moon test -f "fuzz*"         # 1 条红(seed-sweep)转绿 + 1 条已绿
moon test                    # 全量:327 测试,0 红
```

并建议追加一条**针对该 bug 的回归单测**(修复时一并加入,防止回退):构造一个把 distance 有序不变式破坏掉的极小表状态,断言 `insert` 对已存在键返回 `Some(旧值)` 且不产生重复键。可用本报告第 2.3 节的 14 元素前置态作起点。

## 7. 证据文件(修复时参考)

- **捕获测试**:`src/model_wbtest.mbt`(`model: 8000 …`、`model: 8000 insert-heavy …`)、`src/fuzz_wbtest.mbt`(`fuzz: sweep 60 LCG seeds …`)。
- **白盒诊断可复现**:`model_wbtest.mbt` 内 `check_internal_invariants` 在第 6151 步后断言 `order.length() == positions.length()` 即失败;因 `IndexMap` 为私有类型、`_wbtest.mbt` 可读私有字段,修复者可临时加一段对 `probe_find` vs `robin_hood_find` 的断言复现第 3 节的分歧值。
- **桶级证据**:见第 3 节(插入前 cap=32/mask=31,桶 23/24/25 布局)。