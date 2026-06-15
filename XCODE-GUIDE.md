# 🐱 CatStretch Xcode 使用指南

## 项目已为你打开！

Xcode 应该已经自动打开了项目。如果没有：
1. 双击 `CatStretchApp.xcodeproj` 文件
2. 或者在 Xcode 中选择 `File` > `Open...` 然后选择该项目

## 第一次运行

1. 在 Xcode 顶部选择目标为 **My Mac**
2. 点击左上角的 ▶️ 运行按钮（或按 `Cmd + R`）
3. 等待编译完成
4. 菜单栏会出现 🐱 图标

## 项目文件说明

| 文件 | 作用 |
|------|------|
| `CatStretchApp.swift` | 应用入口，定义应用生命周期 |
| `AppDelegate.swift` | 核心逻辑：菜单栏、定时器、提醒触发 |
| `CatWindow.swift` | 全屏猫咪窗口 + 设置界面 |

## 你可以尝试的修改

### 1. 修改提醒间隔（默认 45 分钟）

打开 `AppDelegate.swift`，找到：
```swift
var remainingTime: TimeInterval = 45 * 60
```
改为你想要的时间（单位：秒）

### 2. 修改休息时长（默认 5 分钟）

打开 `CatWindow.swift`，找到：
```swift
let useDuration = duration > 0 ? duration : 5 * 60
```
改为 `3 * 60`（3 分钟）或 `10 * 60`（10 分钟）

### 3. 替换猫咪图片

1. 准备一张猫咪图片（建议 400x400 像素）
2. 拖拽到 Xcode 的 `Assets.xcassets` 文件夹
3. 命名为 `cat`
4. 在 `CatWindow.swift` 中替换：
```swift
// 原来的代码：
if let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Cat") {
    catImageView.image = image
}

// 改为：
catImageView.image = NSImage(named: "cat")
```

### 4. 添加猫咪呼噜声

1. 准备一个音频文件（如 `purr.mp3`）
2. 拖拽到 Xcode 项目
3. 在 `AppDelegate.swift` 的 `showCat()` 方法中添加：
```swift
// 在 NSSound(named: "Funk")?.play() 下面添加：
if let soundURL = Bundle.main.url(forResource: "purr", withExtension: "mp3") {
    try? AVAudioPlayer(contentsOf: soundURL).play()
}
```

## 调试技巧

### 查看日志输出
运行应用后，Xcode 底部会显示 `Debug Area`，可以看到所有 `print()` 输出。

如果看不到，按 `Cmd + Shift + Y` 打开。

### 断点调试
在代码行号左侧点击添加断点，运行时会暂停。

### 实时预览 SwiftUI
在 `CatWindow.swift` 底部添加：
```swift
#Preview {
    SettingsView(appDelegate: AppDelegate())
}
```
然后点击右侧的预览按钮。

## 编译错误？

如果遇到编译错误，告诉我错误信息，我帮你修复！

## 下一步建议

1. ✅ 先运行看看效果
2. ✅ 尝试修改一些参数
3. ✅ 添加真实猫咪图片
4. ✅ 优化动画效果
5. ✅ 添加音效

有什么想改的随时告诉我！🐱
