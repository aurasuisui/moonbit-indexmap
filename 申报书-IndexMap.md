# MoonBit IndexMap 项目申报书

## 基本信息

- **项目名称**：MoonBit IndexMap：保留插入顺序的哈希表
- **参赛者**：徐家宝
- **联系方式**：18267593686
- **GitHub 仓库链接**：https://github.com/aurasuisui/moonbit-indexmap
- **Gitlink 仓库链接**：https://gitlink.org.cn/aurasuisui/moonbit-indexmap
- **项目方向**：基础数据结构与算法 / MoonBit 标准库补全
- **是否为移植项目**：是

## 项目简介

MoonBit IndexMap 计划将 Rust 生态中广泛使用的 `indexmap` crate（月下载量超 2000 万次）移植到 MoonBit 生态，为 MoonBit 开发者提供一个能够记住键插入顺序的哈希表实现。

MoonBit 内置的 `Map[K, V]` 不保证迭代顺序。在实际开发中，需要按插入顺序遍历键值对的场景非常普遍：配置文件解析需要保持 key 的书写顺序、JSON 序列化需要保留字段顺序、LRU 缓存需要有序淘汰、测试代码需要确定性的迭代结果。IndexMap 正是解决这类问题的标准方案。

项目面向所有 MoonBit 应用开发者、库作者和工具链开发者，目标是成为 MoonBit 生态中「有序哈希表」的事实标准实现。

## 核心功能范围

- 提供 `IndexMap[K, V]` 数据结构，支持 `insert`、`get`、`remove`、`contains`、`clear` 等基本操作；
- 采用 Robin Hood 开放寻址哈希表，保证 O(1) 平均查找性能，probe 距离均匀可控；
- 通过附属 `Array[K]` 维护键的插入顺序，迭代严格按插入顺序输出；
- 实现 Rust 风格的 Entry API（`entry()` 返回 Occupied/Vacant 视图），支持原地修改而无需重复查表；
- 提供 `IndexSet[K]`（基于 IndexMap 构建的有序哈希集），支持 `is_disjoint`、`is_subset`、`is_superset` 等集合运算；
- 支持按插入位置索引访问（`get_index`、`first`、`last`、`pop`）；
- 支持 `retain`、`sort_by_key`、`drain`、`extend` 等批量操作；
- 实现 `Show`、`Hash`、`Eq` 标准 trait；
- 提供不少于 40 个测试用例，覆盖基本操作、顺序保持、边界条件和高负载场景；
- 提供 README 和 API 文档，说明安装方式、使用方法和可复现示例；
- 使用 GitHub Actions 持续集成，覆盖类型检查、格式化检查、编译和测试流程。

## 移植或参考说明

- **原项目名称**：indexmap
- **原项目链接**：https://github.com/indexmap-rs/indexmap
- **原项目许可证**：Apache-2.0 OR MIT
- **本项目许可证**：Apache-2.0

与原项目相比，本项目做了以下适配和简化：

- 使用 MoonBit 原生 `struct`、`trait`（`Hash + Eq`）、`Array` 和测试体系组织代码，不照搬 Rust 的类型系统和模块结构；
- 哈希表从零实现（Robin Hood 开放寻址），不依赖 MoonBit 内置 Map 的不稳定 API，确保代码自包含和长期可维护；
- Entry API 使用 MoonBit 的 `enum EntryView { Occupied(...), Vacant(...) }` 实现，充分利用 MoonBit 的代数数据类型；
- 暂不实现可插拔哈希算法（如 `HashBuilder` trait），直接使用 MoonBit 内置 `Hash` trait，简化 API 并降低学习成本；
- 迭代器采用显式 `Iter` 类型 + `next()` 方法模式，适配 MoonBit 当前的迭代风格；
- 未实现 `Equivalent` trait（异构查找），因 MoonBit 类型系统目前不支持类似 Rust 的 Borrow 抽象。
