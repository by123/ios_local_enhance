//
//  CustomDropdown.swift
//  LocalEnhance
//
//  Created by by on 2025/8/8.
//

import Foundation
import SwiftUI

// MARK: - 自定义下拉菜单组件
struct CustomDropdown: View {
    @Binding var selection: String
    let options: [String]
    let placeholder: String
    @State var isExpanded = false
    let onChange: (_ model: String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 选择器头部
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selection == placeholder ? placeholder : selection)
                        .foregroundColor(selection == placeholder ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 下拉选项
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            if(option != selection) {
                                onChange(option)
                            }
                            selection = option
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                selection == option ? Color.blue.opacity(0.1) : Color.white
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if option != options.last {
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
            }
        }
        .zIndex(1000) // 确保下拉菜单显示在最上层
    }
}
