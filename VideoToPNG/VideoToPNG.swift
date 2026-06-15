import SwiftUI
import AVFoundation
import AppKit

@main
struct VideoToPNGApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var status: String = "点击选择视频文件"
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("视频转 PNG 序列工具")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Button(action: convertVideo) {
                Text(status)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if progress > 0 {
                ProgressView(value: progress)
                    .frame(width: 300)
            }
            
            Text("转换后的图片将保存在视频同级目录的 'Frames' 文件夹中")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 400, height: 200)
    }
    
    func convertVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        
        if panel.runModal() == .OK, let url = panel.url {
            status = "正在转换，请稍候..."
            
            Task {
                await extractFrames(from: url)
            }
        }
    }
    
    @MainActor
    func extractFrames(from url: URL) async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        // 获取视频时长
        guard let duration = try? await asset.load(.duration) else {
            status = "❌ 无法读取视频信息"
            return
        }
        
        let fps = 24.0
        let totalSeconds = duration.seconds
        let totalFrames = Int(totalSeconds * fps)
        
        let outputFolder = url.deletingLastPathComponent().appendingPathComponent("Frames")
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        
        var successCount = 0
        
        // 逐帧提取
        for i in 0..<totalFrames {
            let time = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
            if let image = try? generator.image(at: time) {
                let filename = String(format: "cat_%04d.png", i + 1)
                let outputPath = outputFolder.appendingPathComponent(filename)
                
                if let data = image.pngData() {
                    try? data.write(to: outputPath)
                    successCount += 1
                }
            }
            
            progress = Double(i) / Double(totalFrames)
            status = "正在转换: \(successCount)/\(totalFrames) 帧"
        }
        
        status = "✅ 成功！共提取 \(successCount) 张图片"
        progress = 1.0
    }
}
