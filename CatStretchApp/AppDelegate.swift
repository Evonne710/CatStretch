import Cocoa
import AVFoundation
import CoreMedia

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var timer: Timer?
    var remainingTime: TimeInterval = 45 * 60
    var isPaused = false
    var isResting = false
    var catWindow: CatWindow?
    var lockEndTime: Date?
    
    // 设置窗口（用 NSWindowController 管理，避免 releasedWhenClosed 导致的释放问题）
    var settingsWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🐱 Cat Stretch 启动成功！")
        
        // 注册退出通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )

        // 设置菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐱"
        }
        
        // 创建菜单并设置 delegate（动态更新）
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // 开始计时
        startTimer()
        updateMenuBar()

        print("✅ 菜单栏图标已显示，点击开始使用！")
    }
    
    @objc func appWillTerminate() {
        print("🛑 App terminating, cleaning up...")
        
        // 停止主倒计时
        timer?.invalidate()
        timer = nil
        isResting = false
        
        // 停止猫咪窗口内的播放和倒计时
        if let catWindow = catWindow {
            catWindow.stopVideo()
        }
    }
    
    // NSMenuDelegate：菜单即将显示时动态更新内容
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let timeItem: NSMenuItem
        if isResting {
            timeItem = NSMenuItem(title: "⏱ 😴 休息中", action: nil, keyEquivalent: "")
        } else {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            let timeStr = String(format: "⏱ 剩余 %d:%02d", minutes, seconds)
            timeItem = NSMenuItem(title: timeStr, action: nil, keyEquivalent: "")
        }
        timeItem.isEnabled = false
        menu.addItem(timeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleTitle = isPaused ? "▶️ 继续计时" : "⏸️ 暂停计时"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleTimer), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem(title: "🔔 立即提醒", action: #selector(triggerNow), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "⚙️ 偏好设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🚪 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    
    @objc func toggleTimer() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            timer = nil
            print("⏸️ 计时已暂停")
        } else {
            startTimer(resetTime: false)
            print("▶️ 计时已继续")
        }
        updateMenuBar()
    }
    
    @objc func startTimer(resetTime: Bool = true) {
        timer?.invalidate()
        let interval = UserDefaults.standard.double(forKey: "interval")
        let useInterval = interval > 0 ? interval : 45 * 60
        
        if resetTime {
            remainingTime = useInterval
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isPaused && !self.isResting {
                self.remainingTime -= 1
                if self.remainingTime <= 0 {
                    self.showCat()
                    return
                }
                self.updateMenuBar()
            }
        }
    }
    
    @objc func triggerNow() {
        print("🔔 立即触发提醒！")
        timer?.invalidate()
        timer = nil
        isPaused = false
        // 进入休息模式，由休息结束后再重新启动工作计时器
        showCat()
    }
    
    // MARK: - 设置窗口（纯 AppKit，避免 SwiftUI/AppKit 混用导致卡死）
    
    @objc func openSettings() {
        if let windowController = settingsWindowController {
            windowController.showWindow(nil)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "⚙️ 偏好设置"
        window.center()
        window.level = .floating
        // 关键：关闭窗口时不自动释放，由 NSWindowController 管理生命周期
        window.isReleasedWhenClosed = false
        
        let settingsView = createSettingsView()
        window.contentView = settingsView
        
        let windowController = NSWindowController(window: window)
        settingsWindowController = windowController
        windowController.showWindow(nil)
    }
    
    @objc func closeSettingsWindow() {
        settingsWindowController?.close()
        settingsWindowController = nil
    }
    
    private func createSettingsView() -> NSView {
        let savedInterval = UserDefaults.standard.integer(forKey: "interval")
        let savedDuration = UserDefaults.standard.integer(forKey: "duration")
        
        let currentInterval = savedInterval > 0 ? savedInterval / 60 : 45
        let currentDuration = savedDuration > 0 ? savedDuration / 60 : 5
        
        // 根视图
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        
        // 主垂直布局
        let stackView = NSStackView(frame: NSRect(x: 30, y: 30, width: 360, height: 460))
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -30),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -30)
        ])
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "⚙️ 偏好设置")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        stackView.addArrangedSubview(titleLabel)
        stackView.setCustomSpacing(8, after: titleLabel)
        
        // 分隔线
        let separator1 = NSBox()
        separator1.boxType = .separator
        stackView.addArrangedSubview(separator1)
        
        // 提醒间隔
        let intervalLabel = NSTextField(labelWithString: "⏰ 提醒间隔")
        intervalLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        stackView.addArrangedSubview(intervalLabel)
        
        let intervalPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 28))
        intervalPopup.addItems(withTitles: ["30 分钟", "45 分钟", "60 分钟", "90 分钟"])
        intervalPopup.tag = 100
        intervalPopup.selectItem(at: intervalIndex(for: currentInterval))
        intervalPopup.target = self
        intervalPopup.action = #selector(settingsValueChanged(_:))
        stackView.addArrangedSubview(intervalPopup)
        
        // 休息时长
        let durationLabel = NSTextField(labelWithString: "😴 休息时长")
        durationLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        stackView.addArrangedSubview(durationLabel)
        
        let durationPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 28))
        durationPopup.addItems(withTitles: ["3 分钟", "5 分钟", "10 分钟"])
        durationPopup.tag = 101
        durationPopup.selectItem(at: durationIndex(for: currentDuration))
        durationPopup.target = self
        durationPopup.action = #selector(settingsValueChanged(_:))
        stackView.addArrangedSubview(durationPopup)
        
        // 分隔线
        let separator2 = NSBox()
        separator2.boxType = .separator
        stackView.addArrangedSubview(separator2)
        
        // 猫咪视频
        let videoLabel = NSTextField(labelWithString: "🐱 猫咪视频")
        videoLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        stackView.addArrangedSubview(videoLabel)
        
        let uploadButton = NSButton(title: "上传透明视频", target: self, action: #selector(uploadVideoClicked))
        uploadButton.bezelStyle = .rounded
        stackView.addArrangedSubview(uploadButton)
        
        let resetButton = NSButton(title: "↩️ 还原默认视频", target: self, action: #selector(resetVideoClicked))
        resetButton.bezelStyle = .rounded
        stackView.addArrangedSubview(resetButton)
        
        let hintLabel = NSTextField(labelWithString: "要求：\n• MOV/MP4 格式\n• 带透明通道（Alpha）\n• 时长不超过 5 分钟\n• 小于 5 分钟会自动循环")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.isSelectable = false
        stackView.addArrangedSubview(hintLabel)
        
        // 分隔线
        let separator3 = NSBox()
        separator3.boxType = .separator
        stackView.addArrangedSubview(separator3)
        
        // 底部按钮
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 20
        buttonStack.distribution = .fillEqually
        
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(closeSettingsWindow))
        cancelButton.bezelStyle = .rounded
        
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettingsClicked))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // 回车键
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(saveButton)
        stackView.addArrangedSubview(buttonStack)
        
        // NSStackView 会自动管理 arrangedSubview 的宽度，不需要额外约束
        
        return rootView
    }
    
    private func intervalIndex(for minutes: Int) -> Int {
        switch minutes {
        case 30: return 0
        case 60: return 2
        case 90: return 3
        default: return 1 // 45
        }
    }
    
    private func durationIndex(for minutes: Int) -> Int {
        switch minutes {
        case 3: return 0
        case 10: return 2
        default: return 1 // 5
        }
    }
    
    @objc private func settingsValueChanged(_ sender: NSPopUpButton?) {
        // 实时反馈，可选：保存时统一处理
    }
    
    @objc private func uploadVideoClicked(_ sender: Any? = nil) {
        let panel = NSOpenPanel()
        panel.title = "选择带透明通道的视频"
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        
        panel.beginSheetModal(for: settingsWindowController!.window!) { [weak self] result in
            guard let self = self else { return }
            if result == .OK, let url = panel.url {
                let error = self.loadUserVideo(from: url)
                self.showAlert(
                    title: error == nil ? "上传成功" : "视频不符合要求",
                    message: error ?? "下次提醒时将使用你上传的视频。",
                    style: error == nil ? .informational : .warning
                )
            }
        }
    }
    
    @objc private func resetVideoClicked(_ sender: Any? = nil) {
        if resetToDefaultVideo() {
            showAlert(title: "已还原", message: "下次提醒时将使用默认视频。", style: .informational)
        } else {
            showAlert(title: "还原失败", message: "无法删除自定义视频，请重启 App 后重试。", style: .warning)
        }
    }
    
    @objc private func saveSettingsClicked(_ sender: Any? = nil) {
        guard let contentView = settingsWindowController?.window?.contentView else {
            closeSettingsWindow()
            return
        }
        
        let intervalPopup = contentView.viewWithTag(100) as? NSPopUpButton
        let durationPopup = contentView.viewWithTag(101) as? NSPopUpButton
        
        let intervalMinutes = intervalPopup?.indexOfSelectedItem == 0 ? 30 :
                              intervalPopup?.indexOfSelectedItem == 2 ? 60 :
                              intervalPopup?.indexOfSelectedItem == 3 ? 90 : 45
        
        let durationMinutes = durationPopup?.indexOfSelectedItem == 0 ? 3 :
                              durationPopup?.indexOfSelectedItem == 2 ? 10 : 5
        
        UserDefaults.standard.set(intervalMinutes * 60, forKey: "interval")
        UserDefaults.standard.set(durationMinutes * 60, forKey: "duration")
        
        remainingTime = Double(intervalMinutes * 60)
        updateMenuBar()
        
        closeSettingsWindow()
        print("✅ 设置已保存")
    }
    
    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "确定")
        alert.beginSheetModal(for: settingsWindowController!.window!, completionHandler: nil)
    }
    
    // MARK: - 其他方法
    
    func updateMenuBar() {
        if let button = statusItem.button {
            if isResting {
                button.title = "😴 休息中"
            } else if isPaused {
                button.title = "⏸️"
            } else {
                let minutes = Int(remainingTime) / 60
                let seconds = Int(remainingTime) % 60
                button.title = String(format: "🐱 %d:%02d", minutes, seconds)
            }
        }
    }
    
    func showCat() {
        print("🐱 猫咪来了！")
        
        // 停止工作倒计时，进入休息状态
        timer?.invalidate()
        timer = nil
        isResting = true
        isPaused = false
        updateMenuBar()
        
        // 播放提示音
        NSSound(named: "Funk")?.play()
        
        // 创建全屏猫咪窗口
        catWindow = CatWindow()
        catWindow?.appDelegate = self
        catWindow?.show()
        
        let duration = UserDefaults.standard.double(forKey: "duration")
        let useDuration = duration > 0 ? duration : 5 * 60
        lockEndTime = Date().addingTimeInterval(useDuration)
    }
    
    // 休息结束后重置计时器
    func resetTimerAfterRest() {
        timer?.invalidate()
        timer = nil
        isResting = false
        lockEndTime = nil
        let interval = UserDefaults.standard.double(forKey: "interval")
        remainingTime = interval > 0 ? interval : 45 * 60
        isPaused = false
        startTimer(resetTime: true)
        updateMenuBar()
        print("🔄 Timer reset after rest session")
    }
    
    func canUnlock() -> Bool {
        guard let lockEndTime = lockEndTime else { return true }
        return Date() >= lockEndTime
    }
    
    // MARK: - 用户上传视频验证与保存
    func validateVideo(url: URL) -> (isValid: Bool, errorMessage: String?) {
        let asset = AVAsset(url: url)
        
        // 检查时长
        let duration = CMTimeGetSeconds(asset.duration)
        if duration.isNaN || duration <= 0 {
            return (false, "无法读取视频时长")
        }
        if duration > 5 * 60 {
            return (false, "视频时长超过5分钟（当前 \(Int(duration)) 秒），请剪辑后再上传")
        }
        
        // 检查是否有 Alpha 通道
        let tracks = asset.tracks(withMediaType: .video)
        guard let track = tracks.first else {
            return (false, "无法读取视频轨道")
        }
        
        var hasAlpha = false
        for desc in track.formatDescriptions {
            let cmDesc = desc as! CMFormatDescription
            let ext = CMFormatDescriptionGetExtensions(cmDesc) as? [String: Any]
            if let containsAlpha = ext?["ContainsAlphaChannel"] as? Int, containsAlpha == 1 {
                hasAlpha = true
                break
            }
        }
        
        if !hasAlpha {
            return (false, "视频不包含透明通道（Alpha），请导出带透明的视频（如 ProRes 4444 / HEVC with Alpha）")
        }
        
        return (true, nil)
    }
    
    func resetToDefaultVideo() -> Bool {
        let userVideoPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CatStretch/user-video.mov")
        
        if FileManager.default.fileExists(atPath: userVideoPath.path) {
            do {
                try FileManager.default.removeItem(at: userVideoPath)
                print("✅ User video removed, will use default video next time")
                return true
            } catch {
                print("❌ Failed to remove user video: \(error)")
                return false
            }
        }
        return true
    }
    
    func loadUserVideo(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // 验证视频
        let validation = validateVideo(url: url)
        guard validation.isValid else {
            print("❌ Video validation failed: \(validation.errorMessage ?? "未知错误")")
            return validation.errorMessage
        }
        
        // 复制到 APP 目录
        let destinationURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CatStretch")
            .appendingPathComponent("user-video.mov")
        
        try? FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("✅ User video saved: \(destinationURL.path)")
            return nil
        } catch {
            print("❌ Failed to copy video: \(error)")
            return "保存视频失败: \(error.localizedDescription)"
        }
    }
}

