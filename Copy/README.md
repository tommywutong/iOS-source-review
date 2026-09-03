# CopyLab：Objective-C copy 实验

这是一个可在 iOS 模拟器运行的最小 Objective-C 实验工程，验证：

- `copy` 与 `mutableCopy` 的结果类型；
- Foundation 容器 `copy` 的浅拷贝行为；
- `strong` 与 `copy` 属性保存可变数组时的区别；
- 自定义对象实现 `NSCopying` / `NSMutableCopying`；
- 嵌套 `NSArray`、`NSDictionary`、`NSSet`、`NSOrderedSet` 的浅拷贝与递归深拷贝；
- 截图表格中 mutable / immutable 对象配合 `copy` / `mutableCopy` 的四种组合。

## 运行

最简单的方式是直接执行脚本：

```bash
./run-simulator.sh
```

脚本默认使用已安装的 iPhone 17（iOS 26.5）模拟器，也可以通过 `DEVICE_ID` 指定其他模拟器。

等价的手动步骤如下：

```bash
xcodegen generate
xcodebuild -project CopyLab.xcodeproj -scheme CopyLab \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build
xcrun simctl boot 'iPhone 17'
xcrun simctl install 'iPhone 17' \
  build/Build/Products/Debug-iphonesimulator/CopyLab.app
xcrun simctl launch --console 'iPhone 17' com.tommywu.lab.CopyLab
```

工程的 App 启动后自动执行实验并退出。完整实验结果见 [RESULTS.md](RESULTS.md)，本次运行的原始输出见 [run-output.txt](run-output.txt)。
