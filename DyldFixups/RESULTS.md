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

- **设备**：iPhone 15（`iPhone15,4`，arm64e），iOS 26.6.2（Build 23G90），Developer Mode 已启用。
- **签名**：免费个人开发者 profile，自动签名；BindUnique 因 App ID 创建周配额耗尽，借用了已注册的 `rebasedense`/`rebasedense.payload` Bundle ID 完成测试，二进制负载仍为 BindUnique 的 4,096 个不同符号绑定。
- **运行**：每个变体安装一次，随后执行 5 次 `--terminate-existing` 的进程重启；记录首次启动与后续 4 次进程重启的 page fault / pagein 均值，完成后卸载该实验 App。

### 静态与动态对照

| 变体 | rebase | bind | imports | chain 页 | 首次 faults | 首次 pageins | 稳态 faults | 稳态 pageins |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 0 | 8 | 8 | 1 | 338 | 16 | 264.0 | 1.2 |
| RebaseDense | 128 | 0 | 0 | 1 | 345 | 13 | 267.0 | 1.5 |
| RebaseSparse | 128 | 0 | 0 | 128 | 346 | 21 | 268.0 | 1.0 |
| BindRepeated | 0 | 4,096 | 1 | 2 | 355 | 25 | 271.0 | 1.2 |
| BindUnique | 0 | 4,096 | 4,096 | 2 | 371 | 23 | 278.2 | 1.0 |

**观察**：

1. **RebaseSparse 首次 pageins 高于 RebaseDense**（21 vs 13），尽管两者静态 rebase 数量相同；唯一区别是前者覆盖 128 个分散的 16 KiB 链页，后者仅 1 页。这与“fixup 页面分布影响首次启动资源访问”一致，但本实验不能单独证明因果关系。
2. **BindRepeated 与 BindUnique 在稳态 pageins 无显著差异**（均值 1.2 vs 1.0），尽管后者有 4,096 个独立导入符号、前者仅 1 个。在此设备、系统版本与二进制规模下，不同导入数量未表现为可观测的 pagein 差异；不能推出“bind 无成本”，但也无法从本实验证明“每个 bind 必然触发新的符号查找 I/O”。
3. **首次启动与同次安装后续进程重启存在明显差距**：首次观测的 faults 在 338–371 之间、pageins 在 13–25 之间；后续观测稳定在 264–278 faults、pageins 接近 1。这是本设备、此安装序列下的观察；未隔离 OS 缓存、安装状态或其他进程活动，因此不将该差异归因为单一机制，也不外推为固定比例。

### 实验局限

- **单一设备与系统**：iPhone 15 / iOS 26.6.2；不同设备、shared cache 版本、dyld 策略可能表现不同。
- **微型负载**：每个 payload 只有 128 或 4,096 个 fixup，远小于真实 App framework；更大规模下 bind 成本可能显现。
- **测量口径**：`task_info` 的 faults/pageins 包含整个进程地址空间，不限于 fixup 页面；无法分离 dyld fixup pass 专属 I/O。
- **console 记录异常**：Baseline 的 `run=1` 下出现两条 `DYLDLAB_RESULT`，而 `main` 只执行一次打印。报告将最早一条（338 faults / 16 pageins）作为首次观测，其余结果仅用于稳态背景；这条重复记录不计为额外独立样本。
- **PrebuiltLoader 未确认**：实验未 dump dyld closure 或 hook `applyFixups`，无法确认这些二进制是否走 JustInTimeLoader 还是 PrebuiltLoader；若为后者，bind target 已预解析，不会在启动时遍历 export trie。

## 当前判定规则

1. 若 release Mach-O 有 `LC_DYLD_CHAINED_FIXUPS`，则本次实验验证的是 chained-fixups 路径；不使用“先 rebase 后 bind 两轮扫描”的旧式模型解释结果。
2. 若 `RebaseSparse` 在相近 rebase 数量下稳定高于 `RebaseDense` 的累计 pageins/faults，结论限于“fixup 页面分散与更高 pre-main 资源消耗相关”。
3. 若 `BindUnique` 与 `BindRepeated` 的静态 imports 与启动资源差异不显著，不得推出 bind 无成本；只能说此设备、系统、二进制规模和测量口径下未观察到显著差异。
4. 所有结论都按“源码机制”“Mach-O 静态事实”“真机观测”三层分别表述。
