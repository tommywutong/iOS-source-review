# 2026-09-18 expanded device run

不可变原始归档；后续插桩或重跑不得覆盖此目录。

## 环境

- iPhone 15 (`iPhone15,4`), arm64e, iOS 26.6.2。
- Xcode 27.0 / iOS 27.0 SDK。
- 每个应用为 Release 真机构建；使用免费个人开发 profile。
- `BindUnique` 的最终五次运行使用其原始 Bundle ID；`InitHeavy` 为绕过 App ID 创建额度复用已注册的 Baseline Bundle ID/profile，二进制和 `DYLD_EXPERIMENT_VARIANT=5` 未变。

## 文件与口径

| 文件 | 内容 |
| --- | --- |
| `static-fixups.txt` | 六变体的 `dyld_info -fixup_chains -imports -fixups` 输出。 |
| `phase-output.txt` | build/install/host launch wall time；host 侧控制命令时长，不是 app 内启动时长。 |
| `run-output.txt` | Baseline 与 RebaseDense 的完整五次运行；另含第一次批量运行中其他目标的拒绝启动日志。 |
| `rebasesparse-rest.txt` | RebaseSparse 首次成功启动之后的第 2–5 次。首启数据见记录的命令输出与实验结论。 |
| `bindrepeated-rest.txt` | BindRepeated 第 2–5 次；首启数据见记录的命令输出与实验结论。 |
| `bindunique-rest.txt` | BindUnique 第 2–5 次；首启数据见记录的命令输出与实验结论。 |
| `initheavy-rest.txt` | InitHeavy 第 2–5 次；首启数据见记录的命令输出与实验结论。 |
| `dyld-*.log` | 对应设备签名/安装前的完整 `xcodebuild` 日志。 |
| `AppLaunch-Baseline.trace` | `xctrace App Launch` 尝试生成的 trace 包。该尝试被设备信任层拒绝，不作为有效启动时长数据。 |

`DYLDLAB_RESULT` 是进入 `main` 后读取的进程累计计数；`DYLDLAB_TIMELINE` 的 `constructor_ns → main_entry_ns` 仅覆盖本应用 constructor 到 `main`，不覆盖 dyld 私有 pre-main 阶段。所有输出均需与上述口径一起解释。
