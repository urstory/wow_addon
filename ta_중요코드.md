# TextArea 구현 중요 코드

## 문제 상황
- TextArea(EditBox with ScrollFrame)가 화면에 표시되지 않음
- 클릭이 안되고 수정이 불가능한 상태
- 광고 메시지가 없는데도 141/255로 표시됨

## CreateTextArea 함수 (현재 코드)

```lua
-- 재사용 가능한 TextArea 생성 함수
local function CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임 생성
    local background = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    background:SetSize(width, height)
    background:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    background:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, background, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- ScrollFrame 내부의 ScrollChild용 프레임
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- EditBox 생성 (ScrollChild의 자식으로)
    local editBox = CreateFrame("EditBox", nil, scrollChild)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetPoint("TOPLEFT", 0, 0)
    editBox:SetPoint("TOPRIGHT", 0, 0)
    editBox:SetTextInsets(5, 5, 5, 5)

    if maxLetters then
        editBox:SetMaxLetters(maxLetters)
    else
        editBox:SetMaxLetters(0)  -- 제한 없음
    end

    -- EditBox 높이 자동 조정 함수
    local function UpdateEditBoxHeight()
        local text = editBox:GetText()
        local _, fontHeight = editBox:GetFont()
        local numLines = math.max(1, select(2, string.gsub(text .. "\n", "\n", "")) or 1)

        -- 최소 높이는 ScrollFrame 높이
        local minHeight = scrollFrame:GetHeight() - 10
        local calculatedHeight = math.max(minHeight, numLines * (fontHeight + 2) + 10)

        editBox:SetHeight(calculatedHeight)
        scrollChild:SetHeight(calculatedHeight)
    end

    -- 텍스트 변경 시 높이 업데이트
    editBox:SetScript("OnTextChanged", function(self)
        UpdateEditBoxHeight()
        -- ScrollFrame 자동 스크롤
        local current = scrollFrame:GetVerticalScroll()
        local max = scrollFrame:GetVerticalScrollRange()
        if current > max * 0.95 then  -- 거의 끝에 있을 때만 자동 스크롤
            scrollFrame:SetVerticalScroll(max)
        end
    end)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- ScrollFrame 클릭 처리
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
            local text = editBox:GetText()
            if not text or text == "" then
                -- 빈 텍스트: 처음 위치로
                editBox:SetCursorPosition(0)
            end
        end
    end)

    -- 초기 높이 설정
    UpdateEditBoxHeight()

    -- background와 editBox 반환
    background.editBox = editBox
    background.scrollFrame = scrollFrame

    return background, editBox, scrollFrame
end
```

## 사용 예시 (광고 메시지)

```lua
-- 광고 메시지 입력 박스 (새로운 TextArea 사용)
local adMessageBackground, adMessageEditBox = CreateTextArea(tab3, 260, 120, 255)
adMessageBackground:SetPoint("TOPLEFT", adMessageHelp, "BOTTOMLEFT", 0, -5)

-- 기존 텍스트 설정
local adText = (FoxChatDB and FoxChatDB.adMessage) or ""
adMessageEditBox:SetText(adText)

-- OnTextChanged 이벤트 오버라이드
local originalOnTextChanged = adMessageEditBox:GetScript("OnTextChanged")
adMessageEditBox:SetScript("OnTextChanged", function(self)
    -- 원래 함수 호출 (높이 조정 등)
    if originalOnTextChanged then
        originalOnTextChanged(self)
    end

    local text = self:GetText()

    if FoxChatDB then
        FoxChatDB.adMessage = text

        -- 광고 메시지 길이 계산
        local adMsg = text or ""
        local firstComeMsg = FoxChatDB.firstComeMessage or ""
        local fullMessage = adMsg

        if firstComeMsg ~= "" then
            fullMessage = fullMessage .. " (" .. firstComeMsg .. ")"
        end

        -- 파티가 있을 때만 파티 정보 추가
        if IsInGroup() then
            local numGroupMembers = GetNumGroupMembers()
            local maxMembers = FoxChatDB.partyMaxSize or 5
            fullMessage = fullMessage .. " (" .. numGroupMembers .. "/" .. maxMembers .. ")"
        end

        -- 바이트 수 계산
        local byteCount = GetUTF8ByteLength(fullMessage)

        -- 레이블 업데이트 (255바이트 제한)
        if byteCount > 255 then
            adCharCountLabel:SetText(string.format("|cFFFF0000(%d/255 : 전송불가)|r", byteCount))
        else
            adCharCountLabel:SetText(string.format("(%d/255)", byteCount))
        end
    end
end)
```

## 원래 동작하던 코드 (참고용)

```lua
-- 기존에 동작하던 간단한 EditBox 코드
local adMessageBackground = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
adMessageBackground:SetSize(260, 120)
adMessageBackground:SetPoint("TOPLEFT", adMessageHelp, "BOTTOMLEFT", 0, -5)
adMessageBackground:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
adMessageBackground:SetBackdropColor(0, 0, 0, 0.8)

adMessageEditBox = CreateFrame("EditBox", "FoxChatAdMessageEditBox", adMessageBackground)
adMessageEditBox:SetSize(250, 110)
adMessageEditBox:SetPoint("TOPLEFT", 5, -5)
adMessageEditBox:SetAutoFocus(false)
adMessageEditBox:SetMultiLine(true)
adMessageEditBox:SetMaxLetters(255)
adMessageEditBox:SetFontObject(GameFontHighlight)
adMessageEditBox:SetText(adText)
adMessageEditBox:SetTextInsets(5, 5, 5, 5)
```

## 문제 분석

1. **EditBox가 보이지 않는 이유**:
   - ScrollChild 프레임의 크기 문제
   - EditBox의 anchor point 설정 문제
   - ScrollFrame과 EditBox 사이의 계층 구조 문제

2. **클릭이 안되는 이유**:
   - ScrollFrame이 마우스 이벤트를 가로챔
   - EditBox가 실제로 렌더링되지 않음

3. **가능한 해결 방법**:
   - EditBox를 ScrollFrame의 직접 child로 설정
   - ScrollChild를 제거하고 간단한 구조로 변경
   - EditBox의 Width를 명시적으로 설정

## WoW Classic EditBox with ScrollFrame 표준 구현

```lua
-- WoW에서 권장하는 표준 방식
local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetFontObject(GameFontHighlight)
editBox:SetWidth(scrollFrame:GetWidth())
scrollFrame:SetScrollChild(editBox)
```