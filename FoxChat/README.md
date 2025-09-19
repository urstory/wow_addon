# FoxChat

A World of Warcraft Classic addon for chat message filtering and highlighting with keyword detection.

## Features

- **Keyword Highlighting**: Automatically highlights messages containing your specified keywords
- **Chat Filtering**: Filter messages to show only those containing your keywords
- **Sound Alerts**: Play sound notifications when keywords are detected
- **Toast Notifications**: Visual popup alerts for keyword matches with customizable position
- **Prefix/Suffix**: Automatically add custom text before and after your messages
- **Minimap Button**: Quick access to toggle filtering and open settings
- **Multi-Channel Support**: Monitor multiple chat channels simultaneously
- **Localization**: Full support for English and Korean

## Installation

1. Download the FoxChat folder
2. Place it in your WoW Classic addons directory:
   - Windows: `World of Warcraft\_classic_\Interface\AddOns\`
   - Mac: `World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW or type `/reload` in chat

## Usage

### Commands

- `/fc` or `/foxchat` - Open settings window
- `/fc toggle` - Enable/disable the addon
- `/fc add <keyword>` - Add a keyword
- `/fc remove <keyword>` - Remove a keyword
- `/fc list` - Show current keywords

### Minimap Button

- **Left Click**: Toggle chat filtering on/off
- **Right Click**: Open settings window
- **Drag**: Move button around minimap

### Settings

The settings window allows you to:
- Configure keywords (comma-separated)
- Select which channels to monitor
- Choose highlight style (bold, color, or both)
- Set highlight color
- Enable/disable sound alerts
- Configure message prefix/suffix
- Show/hide minimap button
- Adjust toast notification position (X, Y coordinates)
  - (0, 0) is screen center
  - Default: (0, -320) - bottom center
  - Maximum 3 toasts displayed simultaneously

## Configuration Options

### Chat Channels
- Say, Yell, Party, Guild, Raid
- Instance, Whisper
- General, Trade, LookingForGroup

### Highlight Styles
- **Bold**: Makes keywords appear in bold white
- **Color Only**: Highlights keywords in your chosen color
- **Bold + Color**: Combines both effects

### Prefix/Suffix
Automatically adds custom text to your messages in selected channels. Useful for guild tags or roleplay.

---

# FoxChat (한국어)

월드 오브 워크래프트 클래식용 채팅 메시지 필터링 및 키워드 강조 애드온입니다.

## 기능

- **키워드 강조**: 지정한 키워드가 포함된 메시지를 자동으로 강조 표시
- **채팅 필터링**: 키워드가 포함된 메시지만 표시하도록 필터링
- **소리 알림**: 키워드 감지 시 소리 알림 재생
- **토스트 알림**: 키워드 매칭 시 위치 조정 가능한 시각적 팝업 알림
- **말머리/말꼬리**: 메시지 앞뒤에 자동으로 텍스트 추가
- **미니맵 버튼**: 필터 전환 및 설정창 열기 빠른 접근
- **다중 채널 지원**: 여러 채팅 채널 동시 모니터링
- **현지화**: 영어 및 한국어 완벽 지원

## 설치 방법

1. FoxChat 폴더를 다운로드합니다
2. WoW 클래식 애드온 디렉토리에 넣습니다:
   - Windows: `World of Warcraft\_classic_\Interface\AddOns\`
   - Mac: `World of Warcraft/_classic_/Interface/AddOns/`
3. WoW를 재시작하거나 채팅창에 `/reload` 입력

## 사용법

### 명령어

- `/fc` 또는 `/foxchat` - 설정창 열기
- `/fc toggle` - 애드온 켜기/끄기
- `/fc add <키워드>` - 키워드 추가
- `/fc remove <키워드>` - 키워드 제거
- `/fc list` - 현재 키워드 목록 표시

### 미니맵 버튼

- **왼쪽 클릭**: 채팅 필터링 켜기/끄기
- **오른쪽 클릭**: 설정창 열기
- **드래그**: 미니맵 주위로 버튼 이동

### 설정

설정창에서 다음을 구성할 수 있습니다:
- 키워드 설정 (쉼표로 구분)
- 모니터링할 채널 선택
- 강조 스타일 선택 (굵게, 색상, 또는 둘 다)
- 강조 색상 설정
- 소리 알림 켜기/끄기
- 메시지 말머리/말꼬리 설정
- 미니맵 버튼 표시/숨기기
- 토스트 알림 위치 조정 (X, Y 좌표)
  - (0, 0)이 화면 정중앙
  - 기본값: (0, -320) - 화면 하단 중앙
  - 최대 3개의 토스트 동시 표시

## 설정 옵션

### 채팅 채널
- 일반 대화, 외치기, 파티, 길드, 공격대
- 인스턴스, 귓속말
- 공개, 거래, 파티찾기

### 강조 스타일
- **굵게**: 키워드를 굵은 흰색으로 표시
- **색상만**: 선택한 색상으로 키워드 강조
- **굵게 + 색상**: 두 효과를 결합

### 말머리/말꼬리
선택한 채널에서 메시지에 자동으로 텍스트를 추가합니다. 길드 태그나 롤플레이에 유용합니다.

## 특징

- 플레이어 이름은 필터링하지 않고 메시지 내용만 필터링
- 위상 메시지(일위상, 이위상, 삼위상)는 말머리/말꼬리 제외
- 설정은 캐릭터별로 저장됨

## 문제 해결

- 애드온이 작동하지 않는 경우: `/reload` 명령어 실행
- 미니맵 버튼이 보이지 않는 경우: 설정창에서 "미니맵 버튼 표시" 확인
- 키워드가 작동하지 않는 경우: 키워드가 쉼표로 올바르게 구분되었는지 확인

## 버전

- 현재 버전: 1.1
- WoW 클래식 호환
- 최신 업데이트: 토스트 위치 설정 기능 추가

## 라이선스

이 애드온은 자유롭게 사용 및 수정할 수 있습니다.