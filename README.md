# iOS 复习源码

用于集中保存 iOS / Objective-C 底层机制的可运行实验、原始运行输出和结论。

## 当前实验

| 目录 | 内容 | 验证状态 |
| --- | --- | --- |
| `Copy/` | `copy`、`mutableCopy`、截图表格四种组合、浅拷贝、递归深拷贝、`NSCopying`、`NSMutableCopying` 以及 NSArray / NSDictionary / NSSet / NSOrderedSet 容器行为 | 已在 iPhone 17 模拟器、iOS 26.5 上运行，25 项断言全部通过 |
| `KVO/` | 预留 KVO 实验目录 | 等待之前 KVO 仓库的路径或 GitHub 地址 |
| `DyldFixups/` | 真机验证 rebase / bind 的 Mach-O 编码、fixup 页面分布与现代 chained fixups；保留静态 `dyld_info` 和设备启动计数的证据边界 | 已在 iPhone 15 / iOS 26.6.2 完成五个变体的静态与真机采集 |

## 运行 Copy 实验

```bash
cd Copy
./run-simulator.sh
```

完整结论见 [`Copy/RESULTS.md`](Copy/RESULTS.md)，本次设备运行的原始日志见 [`Copy/run-output.txt`](Copy/run-output.txt)。

## 运行 dyld fixups 真机实验

```bash
cd DyldFixups
./run-device.sh
```

该实验默认使用连接的 iPhone；它将构建五个变体、用 `dyld_info` 检查静态 fixups，并在真实设备进程的 `main` 首条指令记录累计 pageins/faults。完整设计、原始输出约定与结论边界见 [`DyldFixups/README.md`](DyldFixups/README.md) 和 [`DyldFixups/RESULTS.md`](DyldFixups/RESULTS.md)。

## KVO 仓库接入说明

当前本机和已登录的 `tommywutong` GitHub 仓库列表中没有找到可确认的独立 KVO 实验仓库，现有的是 KVO/KVC 学习资料。为避免把资料误当成实验工程，先保留 `KVO/` 目录；拿到原仓库路径或链接后，再将其完整接入这里并补充运行说明与结果。
