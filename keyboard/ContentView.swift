import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // 1. Luxury Obsidian Background
            Color.black.ignoresSafeArea()
            
            LinearGradient(
                colors: [Color(white: 0.12), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Subtle depth highlight
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.05), Color.clear]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 800
            ).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 50) {
                    // MARK: - Header
                    HeaderView()
                        .padding(.top, 40)
                    
                    // MARK: - Center Aligned Content (Max Width 640)
                    VStack(spacing: 30) {
                        // MARK: - Test Zone
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.white.opacity(0.6))
                                Text("직접 타이핑해 보세요")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            TextField("여기를 눌러 키보드 테스트...", text: $text)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.white)
                                .focused($isFocused)
                                .tint(.white) // Silver cursor
                        }
                        .padding(25)
                        .background(GlassCard())
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal)
                    
                    // MARK: - Setup Guide (Full Width)
                    VStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 40) {
                            Text("사용 시작하기")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                StepView(number: "1", title: "설정 앱 열기", subtitle: "설정 > 일반 > 키보드로 이동",isLast: false)
                                StepView(number: "2", title: "키보드 추가", subtitle: "키보드 > 새로운 키보드 추가", isLast: false)
                                StepView(number: "3", title: "키보드 선택", subtitle: "Custom Keyboard 선택", isLast: false)
                                StepView(number: "4", title: "전체 접근 허용", subtitle: "선택 후 '전체 접근 허용' 활성화", isLast: true)
                            }
                            .padding(.horizontal, 30)
                            
                            // 고급스러운 다크 버튼
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                    Text("아이폰 설정으로 이동하기")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(white: 0.15))
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    }
                                )
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal, 30)
                            
                            Text("* 설정 앱이 열리면 일반 > 키보드 메뉴를 찾아주세요.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.horizontal, 25)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 50)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            Rectangle()
                                .fill(Color.white.opacity(0.02))
                                .overlay(
                                    VStack {
                                        Divider().background(Color.white.opacity(0.08))
                                        Spacer()
                                        Divider().background(Color.white.opacity(0.08))
                                    }
                                )
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Subviews

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 25) {
            // New Luxury Obsidian Logo
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 15)
                .shadow(color: .white.opacity(0.05), radius: 5, x: 0, y: -2)
            
            Text("Custom Keyboard")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.white)
        }
    }
}

struct StepView: View {
    let number: String
    let title: String
    let subtitle: String
    var isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 25) {
            VStack(spacing: 0) {
                Text(number)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white))
                    .shadow(color: .white.opacity(0.2), radius: 5)
                    .zIndex(1)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2, height: 55)
                        .padding(.top, -2)
                } else {
                    Spacer().frame(height: 30)
                }
            }
            .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, 4)
        }
    }
}

struct GlassCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(Color.white.opacity(0.04))
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black.opacity(0.6))
                    .blur(radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear, .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
    }
}

#Preview {
    ContentView()
}
