# FoxChat Update Log

## 2025-09-23 Update - Version 2.1

### Developer
**우르사 (Ursa)** - 20th Anniversary Hardcore Classic Server, Fox and Wolf Guild

---

## 🇺🇸 English

### Major Changes

#### 🎯 **Advanced Filtering Improvements**
- **Own Message Exclusion**: Your own messages are never filtered, even if they contain your filtering keywords
- **Prefix/Suffix Exclusion**: Text set as prefix/suffix is excluded from filtering checks
- **Smart Filtering**: The system now removes prefix/suffix text before checking for keywords

#### 🚀 **Party Recruitment System Enhancements**
- **First Come Message Feature**: Quick party/raid announcement system
  - Automatic channel detection (Party/Raid/Raid Warning)
  - Separate cooldown timer (5 seconds)
  - Right-click to disable feature
- **Party Size Management**:
  - Configurable party size (2-40 players)
  - Automatic "(current/max)" counter in advertisements
  - Optional auto-stop when target size reached
  - Checkbox to control auto-stop behavior
- **Improved Button Management**:
  - Real-time synchronization between buttons and settings
  - Right-click to stop advertising
  - Tooltip support for all buttons

### Bug Fixes
- Fixed GROUP_ROSTER_UPDATE event not triggering
- Fixed auto-stop feature not working for 5-person parties
- Fixed configuration sync issues between buttons and settings panel
- Fixed spam restrictions with proper minimum 30-second cooldown
- Fixed tab UI not loading properly with old config files

---

## 🇰🇷 한국어

### 주요 변경사항

#### 🎯 **고급 필터링 개선**
- **본인 메시지 제외**: 필터링 키워드가 포함되어 있어도 본인이 쓴 메시지는 필터링되지 않음
- **말머리/말꼬리 제외**: 말머리/말꼬리로 설정한 텍스트는 필터링 검사에서 제외
- **스마트 필터링**: 키워드 확인 전에 말머리/말꼬리 텍스트를 먼저 제거하고 검사

#### 🚀 **파티 모집 시스템 개선**
- **선입 메시지 기능**: 빠른 파티/공격대 알림 시스템
  - 자동 채널 감지 (파티/공격대/공격대 경보)
  - 별도 쿨다운 타이머 (5초)
  - 우클릭으로 기능 비활성화
- **파티 인원 관리**:
  - 설정 가능한 파티 인원수 (2-40명)
  - 광고에 자동 "(현재/최대)" 카운터 추가
  - 목표 인원 도달 시 선택적 자동 중지
  - 자동 중지 동작을 제어하는 체크박스
- **개선된 버튼 관리**:
  - 버튼과 설정 간 실시간 동기화
  - 우클릭으로 광고 중지
  - 모든 버튼에 툴팁 지원

### 버그 수정
- GROUP_ROSTER_UPDATE 이벤트가 트리거되지 않는 문제 수정
- 5인 파티에서 자동 중지 기능이 작동하지 않는 문제 수정
- 버튼과 설정 패널 간 동기화 문제 수정
- 최소 30초 쿨다운으로 스팸 제한 문제 수정
- 이전 설정 파일로 인한 탭 UI 로딩 문제 수정

---

## 2025-09-22 Update - Version 2.0

### 🇺🇸 English

### Major Changes

#### 🎨 **New Tab-Based UI System**
- Completely redesigned settings interface with 3 organized tabs
- Modern, clean layout replacing the old single-page scroll design
- Reduced window height from 920px to 500px for better usability

#### 📑 **Tab Organization**
1. **Chat Filtering Tab**
   - All keyword and highlighting settings
   - Channel-specific colors and monitoring
   - Toast notification positioning

2. **Prefix/Suffix Tab**
   - Message prefix and suffix configuration
   - Channel selection for custom text
   - Cleaner, more focused interface

3. **Advertisement Tab**
   - Semi-automated recruitment system (EULA compliant)
   - Manual click button with configurable cooldown
   - Channel selection dropdown
   - Real-time coordinate display during drag

### New Features

#### 🔔 **Advertisement System**
- **Channel Selection**: Choose target channel from dropdown menu
- **Configurable Cooldown**: Select between 15/30/45/60 seconds
- **Smart Cooldown Reset**: Cooldown resets when stopping ads
- **Message Validation**: Empty or whitespace-only messages disable the start button
- **Drag Feedback**: X/Y coordinates update in real-time while dragging
- **Exclusions**: Advertisement messages exclude prefix/suffix automatically
- **Default Position**: X: 350, Y: -150 (right side of screen)

### Bug Fixes
- Fixed `.toc` file to load correct configuration module
- Resolved type mismatch errors between strings and tables for keywords
- Fixed coordinate calculation for center-based (0,0) positioning
- Corrected advertisement button visibility at default position
- Fixed highlight style checkbox display issues
- Removed duplicate "FoxChat" in window title
- Fixed cooldown not resetting when stopping advertisements

---

## 🇰🇷 한국어

### 주요 변경사항

#### 🎨 **새로운 탭 기반 UI 시스템**
- 3개의 정리된 탭으로 완전히 재설계된 설정 인터페이스
- 기존 단일 페이지 스크롤 디자인을 대체하는 현대적이고 깔끔한 레이아웃
- 더 나은 사용성을 위해 창 높이를 920px에서 500px로 축소

#### 📑 **탭 구성**
1. **채팅 필터링 탭**
   - 모든 키워드 및 강조 표시 설정
   - 채널별 색상 및 모니터링
   - 토스트 알림 위치 설정

2. **말머리/말꼬리 탭**
   - 메시지 말머리 및 말꼬리 구성
   - 사용자 정의 텍스트용 채널 선택
   - 더 깔끔하고 집중된 인터페이스

3. **광고 설정 탭**
   - 반자동 모집 시스템 (EULA 준수)
   - 설정 가능한 쿨타임이 있는 수동 클릭 버튼
   - 채널 선택 드롭다운
   - 드래그 중 실시간 좌표 표시

### 새로운 기능

#### 🔔 **광고 시스템**
- **채널 선택**: 드롭다운 메뉴에서 대상 채널 선택
- **설정 가능한 쿨타임**: 15/30/45/60초 중 선택
- **스마트 쿨타임 리셋**: 광고 중지 시 쿨타임 초기화
- **메시지 유효성 검사**: 빈 메시지나 공백만 있는 경우 시작 버튼 비활성화
- **드래그 피드백**: 드래그하는 동안 X/Y 좌표가 실시간으로 업데이트
- **제외 사항**: 광고 메시지는 자동으로 말머리/말꼬리 제외
- **기본 위치**: X: 350, Y: -150 (화면 오른쪽)

### 버그 수정
- 올바른 구성 모듈을 로드하도록 `.toc` 파일 수정
- 키워드의 문자열과 테이블 간 타입 불일치 오류 해결
- 중앙 기준(0,0) 위치 지정을 위한 좌표 계산 수정
- 기본 위치에서 광고 버튼 표시 문제 수정
- 강조 스타일 체크박스 표시 문제 수정
- 창 제목에서 중복된 "FoxChat" 제거
- 광고 중지 시 쿨타임이 재설정되지 않는 문제 수정

---

## 2025-09-19 Update

### 🇺🇸 English

### New Features

#### 1. **Channel-Based Highlight Colors**
- Different highlight colors for each channel group
- Guild: Green
- Public (Say/Yell/General): Yellow
- Party/Raid: Blue
- LookingForGroup: Orange
- Compact UI with checkbox and color picker on single line

#### 2. **Toast Notifications**
- Android-style toast notifications at bottom of screen
- Shows author name and message for 3 seconds
- Background color matches channel group color
- Auto-adjusts height for multi-line messages
- Queue system for multiple messages

#### 3. **Ignore Keywords**
- Add keywords to ignore/exclude from filtering
- Example: If filter keyword is "Azshara" and ignore keyword is "party", message "Azshara party LFM" won't be filtered
- Side-by-side input boxes for filter and ignore keywords

#### 4. **Enhanced Toast Features**
- **Anti-spam**: Same author messages blocked for 10 seconds
- **Click to Whisper**: Click toast to open whisper to message author
- **Visual Feedback**: Cursor changes and tooltip shows on hover

#### 5. **Sound Improvements**
- Changed notification sound to ring.wav for better audibility
- Sound plays when keywords are detected in monitored channels

### Bug Fixes
- Fixed ColorPicker swatchFunc nil error in WoW Classic
- Fixed SetBackdrop error by adding BackdropTemplate
- Fixed ShowToast scope issue for animation callbacks
- Server names removed from player names in toasts

---

### 🇰🇷 한국어

### 새로운 기능

#### 1. **채널별 강조 색상**
- 채널 그룹별로 다른 강조색 설정 가능
- 길드: 초록색
- 공개 (일반/외치기/공개채널): 노란색
- 파티/공격대: 파란색
- 파티찾기: 주황색
- 체크박스와 색상 선택기가 한 줄로 정리된 깔끔한 UI

#### 2. **토스트 알림**
- 화면 하단에 안드로이드 스타일 토스트 알림 표시
- 작성자 이름과 메시지를 3초간 표시
- 채널 그룹에 맞는 배경색 적용
- 여러 줄 메시지에 맞춰 높이 자동 조절
- 여러 메시지를 위한 큐 시스템

#### 3. **무시할 문구**
- 필터링에서 제외할 키워드 추가 가능
- 예시: 필터링 문구에 "아즈샤라"가 있고 무시할 문구에 "파티"가 있으면, "아즈샤라 파티 구해요" 메시지는 필터링되지 않음
- 필터링 문구와 무시할 문구를 나란히 배치한 입력창

#### 4. **토스트 추가 기능**
- **도배 방지**: 같은 작성자의 메시지는 10초간 차단
- **클릭으로 귓속말**: 토스트 클릭 시 해당 작성자에게 귓속말 전송 창 열기
- **시각적 피드백**: 마우스 오버 시 커서 변경 및 툴팁 표시

#### 5. **소리 개선**
- 알림음을 ring.wav로 변경하여 더 잘 들리도록 개선
- 모니터링 중인 채널에서 키워드 감지 시 소리 재생

### 버그 수정
- WoW Classic에서 ColorPicker swatchFunc nil 오류 수정
- BackdropTemplate 추가로 SetBackdrop 오류 해결
- 애니메이션 콜백을 위한 ShowToast 스코프 문제 수정
- 토스트에서 플레이어 이름의 서버명 제거

---

### Installation / 설치
Place the FoxChat folder in your World of Warcraft AddOns directory:
`World of Warcraft\_classic_\Interface\AddOns\`

FoxChat 폴더를 월드 오브 워크래프트 애드온 디렉토리에 넣으세요:
`World of Warcraft\_classic_\Interface\AddOns\`

### Usage / 사용법
- `/fc` or `/foxchat` - Open settings / 설정 창 열기
- Click minimap button / 미니맵 버튼 클릭

---

*Thank you for using FoxChat!*
*FoxChat를 사용해 주셔서 감사합니다!*