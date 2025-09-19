# SimpleFindParty

A World of Warcraft Classic 1.12 addon for filtering and managing party finding messages.

## English

### Overview
SimpleFindParty is an addon designed to help players efficiently find and manage party recruitment messages in WoW Classic. It filters messages from party finding channels, highlights keywords, and provides a clean interface for managing party-related communications.

### Features
- **Channel Message Filtering**: Automatically captures and filters messages from selected channels (default: "파티찾기" channel)
- **Keyword Filtering**: Set specific keywords to filter messages you're interested in
- **Ignore Keywords**: Exclude messages containing certain words even if they match your filters
- **Message Management**:
  - Automatically removes duplicate messages from the same user
  - Auto-cleanup of messages older than 60 seconds
  - Maximum 50 messages stored to prevent memory issues
- **User Interface**:
  - Minimap button for quick access
  - Draggable and resizable message window
  - Settings panel for configuration
  - Quick whisper feature - click on any message to whisper the sender
- **Sound Notifications**: Plays a notification sound when messages matching your filter keywords appear
- **User Blocking**: Block specific users from appearing in your message list

### Installation
1. Download the SimpleFindParty addon
2. Extract to your `World of Warcraft\_classic_\Interface\AddOns\` folder
3. Ensure the folder is named `SimpleFindParty`
4. Restart WoW or type `/reload` in game

### Usage
- **Minimap Button**:
  - Left-click: Open settings window
  - Right-click: Toggle message window
  - Drag: Move the minimap button position
- **Commands**:
  - `/sfp` or `/simplefindparty` - Show help
  - `/sfp show` - Show message window
  - `/sfp hide` - Hide message window
  - `/sfp settings` - Open settings window
  - `/sfp debug` - Show debug information
  - `/sfp reset` - Reset all settings to default

### Configuration
In the settings window, you can:
1. **Select Channel**: Choose which channel to monitor
2. **Filter Keywords**: Enter keywords separated by commas (e.g., "울다만, 성전, 격노")
3. **Ignore Keywords**: Enter words to exclude (e.g., "풀퀘, 일위상")
4. **Sound Toggle**: Enable/disable notification sounds
5. **Manage Blocked Users**: View and unblock users

### Message Window Features
- **Top Bar Icons**:
  - Bell icon: Toggle sound notifications
  - Gear icon: Open settings
  - X button: Close window
- **Message Display**:
  - Green nickname (max 8 Korean characters displayed)
  - Highlighted keywords in yellow
  - Click message to whisper
  - Delete button (-) to remove message
  - Block button (stop icon) to block user
- **Resize Handle**: Bottom-right corner for resizing

### Technical Details
- Compatible with WoW Classic 1.12
- Saves settings per character
- Supports Korean language
- Custom sound file support (place `ring.wav` in addon folder)

### Author
**우르사 (Ursa)** - Fox and Wolf Server (20th Anniversary Hardcore)

### License
This addon is free to use and modify for personal use.

---

## 한국어

### 개요
SimpleFindParty는 WoW 클래식에서 파티 모집 메시지를 효율적으로 찾고 관리할 수 있도록 도와주는 애드온입니다. 파티 찾기 채널의 메시지를 필터링하고, 키워드를 강조 표시하며, 파티 관련 커뮤니케이션을 관리할 수 있는 깔끔한 인터페이스를 제공합니다.

### 주요 기능
- **채널 메시지 필터링**: 선택한 채널의 메시지를 자동으로 캡처하고 필터링 (기본: "파티찾기" 채널)
- **키워드 필터링**: 관심 있는 메시지만 보기 위한 특정 키워드 설정
- **무시 키워드**: 필터와 일치하더라도 특정 단어가 포함된 메시지 제외
- **메시지 관리**:
  - 같은 사용자의 중복 메시지 자동 제거
  - 60초 이상 된 메시지 자동 정리
  - 메모리 문제 방지를 위해 최대 50개 메시지만 저장
- **사용자 인터페이스**:
  - 빠른 접근을 위한 미니맵 버튼
  - 드래그 및 크기 조절 가능한 메시지 창
  - 설정 패널
  - 빠른 귓속말 기능 - 메시지 클릭으로 발신자에게 귓속말
- **소리 알림**: 필터 키워드와 일치하는 메시지가 나타날 때 알림음 재생
- **사용자 차단**: 특정 사용자를 메시지 목록에서 차단

### 설치 방법
1. SimpleFindParty 애드온 다운로드
2. `World of Warcraft\_classic_\Interface\AddOns\` 폴더에 압축 해제
3. 폴더 이름이 `SimpleFindParty`인지 확인
4. WoW 재시작 또는 게임 내에서 `/reload` 입력

### 사용 방법
- **미니맵 버튼**:
  - 좌클릭: 설정창 열기
  - 우클릭: 메시지창 토글
  - 드래그: 미니맵 버튼 위치 이동
- **명령어**:
  - `/sfp` 또는 `/simplefindparty` - 도움말 표시
  - `/sfp show` - 메시지창 표시
  - `/sfp hide` - 메시지창 숨기기
  - `/sfp settings` - 설정창 열기
  - `/sfp debug` - 디버그 정보 표시
  - `/sfp reset` - 모든 설정 초기화

### 설정
설정창에서 다음을 구성할 수 있습니다:
1. **채널 선택**: 모니터링할 채널 선택
2. **필터링 키워드**: 쉼표로 구분된 키워드 입력 (예: "울다만, 성전, 격노")
3. **무시할 키워드**: 제외할 단어 입력 (예: "풀퀘, 일위상")
4. **알림 소리 켜기**: 알림음 활성화/비활성화
5. **차단된 사용자 목록**: 차단된 사용자 확인 및 해제

### 메시지창 기능
- **상단 아이콘**:
  - 종 아이콘: 알림음 토글
  - 톱니바퀴 아이콘: 설정창 열기
  - X 버튼: 창 닫기
- **메시지 표시**:
  - 녹색 닉네임 (한글 최대 8글자 표시)
  - 노란색으로 강조된 키워드
  - 메시지 클릭으로 귓속말
  - 삭제 버튼 (-) 메시지 제거
  - 차단 버튼 (정지 아이콘) 사용자 차단
- **크기 조절**: 우하단 모서리로 창 크기 조절

### 기술 사양
- WoW Classic 1.12 호환
- 캐릭터별 설정 저장
- 한국어 지원
- 커스텀 사운드 파일 지원 (애드온 폴더에 `ring.wav` 파일 배치)

### 제작자
**우르사 (Ursa)** - Fox and Wolf 서버 (20주년 기념 하드코어)

### 라이선스
이 애드온은 개인 사용을 위해 자유롭게 사용하고 수정할 수 있습니다.

---

## Version History / 버전 기록

### v1.0.0 (2025)
- Initial release / 최초 릴리즈
- Core filtering system / 핵심 필터링 시스템
- Message management / 메시지 관리
- Sound notifications / 소리 알림
- User interface / 사용자 인터페이스

## Support / 지원

For bugs or suggestions, please contact the author in-game.
버그나 제안사항은 게임 내에서 제작자에게 연락해주세요.

**Character / 캐릭터**: 우르사 (Ursa)
**Server / 서버**: Fox and Wolf (20th Anniversary Hardcore)
**Region / 지역**: Korea