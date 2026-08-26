# Custom Keyboard

iOS 17 이상에서 동작하는 한글/영문 커스텀 키보드 앱과 키보드 확장 프로젝트다.

## 구조

- `keyboard/`: 테마, 높이, 햅틱 설정을 제공하는 SwiftUI 컨테이닝 앱
- `custom-keyboard/`: 실제 입력을 처리하는 `UIInputViewController` 확장
- `Shared/`: 앱과 확장이 함께 사용하는 설정, 입력 상태, 한글 조합, 문서 명령 모델
- `keyboardTests/`: 한글 조합, 설정 migration, 입력 상태, 문서 명령 테스트

설정은 App Group `group.nijoow.custom.keyboard`의 `UserDefaults`로 공유한다. 입력 내용과
문서 컨텍스트는 저장하거나 네트워크로 전송하지 않는다. 전체 접근이 없으면 키보드는 기본
테마·높이·햅틱 비활성 상태로 계속 동작한다.

## 로컬 검증

```sh
xcodebuild test \
  -project keyboard.xcodeproj \
  -scheme keyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild build \
  -project keyboard.xcodeproj \
  -scheme keyboard \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

빌드 성공만으로 실제 키 입력을 보증할 수는 없다. 출시 전에는 물리 기기에서 빠른 두 손가락
입력, 가장자리 터치, 스페이스 커서 이동, 연속 삭제, VoiceOver, 회전과 iPad 분할 화면을 확인한다.
