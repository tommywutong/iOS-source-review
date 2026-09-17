# dyld fixups lab

This lab measures what can be observed from a real iPhone without private dyld hooks:

- `RebaseDense`: 128 internal function pointers packed into a small data region.
- `RebaseSparse`: the same number of internal pointers spread one per 16 KiB page.
- `BindRepeated`: 4,096 external pointer fixups using one imported symbol.
- `BindUnique`: 4,096 external pointer fixups using 4,096 imported symbols.
- `Baseline`: no experiment framework.

Each app takes a snapshot at the first instruction of `main`, before calling the framework marker. It logs `getrusage(RUSAGE_SELF)` and `TASK_EVENTS_INFO`; these values include dyld and pre-main work, but also unavoidable process/bootstrap work. Startup duration is captured separately with Xcode's App Launch instrument; neither data source exposes a private per-fixup timer.

## Run

```bash
./run-device.sh
```

The default device is the connected iPhone. Override it with `DEVICE_ID=...`; override the signing team with `DEVELOPMENT_TEAM=...`.

`run-device.sh` 会为每个 target 使用其在 `project.yml` 中的独立 Bundle ID。免费个人开发者账号须仍有足够的 App ID 创建额度；否则先等待额度恢复或使用已登记这些标识符的开发团队。脚本在每个变体完成后卸载该实验 App，但不会操作其他 App。

Static fixup metadata is extracted with `dyld_info` from the built arm64 Mach-O files. The device run writes raw console output to `run-output.txt`; the interpretation is in `RESULTS.md`.
