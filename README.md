# 🐱 CatStretch Xcode 项目

## 如何用 Xcode 打开

1. **打开 Xcode**
2. 点击 `File` > `Open...`
3. 选择 `CatStretchApp.xcodeproj` 文件
4. 点击 `Open`

## 项目结构

```
CatStretch-Xcode/
└── CatStretchApp.xcodeproj          # Xcode 项目文件
└── CatStretchApp/
    ├── CatStretchApp.swift          # 应用入口（@main）
    ├── AppDelegate.swift            # 应用代理（菜单栏、定时器逻辑）
    ├── CatWindow.swift              # 全屏猫咪窗口 + 设置界面
    ├── Info.plist                   # 应用配置
    ├── CatStretchApp.entitlements   # 权限配置
    └── Assets.xcassets/             # 资源文件
        └── AppIcon.appiconset/      # 应用图标
```

## 如何运行

1. 在 Xcode 中打开项目后
2. 选择目标设备为 `My Mac`
3. 点击运行按钮 ▶️ 或按 `Cmd + R`

## 如何优化

### 1. 添加真实猫咪图片

在 `CatWindow.swift` 中找到 `show()` 方法，替换 SF Symbol 为真实图片：

```swift
// 替换这部分：
if let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Cat") {
    catImageView.image = image
}

// 改为：
if let imagePath = Bundle.main.path(forResource: "my-cat", ofType: "png") {
    catImageView.image = NSImage(contentsOfFile: imagePath)
}
```

然后在 Xcode 中添加图片资源：
- 拖拽图片到 `Assets.xcassets` 或 `Resources` 文件夹

### 2. 添加更多猫咪动画

在 `CatWindow.swift` 的 `startCatAnimation()` 方法中添加动画效果：

```swift
// 添加左右摇摆
var offsetX: CGFloat = 0
var swinging = true

Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
    guard let self = self else { return }
    
    if swinging {
        offsetX += 2
        if offsetX >= 20 { swinging = false }
    } else {
        offsetX -= 2
        if offsetX <= -20 { swinging = true }
    }
    
    self.catImageView.frame.origin.x = self.originalX + offsetX
}
```

### 3. 添加呼噜声音效

在 `showCat()` 方法中添加：

```swift
// 播放呼噜声
if let soundURL = Bundle.main.url(forResource: "purr", withExtension: "mp3") {
    do {
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.play()
    } catch {
        print("播放声音失败: \(error)")
    }
}
```

### 4. 自定义菜单栏图标

在 `AppDelegate.swift` 的 `applicationDidFinishLaunching` 中：

```swift
// 使用自定义图标
if let iconImage = NSImage(named: "my-menu-icon") {
    button.image = iconImage
} else {
    button.title = "🐱"  // 备用 Emoji
}
```

## 调试技巧

### 查看日志

在 Xcode 底部点击 `Debug Area` 图标（或 `Cmd + Shift + Y`）可以看到 `print()` 输出。

### 断点调试

在代码行号左侧点击可以添加断点，运行时会暂停在该行。

### 实时预览

在 SwiftUI 文件中添加 `#Preview` 可以实时预览界面：

```swift
#Preview {
    SettingsView(appDelegate: AppDelegate())
}
```

## 常见问题

### Q: 菜单栏图标不显示？
A: 检查 `Info.plist` 中 `LSUIElement` 是否为 `true`

### Q: 全屏窗口无法锁定键盘？
A: 需要添加 `NSEvent` 全局监听器来拦截键盘事件

### Q: 如何打包成 .app 发布？
A: 
1. 选择 `Product` > `Archive`
2. 在 Organizer 中选择 `Distribute App`
3. 选择 `Copy App` 导出

## 后续开发建议

1. **添加猫咪动画**：使用 GIF 或视频替代静态图片
2. **完善设置界面**：添加图片上传功能
3. **添加数据统计**：记录每天休息次数
4. **优化动画效果**：使用 Core Animation 或 Lottie
5. **发布到 App Store**：需要开发者账号和沙盒配置

## 灵感来源与声明

CatStretch 的创意受到 [Cat Gatekeeper](https://github.com/zokuzoku/cat-gatekeeper)（作者：zokuzoku）的启发。

本项目为独立实现：
- 所有代码均自行编写
- 除 Meimei 的猫咪视频为实拍外，其它视觉素材（图标、界面等）均由 AI 生成
- 与 Cat Gatekeeper 没有官方关联

Cat Gatekeeper 的源代码采用 MIT License 开源，但其视觉素材和品牌资产保留所有权利。CatStretch 未使用其任何受保护的素材。

## 许可证

- 源代码：[CC BY-NC-ND 4.0](LICENSE)（署名-非商业性使用-禁止演绎）
- 视觉素材（猫咪视频、图标、Logo 等）：保留所有权利，详见 [ASSETS_LICENSE.md](ASSETS_LICENSE.md)
