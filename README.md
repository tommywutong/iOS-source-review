# iOS 复习源码

用于集中保存 iOS / Objective-C 底层机制的可运行实验、原始运行输出和结论。

## 当前实验

| 目录 | 内容 | 验证状态 |
| --- | --- | --- |
| `Copy/` | `copy`、`mutableCopy`、截图表格四种组合、浅拷贝、递归深拷贝、`NSCopying`、`NSMutableCopying` 以及 NSArray / NSDictionary / NSSet / NSOrderedSet 容器行为 | 已在 iPhone 17 模拟器、iOS 26.5 上运行，25 项断言全部通过 |
| `KVO/` | 预留 KVO 实验目录 | 等待之前 KVO 仓库的路径或 GitHub 地址 |

## 运行 Copy 实验

```bash
cd Copy
./run-simulator.sh
```

完整结论见 [`Copy/RESULTS.md`](Copy/RESULTS.md)，本次设备运行的原始日志见 [`Copy/run-output.txt`](Copy/run-output.txt)。

## KVO 仓库接入说明

当前本机和已登录的 `tommywutong` GitHub 仓库列表中没有找到可确认的独立 KVO 实验仓库，现有的是 KVO/KVC 学习资料。为避免把资料误当成实验工程，先保留 `KVO/` 目录；拿到原仓库路径或链接后，再将其完整接入这里并补充运行说明与结果。
