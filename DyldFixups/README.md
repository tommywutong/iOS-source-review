# dyld fixups lab

This lab measures what can be observed from a real iPhone without private dyld hooks:

- `RebaseDense`: 128 internal function pointers packed into a small data region.
- `RebaseSparse`: the same number of internal pointers spread one per 16 KiB page.
- `BindRepeated`: 4,096 external pointer fixups using one imported symbol.
- `BindUnique`: 4,096 external pointer fixups using 4,096 imported symbols.
- `Baseline`: no experiment framework.

Each app takes a snapshot at the first instruction of `main`, before calling the framework marker. It logs `getrusage(RUSAGE_SELF)`, `TASK_EVENTS_INFO`, `TASK_VM_INFO`, and `_dyld_image_count()`. These values include dyld and pre-main work, but also unavoidable process/bootstrap work; they are not a private per-fixup timer.

## Run

```bash
./run-device.sh
```

The default device is the connected iPhone. Override it with `DEVICE_ID=...`; override the signing team with `DEVELOPMENT_TEAM=...`.

`run-device.sh` 会为每个 target 使用其在 `project.yml` 中的独立 Bundle ID。免费个人开发者账号须仍有足够的 App ID 创建额度；否则先等待额度恢复或使用已登记这些标识符的开发团队。脚本在每个变体完成后卸载该实验 App，但不会操作其他 App。

Static fixup metadata is extracted with `dyld_info` from the built arm64 Mach-O files. The device run writes raw console output to `run-output.txt`; the interpretation is in `RESULTS.md`.

## 可复用插桩与断点

`Sources/main.m` 统一保留下列事件和 LLDB 符号；新增实验应复用这些边界，不要重新定义另一套时间口径。

| 边界 | 控制台字段 / signpost | LLDB 断点 |
| --- | --- | --- |
| 早期应用 constructor | `constructor_ns`、`process_lifecycle` begin | `dyldlab_breakpoint_pre_main` |
| 晚期应用 constructor | `constructor_tail_ns` | — |
| `main` 第一条 | `main_entry_ns`、`main_entry` | `dyldlab_breakpoint_main` |
| 实验 marker | `marker_start_ns` / `marker_end_ns` | `dyldlab_breakpoint_marker` |
| 退出前 | `exit_ns`、`before_exit` | `dyldlab_breakpoint_exit` |

示例：

```lldb
breakpoint set --name dyldlab_breakpoint_pre_main
breakpoint set --name dyldlab_breakpoint_main
breakpoint set --name dyldlab_breakpoint_marker
breakpoint set --name dyldlab_breakpoint_exit
```

`constructor_ns → main_entry_ns` 仅是**本应用的 constructor 到 `main`**。它不包含 dyld 私有 loader/fixup/ObjC runtime 的完整 pre-main 时间，不能改名为“dyld pre-main”。`DYLDLAB_RESULT` 中的 faults、pageins、footprint 等也是进程累计值，只适合受控变体的对照。

## 保存并汇总一次运行

每次真机运行后，将 `run-output.txt`、`static-fixups.txt`、`phase-output.txt`、各变体续跑输出、构建日志和 `.trace` 包复制到一个新的 `Records/<timestamp>/`；不要覆盖既有记录。使用：

```bash
python3 summarize_records.py Records/2026-09-18-expanded
```

归档 `Records/2026-09-18-expanded/` 保存了六个变体各 5 次有效启动样本，以及对应构建/静态分析原始文件。
