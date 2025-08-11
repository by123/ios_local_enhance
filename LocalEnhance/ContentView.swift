//
//  ContentView.swift
//  LocalEnhance
//
//  Created by by on 2025/8/8.
//

import SwiftUI
import CoreML
import PhotosUI

struct ContentView: View {
    
    @State var outputImage: UIImage? = nil
    @State private var inputImage: UIImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State var resultText = ""
    @State private var isPressing = false
    let models: [EnhanceModel] = [.realesrgan, .realesrganAnime, .aesrgan , .bsrgan, .lesrcnn, .mmrealsrgan]
    @State private var selectedModel: String = EnhanceModel.realesrgan.rawValue
    
    let loader = ModelLoader()
    
    var body: some View {
        VStack {
            CustomDropdown(selection: $selectedModel, options: models.map{$0.rawValue}, placeholder: "选择模型") { model in
                reset()
                loadModel(model)
                
            }
            ZStack{
                if let inputImage {
                    // 原图
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                } else {
                    // 占位图
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 360, height: 240)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                            }
                        )
                }
                if let outputImage, isPressing {
                    // 结果图
                    Image(uiImage: outputImage).resizable().scaledToFit().cornerRadius(10)
                }
            }.onTapGesture {
                if outputImage != nil {
                    isPressing.toggle()
                }
            }
            .overlay(
                Group {
                    if inputImage != nil {
                        Text(isPressing ? "高清图" : "原图")
                            .foregroundStyle(Color.purple)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                },
                alignment: .topTrailing
            )
            Spacer().frame(height: 32)
            Text(resultText).foregroundStyle(Color.red).font(Font.system(size: 12.0))
            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Text("选择图片")
                    }
                    .frame(width: 120, height: 40)
                    .background(Color.blue)
                    .foregroundStyle(Color.white)
                    .cornerRadius(20)
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        // 将选中的图片转换为UIImage
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                inputImage = uiImage
                                reset()
                            }
                        }
                    }
                }
                
                Button {
                    reset()
                    clickEnhance()
                } label: {
                    Text("高清").foregroundStyle(Color.white)
                }
                .frame(width: 120, height: 40)
                .background(Color.blue)
                .cornerRadius(20)
            }
            
        }
        .padding(20)
        .onAppear {
            loadModel(selectedModel)
        }
        
    }
    
    
    
    func clickEnhance() {
        if let inputImage {
            let startTime = Int(Date().timeIntervalSince1970 * 1000)
            resultText = "高清中..."
            loader.processImage(inputImage, EnhanceModel(rawValue: selectedModel)) { resultImage in
                self.outputImage = resultImage?.resized()
                
                let endTime = Int(Date().timeIntervalSince1970 * 1000)
                if let outputImage {
                    resultText = "高清前：\(inputImage.size)\n高清后：\(outputImage.size)\n消耗时间：\(endTime - startTime) 毫秒"
                }
            }
        }
    }
    
    func reset() {
        outputImage = nil
        resultText = ""
        isPressing = false
    }
    
    func loadModel(_ model: String) {
        if let select = EnhanceModel(rawValue: model) {
            Task {
                resultText = "模型加载中..."
                let result = await loader.loadModelSync(model: select )
                resultText = result ? "模型加载成功" : "模型加载失败"
            }
        }
    }
    
}


#Preview {
    ContentView()
}
