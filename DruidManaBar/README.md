# DruidManaBar

A World of Warcraft Classic addon that displays mana bar for druids in shapeshift forms.

## Features

- **Mana Bar Display**: Shows your current mana while in Bear, Cat, or other shapeshift forms
- **Health Bar**: Optional health bar display with customizable size
- **Smart Visibility**: Choose when to show the bars (always, only in forms, or only in combat)
- **Form-specific Settings**: Enable/disable display for each shapeshift form individually
- **Shapeshift Lines**: Visual indicators showing mana cost requirements for Bear and Cat forms
- **Auto-detection**: Automatically detects mana costs for your shapeshift spells
- **Customizable**: Adjust bar size, position, and display format (numbers/percentage/both)
- **Low Health Warning**: Flashing alert when health drops below threshold
- **Buff Monitor**: Shows missing important buffs (Mark of the Wild, Omen of Clarity, Thorns)
- **Combo Points Display**: Visual combo points (red circles) display in Cat Form

## Commands

- `/dmb` or `/druidmanabar` - Open settings window
- `/dmb test` - Enter test mode (allows repositioning with Shift+drag)
- `/dmb debug` - Display shapeshift spell detection information
- `/dmb checkbuff` - Debug buff detection system

## Installation

1. Download the addon
2. Extract to `World of Warcraft\_classic_\Interface\AddOns\`
3. Restart WoW or type `/reload`

## Configuration

Access the settings window with `/dmb` to customize:

- Bar width and height
- Mana and health display format
- Visibility options per form
- Health flash threshold
- Manual mana cost override (if auto-detection fails)

## Supported Forms

- Bear Form / Dire Bear Form
- Cat Form
- Aquatic Form
- Travel Form
- Moonkin Form

## Language Support

- English
- Korean (한국어)

---

# DruidManaBar (한국어)

월드 오브 워크래프트 클래식용 애드온으로, 드루이드가 변신 상태에서도 마나 바를 표시합니다.

## 기능

- **마나 바 표시**: 곰, 표범 등 변신 폼에서 현재 마나 표시
- **체력 바**: 크기 조절 가능한 체력 바 옵션
- **스마트 표시**: 바 표시 시점 선택 (항상, 변신 중에만, 전투 중에만)
- **폼별 설정**: 각 변신 폼마다 표시 여부 개별 설정
- **변신 선**: 곰과 표범 변신에 필요한 마나 비용을 시각적으로 표시
- **자동 감지**: 변신 스펠의 마나 비용을 자동으로 감지
- **커스터마이징**: 바 크기, 위치, 표시 형식(숫자/퍼센트/모두) 조절 가능
- **체력 경고**: 체력이 임계값 아래로 떨어지면 깜빡임 경고
- **버프 모니터**: 누락된 중요 버프 표시 (야생의 징표, 천명의 전조, 가시)
- **콤보 포인트 표시**: 표범 폼에서 시각적 콤보 포인트(붉은색 원) 표시

## 명령어

- `/dmb` 또는 `/druidmanabar` - 설정창 열기
- `/dmb test` - 테스트 모드 (Shift+드래그로 위치 조정 가능)
- `/dmb debug` - 변신 스펠 감지 정보 표시
- `/dmb checkbuff` - 버프 감지 시스템 디버그

## 설치 방법

1. 애드온 다운로드
2. `World of Warcraft\_classic_\Interface\AddOns\` 폴더에 압축 해제
3. WoW 재시작 또는 `/reload` 입력

## 설정

`/dmb` 명령어로 설정창을 열어 다음 항목들을 커스터마이징할 수 있습니다:

- 바 너비와 높이
- 마나와 체력 표시 형식
- 폼별 표시 옵션
- 체력 깜빡임 임계값
- 수동 마나 비용 설정 (자동 감지 실패 시)

## 지원되는 변신 폼

- 곰 변신 / 광포한 곰 변신
- 표범 변신
- 바다표범 변신
- 여행/치타 변신
- 달빛야수 변신

## 언어 지원

- 영어
- 한국어

## 문제 해결

### 마나 비용이 잘못 표시되는 경우
1. `/dmb` 명령어로 설정창 열기
2. "새로고침" 버튼 클릭하여 자동 감지 재시도
3. 자동 감지가 실패하면 수동으로 마나 비용 입력

### 바가 표시되지 않는 경우
1. 설정창에서 "DruidManaBar 활성화" 체크 확인
2. 표시 모드와 폼별 설정 확인
3. `/reload` 명령어로 UI 재시작

## 버전 히스토리

### v1.0
- 초기 릴리즈
- 기본 마나/체력 바 기능
- 변신 마나 비용 자동 감지
- 한국어/영어 지원

## 크레딧

제작: DruidManaBar Team  
World of Warcraft Classic 드루이드 플레이어를 위해 제작되었습니다.

## 라이선스

이 애드온은 무료 소프트웨어입니다. 자유롭게 사용하고 수정할 수 있습니다.