#!/usr/bin/env swift
import Foundation
import AVFoundation
import AppKit

// 配置
let videoPath = "./cat-green.mp4"
let outputFolder = "./Frames"
let fps = 24.0

// 创建输出目录
try? FileManager.default.createDirectory(atPath: outputFolder, withIntermediateDirectories: true)

guard let url = URL(string: videoPath) else {
    print("❌ 找不到视频文件: \(videoPath)")
    exit(1)
}

let asset = AVURLAsset(url: url)

// 必须加载轨道，否则 generator 无法工作
asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
    var error: NSError?
    let status = asset.statusOfValue(forKey: "tracks", error: &error)
    if status == .loaded {
        print(" Tracks loaded successfully.")
    } else {
        print(" Failed to load tracks.")
    }
}

// 等待一下让异步加载完成
Thread.sleep(forTimeInterval: 1.0)

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 1920, height: 1080)

print(" 开始提取视频帧...")

var successCount = 0
var i = 0
let semaphore = DispatchSemaphore(value: 0)

// 异步生成图像
generator.generateCGImagesAsynchronously(forTimes: (0..<500).map { NSValue(time: CMTime(seconds: Double($0) / fps, preferredTimescale: 600)) }) { time, image, actualTime, result, error in
    if let image = image, result == .succeeded {
        let filename = String(format: "cat_%04d.png", successCount + 1)
        let outputPath = (outputFolder as NSString).appendingPathComponent(filename)
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let data = bitmapRep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: outputPath))
            successCount += 1
        }
    } else if result == .cancelled || result == .failed {
        semaphore.signal()
    }
}

// 阻塞等待提取完成
semaphore.wait()

print("✅ 成功提取 \(successCount) 帧到 \(outputFolder) 文件夹")
