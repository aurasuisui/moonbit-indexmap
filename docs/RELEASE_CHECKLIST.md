# IndexMap 上线测试清单

> 包：`aurasuisui/indexmap`（VERSION 为 `0.4.0`）
> 本文件是仓库根目录 `RELEASE_TEST_CHECKLIST.md` 的 IndexMap 落地记录。发布前必须重新执行
> 文末命令，且所有项目为绿色。

## 当前结论

`insert` 重复键缺陷已由无墓碑删除和统一定位逻辑修复。原先稳定失败的两个模型测试和一个
fuzz 测试现为正式回归门禁；详细根因、桶级证据和修复说明见
[`BUG-insert-duplicate-key.md`](BUG-insert-duplicate-key.md)。

本次随 **v0.4.0** 发布：实现修复、测试与文档已就位，版本已升级（`from_json` 作为新增公开
API 触发 minor 升级）。发布前已重跑文末命令，全部为绿色。

## Tier 0：正确性基础

- [x] 公共 API、边界值、顺序语义、Entry API、traits：库内 `map_test.mbt` / `set_test.mbt` 与独立套件 `api_test.mbt`。
- [x] 白盒不变量：`model_wbtest.mbt` 每步校验 bucket 数量、`order`/`positions`、mask、真实距离、连续探测路径、键唯一性和 `max_probe`。
- [x] 删除实现：cluster 头/中/尾、跨 mask 边界、清空复用、`retain`、`pop`、`swap_remove_index`、扩缩容均覆盖。

## Tier 1：系统化正确性

- [x] 状态机/模型测试：朴素 `Array[(Int, Int)]` oracle 对照手写序列、8000 步混合流、5000 步插入密集流和 QuickCheck 流。
- [x] Fuzz：60 个确定性 LCG seed × 1500 步，以及解码整数流 fuzz。
- [x] 差分：独立套件保留 Rust `indexmap` 的共享语义 fixture 回放；顺序删除使用本库的 shift-remove 语义单独断言。

## Tier 2：现实边缘与健壮性

- [x] HashDoS、冲突簇、超大键值、100k 压力、循环 delete/refill、fill/drain/refill：`indexmap-test-suite`。
- [x] Iterator fail-fast、多个独立迭代器、Entry 句柄失效：独立黑盒套件。
- [x] JSON round-trip、golden order、解码错误：独立黑盒套件。
- [x] 删除后的 `load_factor()`：库内与独立套件均断言立即反映 live entries。

## Tier 3/4：性能与工程门禁

- [x] `moon bench` 与缩放比性能门禁位于 `indexmap-test-suite`，不混入库内正确性测试。
- [x] 库 CI：`fmt --check`、`check --deny-warn`、mbti drift、四后端 × debug/release、示例程序。
- [x] 套件 CI：本库同级 checkout、跨后端测试和 wasm-gc release benchmark。
- [x] `cmd/*` 是 workspace 成员，并由 CI 执行。

## 发布前验证

```bash
# moonbit-indexmap
moon fmt --check
moon check --deny-warn
moon info && git diff --exit-code
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon test --release --target wasm-gc
moon test --release --target wasm
moon test --release --target js
moon test --release --target native
moon build --target wasm-gc
moon build --target wasm
moon build --target js
moon build --target native

# indexmap-test-suite（同样执行目标矩阵）
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon test --release --target wasm-gc
moon test --release --target wasm
moon test --release --target js
moon test --release --target native
moon bench --release --target wasm-gc
```

## 本次修复验证（2026-07-31）

- 库：`moon fmt --check`、`moon check --deny-warn`、接口快照检查、四后端
  debug/release 共八轮测试（每轮 221/221）、四后端构建和三个示例均已通过。
- 独立套件：四后端 debug/release 共八轮测试（每轮 503/503）均已通过；
  wasm-gc release 的六项统计基准与比例性能门禁已通过。
- 套件的 25 条 `[0013]` 未解析类型变量警告来自既有空泛型测试用例；无类型
  错误，且不属于库的 `--deny-warn` 发布门禁。
