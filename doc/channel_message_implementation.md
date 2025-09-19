# WoW Classic 1.12 채널 메시지 시스템 구현 가이드

## 개요
이 문서는 SimpleFindParty 애드온에서 사용된 채널 메시지 시스템의 전체 구현 방법을 설명합니다.

## 1. 시스템 아키텍처

### 주요 컴포넌트
```
SimpleFindParty/
├── SimpleFindParty.lua      # 메인 이벤트 처리
├── FilterSystem.lua          # 메시지 필터링 로직
├── MessageFrame.lua          # 메시지 표시 UI
├── SettingsFrame.lua         # 설정 UI
├── MinimapButton.lua         # 미니맵 버튼
└── SimpleFindParty.toc       # 애드온 매니페스트
```

## 2. 메시지 캡처 및 처리

### 이벤트 핸들러 설정
```lua
-- 프레임 생성 및 이벤트 등록
local frame = CreateFrame("Frame", "SimpleFindPartyFrame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- 이벤트 핸들러 (WoW Classic 스타일)
frame:SetScript("OnEvent", function(self, eventName, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = ...

    if eventName == "CHAT_MSG_CHANNEL" then
        ProcessChannelMessage(arg1, arg2, arg8, arg9)
    end
end)
```

### 메시지 처리 함수
```lua
function ProcessChannelMessage(message, sender, channelNum, channelName)
    -- 1. 채널 확인
    if tonumber(channelNum) ~= selectedChannel then
        return
    end

    -- 2. 발신자 이름 정리
    local cleanSender = sender
    local dashPos = string.find(sender, "-")
    if dashPos then
        cleanSender = string.sub(sender, 1, dashPos - 1)
    end

    -- 3. 필터 적용
    if ShouldShowMessage(message) then
        AddFilteredMessage(cleanSender, message, time())
        RefreshMessageDisplay()
    end
end
```

## 3. 필터 시스템 구현

### 필터 키워드 관리
```lua
local filterKeywords = {}
local ignoreKeywords = {}

function UpdateFilterKeywords(keywordString)
    filterKeywords = {}

    -- 쉼표로 구분된 키워드 파싱
    local iterator = string.gmatch or string.gfind
    for keyword in iterator(keywordString, "[^,]+") do
        -- 앞뒤 공백 제거
        keyword = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
        if keyword ~= "" then
            table.insert(filterKeywords, string.lower(keyword))
        end
    end
end
```

### 메시지 필터링 로직
```lua
function ShouldShowMessage(message)
    local lowerMessage = string.lower(message)

    -- 1. 길이 체크
    if string.len(message) <= 5 then
        return false
    end

    -- 2. 무시 키워드 체크
    for _, keyword in ipairs(ignoreKeywords) do
        if string.find(lowerMessage, keyword, 1, true) then
            return false
        end
    end

    -- 3. 필터 키워드 체크
    if #filterKeywords == 0 then
        return true  -- 필터 없으면 모두 표시
    end

    for _, keyword in ipairs(filterKeywords) do
        if string.find(lowerMessage, keyword, 1, true) then
            return true
        end
    end

    return false
end
```

## 4. 메시지 저장 구조

### 메시지 데이터 구조
```lua
local filteredMessages = {}

-- 메시지 추가
function AddFilteredMessage(author, message, timestamp)
    -- 중복 제거 (같은 작성자의 이전 메시지)
    for i, msg in ipairs(filteredMessages) do
        if msg.author == author then
            table.remove(filteredMessages, i)
            break
        end
    end

    -- 새 메시지 추가 (최신이 앞에)
    table.insert(filteredMessages, 1, {
        author = author,
        message = message,
        timestamp = timestamp,
        highlighted = HighlightKeywords(message)
    })

    -- 최대 개수 제한
    if #filteredMessages > 50 then
        table.remove(filteredMessages, 51)
    end

    -- 알림 소리
    if soundEnabled then
        PlaySound(3175)  -- WoW Classic은 숫자 ID 사용
    end
end
```

## 5. UI 구현

### 메시지 프레임 생성
```lua
function CreateMessageFrame()
    local frame = CreateFrame("Frame", "SimpleFindPartyMessageFrame", UIParent)
    frame:SetWidth(500)
    frame:SetHeight(250)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

    -- 배경 설정 (SetBackdrop 미지원)
    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    backdrop:SetAllPoints(frame)
    backdrop:SetVertexColor(0, 0, 0, 0.4)

    -- 스크롤 프레임
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20)

    return frame
end
```

### 메시지 표시
```lua
function DisplayMessage(msgData, parent, yOffset)
    local msgFrame = CreateFrame("Frame", nil, parent)
    msgFrame:SetHeight(25)

    -- 닉네임
    local nicknameText = msgFrame:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    nicknameText:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 5, -2)
    nicknameText:SetWidth(100)
    nicknameText:SetText("|cff00ff00" .. msgData.author .. "|r")

    -- 메시지
    local messageButton = CreateFrame("Button", nil, msgFrame)
    messageButton:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 110, 0)
    messageButton:SetPoint("BOTTOMRIGHT", msgFrame, "BOTTOMRIGHT", -40, 0)

    local messageText = messageButton:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    messageText:SetText(msgData.highlighted)

    -- 클릭 이벤트 (귓속말)
    messageButton:SetScript("OnClick", function()
        DEFAULT_CHAT_FRAME.editBox:Show()
        DEFAULT_CHAT_FRAME.editBox:SetFocus()
        DEFAULT_CHAT_FRAME.editBox:SetText("/귓속말 " .. msgData.author .. " ")
    end)

    return msgFrame
end
```

## 6. 설정 저장

### SavedVariables 설정
```lua
-- .toc 파일에서 정의
## SavedVariables: SimpleFindPartyDB

-- 기본값 설정
local defaults = {
    selectedChannel = nil,
    filterKeywords = "",
    ignoreKeywords = "",
    blockedUsers = {},
    soundEnabled = true,
    messageFramePos = nil
}

-- 초기화
function InitializeSavedVariables()
    if not SimpleFindPartyDB then
        SimpleFindPartyDB = {}
    end

    for k, v in pairs(defaults) do
        if SimpleFindPartyDB[k] == nil then
            SimpleFindPartyDB[k] = v
        end
    end
end
```

## 7. 자동 메시지 정리

### 타이머 기반 정리
```lua
local cleanupTimer = CreateFrame("Frame")
local elapsed = 0

cleanupTimer:SetScript("OnUpdate", function()
    elapsed = elapsed + (arg1 or 0.01)

    if elapsed > 5 then  -- 5초마다 체크
        elapsed = 0
        CleanupOldMessages()
    end
end)

function CleanupOldMessages()
    local currentTime = time()

    for i = #filteredMessages, 1, -1 do
        -- 60초 이상 된 메시지 제거
        if currentTime - filteredMessages[i].timestamp > 60 then
            table.remove(filteredMessages, i)
        end
    end
end
```

## 8. 키워드 하이라이팅

```lua
function HighlightKeywords(message)
    if #filterKeywords == 0 then
        return message
    end

    local result = message

    for _, keyword in ipairs(filterKeywords) do
        -- 특수 문자 이스케이프
        local pattern = string.gsub(keyword, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")

        -- 대소문자 변형 처리
        local variations = {
            pattern,
            string.upper(pattern),
            string.upper(string.sub(pattern, 1, 1)) .. string.lower(string.sub(pattern, 2))
        }

        for _, var in ipairs(variations) do
            result = string.gsub(result, "(" .. var .. ")", "|cffffff00%1|r")
        end
    end

    return result
end
```

## 9. 미니맵 버튼 구현

```lua
function CreateMinimapButton()
    local button = CreateFrame("Button", "SimpleFindPartyMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")

    -- 아이콘
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetAllPoints(button)

    -- 클릭 이벤트
    button:SetScript("OnMouseDown", function()
        if IsMouseButtonDown("LeftButton") then
            -- 설정창 열기
            SimpleFindPartySettingsFrame:Show()
        elseif IsMouseButtonDown("RightButton") then
            -- 메시지창 토글
            if SimpleFindPartyMessageFrame:IsShown() then
                SimpleFindPartyMessageFrame:Hide()
            else
                SimpleFindPartyMessageFrame:Show()
            end
        end
    end)

    return button
end
```

## 10. 일반적인 문제 해결

### 문제: 메시지가 표시되지 않음
- 채널 번호 확인
- 필터 키워드 확인
- 이벤트 등록 확인

### 문제: 한글 깨짐
- UTF-8 인코딩 확인
- 폰트 설정 확인

### 문제: 성능 이슈
- 메시지 개수 제한
- 타이머 간격 조정
- 불필요한 UI 업데이트 제거

## 11. 테스트 방법

```lua
-- 테스트 메시지 추가
SLASH_SFPTEST1 = "/sfptest"
SlashCmdList["SFPTEST"] = function()
    AddFilteredMessage("TestUser", "테스트 메시지입니다", time())
    RefreshMessageDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("테스트 메시지 추가됨")
end

-- 디버그 모드
SLASH_SFPDEBUG1 = "/sfpdebug"
SlashCmdList["SFPDEBUG"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("선택 채널: " .. tostring(selectedChannel))
    DEFAULT_CHAT_FRAME:AddMessage("필터 키워드: " .. table.concat(filterKeywords, ", "))
    DEFAULT_CHAT_FRAME:AddMessage("메시지 개수: " .. #filteredMessages)
end
```