import SwiftUI

struct KeyboardView: View {
    var onKeyTap: (String) -> Void
    var onDelete: () -> Void
    var onSpace: () -> Void
    var onEnter: () -> Void
    var onNextKeyboard: () -> Void
    
    @State private var isShifted: Bool = false
    
    let firstRow = ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"]
    let firstRowShifted = ["ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ", "ㅛ", "ㅕ", "ㅑ", "ㅒ", "ㅖ"]
    let secondRow = ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"]
    let thirdRow = ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]
    
    var body: some View {
        VStack(spacing: 8) {
            // First Row
            HStack(spacing: 6) {
                ForEach(0..<firstRow.count, id: \.self) { i in
                    KeyButton(text: isShifted ? firstRowShifted[i] : firstRow[i]) {
                        onKeyTap(isShifted ? firstRowShifted[i] : firstRow[i])
                        if isShifted { isShifted = false }
                    }
                }
            }
            
            // Second Row
            HStack(spacing: 6) {
                ForEach(secondRow, id: \.self) { key in
                    KeyButton(text: key) {
                        onKeyTap(key)
                        if isShifted { isShifted = false }
                    }
                }
            }
            
            // Third Row
            HStack(spacing: 6) {
                // Shift Button
                FunctionKeyButton(systemName: isShifted ? "shift.fill" : "shift", color: isShifted ? .blue : .gray.opacity(0.3)) {
                    isShifted.toggle()
                }
                .frame(width: 45)
                
                ForEach(thirdRow, id: \.self) { key in
                    KeyButton(text: key) {
                        onKeyTap(key)
                        if isShifted { isShifted = false }
                    }
                }
                
                // Backspace Button
                FunctionKeyButton(systemName: "delete.left", color: .gray.opacity(0.3)) {
                    onDelete()
                }
                .frame(width: 45)
            }
            
            // Fourth Row
            HStack(spacing: 6) {
                // Next Keyboard
                FunctionKeyButton(systemName: "globe", color: .gray.opacity(0.3)) {
                    onNextKeyboard()
                }
                .frame(width: 45)
                
                // Space
                Button(action: onSpace) {
                    Text("space")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Enter
                Button(action: onEnter) {
                    Text("완료")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(height: 42)
                        .background(Color.blue)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(6)
        .background(KeyboardBackground())
    }
}

// MARK: - Components

struct KeyButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(text)
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white.opacity(0.9))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FunctionKeyButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(color)
                .foregroundColor(.black)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct KeyboardBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.82, green: 0.84, blue: 0.86))
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    KeyboardView(onKeyTap: { _ in }, onDelete: {}, onSpace: {}, onEnter: {}, onNextKeyboard: {})
}
