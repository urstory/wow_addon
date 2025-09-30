# FoxChat 애드온 리팩토링 계획

## 현재 구조 분석

### 파일 현황
- **FoxChat.lua** (3,113줄): 메인 로직, 키워드 필터링, 미니맵 버튼, 광고/선입 버튼, 자동 기능들
- **FoxChat_Config_TabUI.lua** (3,221줄): 설정 UI 전체 (탭 시스템, 자동 탭의 메뉴 시스템)
- **FoxChatLogger.lua** (797줄): 채팅 로그 기능
- **FoxChatRollTracker.lua** (829줄): 주사위 집계 기능
- **FoxChat_Settings.lua** (175줄): 설정 저장/로드
- **FoxChat_Debug.lua** (139줄): 디버그 기능
- **Localization.lua** (183줄): 다국어 지원

### 주요 문제점
1. FoxChat.lua와 FoxChat_Config_TabUI.lua가 각각 3,000줄이 넘어 유지보수가 어려움
2. 기능별로 명확하게 분리되지 않아 코드 찾기가 힘듦
3. UI 코드와 비즈니스 로직이 혼재되어 있음

## 리팩토링 계획

### 1단계: 핵심 모듈 구조 설계

```
FoxChat/
├── FoxChat.toc (파일 로드 순서 정의)
├── Core/
│   ├── FoxChat_Core.lua (초기화, 이벤트 관리)
│   ├── FoxChat_Settings.lua (설정 저장/로드)
│   └── FoxChat_Localization.lua
├── Features/
│   ├── FoxChat_KeywordFilter.lua (키워드 필터링, 하이라이트)
│   ├── FoxChat_PrefixSuffix.lua (말머리/말꼬리)
│   ├── FoxChat_Advertisement.lua (광고 기능)
│   ├── FoxChat_FirstCome.lua (선입 기능)
│   ├── FoxChat_AutoTrade.lua (거래 자동 기능)
│   ├── FoxChat_AutoGreeting.lua (자동 인사)
│   ├── FoxChat_AutoReply.lua (자동 응답)
│   ├── FoxChat_RollTracker.lua (주사위 집계)
│   └── FoxChat_Logger.lua (채팅 로그)
├── UI/
│   ├── FoxChat_MinimapButton.lua (미니맵 버튼)
│   ├── FoxChat_Toast.lua (토스트 알림)
│   ├── FoxChat_AdButton.lua (광고 버튼 UI)
│   ├── FoxChat_FirstComeButton.lua (선입 버튼 UI)
│   └── Config/
│       ├── FoxChat_ConfigMain.lua (설정창 메인 프레임)
│       ├── FoxChat_ConfigTabSystem.lua (탭 시스템)
│       ├── Tabs/
│       │   ├── FoxChat_Tab_Basic.lua (기본 설정 탭)
│       │   ├── FoxChat_Tab_Highlight.lua (하이라이트 탭)
│       │   ├── FoxChat_Tab_Advertisement.lua (광고/선입 탭)
│       │   └── FoxChat_Tab_Auto.lua (자동 탭 - 메뉴 시스템)
│       └── AutoMenus/
│           ├── FoxChat_AutoMenu_Trade.lua (거래 메뉴)
│           ├── FoxChat_AutoMenu_Greet.lua (인사 메뉴)
│           ├── FoxChat_AutoMenu_Reply.lua (응답 메뉴)
│           ├── FoxChat_AutoMenu_Roll.lua (주사위 메뉴)
│           └── FoxChat_AutoMenu_ChatLog.lua (채팅로그 메뉴)
└── Utils/
    ├── FoxChat_UTF8.lua (UTF8 처리 유틸리티)
    ├── FoxChat_Debug.lua (디버그 유틸리티)
    └── FoxChat_Common.lua (공통 유틸리티)
```

### 2단계: 모듈 간 통신 구조

#### 네임스페이스 구조
```lua
-- 전역 네임스페이스
FoxChat = {
    Core = {},      -- 코어 모듈
    Features = {},  -- 기능 모듈
    UI = {},        -- UI 모듈
    Utils = {},     -- 유틸리티
    Events = {},    -- 이벤트 디스패처
    Config = {}     -- 설정 관련
}
```

#### 이벤트 시스템
```lua
-- 커스텀 이벤트로 모듈 간 통신
FoxChat.Events:Register("FOXCHAT_KEYWORD_MATCHED", handler)
FoxChat.Events:Trigger("FOXCHAT_KEYWORD_MATCHED", data)
```

### 3단계: 단계별 리팩토링 절차

#### Phase 1: 기본 구조 준비 (위험도: 낮음)
1. 새 디렉토리 구조 생성
2. FoxChat_Core.lua 생성 (초기화 코드만)
3. 네임스페이스 및 이벤트 시스템 구현
4. 기존 FoxChat.lua와 공존하도록 설정

#### Phase 2: 독립적 기능 분리 (위험도: 낮음)
1. UTF8 유틸리티 → FoxChat_UTF8.lua
2. 디버그 기능 → 이미 분리되어 있음
3. 토스트 알림 → FoxChat_Toast.lua
4. 미니맵 버튼 → FoxChat_MinimapButton.lua

#### Phase 3: 핵심 기능 분리 (위험도: 중간)
1. 키워드 필터링 로직 → FoxChat_KeywordFilter.lua
2. 말머리/말꼬리 기능 → FoxChat_PrefixSuffix.lua
3. 광고 기능 → FoxChat_Advertisement.lua
4. 선입 기능 → FoxChat_FirstCome.lua

#### Phase 4: 자동 기능 분리 (위험도: 중간)
1. 거래 자동 기능 → FoxChat_AutoTrade.lua
2. 자동 인사 → FoxChat_AutoGreeting.lua
3. 자동 응답 → FoxChat_AutoReply.lua

#### Phase 5: UI 분리 (위험도: 높음)
1. 설정창 메인 프레임 분리
2. 각 탭을 독립 파일로 분리
3. 자동 탭의 각 메뉴를 독립 파일로 분리
4. 공통 UI 컴포넌트 (TextArea, Separator 등) 분리

#### Phase 6: 최종 정리
1. 기존 FoxChat.lua 제거
2. FoxChat.toc 파일 업데이트
3. 모든 기능 테스트

### 4단계: 구현 시 주의사항

#### 의존성 관리
- 각 모듈은 FoxChat 네임스페이스를 통해서만 통신
- 순환 의존성 방지
- 로드 순서 명확히 정의 (toc 파일)

#### 설정 관리
- FoxChatDB는 FoxChat_Settings.lua에서만 직접 접근
- 다른 모듈은 API를 통해 설정 읽기/쓰기

#### 이벤트 처리
- WoW 이벤트는 Core 모듈에서 받아서 커스텀 이벤트로 배포
- 각 기능 모듈은 필요한 이벤트만 구독

### 5단계: 테스트 계획

#### 단위 테스트
- 각 모듈 분리 후 개별 기능 테스트
- 키워드 필터링, 자동 기능 등 핵심 기능 우선

#### 통합 테스트
- 모듈 간 통신 테스트
- 설정 저장/로드 테스트
- UI 상호작용 테스트

#### 회귀 테스트
- 기존 기능 모두 정상 작동 확인
- 성능 저하 없는지 확인

### 예상 효과

1. **유지보수성 향상**
   - 기능별로 파일이 분리되어 찾기 쉬움
   - 각 파일이 500줄 이하로 관리 가능

2. **확장성 향상**
   - 새 기능 추가 시 독립된 모듈로 개발 가능
   - 기존 코드 영향 최소화

3. **테스트 용이성**
   - 모듈별 독립적 테스트 가능
   - 버그 발생 시 영향 범위 축소

4. **협업 개선**
   - 여러 개발자가 동시에 다른 모듈 작업 가능
   - 코드 충돌 최소화

### 리스크 및 대응 방안

1. **기능 누락 위험**
   - 대응: 체크리스트 작성, 철저한 테스트

2. **성능 저하 위험**
   - 대응: 프로파일링, 필요시 최적화

3. **하위 호환성 문제**
   - 대응: 설정 마이그레이션 코드 작성

### 구현 우선순위

1. **즉시 시작 가능** (Phase 1-2)
   - 기본 구조 생성
   - 유틸리티 분리

2. **단계적 진행** (Phase 3-4)
   - 독립적 기능부터 분리
   - 의존성 낮은 순서로 진행

3. **신중한 접근** (Phase 5)
   - UI는 가장 복잡하므로 마지막에
   - 충분한 테스트 후 진행

### 예상 소요 시간

- Phase 1-2: 2-3시간
- Phase 3-4: 4-5시간
- Phase 5: 5-6시간
- Phase 6 및 테스트: 3-4시간

**총 예상 시간: 14-18시간**

## 결론

FoxChat 애드온은 현재 구조적으로 리팩토링이 필요한 상태입니다. 제안된 모듈화 구조를 통해:

1. 3,000줄이 넘는 거대한 파일들을 500줄 이하의 관리 가능한 모듈로 분리
2. 기능별 명확한 책임 분리로 유지보수성 대폭 향상
3. 향후 기능 추가 및 수정이 용이한 확장 가능한 구조 확보

단계별 접근을 통해 리스크를 최소화하면서 안정적으로 리팩토링을 진행할 수 있습니다.