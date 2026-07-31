# 缺陷报告：`insert` 曾将已有键误判为新键（已修复）

> 包：`aurasuisui/indexmap`（未发布工作树，VERSION 仍为 `0.3.3`）
> 发现方式：RELEASE_TEST_CHECKLIST Tier 1 的模型测试与 op-stream fuzz
> 状态：**已修复并完成完整验证**（2026-07-31）

## 症状

旧实现中，`IndexMap::insert(k, v)` 在少量删除、重插和扩容组合后，可能把已存在的 `k`
判为不存在：返回 `None`、把键再次追加到 `order`，最终造成 `len`、`order` 和
`positions` 不一致。这是数据完整性缺陷。

稳定复现（修复前必红）：

```bash
moon test -f "*8000*"
moon test -f "*insert-heavy*"
moon test -f "*fuzz: sweep*"
```

最早的确定性失败发生在 8000 步模型序列第 6151 步：对键 `14` 的覆盖插入返回
`None`，而数组 oracle 正确返回 `Some(3)`。

## 根因

旧表同时存在两套查找逻辑：

- `probe_find` 为 `get`、`contains`、`remove` 等操作一直扫描到空桶；
- `robin_hood_find` 为 `insert`、`entry` 使用“resident distance 小于当前 probe
  distance 时提前判定未命中”的优化。

墓碑删除保留了死桶；后续插入命中墓碑时会直接落位，而不会完成维持 Robin Hood
提前终止条件所需的整段位移。于是第二套查找会在一个低 distance 的 resident
处停止，而第一套查找仍能在后方找到同一个键。

当时的桶级证据如下（`cap = 32`）：

```text
[23] key=18  home=22  distance=1
[24] key=7   home=24  distance=0
[25] key=14  home=23  distance=2   # 目标键
```

从 home bucket 23 查找键 14 时，旧的提前终止逻辑在 bucket 24 得到错误的“未命中”，
因而制造重复键。问题不是 oracle；故障前真实 map 与 oracle 内容完全相同，且
`contains(14)` 已返回 `true`。

## 修复

`src/map.mbt` 现在采用无墓碑布局：

1. 删除移除了 `TOMBSTONE_HASH`、`tombstone_count` 和墓碑阈值 rehash。
2. `backshift_remove` 从删除洞向后搬移所有 `distance > 0` 的条目，并将其 distance
   减一，直到空桶或 home bucket 条目为止。每个仍存条目从 home 到自身的探测路径
   因而始终连续。
3. `locate` 取代旧的两套查找：它会扫描到空桶后才报告未命中，同时记住第一个可进行
   Robin Hood 位移的桶。即使未来内部距离布局被破坏，也不会静默复制已有键。
4. 常规插入和 `rehash` 共同调用 `robin_hood_insert_into`，避免两条位移实现再次分叉。

`load_factor()` 也相应改为严格的 `len / capacity`，不再包含历史删除次数。

## 回归覆盖

- `src/model_wbtest.mbt`：8000 步混合模型、5000 步插入密集模型、每一步的
  oracle/顺序/桶距离/探测路径/唯一性检查。
- `src/fuzz_wbtest.mbt`：60 个 LCG seed 的 op-stream fuzz。
- `src/model_wbtest.mbt`：跨 mask 边界的后向搬移测试，以及故意构造旧的
  `distance 1 → 0 → 2` 形状后覆盖已有键的防御测试。
- `indexmap-test-suite`：100k 删除重插后的顺序与 `get_index_of`，循环 delete/refill，
  以及删除后 load factor 立即下降。

这些测试在修复前至少有三条稳定失败；修复后必须与所有后端矩阵一同全绿。

本次验证结果：库在 wasm-gc / wasm / js / native 的 debug 与 release 八轮中均为
221/221；独立套件相同八轮均为 503/503，wasm-gc release 的六项统计基准也通过。
