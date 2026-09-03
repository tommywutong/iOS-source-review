# 实验结果与结论

## 运行环境

- 工程：`CopyLab`
- 语言：Objective-C，ARC
- 设备：iPhone 17 模拟器，iOS 26.5
- 结论基于本次模拟器运行输出；Foundation 私有类名和地址不应作为业务逻辑判断依据。
- 本次原始输出见 [run-output.txt](run-output.txt)。

## 实验结论

### 1. `copy` 与 `mutableCopy`

对 `NSMutableString` 执行 `copy`，结果通常是不可变 `NSString`；执行 `mutableCopy`，结果是可变 `NSMutableString`。

`copy` 不保证一定分配新对象。对于某些本来不可变的对象，类可以直接返回自身；是否返回新对象由具体类的 `copyWithZone:` 决定。

### 2. Foundation 容器的普通 `copy`

`NSArray`、`NSDictionary`、`NSSet`、`NSOrderedSet` 的普通 `copy` 通常只复制外层容器。容器中的元素仍然共享，因此它是容器层面的浅拷贝，不是递归深拷贝。

外层容器已经分离，所以对源数组增删元素不会改变副本；但如果两个容器共享一个可变元素，修改该元素会同时反映到两个容器中。

### 3. `mutableCopy`

`mutableCopy` 通常会得到可变容器，但只保证返回的这一层容器可变，不保证其中的元素被复制。可变性和拷贝深度是两个不同维度。

### 4. `strong` 与 `copy`

`strong` 属性直接持有传入的可变数组，外部修改原数组会影响属性；`copy` 属性保存外层副本，外部对原数组的增删不会影响属性。

因此不建议这样声明：

```objc
@property (nonatomic, copy) NSMutableArray *array;
```

因为 `copy` 后运行时对象通常是不可变 `NSArray`，调用 `addObject:` 等方法可能崩溃。需要可变数组时，使用 `strong`，或在 setter 中使用 `[value mutableCopy]`。

### 5. `NSCopying` 与 `NSMutableCopying`

`NSCopying` 要求实现 `copyWithZone:`；`NSMutableCopying` 要求实现 `mutableCopyWithZone:`。协议只规定“如何复制”，不会自动让对象变成深拷贝，也不会自动提供可变子类。示例中的 `CopyPerson` 本身通过可写属性保持可变，所以它的 `mutableCopyWithZone:` 返回独立的同类对象；真实项目中也可以让它返回专门的可变子类。

自定义对象的 `copyWithZone:` 必须创建独立实例，并按对象语义复制各属性。示例中的 `CopyPerson` 复制后修改副本的 `name`，不会影响原对象。

### 6. 容器深拷贝

Foundation 容器没有一个对任意嵌套对象都自动递归复制的普通 `copy`。真正的深拷贝需要递归遍历数组、字典、集合，并对每个元素执行 `copy`；元素必须支持 `NSCopying`，否则只能继续共享或由业务代码定义复制规则。

本实验的 `DeepCopyObject` 是教学用递归实现，不应当被理解为所有对象的通用安全深拷贝方案。字典 key 还必须保持合法的哈希和相等语义，存在循环引用、不可复制对象或特殊资源对象时需要单独设计。

## 一句话记忆

`copy` 通常复制外层并得到不可变对象；`mutableCopy` 通常复制外层并得到可变对象；普通容器拷贝通常是浅拷贝；深拷贝需要递归复制内部对象；`strong` 共享原对象，`copy` 隔离外层容器。
