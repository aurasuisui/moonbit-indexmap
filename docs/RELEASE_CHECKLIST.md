# indexmap 上线测试清单(RELEASE_CHECKLIST)

> 库:`aurasuisui/indexmap` **v0.3.3** · 核对日期:2026-07-27 · 工具链:`moon 0.1.20260724`
> 本文件是仓库根 `RELEASE_TEST_CHECKLIST.md` 的 **indexmap 专属副本**,逐项标注已核实现状 + 证据(文件 / 测试名)。随版本控制,上线前逐项核对。
>
> **测试合计**:库自测 277(原有)+ 本次新增 48 = **325**;另有独立仓库 `indexmap-test-suite` 236 条黑盒测试。
> 本次新增 4 个文件:`src/model_wbtest.mbt`(模型 + 白盒不变量)、`src/fuzz_wbtest.mbt`(fuzz)、`src/adversarial_test.mbt`(HashDoS)、`src/failfast_panic_test.mbt`(fail-fast)。

---

## ⚠️ 阻断级发现(本次模型测试新抓到,**待修复后方可上线**)

**`insert` 会对已存在的键返回 `None` 并插入重复键**(应返回 `Some(旧值)`)。

- **完整缺陷报告**(症状 / 精确复现 / 桶级证据 / 探针轨迹 / 根因到行 / 修复方案 / 验证):见 [`docs/BUG-insert-duplicate-key.md`](BUG-insert-duplicate-key.md)。**修复以此报告为依据。**
- **一句话根因**:`probe_find`(get/contains/remove 用,穷尽探测)能找到已存在键,而 `robin_hood_find`(insert/entry 用)带 Robin Hood 提前终止,在表进入"distance 有序不变式被破坏"的状态时提前返回"未找到",使 `insert` 把已存键当新键、产生重复。
- **复现**:`moon test -f "*8000*"`(必现于第 6151 步,键 14);`moon test -f "fuzz*"` 的 seed-sweep 在 ≤1500 步内亦复现。
- **建议修复**:`robin_hood_find` 改穷尽探测(详见报告第 5 节);改后 `model*` 2 红 + `fuzz*` 1 红应自动转绿。
- **现状**:模型/fuzz 测试已作为**回归标记**保留(红),修复后应自动转绿。

---

## Tier 0 — 正确性地基(阻断级)→ ✅ 充分

- [x] **API / 单元测试**:独立套件 `tests/api_test.mbt`(90,每公开方法一条)+ 库 `src/map_test.mbt`(131)、`src/set_test.mbt`(52)。
- [x] **边界 / 异常**:`tests/stress_test.mbt` §4(0 / -1 / Int MIN/MAX / 空串键值 / 64KB / 重复键 / 越界下标 `99`、`-1`);`src/map_test.mbt` 边界块。
- [x] **不变量测试**:插入序(1→100k)、计数一致、桶为 2 的幂(`tests/comprehensive_test.mbt` 扩容级联 16→16384@20k;`src/property_test.mbt`)。**本次新增白盒** `src/model_wbtest.mbt` 的 `check_internal_invariants` 在每个变更后断言 `CLAUDE.md` 全部 8 条不变量(`wb:*` 5 条全绿)。

## Tier 1 — 系统化正确性 → 本次大幅补强(原最薄弱层)

- [x] **模型 / 状态化属性测试 ⭐**(原 ❌):本次新增 `src/model_wbtest.mbt`——朴素 `Array[(Int,Int)]` oracle + 共享 `Op` 解释器,随机操作流同时施加到真结构与 oracle,**逐步**断言返回值 + 全序内容 + 内部不变量。驱动:手写黄金序列(含 `swap_remove_index` 保序 shift、`get_mut` 权威性、`sort_by_key`、`drain`、Entry API)+ 8000 步 LCG 流 + 5000 步扩容流 + QuickCheck。**状态:测试已就绪;其中 2 条长流因上述 bug 红(回归标记)。**
- [ ] **差分测试 vs Rust indexmap**(原 ❌):**未做**(G2)。需 cargo 生成黄金夹具;MoonBit 回放经 insert 路径会因上述 bug 红,宜修后做。已知须排除/转译的差异:`swap_remove`(Rust O(1) swap vs 本库保序 shift)、`Eq/Hash`(Rust 序无关 vs 本库序敏感)、哈希值不可比。
- [x] **模糊测试 fuzzing**(原 ❌):本次新增 `src/fuzz_wbtest.mbt`——seed-sweep 操作流 fuzz(60 种子 × 1500 步)+ 解码整数流 fuzz,复用模型 oracle。**状态:1 红(seed-sweep 抓到上述 bug)/ 1 绿。**

## Tier 2 — 现实边缘健壮性 → 本次补齐 HashDoS + fail-fast

- [x] **压力 / 规模**:100k 插入、50k 查全量、扩容级联、墓碑累积(90% 删除触发 rehash)、fill→drain→refill、64KB 键值、5000 对象 GC churn(`tests/stress_test.mbt`、`tests/comprehensive_test.mbt`、`src/bench_test.mbt`)。
- [x] **对抗性输入 / HashDoS**(原 ❌):本次新增 `src/adversarial_test.mbt`(9 条全绿)——自定义 `Hash` 键(全碰撞 `SameHash` / 4 路聚集 `FewHash`),断言碰撞洪水下全键可取、删除/覆盖/保序/Eq 消歧正确;`max_probe()` 线性有界(`>= n/2`、`<= n`),且 600 vs 2400 规模下探针距离**线性**增长(`<= 8×`,排除超线性)。
- [x] **迭代器 / 别名契约**(原 ◐ 仅文档):本次新增 `src/failfast_panic_test.mbt`(22 条全绿)——利用 `test "panic …"` 约定**进程内断言** fail-fast `abort`(推翻旧版"abort 不可测"认知):`iter`/`keys`/`values` × insert/remove/clear/pop/sort/retain/get_mut/entry 各变更、OccupiedEntry 失效键 abort,加 3 条非 panic 负例(先变更再建迭代器、双独立迭代器)。
- [ ] **序列化往返 + 格式稳定**(原 ❌):**未做**(G5)。`to_json` 有 6 处单向测试;库**无 `from_json`**,往返不可能;无 golden-file。建议:String 键规范版 `from_json` + `from_json_with(parse_key)` 逃生口(core `Json` 对象保序 → String 键往返无损,序敏感 `Eq` 使 `from_json(m.to_json()) == m` 为最强断言)。属公开 API 变更,需 mbti regen + semver 次版本(v0.4.0)。

## Tier 3 — 非功能 / 生产卫生 → 普遍欠缺

- [ ] **性能基准 + 回归门禁**(原 ⚠️):`src/bench_test.mbt` **无计时**(大 N 正确性)。G7 未做:建议 `moon bench`(`@bench.T`)+ 程序化 `@bench.Bench()::dump_summaries()` 对比检入 baseline,`>2×` 回归硬 fail,完整结果作产物(诚实对待共享 runner 噪声)。
- [ ] **跨后端 / 跨配置矩阵**(原 ❌):仅 wasm-gc。G8 未做:`--target wasm-gc/wasm/js/native × debug/release` 矩阵。
- [◐] **并发语义**:README 声明 "production-ready for single-threaded use";测试中"并发"仅 copy/consume 隔离。建议 README 显式声明"单线程、迭代器 fail-fast 非线程安全"。
- [◐] **内存**:容量/缩容/稳态/GC churn 已验;无泄漏/占用测量(语言受限)。
- [x] **Trait 契约一致性**:`Eq 相等 ⇒ Hash 相等`、Show/Debug/ToJson 已测(两仓库)。遗留隐患:无 `Show` 的自定义键为潜在序列化陷阱(从不被序列化)。

## Tier 4 — 元层 → CI 部分、示例未进 CI

- [ ] **变异测试**(原 ❌):无 MoonBit 工具。代偿:模型测试固有敏感性(本次即抓到"选错存活键"类 bug)+ 手工故障注入自检。
- [◐] **CI 流水线门禁**:五步 `fmt --check → check → info && git diff --exit-code → test → build` 已在;**缺** `moon check --deny-warn`(14 个 `[0083]` 警告;**注意:既往曾"刻意保留"该批警告,启用 --deny-warn 需先决策**)与全后端 `moon test`(G8)。
- [x] **API / ABI 稳定**(基本):`pkg.generated.mbti` 已提交 + CI diff 门禁;CHANGELOG 用 keep-a-changelog。建议补显式 semver 政策(0.3.3 曾将破坏性 bound 变更作 patch 发布)。
- [ ] **文档 / 示例可运行**(原 ⚠️):`cmd/config_parse`、`cmd/json_order`、`cmd/lru_cache` 自 v0.3.2 起被排除出 `moon.work`,CI 不编译不运行。G10 未做:`pkgtype(kind:"executable")` 迁移 + 自断言 + `examples` CI job。

---

## 缺口优先级(建议)

| 优先级 | 缺口 | 层 | 阻塞 |
|---|---|---|---|
| P0 | **修复 robin_hood_find 重复键 bug** | — | 上线阻断 |
| P1 | 序列化往返 + golden(需 from_json) | Tier 2 | 公开 API 变更,需设计签字 |
| P1 | vs Rust 差分 | Tier 1 | 需 cargo;宜修 bug 后 |
| P2 | 真基准 + 回归门禁 | Tier 3 | baseline 平台相关 |
| P2 | 跨后端 CI 矩阵 + 套件 CI | Tier 3/4 | native 或需 gcc |
| P3 | `--deny-warn`(先决策是否清 14 警告) | Tier 4 | 与既往决策冲突 |
| P3 | cmd 示例进 CI | Tier 4 | `pkgtype` 迁移 |
| P3 | semver 政策 / 并发声明 / 变异代偿 | Tier 3/4 | 文档 |

## 复现 / 验证命令

```bash
moon test                      # 全量:325 = 322 过 + 3 红(均为重复键 bug)
moon test -f "model*"          # 模型 + 白盒不变量(2 红 = bug 标记)
moon test -f "fuzz*"           # fuzz(1 红 = bug 标记 / 1 绿)
moon test -f "hashdos*"        # HashDoS(9 绿)
moon test -f "panic*"          # fail-fast(19 绿)
moon test -f "fail-fast*"      # fail-fast 负例(3 绿)
moon test -f "*8000*"          # 最小复现重复键 bug(第 6151 步)
```
