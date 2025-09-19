# FoxChat Update Log

## 2025-09-19 Update

### Developer
**Ursa** - 20th Anniversary Hardcore Server, Fox and Wolf Guild

---

## 🇺🇸 English

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

## 🇰🇷 한국어

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