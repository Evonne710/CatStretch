import Cocoa
import AVFoundation
import AVKit
import CoreImage.CIFilterBuiltins

// MARK: - 语言检测工具
class LanguageManager {
    static let shared = LanguageManager()
    let isChinese: Bool
    
    private init() {
        let preferredLanguages = Bundle.main.preferredLocalizations
        let firstLanguage = preferredLanguages.first ?? "en"
        self.isChinese = firstLanguage.hasPrefix("zh") || firstLanguage.hasPrefix("cmn")
    }
    
    // 提示文字
    var stretchHint: String {
        isChinese ? "和它一起伸展吧" : "Go Stretch!"
    }
    
    // 休息时间标签
    func restTimeLabel(minutes: Int, seconds: Int) -> String {
        if isChinese {
            return String(format: "休息时间：%d:%02d", minutes, seconds)
        } else {
            return String(format: "Rest Time: %d:%02d", minutes, seconds)
        }
    }
    
    // 休息结束标签
    var restFinished: String {
        isChinese ? "休息结束！可以返回工作了 💪" : "Rest over! Back to work 💪"
    }
    
    // 紧急退出提示
    var emergencyHint: String {
        isChinese ? "长按退出" : "Hold to exit"
    }
    
    // 紧急退出成功
    var emergencySuccess: String {
        isChinese ? "已退出" : "Exited"
    }
}

class CatWindow {
    weak var appDelegate: AppDelegate?
    var window: NSWindow!
    var timerLabel: NSTextField!
    var closeButton: NSButton!
    var emergencyButton: WaterBallButton!
    var emergencyIcon: NSView!  // 存储倒计时标签
    var endTime: Date?
    var countdownTimer: Timer?
    
    // 视频播放器
    var catVideoView: NSView!
    var catPlayer: AVPlayer?
    var catPlayerLayer: AVPlayerLayer?
    var videoURL: URL?
    var videoDuration: TimeInterval = 0
    var isUserVideo: Bool = false
    
    // 紧急退出相关
    var emergencyPressStartTime: Date?
    var emergencyTimer: Timer?
    var emergencyProgressLabel: NSTextField!
    let emergencyHoldDuration: TimeInterval = 10
    
    func show() {
        guard let screen = NSScreen.main else { return }
        let rect = screen.frame
        
        window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver + 1  // 最高层级，确保在所有窗口上面
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .ignoresCycle]
        
        // 🔥 透明背景设置
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        
        // 猫咪视频播放器 - 全屏
        setupCatVideoPlayer(frame: rect)
        
        // 顶部倒计时 - 中间最上方，深灰色
        timerLabel = NSTextField(labelWithString: "5:00")
        timerLabel.font = NSFont(name: "SFProDisplay-Bold", size: 56) ?? NSFont.systemFont(ofSize: 56, weight: .bold)
        timerLabel.textColor = NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)  // 深灰色
        timerLabel.alignment = .center
        timerLabel.frame = NSRect(x: 0, y: Int(rect.height) - 120, width: Int(rect.width), height: 70)
        timerLabel.drawsBackground = false
        timerLabel.isBordered = false
        
        // 关闭按钮
        let closeTitle = LanguageManager.shared.isChinese ? "结束休息" : "Done"
        closeButton = NSButton(title: closeTitle, target: self, action: #selector(tryClose))
        closeButton.bezelStyle = .rounded
        closeButton.isHidden = true
        closeButton.frame = NSRect(x: Int(rect.width / 2) - 60, y: 80, width: 120, height: 40)
        closeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.35, alpha: 0.5).cgColor
        closeButton.layer?.cornerRadius = 20
        
        // 💧 水球紧急退出按钮 - 右下角
        let waterBallBtn = WaterBallButton(frame: NSRect(x: Int(rect.width) - 80, y: 30, width: 60, height: 60))
        waterBallBtn.catWindow = self
        
        // 倒计时标签（显示在水球上，垂直居中）
        let countdownLabel = NSTextField(labelWithString: "10")
        countdownLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        countdownLabel.textColor = NSColor(white: 1.0, alpha: 0.95)
        countdownLabel.alignment = .center
        countdownLabel.frame = NSRect(x: 0, y: 8, width: 60, height: 44)
        countdownLabel.drawsBackground = false
        countdownLabel.isBordered = false
        waterBallBtn.addSubview(countdownLabel)
        emergencyIcon = countdownLabel
        
        emergencyButton = waterBallBtn
        
        // 紧急退出进度标签（按钮下方文字）
        emergencyProgressLabel = NSTextField(labelWithString: "Ready to Go!")
        emergencyProgressLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emergencyProgressLabel.textColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.4, alpha: 0.8)
        emergencyProgressLabel.alignment = .center
        emergencyProgressLabel.frame = NSRect(x: Int(rect.width) - 90, y: 8, width: 80, height: 18)
        emergencyProgressLabel.isHidden = true
        emergencyProgressLabel.drawsBackground = false
        emergencyProgressLabel.isBordered = false
        
        // 添加所有视图 - 正确的层级顺序
        // 1. 猫咪视频（最底层）
        catVideoView.wantsLayer = true
        catVideoView.layer?.zPosition = 0
        window.contentView?.addSubview(catVideoView)
        
        // 2. 倒计时（在视频上面，最高层级）
        timerLabel.wantsLayer = true
        timerLabel.layer?.zPosition = 100
        window.contentView?.addSubview(timerLabel)
        
        // 3. 按钮（在视频上面，最高层级）
        closeButton.layer?.zPosition = 100
        window.contentView?.addSubview(closeButton)
        
        emergencyButton.layer?.zPosition = 100
        window.contentView?.addSubview(emergencyButton)
        
        emergencyProgressLabel.layer?.zPosition = 100
        window.contentView?.addSubview(emergencyProgressLabel)
        
        // 确保视频层可见
        print("📹 Video view frame: \(catVideoView.frame)")
        print("📹 Player layer frame: \(catPlayerLayer?.frame)")
        
        print("✅ All views added to window (no frosted glass background)")
        
        // 启动毛玻璃效果
        startFrostedGlassEffects()
    }
    
    // MARK: - 毛玻璃效果
    
    // 创建自定义毛玻璃效果视图
    func createCustomFrostedGlassView(frame: NSRect) -> NSView {
        let glassView = NSView(frame: frame)
        glassView.wantsLayer = true
        
        guard let layer = glassView.layer else { return glassView }
        
        // 基础半透明背景（浅色液态玻璃）
        layer.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.96, alpha: 0.55).cgColor
        
        // 添加多层渐变模拟液态玻璃高光
        // 顶部高光（模拟光线从上方照射）
        let topHighlight = CAGradientLayer()
        topHighlight.frame = CGRect(x: 0, y: 0, width: layer.bounds.width, height: layer.bounds.height * 0.6)
        topHighlight.colors = [
            NSColor(white: 1.0, alpha: 0.4).cgColor,
            NSColor(white: 1.0, alpha: 0.1).cgColor,
        ]
        topHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        topHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.addSublayer(topHighlight)
        
        // 中间液态反光
        let midReflection = CAGradientLayer()
        midReflection.frame = CGRect(x: 0, y: layer.bounds.height * 0.3, width: layer.bounds.width, height: layer.bounds.height * 0.4)
        midReflection.colors = [
            NSColor(white: 1.0, alpha: 0.05).cgColor,
            NSColor(calibratedRed: 0.98, green: 0.97, blue: 1.0, alpha: 0.15).cgColor,
            NSColor(white: 1.0, alpha: 0.05).cgColor,
        ]
        midReflection.startPoint = CGPoint(x: 0.0, y: 0.5)
        midReflection.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.addSublayer(midReflection)
        
        // 底部微弱反光
        let bottomHighlight = CAGradientLayer()
        bottomHighlight.frame = CGRect(x: 0, y: layer.bounds.height * 0.7, width: layer.bounds.width, height: layer.bounds.height * 0.3)
        bottomHighlight.colors = [
            NSColor(white: 1.0, alpha: 0.05).cgColor,
            NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.98, alpha: 0.2).cgColor,
        ]
        bottomHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.addSublayer(bottomHighlight)
        
        // 边缘高光（四个边）
        let edgeGlow = CALayer()
        edgeGlow.frame = layer.bounds.insetBy(dx: 1, dy: 1)
        edgeGlow.borderColor = NSColor(white: 1.0, alpha: 0.6).cgColor
        edgeGlow.borderWidth = 1.0
        layer.addSublayer(edgeGlow)
        
        print("✅ Custom frosted glass view created")
        
        return glassView
    }
    
    // 创建毛玻璃效果视图 - 使用 macOS 原生 NSVisualEffectView
    func createFrostedGlassView(frame: NSRect) -> NSView {
        let visualEffect = NSVisualEffectView(frame: frame)
        visualEffect.material = .sidebar  // 浅色毛玻璃效果
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        
        // 添加轻微圆角
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 0
        visualEffect.layer?.masksToBounds = true
        
        return visualEffect
    }
    
    // 启动效果
    func startFrostedGlassEffects() {
        // 开始倒计时
        let duration = UserDefaults.standard.double(forKey: "duration")
        let useDuration = duration > 0 ? duration : 5 * 60
        endTime = Date().addingTimeInterval(useDuration)
        
        startTimer()
        
        // 图片序列会在 setupCatVideoPlayer 中自动开始播放
        
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        print("✅ Cat window displayed (transparent video layout)")
    }
    
    // MARK: - 透明视频播放器
    
    func setupCatVideoPlayer(frame: NSRect) {
        // 1. 优先加载用户上传的视频
        var videoURL: URL?
        let userVideoPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CatStretch/user-video.mov")
        
        if FileManager.default.fileExists(atPath: userVideoPath.path) {
            videoURL = userVideoPath
            isUserVideo = true
            print("📦 Using user uploaded video")
        } else if let bundleURL = Bundle.main.url(forResource: "cat-transparent", withExtension: "mov") {
            videoURL = bundleURL
            isUserVideo = false
            print("📦 Using bundled transparent video")
        } else if let greenURL = Bundle.main.url(forResource: "cat-green", withExtension: "mp4") {
            videoURL = greenURL
            isUserVideo = false
            print("⚠️ Using bundled green screen video")
        }
        
        guard let url = videoURL else {
            print("❌ No video file found")
            return
        }
        
        self.videoURL = url
        
        // 获取视频时长
        let asset = AVAsset(url: url)
        videoDuration = CMTimeGetSeconds(asset.duration)
        if videoDuration.isNaN || videoDuration <= 0 {
            videoDuration = 0
        }
        print("⏱️ Video duration: \(Int(videoDuration))s")
        
        // 2. 创建播放器
        let playerItem = AVPlayerItem(url: url)
        catPlayer = AVPlayer(playerItem: playerItem)
        catPlayer?.actionAtItemEnd = .none
        catPlayer?.volume = 0
        
        // 3. 创建 PlayerLayer
        catPlayerLayer = AVPlayerLayer(player: catPlayer)
        catPlayerLayer?.frame = frame
        catPlayerLayer?.videoGravity = .resizeAspect
        catPlayerLayer?.backgroundColor = NSColor.clear.cgColor
        
        // 4. 创建容器视图
        let videoContainer = NSView(frame: frame)
        videoContainer.wantsLayer = true
        videoContainer.layer?.backgroundColor = NSColor.clear.cgColor
        if let playerLayer = catPlayerLayer {
            videoContainer.layer?.addSublayer(playerLayer)
        }
        
        catVideoView = videoContainer
        
        // 5. 监听播放结束，自动循环
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // 6. 开始播放
        catPlayer?.play()
        print("📹 Video playback started")
    }
    
    // 加载视频文件
    func loadVideo(from url: URL) {
        videoURL = url
        print("📹 Loading video from: \(url.path)")
        print("📹 File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        // 检查视频视图是否是绿幕抠像视图
        if let chromaKeyView = catVideoView as? CatVideoChromaKeyView {
            chromaKeyView.setupPlayer(with: url)
            print("✅ Green screen video loaded")
        } else {
            print("⚠️ catVideoView is not CatVideoChromaKeyView")
        }
    }
    
    // 视频播放结束后自动循环（短视频循环，长视频不循环）
    @objc func playerItemDidReachEnd(notification: Notification) {
        let restDuration = UserDefaults.standard.double(forKey: "duration")
        let restSeconds = restDuration > 0 ? restDuration : 5 * 60
        
        if videoDuration > 0 && videoDuration < restSeconds {
            // 短视频：循环播放
            if let playerItem = notification.object as? AVPlayerItem {
                playerItem.seek(to: .zero, completionHandler: nil)
                catPlayer?.play()
                print("🔄 Short video looped (duration: \(Int(videoDuration))s < rest: \(Int(restSeconds))s)")
            }
        } else {
            // 长视频：停留在最后一帧，不循环
            print("⏹️ Long video finished (duration: \(Int(videoDuration))s >= rest: \(Int(restSeconds))s)")
        }
    }
    
    // 设置色度键滤镜（绿幕/白底抠像）
    func applyChromaKeyFilter() {
        // 确保视频层背景透明
        catPlayerLayer?.backgroundColor = NSColor.clear.cgColor
        catVideoView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 注意：完整的色度键抠像需要自定义 AVVideoCompositing
        // 这里使用简单的混合模式来模拟
        catPlayerLayer?.isOpaque = false
        
        print("🎬 Video background set to transparent")
        print("📝 For full chroma key, add video with transparent background")
    }
    
    // 用户上传视频（由 AppDelegate 统一管理，这里保留兼容调用）
    func loadUserVideo(from url: URL) -> String? {
        return appDelegate?.loadUserVideo(from: url)
    }
    
    func startTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.endTime else { return }
            let remaining = endTime.timeIntervalSinceNow
            
            if remaining <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.timerLabel.stringValue = "Done!"
                self.closeButton.isHidden = false
                
                // 播放提示音
                NSSound(named: "Ping")?.play()
            } else {
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                self.timerLabel.stringValue = String(format: "%d:%02d", minutes, seconds)
            }
        }
    }
    
    // MARK: - 紧急退出功能
    
    @objc func emergencyButtonPressed() {
        print("🆘 紧急退出按钮被点击")
        // 这个方法会在按钮按下和释放时调用
    }
    
    func startEmergencyExit() {
        emergencyPressStartTime = Date()
        
        // 暂停倒计时
        pauseTimer()
        
        // 显示按钮下方文字
        emergencyProgressLabel.isHidden = false
        emergencyProgressLabel.stringValue = "Ready to Go!"
        
        // 获取水球按钮和倒计时标签
        guard let countdownLabel = emergencyIcon as? NSTextField else { return }
        
        emergencyTimer?.invalidate()
        emergencyTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.emergencyPressStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = self.emergencyHoldDuration - elapsed
            
            if remaining <= 0 {
                // 倒计时结束，退出
                self.emergencyTimer?.invalidate()
                countdownLabel.stringValue = "0"
                self.emergencyButton.setWaterLevel(0.0)  // 水排空
                self.emergencyProgressLabel.stringValue = "Exited"
                
                // 关键修复：清理倒计时
                self.appDelegate?.resetTimerAfterRest()
                self.emergencyPressStartTime = nil
                
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.stopVideo() // 停止视频
                    self.window.close()
                    print("🆘 Emergency exit: Cat window closed")
                }
            } else {
                // 更新按钮上的倒计时数字（10-0）
                let countNum = Int(remaining) + 1
                countdownLabel.stringValue = "\(countNum)"
                
                // 更新水位（从 1.0 降到 0.0）
                let progress_ratio = elapsed / self.emergencyHoldDuration
                self.emergencyButton.setWaterLevel(1.0 - progress_ratio)
            }
        }
    }
    
    func cancelEmergencyExit() {
        if emergencyPressStartTime != nil {
            emergencyTimer?.invalidate()
            emergencyPressStartTime = nil
            
            // 隐藏按钮下方文字
            emergencyProgressLabel.isHidden = true
            
            // 重置按钮上的倒计时
            if let countdownLabel = emergencyIcon as? NSTextField {
                countdownLabel.stringValue = "10"
            }
            
            // 重置水位到满
            self.emergencyButton.setWaterLevel(1.0)
            
            // 恢复倒计时
            resumeTimer()
            
            print("🆘 Emergency exit cancelled")
        }
    }
    
    // 暂停/恢复计时器
    var isTimerPaused = false
    var savedRemainingTime: TimeInterval = 0
    
    func pauseTimer() {
        isTimerPaused = true
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    func resumeTimer() {
        if isTimerPaused {
            isTimerPaused = false
            startTimer()
        }
    }
    
    @objc func tryClose() {
        guard let appDelegate = self.appDelegate else { return }
        if appDelegate.canUnlock() {
            stopVideo()
            window.close()
            print("✅ 猫咪窗口已关闭")
        } else {
            print("⏰ 休息时间还没结束哦！")
        }
    }
    
    func stopVideo() {
        catPlayer?.pause()
        catPlayer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        emergencyTimer?.invalidate()
        
        // 重置主倒计时器
        self.appDelegate?.resetTimerAfterRest()
        
        print("🛑 Video stopped and cleaned up")
    }
}

// MARK: - 水球紧急退出按钮（带水波动画和水位下降效果）
class WaterBallButton: NSButton {
    var catWindow: CatWindow?
    var waterLevel: CGFloat = 1.0  // 水位 1.0 = 满，0.0 = 空
    var wavePhase: CGFloat = 0
    var waveTimer: Timer?
    var isPressed = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupWaterBall()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupWaterBall() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = frame.width / 2
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.3).cgColor
        layer?.borderWidth = 1.5
        
        // 移除默认按钮文字
        title = ""
        isBordered = false
        
        // 启动水波动画
        startWaveAnimation()
    }
    
    func startWaveAnimation() {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.wavePhase += 0.08
            self?.layer?.setNeedsDisplay()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let width = bounds.width
        let height = bounds.height
        
        // 裁剪为圆形
        let circlePath = CGPath(ellipseIn: bounds, transform: nil)
        context.addPath(circlePath)
        context.clip()
        
        // 背景（透明）
        NSColor.clear.setFill()
        context.fill(bounds)
        
        // 水位计算
        let waterY = height - (waterLevel * height)
        
        // 绘制水波
        let waterPath = CGMutablePath()
        waterPath.move(to: CGPoint(x: 0, y: waterY))
        
        // 正弦波
        for x in stride(from: 0, to: width, by: 1) {
            let y = waterY + sin((x / width) * .pi * 4 + wavePhase) * 4
            waterPath.addLine(to: CGPoint(x: x, y: y))
        }
        
        waterPath.addLine(to: CGPoint(x: width, y: height))
        waterPath.addLine(to: CGPoint(x: 0, y: height))
        waterPath.closeSubpath()
        
        // 水渐变色（浅蓝 → 深蓝）
        let gradientColors = [
            NSColor(calibratedRed: 0.6, green: 0.8, blue: 1.0, alpha: 0.6).cgColor,
            NSColor(calibratedRed: 0.4, green: 0.6, blue: 0.9, alpha: 0.7).cgColor,
        ]
        
        guard let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 1.0]) else { return }
        
        context.addPath(waterPath)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: waterY), end: CGPoint(x: 0, y: height), options: [])
        
        // 高光效果
        let highlightPath = CGPath(ellipseIn: bounds.insetBy(dx: 4, dy: 4), transform: nil)
        context.addPath(highlightPath)
        context.setStrokeColor(NSColor(white: 1.0, alpha: 0.2).cgColor)
        context.setLineWidth(2.0)
        context.strokePath()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isPressed = true
        
        if let window = self.catWindow {
            window.startEmergencyExit()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isPressed = false
        
        if let window = self.catWindow {
            window.cancelEmergencyExit()
        }
    }
    
    // 更新水位（0.0 - 1.0）
    func setWaterLevel(_ level: CGFloat) {
        waterLevel = max(0.0, min(1.0, level))
        
        // 平滑动画
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        layer?.setNeedsDisplay()
        CATransaction.commit()
    }
    
    deinit {
        waveTimer?.invalidate()
    }
}

// MARK: - 绿幕抠像视频视图
class CatVideoChromaKeyView: NSView {
    var player: AVPlayer?
    var playerOutput: AVPlayerItemVideoOutput?
    var displayLink: CVDisplayLink?
    var ciContext: CIContext!
    var chromaKeyFilter: CIFilter!
    var videoLoaded = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupChromaKey()
        print("🎬 CatVideoChromaKeyView created: \(frameRect)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupChromaKey() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
        
        // 创建色度键滤镜（绿色）
        chromaKeyFilter = CIFilter(name: "CIChromaKeyFilter")
    }
    
    func setupPlayer(with url: URL) {
        print("📹 Setting up player with: \(url.lastPathComponent)")
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        playerOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        playerItem.add(playerOutput!)
        
        player = AVPlayer(playerItem: playerItem)
        player?.actionAtItemEnd = .none
        player?.volume = 0  // 静音
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // 等待视频准备好再启动显示链接
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        player?.play()
        print("▶️ Video play started")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let item = object as? AVPlayerItem {
                switch item.status {
                case .readyToPlay:
                    print("✅ Video ready to play!")
                    videoLoaded = true
                    setupDisplayLink()
                case .failed:
                    print("❌ Video failed to load: \(item.error?.localizedDescription ?? "unknown")")
                case .unknown:
                    print("⏳ Video status unknown")
                @unknown default:
                    break
                }
            }
        }
    }
    
    func setupDisplayLink() {
        let status = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if status == kCVReturnSuccess, let link = displayLink {
            CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
                DispatchQueue.main.async {
                    self?.needsDisplay = true
                }
                return kCVReturnSuccess
            }
            CVDisplayLinkStart(link)
            print("🔗 Display link started")
        } else {
            print("⚠️ Failed to create display link: \(status)")
        }
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {
        print("🔄 Video reached end, looping...")
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: .zero, completionHandler: nil)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let output = playerOutput else {
            print("⚠️ No player output in draw")
            return
        }
        
        let currentTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: currentTime) else { return }
        
        guard let pixelBuffer = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        chromaKeyFilter.setValue(ciImage, forKey: kCIInputImageKey)
        chromaKeyFilter.setValue(CIColor(red: 0.0, green: 1.0, blue: 0.0), forKey: "inputColor")
        chromaKeyFilter.setValue(0.35, forKey: "inputThreshold")
        
        guard let outputImage = chromaKeyFilter.outputImage else { return }
        
        let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
        
        if let cgImage = cgImage {
            let nsImage = NSImage(cgImage: cgImage, size: bounds.size)
            nsImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
    
    func stopPlayback() {
        CVDisplayLinkStop(displayLink!)
        player?.pause()
    }
    
    deinit {
        stopPlayback()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        print("🧹 CatVideoChromaKeyView deinit")
    }
}
