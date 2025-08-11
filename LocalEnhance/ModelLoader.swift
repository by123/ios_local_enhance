//
//  ModelLoader.swift
//  LocalEnhance
//
//  Created by by on 2025/8/8.
//

import Foundation
import CoreML
import Vision
import Accelerate
import UIKit

enum EnhanceModel: String {
    case realesrgan = "realesrgan512 66.9M"
    case realesrganAnime = "realesrganAnime512 17.9M"
    case aesrgan = "aesrgan256 66.9M"
    case bsrgan = "bsrgan512 66.9M"
    case lesrcnn = "lesrcnn128 4.3M"
    case mmrealsrgan = "mmrealsrgan256 104.6M"
    
}

class ModelLoader {
    
    private var realesrgan512Model: realesrgan512?
    private var realesrganAnime512Model: realesrganAnime512?
    private var aesrgan256Model: aesrgan256?
    private var bsrgan512Model: bsrgan512?
    private var lesrcnn128Model: lesrcnn128?
    private var mmrealsrgan256Model: mmrealsrgan256?
    
    // 加载模型
    func loadModelSync(model: EnhanceModel) async -> Bool {
        return await withCheckedContinuation { continuation in
            releaseAllModels()
            DispatchQueue.global().async {
                do {
                    switch model {
                    case .realesrgan:
                        self.realesrgan512Model = try realesrgan512(configuration: MLModelConfiguration())
                    case .realesrganAnime:
                        self.realesrganAnime512Model = try realesrganAnime512(configuration: MLModelConfiguration())
                    case .aesrgan:
                        self.aesrgan256Model = try aesrgan256(configuration: MLModelConfiguration())
                    case .bsrgan:
                        self.bsrgan512Model = try bsrgan512(configuration: MLModelConfiguration())
                    case .lesrcnn:
                        self.lesrcnn128Model = try lesrcnn128(configuration: MLModelConfiguration())
                    case .mmrealsrgan:
                        self.mmrealsrgan256Model = try mmrealsrgan256(configuration: MLModelConfiguration())
                    }
                    print("模型加载成功")
                    continuation.resume(returning: true)
                } catch {
                    print("模型加载失败: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func releaseAllModels() {
        realesrgan512Model = nil
        realesrganAnime512Model = nil
        aesrgan256Model = nil
        bsrgan512Model = nil
        lesrcnn128Model = nil
        mmrealsrgan256Model = nil
    }
    
    // 主处理函数
    func processImage(_ inputImage: UIImage, _ model: EnhanceModel?, completion: @escaping (UIImage?) -> Void) {
        guard let model else { return }
        var inputSize = 512
        if(model.rawValue.contains("256")) {
            inputSize = 256
        }
        if (model.rawValue.contains("128")) {
            inputSize = 128
        }
        
        // 记录原始图片尺寸
        let originalSize = inputImage.size
        print("原始图片尺寸: \(originalSize)")
        
        // 预处理：调整输入图片到 inputSize x inputSize
        guard let resizedImage = resizeImageForModel(inputImage, targetSize: CGSize(width: inputSize, height: inputSize)) else {
            completion(nil)
            return
        }
        
        // 转换为 CVPixelBuffer
        guard let pixelBuffer = imageToPixelBuffer(resizedImage, size: CGSize(width: inputSize, height: inputSize)) else {
            completion(nil)
            return
        }
        
        // 模型推理
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var outputPixelBuffer: CVPixelBuffer? = nil
                switch(model) {
                case .realesrgan:
                    // 输出 (2048x2048)
                    if let realesrgan512Model = self.realesrgan512Model {
                        let prediction = try realesrgan512Model.prediction(input: pixelBuffer)
                        outputPixelBuffer = prediction.activation_out
                    }
                case .realesrganAnime:
                    // 输出 (2048x2048)
                    if let realesrganAnime512Model = self.realesrganAnime512Model {
                        let prediction = try realesrganAnime512Model.prediction(input: pixelBuffer)
                        outputPixelBuffer = prediction.activation_out
                    }
                case .aesrgan:
                    //输出 (1024x1024)
                    if let aesrgan256Model = self.aesrgan256Model {
                        let prediction = try aesrgan256Model.prediction(input: pixelBuffer)
                        outputPixelBuffer = prediction.activation_out
                    }
                case .bsrgan:
                    // 输出 (256x256)
                    if let bsrgan512Model = self.bsrgan512Model {
                        let prediction = try bsrgan512Model.prediction(input: bsrgan512Input(x: pixelBuffer))
                        outputPixelBuffer = prediction.activation_out
                    }
                case .lesrcnn:
                    // 输出 (512x512)
                    if let lesrcnn128Model = self.lesrcnn128Model {
                        let prediction = try lesrcnn128Model.prediction(input: lesrcnn128Input(x: pixelBuffer))
                        outputPixelBuffer = prediction.activation_out
                    }
                case .mmrealsrgan:
                    //输出 (1024x1024)
                    if let mmrealsrgan256Model = self.mmrealsrgan256Model {
                        let prediction = try mmrealsrgan256Model.prediction(input: mmrealsrgan256Input(x_1: pixelBuffer))
                        outputPixelBuffer = prediction.activation_out
                    }
                }
                
                // 转换为UIImage
                if let outputPixelBuffer, let outputImage = self.pixelBufferToImage(outputPixelBuffer) {
                    print("模型输出图片尺寸: \(outputImage.size)")
                    
                    // 等比例适配回原始尺寸比例
                    let finalImage = self.adaptOutputToOriginalAspectRatio(
                        outputImage: outputImage,
                        originalSize: originalSize,
                        intputSize: CGFloat(inputSize)
                    )
                    
                    DispatchQueue.main.async {
                        completion(finalImage)
                    }
                }
                outputPixelBuffer = nil
            } catch {
                print("模型推理失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    // 将输入图片调整为模型需要的尺寸
    private func resizeImageForModel(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let originalSize = image.size
        
        // 计算缩放比例（按长边缩放）
        let maxDimension = max(originalSize.width, originalSize.height)
        let scale = targetSize.width / maxDimension // inputSize / 640 = 0.8
        
        // 计算缩放后的尺寸
        let scaledWidth = originalSize.width * scale   // 480 * 0.8 = 384
        let scaledHeight = originalSize.height * scale // 640 * 0.8 = inputSize
        let scaledSize = CGSize(width: scaledWidth, height: scaledHeight)
        
        // 计算在inputSizexinputSize画布中的居中位置
        let x = (targetSize.width - scaledWidth) / 2   // (512 - 384) / 2 = 64
        let y = (targetSize.height - scaledHeight) / 2 // (512 - 512) / 2 = 0
        
        print("原始尺寸: \(originalSize)")
        print("缩放后尺寸: \(scaledSize)")
        print("在画布中的位置: (\(x), \(y))")
        
        // 创建inputSizexinputSize的黑色画布
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 填充黑色背景
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: targetSize))
        
        // 在居中位置绘制缩放后的图片
        let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        image.draw(in: drawRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // 将UIImage转换为CVPixelBuffer
    private func imageToPixelBuffer(_ image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()
        
        return buffer
    }
    
    // 将CVPixelBuffer 转换为 UIImage
    private func pixelBufferToImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // 将2048x2048的输出等比例适配到原始图片比例
    private func adaptOutputToOriginalAspectRatio(outputImage: UIImage, originalSize: CGSize, intputSize: CGFloat) -> UIImage {
        let outputSize = outputImage.size // 2048x2048
        
        // 计算原始图片在inputSizexinputSize中的缩放信息
        let maxDimension = max(originalSize.width, originalSize.height) // 640
        let inputScale = intputSize / maxDimension // inputSize / 640 = 0.8
        let scaledWidth = originalSize.width * inputScale   // 480 * 0.8 = 384
        let scaledHeight = originalSize.height * inputScale // 640 * 0.8 = 512
        
        // 在512x512中的居中位置
        let inputX = (intputSize - scaledWidth) / 2  // (512 - 384) / 2 = 64
        let inputY = (intputSize - scaledHeight) / 2 // (512 - 512) / 2 = 0
        
        // 计算在2048x2048输出中对应的区域（放大4倍）
        let outputScale = outputSize.width / intputSize // 2048 / inputSize = 4
        let cropX = inputX * outputScale      // 64 * 4 = 256
        let cropY = inputY * outputScale      // 0 * 4 = 0
        let cropWidth = scaledWidth * outputScale   // 384 * 4 = 1536
        let cropHeight = scaledHeight * outputScale // inputSize * 4 = 2048
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        print("输入图片在inputSizexinputSize中的位置: (\(inputX), \(inputY)), 尺寸: (\(scaledWidth), \(scaledHeight))")
        print("输出图片中需要裁剪的区域: \(cropRect)")
        
        // 执行裁剪，得到有效的图像区域
        guard let croppedImage = cropImage(outputImage, cropRect: cropRect) else {
            return outputImage
        }
        
        print("裁剪后尺寸: \(croppedImage.size)")
        
        // 最终将图片放大至 2k
        var scale = 2048 / max(cropWidth, cropHeight)
        scale = (scale > 1) ? scale : 1.0
        var finalImage: UIImage? = nil
        print("放大倍数: \(scale)")
        let finalWidth = cropWidth * scale
        let finalHeight = cropHeight * scale
        let finalSize = CGSize(width: finalWidth, height: finalHeight)
        
        finalImage = resizeImageToExactSize(croppedImage, targetSize: finalSize)
        
        
        print("最终输出尺寸: \(finalImage?.size ?? croppedImage.size)")
        return finalImage ?? croppedImage
    }
    
    // 精确调整图片到指定尺寸
    private func resizeImageToExactSize(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // 裁剪图片
    private func cropImage(_ image: UIImage, cropRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 注意：CGImage的坐标系可能需要调整
        let scaledCropRect = CGRect(
            x: cropRect.origin.x * image.scale,
            y: cropRect.origin.y * image.scale,
            width: cropRect.size.width * image.scale,
            height: cropRect.size.height * image.scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledCropRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    
}


extension UIImage {
    func resized() -> UIImage? {
        let scaleSize: CGSize = self.size
        let renderer = UIGraphicsImageRenderer(size: scaleSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaleSize))
        }
    }
}
