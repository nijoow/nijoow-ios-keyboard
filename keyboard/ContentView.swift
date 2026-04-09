import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // 1. Premium Background
            Color.black.ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.15), Color.black]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            ).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // MARK: - Header
                    HeaderView()
                        .padding(.top, 20)
                    
                    // MARK: - Center Aligned Content (Max Width 640)
                    VStack(spacing: 30) {
                        // MARK: - Test Zone
                        VStack(alignment: .leading, spacing: 15) {
                            Label("직접 타이핑해 보세요", systemImage: "keyboard")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            TextField("여기를 눌러 키보드 테스트...", text: $text)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.white)
                                .focused($isFocused)
                                .tint(.purple)
                        }
                        .padding()
                        .background(GlassCard())
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal)
                    
                    // MARK: - Setup Guide (Full Width)
                    VStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 30) {
                            Text("사용 시작하기")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 25)
                            
                            // 단계별 정렬 개선
                            VStack(alignment: .leading, spacing: 0) {
                                StepView(number: "1", title: "설정 앱 열기", subtitle: "설정 > 일반 > 키보드로 이동",isLast: false)
                                StepView(number: "2", title: "키보드 추가", subtitle: "키보드 > 새로운 키보드 추가", isLast: false)
                                StepView(number: "3", title: "키보드 선택", subtitle: "Custom Keyboard 선택", isLast: false)
                                StepView(number: "4", title: "전체 접근 허용", subtitle: "선택 후 '전체 접근 허용' 활성화", isLast: true)
                            }
                            .padding(.horizontal, 25)
                            
                            // 설정 바로가기 버튼
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("아이폰 설정으로 이동하기")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal, 25)
                            
                            Text("* 설정 앱이 열리면 일반 > 키보드 메뉴를 찾아주세요.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 25)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            Rectangle()
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    VStack {
                                        Divider().background(Color.white.opacity(0.1))
                                        Spacer()
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                )
                        )
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Subviews

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Text("Custom Keyboard")
                .font(.system(size: 28, weight: .bold, design: .rounded))
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
        HStack(alignment: .top, spacing: 20) {
            // 수직선과 동그라미를 포함한 인디케이터 영역
            VStack(spacing: 0) {
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.purple))
                    .zIndex(1)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 2, height: 45)
                        .padding(.top, -2) // 끊김 방지
                } else {
                    // 마지막 아이템은 선 대신 여백
                    Spacer().frame(height: 30)
                }
            }
            .frame(width: 28) // 수직선 정렬을 위해 고정 너비 할당
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.top, 4) // 숫자 동그라미와 텍스트 중앙 맞춤 조절
        }
    }
}

struct GlassCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
}
