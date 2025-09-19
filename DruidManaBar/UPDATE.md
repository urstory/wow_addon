# DruidManaBar Update Log

## Version 1.2.0 (2025-09-17)

### New Features

#### 🛡️ Buff Monitor
- **Missing Buff Indicators**: Displays icons when important buffs are missing
  - Mark of the Wild / Gift of the Wild
  - Omen of Clarity
  - Thorns
- **Smart Detection**: Only shows icons for spells you have learned
- **Configuration**: Can be toggled on/off in settings

#### 🎯 Combo Points Display
- **Visual Bubbles**: Shows combo points as red circles above health bar
- **Cat Form Only**: Automatically appears when in Cat Form with a target
- **Real-time Updates**: Updates instantly when combo points change
- **Hide on Zero**: No display when you have no combo points

### Commands
- **New Debug Command**: `/dmb checkbuff` - Debug buff detection system

### Bug Fixes
- Fixed buff detection for Omen of Clarity
- Improved frame layering to prevent UI elements from being hidden
- Fixed vararg function errors in event handlers

---

## 버전 1.2.0 (2025-09-17)

### 새로운 기능

#### 🛡️ 버프 모니터
- **누락된 버프 표시**: 중요한 버프가 없을 때 아이콘 표시
  - 야생의 징표 / 야생의 선물
  - 천명의 전조
  - 가시
- **스마트 감지**: 배운 주문만 아이콘으로 표시
- **설정 가능**: 설정에서 켜기/끄기 가능

#### 🎯 콤보 포인트 표시
- **시각적 버블**: 체력바 위에 붉은색 원으로 콤보 포인트 표시
- **표범 폼 전용**: 표범 폼에서 타겟이 있을 때 자동으로 표시
- **실시간 업데이트**: 콤보 포인트 변경 시 즉시 업데이트
- **0일 때 숨김**: 콤보 포인트가 없으면 표시하지 않음

### 명령어
- **새 디버그 명령어**: `/dmb checkbuff` - 버프 감지 시스템 디버그

### 버그 수정
- 천명의 전조 버프 감지 수정
- UI 요소가 가려지지 않도록 프레임 레이어링 개선
- 이벤트 핸들러의 vararg 함수 오류 수정

---

## Installation / 설치

### English
1. Delete old DruidManaBar folder if exists
2. Extract new version to `Interface\AddOns\`
3. Reload UI with `/reload`

### 한국어
1. 기존 DruidManaBar 폴더가 있다면 삭제
2. 새 버전을 `Interface\AddOns\`에 압축 해제
3. `/reload`로 UI 새로고침

## Known Issues / 알려진 문제
- Buff icons do not blink (by design - removed for better user experience)
- 버프 아이콘이 깜빡이지 않음 (더 나은 사용자 경험을 위해 의도적으로 제거)

## Contact / 문의
Report bugs or suggestions on the addon page
애드온 페이지에서 버그나 제안사항을 보고해주세요