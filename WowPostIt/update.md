# WowPostIt Update Log

## Version 1.1 - 에디터 개선 및 TextArea 구현

### 변경 날짜
2025-09-26

### 주요 변경사항

#### 1. TextArea 에디터 구현
- FoxChat과 동일한 TextArea 컴포넌트 적용
- 기존 단순 EditBox에서 ScrollFrame이 있는 고급 에디터로 업그레이드
- 긴 메모 작성 시 편의성 대폭 향상

#### 2. 에디터 기능 개선
- **스크롤바 지원**: 긴 텍스트 입력 시 스크롤바 자동 표시
- **자동 스크롤**: 커서 이동에 따른 자동 스크롤
- **마우스 휠 스크롤**: 마우스 휠로 편리한 스크롤
- **ESC 키 지원**: ESC 키로 편집 포커스 해제

#### 3. UI/UX 개선
- **포스트잇 스타일 유지**: 노란색 배경 그대로 유지
- **가독성 향상**: 적절한 여백과 폰트 설정
- **경계 처리**: 텍스트가 에디터 경계에서 잘리지 않도록 개선

#### 4. 버그 수정
- **커서 정렬 문제**: SetSpacing(0) 설정으로 커서와 텍스트 정확히 정렬
- **하단 잘림 방지**: 충분한 하단 여백으로 커서가 항상 보이도록 수정
- **스크롤 범위 최적화**: 2000px 고정 높이로 안정적인 스크롤

#### 5. 기술적 세부사항

##### CreateTextArea 함수 설정
```lua
-- EditBox 설정
editBox:SetHeight(2000)  -- 충분한 고정 높이
editBox:SetMaxLetters(5000)  -- 최대 5000자
editBox:SetTextInsets(5, 5, 5, 5)  -- 적절한 여백
editBox:SetSpacing(0)  -- 커서 정렬을 위한 줄 간격

-- 폰트 설정
local font, size = ChatFontNormal:GetFont()
editBox:SetFont(font, size, "")
```

##### 자동 스크롤 로직
```lua
-- 커서가 화면 밖으로 나가지 않도록 자동 조정
if cursorBottom > (scrollOffset + scrollHeight - 30) then
    scrollFrame:SetVerticalScroll(cursorBottom - scrollHeight + 30)
end
```

#### 6. 통합 방식
```lua
-- 기존 editFrame에 CreateTextArea 적용
local editAreaBg, editBox, editScrollFrame = CreateTextArea(editFrame, 390, 340, 5000)

-- 기존 noteEditBox 변수와 호환성 유지
noteEditBox = editBox

-- 자동 저장 기능 유지
noteEditBox:HookScript("OnTextChanged", function(self, userInput)
    if userInput and currentNoteId then
        addon.SaveNote(currentNoteId, self:GetText())
    end
end)
```

#### 7. 호환성
- WoW Classic 1.15 (20주년 하드코어)
- 기존 저장된 메모와 100% 호환
- 기존 설정 및 데이터 구조 변경 없음

### 사용자 가이드
1. **스크롤**: 마우스 휠 또는 우측 스크롤바 사용
2. **편집 종료**: ESC 키를 눌러 편집 모드 종료
3. **자동 저장**: 텍스트 입력 시 실시간 자동 저장

### 알려진 제한사항
- EditBox 높이는 2000px로 고정 (WoW API 제약)
- 최대 5000자 제한

### 향후 계획
- 텍스트 검색 기능 추가 고려
- 메모 내 링크 지원 검토
- 폰트 크기 조절 옵션 추가 고려

### 개발자 노트
WowPostIt의 에디터를 FoxChat의 TextArea 컴포넌트로 교체하여 일관성 있는 사용자 경험을 제공합니다. 포스트잇의 고유한 노란색 디자인은 그대로 유지하면서 편집 기능만 개선했습니다.

### 파일 변경
- `WowPostIt_Config.lua`: CreateTextArea 함수 추가 및 에디터 통합

---

개발자: 우르사 (20주년 하드코어 클래식 서버, Fox and Wolf 길드)