import SwiftUI
import UIKit

struct ContentView: View {
  @State private var settings = KeyboardPreferencesStore.load()
  @State private var text = ""
  @State private var saveFailed = false
  @FocusState private var isFocused: Bool

  private var palette: KeyboardThemePalette {
    KeyboardThemePalette.make(for: settings)
  }

  var body: some View {
    ZStack {
      background

      ScrollView {
        VStack(spacing: 28) {
          HeaderView(accent: palette.accent)
            .padding(.top, 24)

          VStack(spacing: 22) {
            KeyboardPreview(settings: settings)
            settingsCard
            testCard
            setupCard
          }
          .frame(maxWidth: 680)
          .padding(.horizontal, 18)
          .padding(.bottom, 40)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var background: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [
          Color(uiColor: palette.accent).opacity(0.10),
          Color(white: 0.075),
          .black,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      RadialGradient(
        colors: [.white.opacity(0.065), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 700
      )
      .ignoresSafeArea()
    }
  }

  private var settingsCard: some View {
    VStack(alignment: .leading, spacing: 24) {
      sectionHeader(
        title: "키보드 설정",
        subtitle: "변경한 설정은 키보드를 다시 열면 적용돼요."
      )

      VStack(alignment: .leading, spacing: 14) {
        settingLabel("글래스 테마")

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
          ForEach(KeyboardThemePreset.allCases.filter { $0 != .custom }) { preset in
            ThemeSwatchButton(
              preset: preset,
              isSelected: settings.theme == preset,
              action: { updateSettings { $0.theme = preset } }
            )
          }
        }

        ColorPicker(selection: customAccentBinding, supportsOpacity: false) {
          HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
              .foregroundStyle(Color(uiColor: settings.customAccent.uiColor))
            VStack(alignment: .leading, spacing: 2) {
              Text("포인트 색상 직접 선택")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
              Text("선택한 색상은 읽기 좋은 범위로 자동 보정돼요.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
          }
          .contentShape(Rectangle())
        }
        .padding(14)
        .background(settingRowBackground(isActive: settings.theme == .custom))
      }

      Divider().overlay(.white.opacity(0.08))

      VStack(alignment: .leading, spacing: 12) {
        settingLabel("키보드 높이")
        Picker("키보드 높이", selection: settingsBinding(for: \.height)) {
          ForEach(KeyboardHeightPreset.allCases) { preset in
            Text(preset.title).tag(preset)
          }
        }
        .pickerStyle(.segmented)
      }

      Divider().overlay(.white.opacity(0.08))

      Toggle(isOn: hapticsBinding) {
        VStack(alignment: .leading, spacing: 4) {
          Text("키 입력 햅틱")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
          Text("일반 입력과 커서 이동·연속 삭제에 가벼운 피드백을 줘요.")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.48))
        }
      }
      .tint(Color(uiColor: palette.accent))

      if saveFailed {
        Label(
          "설정을 저장하지 못했어요. App Group 설정을 확인해 주세요.",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.orange)
      }

      Button {
        KeyboardPreferencesStore.reset()
        settings = .default
        saveFailed = !KeyboardPreferencesStore.save(settings)
      } label: {
        Label("기본 설정으로 복원", systemImage: "arrow.counterclockwise")
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 13)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.white.opacity(0.72))
      .background(settingRowBackground(isActive: false))
    }
    .padding(22)
    .background(GlassCard(cornerRadius: 24))
  }

  private var testCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      sectionHeader(title: "직접 타이핑해 보기", subtitle: "설정 적용 후 실제 입력감을 확인해 보세요.")

      TextField("여기를 눌러 키보드 테스트...", text: $text, axis: .vertical)
        .lineLimit(2...5)
        .focused($isFocused)
        .tint(Color(uiColor: palette.accent))
        .padding(16)
        .background(settingRowBackground(isActive: isFocused))
    }
    .padding(22)
    .background(GlassCard(cornerRadius: 24))
  }

  private var setupCard: some View {
    VStack(alignment: .leading, spacing: 20) {
      sectionHeader(title: "사용 시작하기", subtitle: "앱 설정을 공유하려면 전체 접근이 필요해요.")

      VStack(spacing: 0) {
        StepView(number: "1", title: "설정 앱 열기", subtitle: "일반 > 키보드로 이동", isLast: false)
        StepView(number: "2", title: "키보드 추가", subtitle: "새로운 키보드 추가 선택", isLast: false)
        StepView(number: "3", title: "Custom Keyboard 선택", subtitle: "키보드 목록에 추가", isLast: false)
        StepView(
          number: "4", title: "전체 접근 허용", subtitle: "테마·높이·햅틱 설정 공유에 사용", isLast: true)
      }

      Button {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
      } label: {
        Label("아이폰 설정으로 이동", systemImage: "gearshape.fill")
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.white)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color(uiColor: palette.activeKeyBackground))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(.white.opacity(0.22), lineWidth: 1)
          )
      )

      Label(
        "전체 접근은 앱과 키보드 사이의 설정 공유에만 사용하며, 입력 내용은 수집하거나 전송하지 않아요.",
        systemImage: "lock.shield.fill"
      )
      .font(.system(size: 12))
      .foregroundStyle(.white.opacity(0.48))
    }
    .padding(22)
    .background(GlassCard(cornerRadius: 24))
  }

  private var customAccentBinding: Binding<Color> {
    Binding(
      get: { Color(uiColor: settings.customAccent.uiColor) },
      set: { color in
        updateSettings {
          $0.customAccent = KeyboardRGBA(color: UIColor(color))
          $0.theme = .custom
        }
      }
    )
  }

  private var hapticsBinding: Binding<Bool> {
    Binding(
      get: { settings.hapticsEnabled },
      set: { enabled in
        updateSettings { $0.hapticsEnabled = enabled }
        if enabled {
          let generator = UIImpactFeedbackGenerator(style: .soft)
          generator.prepare()
          generator.impactOccurred(intensity: 0.52)
        }
      }
    )
  }

  private func settingsBinding<Value>(
    for keyPath: WritableKeyPath<KeyboardSettings, Value>
  ) -> Binding<Value> {
    Binding(
      get: { settings[keyPath: keyPath] },
      set: { value in updateSettings { $0[keyPath: keyPath] = value } }
    )
  }

  private func updateSettings(_ mutation: (inout KeyboardSettings) -> Void) {
    var updated = settings
    mutation(&updated)
    settings = updated
    saveFailed = !KeyboardPreferencesStore.save(updated)
  }

  private func sectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.system(size: 20, weight: .bold, design: .rounded))
      Text(subtitle)
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.48))
    }
  }

  private func settingLabel(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold, design: .rounded))
      .foregroundStyle(.white.opacity(0.68))
  }

  private func settingRowBackground(isActive: Bool) -> some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(isActive ? Color(uiColor: palette.accent).opacity(0.17) : .white.opacity(0.045))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            isActive ? Color(uiColor: palette.accent).opacity(0.52) : .white.opacity(0.09),
            lineWidth: 1
          )
      )
  }
}

private struct HeaderView: View {
  let accent: UIColor

  var body: some View {
    VStack(spacing: 14) {
      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color(uiColor: accent).opacity(0.38), lineWidth: 1)
        )
        .shadow(color: Color(uiColor: accent).opacity(0.16), radius: 18)

      VStack(spacing: 5) {
        Text("Custom Keyboard")
          .font(.system(size: 29, weight: .bold, design: .rounded))
        Text("나에게 맞춘 글래스 한글 키보드")
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.5))
      }
    }
  }
}

private struct ThemeSwatchButton: View {
  let preset: KeyboardThemePreset
  let isSelected: Bool
  let action: () -> Void

  private var palette: KeyboardThemePalette {
    KeyboardThemePalette.make(for: KeyboardSettings(theme: preset))
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 9) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color(uiColor: palette.keyBackground))
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .black.opacity(0.1)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
          )
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(Color(uiColor: palette.accent).opacity(isSelected ? 0.9 : 0.32), lineWidth: 1)
          )
          .frame(height: 38)

        Text(preset.title)
          .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
          .foregroundStyle(.white.opacity(isSelected ? 1 : 0.62))
      }
      .padding(9)
      .background(
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .fill(isSelected ? Color(uiColor: palette.accent).opacity(0.13) : .white.opacity(0.025))
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(preset.title) 테마")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct KeyboardPreview: View {
  let settings: KeyboardSettings

  private var palette: KeyboardThemePalette { KeyboardThemePalette.make(for: settings) }
  private var rowHeight: CGFloat { 28 * settings.height.rowScale }

  var body: some View {
    VStack(spacing: 4) {
      previewRow(["|◀", "◀", "▶", "▶|", "☺", "⌄"], special: true, height: 22)
      previewRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], height: rowHeight * 0.86)
      previewRow(["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"], height: rowHeight)
      previewRow(["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"], height: rowHeight)
      HStack(spacing: 4) {
        PreviewKey(label: "⇧", palette: palette, special: true)
          .frame(width: 42)
        previewRowContent(["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"])
        PreviewKey(label: "⌫", palette: palette, special: true)
          .frame(width: 42)
      }
      .frame(height: rowHeight)
      HStack(spacing: 4) {
        PreviewKey(label: "♥", palette: palette, special: true).frame(width: 42)
        PreviewKey(label: "ENG", palette: palette, special: true).frame(width: 48)
        PreviewKey(label: "", palette: palette, special: false)
        PreviewKey(label: ".", palette: palette, special: false).frame(width: 34)
        PreviewKey(label: "↵", palette: palette, special: true).frame(width: 42)
      }
      .frame(height: rowHeight * 0.9)
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 17, style: .continuous)
        .fill(Color(uiColor: palette.keyboardBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    )
    .shadow(color: .black.opacity(0.42), radius: 14, y: 8)
    .animation(.easeOut(duration: 0.18), value: settings)
    .accessibilityLabel("선택한 키보드 설정 미리보기")
  }

  private func previewRow(_ labels: [String], special: Bool = false, height: CGFloat) -> some View {
    previewRowContent(labels, special: special)
      .frame(height: height)
  }

  private func previewRowContent(
    _ labels: [String], special: Bool = false
  ) -> some View {
    HStack(spacing: 4) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        PreviewKey(label: label, palette: palette, special: special)
      }
    }
  }
}

private struct PreviewKey: View {
  let label: String
  let palette: KeyboardThemePalette
  let special: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: 7, style: .continuous)
      .fill(Color(uiColor: special ? palette.specialKeyBackground : palette.keyBackground))
      .overlay(
        LinearGradient(
          colors: [.white.opacity(0.19), .clear, .black.opacity(0.08)],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(.white.opacity(0.16), lineWidth: 0.6)
      )
      .overlay(
        Text(label)
          .font(.system(size: label.count > 1 ? 8 : 11, weight: .medium, design: .rounded))
          .foregroundStyle(Color(uiColor: special ? palette.specialKeyText : palette.keyText))
      )
  }
}

private struct StepView: View {
  let number: String
  let title: String
  let subtitle: String
  let isLast: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(spacing: 0) {
        Text(number)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(.black)
          .frame(width: 28, height: 28)
          .background(Circle().fill(.white))

        if !isLast {
          Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 38)
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 15, weight: .semibold, design: .rounded))
        Text(subtitle)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.44))
      }
      .padding(.top, 3)

      Spacer()
    }
  }
}

private struct GlassCard: View {
  let cornerRadius: CGFloat

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(.white.opacity(0.04))
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(.black.opacity(0.55))
          .blur(radius: 5)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.19), .clear, .white.opacity(0.07)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
  }
}

#Preview {
  ContentView()
}
