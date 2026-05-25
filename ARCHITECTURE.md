# moonbit-indexmap 架构设计

## 项目定位

将 Rust 生态中广泛使用的 `indexmap` crate 移植到 MoonBit，实现一个**保留插入顺序的哈希表**。

## 为什么需要 indexmap

MoonBit 内置的 `Map[K, V]` 不保证迭代顺序。当开发者需要「记住用户配置的先后顺序」「按插入顺序遍历 JSON 字段」「实现 LRU 缓存」等场景时，indexmap 是标准解决方案。Rust 的 indexmap crate 月下载量超过 2000 万次，说明这是一个真实且高频的需求。

## 核心数据结构

```
IndexMap[K, V]
 ├── buckets: FixedArray[Option[Entry[K, V]]]  ← 开放寻址哈希表
 ├── order: Array[K]                             ← 插入顺序记录
 ├── len: Int                                    ← 实际元素数
 └── mask: Int                                   ← buckets.len() - 1

Entry[K, V]
 ├── key: K        ← 键
 ├── value: V      ← 值
 └── hash: Int     ← 缓存的哈希值（避免重复计算）
```

## 算法设计

**哈希表**：开放寻址，线性探测（linear probing）
- 负载因子 0.75 触发扩容（容量翻倍）
- 删除使用 tombstone 标记，防止探测链断裂
- tombstone 过多时触发 rehash

**顺序维护**：
- `order: Array[K]` 按插入顺序存储所有 key
- 插入新 key 时追加到 order 末尾
- 删除时在 order 中线性查找并移除（O(n)，可接受的取舍）
- 迭代时遍历 order，从哈希表中取值

## API 设计（对标 Rust indexmap）

| 方法 | 说明 |
|------|------|
| `new()` → IndexMap | 创建空 map |
| `with_capacity(n)` → IndexMap | 预分配容量 |
| `len()` → Int | 元素数量 |
| `is_empty()` → Bool | 是否为空 |
| `insert(key, value)` → Option[V] | 插入，返回旧值 |
| `get(key)` → Option[V] | 查询 |
| `remove(key)` → Option[V] | 删除并返回值 |
| `contains(key)` → Bool | 是否包含 |
| `clear()` → Unit | 清空 |
| `iter()` → Iter[K, V] | 按插入顺序迭代 |
| `keys()` → Keys[K] | 按插入顺序迭代键 |
| `values()` → Values[V] | 按插入顺序迭代值 |
| `get_index(i)` → Option[(K, V)] | 按位置索引 |
| `swap_remove_index(i)` → Option[(K, V)] | 按位置移除（O(1)） |

## 模块划分

```
src/
├── lib.mbt      # 模块文档 + 公开 re-export
├── map.mbt      # IndexMap 核心实现（~400 行）
├── set.mbt      # IndexSet（基于 IndexMap，~150 行）
├── iter.mbt     # 迭代器类型（~100 行）
└── hash.mbt     # 哈希辅助函数（~50 行）
```

## 测试策略

- 基本操作测试：insert/get/remove/contains
- 顺序保持测试：验证迭代顺序 === 插入顺序
- 边界测试：空 map、单元素、大量元素、rehash
- 碰撞测试：相同哈希值的 key
- 正确性测试：与 MoonBit 内置 Map 交叉验证
- 基准测试：insert/get/iter 性能对比

## 与 Rust indexmap 的差异

| 特性 | Rust indexmap | 本项目 |
|------|-------------|--------|
| 哈希算法 | 可插拔 HashBuilder | MoonBit 内置 Hash trait |
| Entry API | ✅ 完整支持 | ✅ 计划支持 |
| 等价性 | Equivalent trait | 仅支持完全类型匹配 |
| 序列化 | serde 支持 | 待定 |
