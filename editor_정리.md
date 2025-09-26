# WowPostIt 에디터 현재 상태 정리

## 현재 문제 (해결됨)
1. ~~텍스트 입력은 가능하지만 커서가 텍스트 줄 위쪽에 표시됨~~ ✓ 해결
2. ~~스크롤 범위 문제는 고정 높이 2000px로 임시 해결~~ ✓ 해결
3. ~~동적 높이 조정 시도했으나 OnTextChanged 핸들러 충돌로 제거~~ ✓ 해결

---

# WoW 애드온 TextArea 에디터 만들기 가이드

## 1. 개요
WoW Classic에서 멀티라인 텍스트 입력을 위한 스크롤 가능한 TextArea를 만드는 완전한 가이드입니다.

## 2. 핵심 구조
TextArea는 3개의 프레임으로 구성됩니다:
- **배경 프레임 (Frame)**: 전체 컨테이너
- **스크롤 프레임 (ScrollFrame)**: 스크롤 기능 제공
- **편집 상자 (EditBox)**: 실제 텍스트 입력

## 3. 단계별 구현 방법

### 3.1 기본 프레임 생성
```lua
-- 1. 배경 프레임 생성
local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
bg:SetSize(width, height)  -- 원하는 크기 설정
bg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
bg:SetBackdropColor(0, 0, 0, 0.8)  -- 배경색 설정
```

### 3.2 스크롤 프레임 추가
```lua
-- 2. 스크롤 프레임 생성 (템플릿 사용이 중요!)
local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)  -- 스크롤바 공간 확보 (-26)
```

### 3.3 EditBox 생성 및 설정
```lua
-- 3. EditBox 생성
local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)  -- 필수: 멀티라인 활성화
editBox:SetAutoFocus(false)  -- 자동 포커스 방지
editBox:SetFontObject(GameFontHighlight)  -- 폰트 설정
editBox:SetWidth(scrollFrame:GetWidth() - 5)  -- 너비 설정
editBox:SetHeight(2000)  -- 충분한 고정 높이 (중요!)
editBox:SetMaxLetters(5000)  -- 최대 글자 수
editBox:SetTextInsets(5, 5, 5, 25)  -- 여백 (좌, 우, 상, 하)
```

### 3.4 폰트 및 줄 간격 설정 (커서 정렬 핵심)
```lua
-- 4. 폰트와 줄 간격 설정
local font, size = ChatFontNormal:GetFont()
editBox:SetFont(font, size, "")
editBox:SetSpacing(0)  -- 줄 간격 0으로 설정 (커서 정렬에 중요!)
```

### 3.5 ScrollChild 설정
```lua
-- 5. ScrollChild로 EditBox 등록
scrollFrame:SetScrollChild(editBox)
```

## 4. 핵심 이벤트 처리

### 4.1 ESC 키로 포커스 해제
```lua
editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
```

### 4.2 자동 스크롤 구현 (가장 중요!)
```lua
-- 재귀 방지를 위한 플래그
editBox.isScrolling = false

editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
    if self.isScrolling then return end  -- 재귀 방지

    local scrollOffset = scrollFrame:GetVerticalScroll()
    local scrollHeight = scrollFrame:GetHeight()
    local cursorTop = -y  -- y는 음수로 전달됨
    local cursorBottom = -y + h

    -- 커서가 위쪽 경계를 벗어난 경우
    if cursorTop < scrollOffset then
        self.isScrolling = true
        scrollFrame:SetVerticalScroll(math.max(0, cursorTop - 5))
        C_Timer.After(0.01, function() self.isScrolling = false end)

    -- 커서가 아래쪽 경계를 벗어난 경우
    elseif cursorBottom > (scrollOffset + scrollHeight - 30) then
        self.isScrolling = true
        local newScroll = cursorBottom - scrollHeight + 30
        local maxScroll = self:GetHeight() - scrollHeight
        scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, newScroll)))
        C_Timer.After(0.01, function() self.isScrolling = false end)
    end
end)
```

### 4.3 마우스 휠 스크롤
```lua
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local maxScroll = self:GetVerticalScrollRange()
    local scrollStep = 20

    if delta > 0 then  -- 위로 스크롤
        self:SetVerticalScroll(math.max(0, current - scrollStep))
    else  -- 아래로 스크롤
        self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
    end
end)
```

### 4.4 배경 클릭 시 포커스
```lua
bg:EnableMouse(true)
bg:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        editBox:SetFocus()
    end
end)
```

## 5. 초기화 지연 실행
```lua
-- EditBox 너비를 실제 ScrollFrame 너비에 맞추기
C_Timer.After(0.1, function()
    local w = scrollFrame:GetWidth()
    if w and w > 0 then
        editBox:SetWidth(w - 5)
    end
end)
```

## 6. 완성된 CreateTextArea 함수

```lua
local function CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(scrollFrame:GetWidth() - 5)
    editBox:SetHeight(2000)  -- 충분히 큰 고정 높이
    editBox:SetMaxLetters(maxLetters or 5000)
    editBox:SetTextInsets(5, 5, 5, 25)  -- 하단 여백 증가

    -- 폰트 설정
    local font, size = ChatFontNormal:GetFont()
    editBox:SetFont(font, size, "")
    editBox:SetSpacing(0)  -- 커서 정렬을 위해 0으로 설정

    -- ScrollChild로 설정
    scrollFrame:SetScrollChild(editBox)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 커서 위치 변경 시 자동 스크롤
    editBox.isScrolling = false
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if self.isScrolling then return end

        local scrollOffset = scrollFrame:GetVerticalScroll()
        local scrollHeight = scrollFrame:GetHeight()
        local cursorTop = -y
        local cursorBottom = -y + h

        if cursorTop < scrollOffset then
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorTop - 5))
            C_Timer.After(0.01, function() self.isScrolling = false end)
        elseif cursorBottom > (scrollOffset + scrollHeight - 30) then
            self.isScrolling = true
            local newScroll = cursorBottom - scrollHeight + 30
            local maxScroll = self:GetHeight() - scrollHeight
            scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, newScroll)))
            C_Timer.After(0.01, function() self.isScrolling = false end)
        end
    end)

    -- 배경 클릭 시 EditBox로 포커스
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
        end
    end)

    -- 마우스 휠 스크롤
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 20

        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        end
    end)

    -- EditBox 크기 조정
    C_Timer.After(0.1, function()
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            editBox:SetWidth(w - 5)
        end
    end)

    return bg, editBox, scrollFrame
end
```

## 7. 사용 방법

### 7.1 TextArea 생성
```lua
local bg, editBox, scrollFrame = CreateTextArea(parent, 400, 300, 5000)
bg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```

### 7.2 텍스트 변경 감지
```lua
editBox:HookScript("OnTextChanged", function(self, userInput)
    if userInput then  -- 사용자 입력인 경우만
        local text = self:GetText()
        -- 텍스트 처리 로직
        print("텍스트 변경됨:", text)
    end
end)
```

### 7.3 텍스트 가져오기/설정하기
```lua
-- 텍스트 설정
editBox:SetText("초기 텍스트")

-- 텍스트 가져오기
local text = editBox:GetText()
```

## 8. 주요 문제 해결 방법

### 8.1 커서가 텍스트와 정렬되지 않는 경우
- **해결책**: `SetSpacing(0)` 사용
- 폰트에 따라 0, 1, 2 중 적절한 값 선택

### 8.2 커서가 하단에서 잘리는 경우
- **해결책**: `SetTextInsets(5, 5, 5, 25)` - 하단 여백 증가
- 자동 스크롤 트리거 위치 조정 (30-40px 여유)

### 8.3 스크롤이 제대로 작동하지 않는 경우
- **해결책**: EditBox 높이를 충분히 크게 설정 (2000px)
- `UIPanelScrollFrameTemplate` 템플릿 사용 필수

### 8.4 OnTextChanged 핸들러 충돌
- **해결책**: `HookScript` 사용 (SetScript 대신)
- CreateTextArea에서는 OnTextChanged를 설정하지 않음

### 8.5 무한 루프/크래시 방지
- **해결책**: isScrolling 플래그 사용
- C_Timer.After(0.01) 사용하여 비동기 처리

## 9. 최적화 팁

1. **고정 높이 사용**: 동적 높이 조정보다 안정적
2. **재귀 방지 플래그**: 이벤트 처리 시 필수
3. **적절한 여백**: 경계 잘림 방지
4. **템플릿 활용**: UIPanelScrollFrameTemplate 사용
5. **지연 실행**: 초기화 시 C_Timer.After 활용

## 10. WoW API 제약사항

1. `UpdateScrollChildRect()` - 존재하지 않음
2. `GetSpacing()` - 일부 버전에서 지원 안 됨
3. EditBox 높이 제한 - 매우 큰 값은 문제 발생
4. OnTextChanged - SetScript와 HookScript 충돌 가능

## 11. 테스트 체크리스트

- [ ] 텍스트 입력 가능
- [ ] 커서와 텍스트 정렬 확인
- [ ] 자동 스크롤 작동
- [ ] 마우스 휠 스크롤 작동
- [ ] ESC 키로 포커스 해제
- [ ] 긴 텍스트 입력 시 스크롤
- [ ] 하단 커서 표시 확인
- [ ] /reload 후 정상 작동

---

## 현재 CreateTextArea 함수 (FoxChat/FoxChat_Config_TabUI.lua)

### 위치
`/Users/toto/devel/wow/exam01/FoxChat/FoxChat_Config_TabUI.lua` (18-88줄)

### 전체 코드
```lua
-- 재사용 가능한 TextArea 생성 함수 (안정적인 버전)
local function CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(scrollFrame:GetWidth() - 5)
    editBox:SetHeight(2000)  -- 충분히 큰 고정 높이
    editBox:SetMaxLetters(maxLetters or 0)
    editBox:SetTextInsets(5, 5, 5, 25)  -- 하단 여백 증가

    -- 줄 간격 조정 (커서 위치 문제 해결)
    editBox:SetSpacing(0)  -- 줄 간격을 0으로 설정

    -- ScrollChild로 설정
    scrollFrame:SetScrollChild(editBox)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 커서 위치 변경 시 자동 스크롤 (안전한 버전)
    editBox.isScrolling = false
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if self.isScrolling then return end  -- 재귀 방지

        local scrollOffset = scrollFrame:GetVerticalScroll()
        local scrollHeight = scrollFrame:GetHeight()
        local cursorTop = -y
        local cursorBottom = -y + h

        -- 커서가 화면 밖으로 나가는 것을 방지
        local maxScroll = self:GetHeight() - scrollHeight
        if maxScroll < 0 then maxScroll = 0 end

        -- 스크롤 업데이트가 필요한 경우만 처리
        if cursorTop < scrollOffset then
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorTop - 5))  -- 상단 여유 추가
            C_Timer.After(0.01, function() self.isScrolling = false end)
        elseif cursorBottom > (scrollOffset + scrollHeight - 40) then  -- 하단 여유를 40으로 증가
            self.isScrolling = true
            local newScroll = cursorBottom - scrollHeight + 40
            scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, newScroll)))  -- 최대 스크롤 범위 제한
            C_Timer.After(0.01, function() self.isScrolling = false end)
        end
    end)

    -- 배경 클릭 시 EditBox로 포커스
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
        end
    end)

    -- 마우스 휠 스크롤
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 20

        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        end
    end)

    -- EditBox 크기를 실제로 맞추기 위한 지연 실행
    C_Timer.After(0.1, function()
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            editBox:SetWidth(w - 5)
        end
    end)

    bg.editBox = editBox
    bg.scrollFrame = scrollFrame

    return bg, editBox, scrollFrame
end
```

## WowPostIt 버전 CreateTextArea (WowPostIt/WowPostIt_Config.lua)

### 위치
`/Users/toto/devel/wow/exam01/WowPostIt/WowPostIt_Config.lua` (11-88줄)

### 전체 코드
```lua
-- 재사용 가능한 TextArea 생성 함수 (안정적인 버전)
local function CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetWidth(scrollFrame:GetWidth() - 5)
    editBox:SetHeight(2000)  -- 충분히 큰 고정 높이
    editBox:SetMaxLetters(maxLetters or 5000)
    editBox:SetTextInsets(5, 5, 5, 5)

    -- 폰트 설정 (줄 간격 문제 해결)
    local font, size = ChatFontNormal:GetFont()
    editBox:SetFont(font, size, "")
    editBox:SetSpacing(0)  -- 줄 간격을 0으로 설정하여 커서 정렬

    -- ScrollChild로 설정
    scrollFrame:SetScrollChild(editBox)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 커서 위치 변경 시 자동 스크롤 (안전한 버전)
    editBox.isScrolling = false
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if self.isScrolling then return end  -- 재귀 방지

        local scrollOffset = scrollFrame:GetVerticalScroll()
        local scrollHeight = scrollFrame:GetHeight()
        local cursorTop = -y
        local cursorBottom = -y + h

        -- 스크롤 업데이트가 필요한 경우만 처리
        if cursorTop < scrollOffset then
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorTop))
            C_Timer.After(0.01, function() self.isScrolling = false end)
        elseif cursorBottom > (scrollOffset + scrollHeight - 30) then  -- 여유 공간을 30으로 증가
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorBottom - scrollHeight + 30))  -- 더 많이 스크롤
            C_Timer.After(0.01, function() self.isScrolling = false end)
        end
    end)

    -- 배경 클릭 시 EditBox로 포커스
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
        end
    end)

    -- 마우스 휠 스크롤
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 20

        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        end
    end)

    -- EditBox 크기를 실제로 맞추기 위한 지연 실행
    C_Timer.After(0.1, function()
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            editBox:SetWidth(w - 5)
        end
    end)

    return bg, editBox, scrollFrame
end
```

## WowPostIt 에디터 통합 부분

### 위치
`WowPostIt_Config.lua` (385-409줄)

### 통합 코드
```lua
-- CreateTextArea를 사용한 편집 영역 생성
local editAreaBg, editBox, editScrollFrame = CreateTextArea(editFrame, 390, 340, 5000)
editAreaBg:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 0, 0)
editAreaBg:SetPoint("BOTTOMRIGHT", editFrame, "BOTTOMRIGHT", 0, 0)

-- 포스트잇 배경색 적용
editAreaBg:SetBackdropColor(1.0, 1.0, 0.6, 0.3)  -- 기본 노란색

-- 포스트잇 배경 텍스처 추가
local editBg = editAreaBg:CreateTexture(nil, "BACKGROUND")
editBg:SetAllPoints(editAreaBg)
editBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
editBg:SetVertexColor(1.0, 1.0, 0.6, 0.3)
editBox.bg = editBg  -- 기존 코드와의 호환성을 위해 유지

-- noteEditBox를 전역 변수에 할당
noteEditBox = editBox

-- noteWindow에 참조 저장 (레이아웃 업데이트를 위해)
noteWindow.editScrollFrame = editScrollFrame
noteWindow.editAreaBg = editAreaBg

-- 텍스트 변경 시 자동 저장
noteEditBox:HookScript("OnTextChanged", function(self, userInput)
    if userInput and currentNoteId then
        addon.SaveNote(currentNoteId, self:GetText())
        addon:UpdateNoteList()
    end
end)
```

## 전문가에게 질문할 내용

1. **커서 위치 문제**
   - EditBox에서 커서가 텍스트 줄 위쪽에 표시되는 문제를 어떻게 해결할 수 있을까요?
   - SetSpacing, SetFont, SetTextInsets 외에 영향을 줄 수 있는 다른 설정이 있을까요?

2. **동적 높이 조정**
   - EditBox의 높이를 텍스트 양에 따라 동적으로 조정하면서도 스크롤이 제대로 작동하게 하는 방법은?
   - UpdateScrollChildRect() 대신 사용할 수 있는 API는?

3. **OnTextChanged 핸들러**
   - CreateTextArea에서 기본 동작을 설정하고, 이후 각 용도별로 추가 핸들러를 HookScript로 연결하는 올바른 패턴은?

## 관련 파일 경로
- `/Users/toto/devel/wow/exam01/FoxChat/FoxChat_Config_TabUI.lua`
- `/Users/toto/devel/wow/exam01/WowPostIt/WowPostIt_Config.lua`

## WoW API 버전
- WoW Classic 1.15 (20주년 하드코어)