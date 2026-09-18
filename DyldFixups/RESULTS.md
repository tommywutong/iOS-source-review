# 实验结果与结论

> 该文件只在 `run-device.sh` 成功完成全部五个真机变体后填写数值和最终结论。原始观测分别保存在 `static-fixups.txt` 与 `run-output.txt`；两者均被忽略，避免将机器相关地址和构建产物提交到仓库。

## 要检验的论点

| 论点 | 实验可证实的范围 | 不可从本实验推出的结论 |
| --- | --- | --- |
| Rebase 是镜像内地址修正 | `dyld_info -fixups` 应显示 image-relative target | 不把“链接时地址相对 0”写成所有 Mach-O 格式的通用表述 |
| Bind 是外部符号绑定 | `dyld_info -imports` 与 `-fixups` 应显示提供 dylib 和 symbol | 不假设每次 bind 都现场遍历 export trie；PrebuiltLoader 可预存 target 表 |
| Rebase 的主要成本是 page fault / I/O | 比较 dense 与 sparse rebase 的首次启动累计 `pageins` / `faults`，并以 App Launch trace 比较启动阶段时长 | `getrusage` 是进程累计值，不能将单次 page fault 归因给某一个 fixup |
| Bind 的单次 CPU 开销更高 | 比较 repeated 与 unique bind 的静态导入数和启动资源 | 没有私有 dyld phase timer 时，不宣称已独立测量每次 bind 的 CPU 周期 |
| chained fixups 按页统一处理 rebase/bind | 检查 `LC_DYLD_CHAINED_FIXUPS`、chain starts 与 import table | 不把“按页入口”夸张成“零 page fault”或“完全消除脏页” |

## 已由 dyld-1378 源码确认的机制

- 启动时，`dyldMain.cpp:770-798` 在统一 loop 中对已加载 Loader 调 `applyFixups`；它不是先执行一个全局 rebase pass、再执行一个全局 bind pass。
- `JustInTimeLoader.cpp:806-855` 先构造解析后的 bind target 表，再交给 `applyFixupsGeneric`；`logFixup` 在 `:628-669` 将 rebase 记录为 image + runtime offset，将 bind 记录为 target loader + symbol。
- `PrebuiltLoader.cpp:486-567` 对 shared-cache image 跳过普通 fixups；非 cache prebuilt image 读取预存 bind target 表后仍调用 `applyFixupsGeneric`。因此“现代系统仍需要 bind”与“每个 bind 都在启动时字符串查找”不能同时无条件成立。

## 静态 Mach-O 结果

使用 Xcode 27.0 的 iOS 27.0 SDK 编译 arm64 Release 二进制，并用 `dyld_info -fixup_chains -imports -fixups` 检查。每个 payload 都使用 `LC_DYLD_CHAINED_FIXUPS`，链页大小为 `0x4000`（16 KiB）。

| 变体 payload | rebase | bind | imports | 含 fixup 的 chain 页 | 静态判定 |
| --- | ---: | ---: | ---: | ---: | --- |
| `RebaseDensePayload` | 128 | 0 | 0 | 1 | 同数内部指针集中于一页 |
| `RebaseSparsePayload` | 128 | 0 | 0 | 128 | 同数内部指针分散为每页一个 |
| `BindRepeatedPayload` | 0 | 4,096 | 1 | 2 | 4,096 个位置绑定同一导入符号 |
| `BindUniquePayload` | 0 | 4,096 | 4,096 | 2 | 4,096 个位置绑定不同导入符号 |
| `InitHeavy`（app） | 0 | 8 | 8 | 1 | 4,096 个 C constructor；不引入专门的 framework fixup 负载 |

这证明现代 arm64 产物中 rebase 与 bind 仍是不同语义的 fixup：前者目标为当前 image 内的 runtime offset，后者携带外部 provider/symbol；同时两者均编码于同一套 chained-fixups 页链，而不是两个全局扫描阶段。

## 对原文论点的裁定

| 原文论点 | 裁定 | 证据与修正 |
| --- | --- | --- |
| Rebase 处理镜像内部指针，Bind 处理导入目标 | **成立，但措辞应改** | 本实验的 `dyld_info` 分别显示 image-relative `rebase` 与 `BindProvider/_provider_symbol_*` 的 `bind`。应写“内部目标 / 需解析的绑定目标”，不要绝对化为“Bind 必然跨镜像”，因为 Mach-O 也存在 self、weak、absolute 等 bind target。 |
| Rebase 只做 `pointer + slide` | **条件成立** | 对非认证的常规 rebase 是有用心智模型；但 arm64e 链节点还可能带 PAC 元数据。`fixup-chains.h:116-158` 显示 authenticated rebase/bind 均有 `next`、`bind`、`auth` 位。 |
| Bind 单次比 Rebase 更耗 CPU，因为必须在 export trie 字符串查找 | **旧式/JIT 路径条件成立；不能泛化** | `JustInTimeLoader.cpp:806-855` 先解析 bind target 表再写 fixups。现代 `PrebuiltLoader` 将 bind target 预计算为 `<LoaderRef, offset>`（`doc/dyld4.md:62-69`），运行时读取目标表后仍写 fixups（`PrebuiltLoader.cpp:501-567`）；因此“每个 bind 都在启动时遍历 trie”不成立。 |
| Rebase 通常因 Page Fault / I/O 耗时更高，Bind 只访问 Rebase 已触及约 30% 页面 | **前半待真机数据；30% 未证实** | 静态实验确认相同 128 rebase 可覆盖 1 或 128 个 16 KiB chain 页，证明页面分布是可控变量；但无法从此推出 I/O 主导或固定的 30% 比例。未发现本次源码或 Apple 一手资料支持“30%”这个可泛化常数。 |
| dyld 3 自 iOS 13 起全面落地 | **表述不精确** | `dyld4.md:45-77` 说明 dyld4 以 PrebuiltLoader/JustInTimeLoader 的逐镜像连续模型取代 dyld3/dyld2 的模式划分。版本与部署说法必须绑定具体系统版本和实测二进制，不能用“iOS 13 起全面”概括当前实现。 |
| chained fixups 从 iOS 13.4 引入，1 bit 标识 rebase/bind，按页一次完成两者 | **核心成立，边界须补** | `Policy.cpp:142-169` 标注 iOS 13.4 支持；`fixup-chains.h:57-77` 提供每页 chain start，`:116-226` 在常见格式中以 `bind` 位分辨 rebase/bind。它组织为一套页链，不代表“任何页面只访问一次”，也不等同于“彻底消除 page fault/脏页”。 |
| shared cache 预绑定消除了所有应用 bind | **错误** | shared-cache image 可跳过普通 fixups（`PrebuiltLoader.cpp:486-498`），但非 cache app/framework 仍可走 `applyFixupsGeneric`；本实验的嵌入 framework 正是这种 on-disk image。 |

`Loader.cpp:2127-2195` 还显示 page-in linking 受模式、沙盒、链格式和 bind-target 数量限制，失败时会回退到进程内 fixups。因此不能把“modern chained fixups”简化为无条件消除 I/O 或 page fault。

## 真机环境与动态数据

- **设备**：iPhone 15（`iPhone15,4`，arm64e），iOS 26.6.2（Build 23G90），Developer Mode 已启用，DDI 可用。
- **变体**：Baseline、RebaseDense、RebaseSparse、BindRepeated、BindUnique、InitHeavy。
- **运行**：每个变体安装一次，执行 5 次 `--terminate-existing` 进程重启，最后卸载；每次应用启动均输出 `DYLDLAB_RESULT` 和 `DYLDLAB_TIMELINE`。
- **profile**：每个真实 Bundle ID 的 profile 在安装 App 前显式注册到设备。`BindUnique` 五次使用原始 `com.tommywu.lab.dyldfixups.bindunique`。由于免费账号 App ID 创建配额，`InitHeavy` 的二进制使用 variant 5，但临时复用已注册的 Baseline Bundle ID/profile；这只影响签名身份，不改变 InitHeavy 代码。

### 静态与动态对照

| 变体 | rebase | bind | imports | chain 页 | 首次 faults | 首次 pageins | 后 4 次 faults 均值 | 后 4 次 pageins 均值 | constructor→main 均值 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 0 | 8 | 8 | 1 | 340 | 15 | 266.0 | 1.25 | 1.310 ms |
| RebaseDense | 128 | 0 | 0 | 1 | 346 | 24 | 268.0 | 1.00 | 1.013 ms |
| RebaseSparse | 128 | 0 | 0 | 128 | 352 | 120 | 268.3 | 2.75 | 0.987 ms |
| BindRepeated | 0 | 4,096 | 1 | 2 | 355 | 29 | 272.0 | 1.00 | 1.068 ms |
| BindUnique | 0 | 4,096 | 4,096 | 2 | 369 | 37 | 277.3 | 6.75 | 1.021 ms |
| InitHeavy | 0 | 8 | 8 | 1 | 347 | 36 | 272.0 | 10.00 | 1.654 ms |

### 启动阶段与构建阶段

`build` / `install` / `launch` 是主机侧命令 wall time；它们不是 App 内部的 dyld 阶段计时。以下是一次六变体批次的记录，原始值在 `Records/2026-09-18-expanded/phase-output.txt`：

| 变体 | build wall | install wall | 5 次 host launch 均值 |
| --- | ---: | ---: | ---: |
| Baseline | 10,343 ms | 3,126 ms | 1,093.8 ms |
| RebaseDense | 6,013 ms | 4,901 ms | 574.2 ms |
| RebaseSparse | 4,490 ms | 3,350 ms | 527.2 ms |
| BindRepeated | 8,675 ms | 4,114 ms | 997.6 ms |
| BindUnique | 19,830 ms | 3,772 ms | 584.2 ms |
| InitHeavy | 8,248 ms | 2,082 ms | 546.8 ms |

阶段解释必须分开：

1. **构建期**：`xcodebuild` 编译、链接、签名和 Xcode 增量构建状态的总 wall time；BindUnique 较长不能直接归因于 bind 运行时成本。
2. **安装期**：profile 注册、App 安装和 CoreDevice 通信的主机 wall time；不属于 App 启动时间。
3. **pre-main 可观测区间**：`constructor_ns → main_entry_ns`。这是本应用 constructor 到 `main` 的区间；它不含 dyld 私有 loader/fixup/ObjC runtime 各阶段的独立计时。
4. **main 区间**：`main_entry_ns → marker_start_ns` 几乎只包含输出、快照和控制开销；`marker_start_ns → marker_end_ns` 是实验 payload marker 的执行区间。
5. **退出前**：`exit_ns` 和 `before_exit` signpost 记录 marker 后到退出的边界；进程退出由 `devicectl` 等待完成。

### 真机观察

1. **页面分布差异清晰**：RebaseDense 与 RebaseSparse 都是 128 个 rebase，但首次 pageins 为 24 与 120；后续均接近 1–3。这个对照支持“fixup 所在页面分布会影响首次访问资源”的有限结论，不证明所有 pagein 都由 fixup 单独触发。
2. **重复 bind 与唯一 bind 没有可隔离的单次 bind 成本证据**：BindRepeated 首次 29 pageins、BindUnique 首次 37，后续均值分别 1.00 与 6.75；两组启动顺序、安装状态和设备全局缓存不能完全隔离，因此不能将差值归因于“符号字符串查找次数”。静态 imports 差异仍然被准确验证。
3. **InitHeavy 的 constructor 区间更长**：InitHeavy 平均 constructor→main 为 1.654 ms，Baseline 为 1.310 ms；它验证了大量用户态 constructor 能改变 main 前可观测区间，但该区间仍不是 dyld 私有 pre-main 时间。
4. **进程累计指标**：`faults` / `pageins` / `cow_faults` 是 `main` 时读取的整个进程累计值；新增 `resident_bytes`、`footprint_bytes`、`virtual_bytes`、`internal_bytes`、`compressed_bytes` 和 `images` 字段可供后续对照，但不能将某个值直接标成单个 fixup 的成本。

### 实验局限与复用边界

- **单一设备与系统**：iPhone 15 / iOS 26.6.2；不同设备、shared cache、系统策略可能不同。
- **微型负载**：payload 只有 128 或 4,096 个 fixup；InitHeavy 有 4,096 个 constructor，仍远小于大型真实 App。
- **host launch wall time 不等于启动时间**：包含 CoreDevice、console 转发和等待进程退出；需要严格启动时长时，应使用成功的 App Launch trace或统一设备端时间源。
- **App Launch trace**：本次 trace 尝试曾被设备信任层拒绝，`Records/2026-09-18-expanded/AppLaunch-Baseline.trace` 仅保存失败尝试，不作为有效启动时长。
- **PrebuiltLoader 未确认**：未 dump dyld closure 或 hook `applyFixups`，无法确认具体镜像走 JustInTimeLoader 还是 PrebuiltLoader；若为后者，bind target 可已预解析。
- **原始数据不可覆盖**：本批次所有原始文件保存在 `Records/2026-09-18-expanded/`，后续实验应使用新的时间戳目录。

## 当前判定规则

1. 若 release Mach-O 有 `LC_DYLD_CHAINED_FIXUPS`，则本次验证的是 chained-fixups 路径；不使用“先 rebase 后 bind 两轮扫描”的旧式模型解释结果。
2. RebaseDense / RebaseSparse 的差异只支持“页面布局与首次资源访问相关”的受限表述。
3. BindRepeated / BindUnique 的差异不能单独证明每个 bind 都会现场遍历 export trie，也不能证明 bind 无成本。
4. InitHeavy 的差异只支持“用户态 constructor 会扩大 constructor→main 区间”的表述。
5. 所有结论分为“源码机制”“Mach-O 静态事实”“真机观测”“主机控制耗时”四层。

## 扩展插桩验证

扩展插桩版 Baseline 已在同一台真机启动，原始输出保存于 `Records/2026-09-18-expanded/instrumented-baseline.txt`：

| 字段 | 本次值 | 含义 |
| --- | ---: | --- |
| `faults` / `pageins` / `cow_faults` | 280 / 15 / 36 | `main` 时刻的进程累计 VM 事件。 |
| `images` | 177 | `_dyld_image_count()` 在 `main` 时刻的加载 image 数。 |
| `resident_bytes` | 2,850,816 | `TASK_VM_INFO.resident_size`。 |
| `footprint_bytes` | 1,476,112 | `TASK_VM_INFO.phys_footprint`。 |
| `virtual_bytes` | 474,681,737,216 | `TASK_VM_INFO.virtual_size`。 |
| `internal_bytes` / `compressed_bytes` | 1,114,112 / 0 | `TASK_VM_INFO` 的 internal / compressed。 |
| constructor→main | 0.772 ms | `constructor_ns=1539496599791` 到 `main_entry_ns=1539497372125`。 |
| constructor tail→main | 0.772 ms | 两个本应用 constructor 之间只有 84 ns；它不包含其他 image 的 constructor。 |
| main→exit | 0.066 ms | 此 CLI 风格 App 无 UI run loop，几乎立即退出。 |

代码还在四个边界写入 `os_signpost`：`process_lifecycle` interval、`main_entry`、`before_exit`。本批次的 App Launch trace 因早期设备信任失败不可用，因此不将 signpost 声明为已由 Instruments trace 解析验证；源代码与控制台时间线共同提供可复用边界。

真机进程快速退出后，CoreDevice 可能在已收到两行控制台输出后报告“无法确定 PID”。该状态不覆盖应用已经写入并刷新的 `DYLDLAB_RESULT` / `DYLDLAB_TIMELINE`；原始归档中保留了完整诊断。
