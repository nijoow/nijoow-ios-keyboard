# Custom Keyboard

iOS 17 이상을 지원하는 한글·영문 커스텀 키보드입니다. SwiftUI로 설정 앱을, UIKit으로 키보드 익스텐션을 구현했습니다.

## 주요 기능

- 한글 조합 및 영문 입력
- 테마, 키보드 높이, 햅틱 세기 설정
- 숫자, 소수, 전화번호 입력창에 맞춘 전용 키패드
- 숫자 패드의 `#+=`, `123` 버튼으로 기호와 숫자 전환
- 스페이스바 커서 이동 및 연속 삭제

## 사용 안내

- 설정 앱에서 키보드를 추가하고 원하는 테마와 높이를 선택합니다.
- App Group의 `UserDefaults`로 앱과 키보드 익스텐션 간 설정을 공유합니다.
- 입력 내용은 저장하거나 네트워크로 전송하지 않으며, 전체 접근 권한 없이 기본 설정으로 사용할 수 있습니다.

## 구조

- `keyboard/`: SwiftUI 설정 앱
- `custom-keyboard/`: `UIInputViewController` 키보드 확장
- `Shared/`: 설정, 입력 상태, 한글 조합, 문서 명령
- `keyboardTests/`: 한글 조합, 설정 마이그레이션, UIKit 컨트롤러 테스트

## 테스트와 빌드

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
