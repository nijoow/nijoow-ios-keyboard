# Custom Keyboard

iOS 17 이상에서 동작하는 한글/영문 커스텀 키보드 앱과 키보드 확장 프로젝트다.

## 구조

- `keyboard/`: 테마, 높이, 햅틱 설정을 제공하는 SwiftUI 컨테이닝 앱
- `custom-keyboard/`: 실제 입력을 처리하는 `UIInputViewController` 확장
- `Shared/`: 앱과 확장이 함께 사용하는 설정, 입력 상태, 한글 조합, 문서 명령 모델
- `keyboardTests/`: 한글 조합, 설정 migration 및 실제 UIKit 컨트롤러 테스트

설정은 App Group `group.nijoow.custom.keyboard.v2`의 `UserDefaults`로 공유한다. 입력 내용과
문서 컨텍스트는 저장하거나 네트워크로 전송하지 않는다. 전체 접근이 없으면 키보드는 기본
테마·높이·햅틱 비활성 상태로 계속 동작한다.

## 입력 및 복귀 정책

- 한글은 기존 prefix-diff 방식으로 조합 문자열의 바뀐 꼬리만 삭제·삽입한다.
  연속 입력에서 이전 글자를 덮어쓰던 marked-text 변경은 철회했다.
- 문서 식별자가 바뀌면 이전 조합과 반복 입력을 새 입력창에 적용하지 않는다.
  초기화 중 식별자가 없는 경우도 허용하며, 입력 내용은 로그에 기록하지 않는다.
- 숫자/ASCII 숫자 입력창은 전용 숫자 패드, 소수 입력창은 지역 설정의 소수 구분자를 표시한다.
  전화번호 입력창에서 확장이 허용되면 전화번호 패드를 사용한다. iOS가 시스템 키보드를
  강제하는 입력창에서는 확장의 레이아웃을 표시할 수 없다.
- 숫자 패드의 `#+=` 버튼으로 `* # + - / . ( ) ,` 기호를 입력하고 `123`으로 돌아온다.
  전환 시 키 버튼을 재사용하며, 다른 입력창으로 이동하면 숫자 모드로 초기화한다.
- 앱 전환 때 기본 키 UI를 재사용하고 이모지와 타이머를 정리한다. 숨겨진 상태의 메모리
  경고에서는 UI도 해제하되 active/appear 시 복구한다. OS의 프로세스 종료 자체는 막지 않는다.
- 호스트의 임시 높이가 커져도 실제 키 영역은 설정 높이를 넘지 않고 하단에 정렬된다.

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
