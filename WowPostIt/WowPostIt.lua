local addonName, addon = ...
local L = addon.L or {}

-- 기본 설정
local defaults = {
    minimapButton = {
        hide = false,
        minimapPos = 45,
        radius = 80,
    },
    notes = {},
    selectedNoteId = nil,
    windowPosition = {
        point = "CENTER",
        x = 0,
        y = 0,
    },
}

-- 전역 변수
WowPostItDB = WowPostItDB or {}
local minimapButton = nil

-- 각 모양별 사분면이 원형(true)/각짐(false)인지 표
local MinimapShapes = {
    ["ROUND"]                  = {true,  true,  true,  true },
    ["SQUARE"]                 = {false, false, false, false},
    ["CORNER-TOPLEFT"]         = {false, false, false, true },
    ["CORNER-TOPRIGHT"]        = {false, false, true,  false},
    ["CORNER-BOTTOMLEFT"]      = {false, true,  false, false},
    ["CORNER-BOTTOMRIGHT"]     = {true,  false, false, false},
    ["SIDE-LEFT"]              = {false, true,  false, true },
    ["SIDE-RIGHT"]             = {true,  false, true,  false},
    ["SIDE-TOP"]               = {false, false, true,  true },
    ["SIDE-BOTTOM"]            = {true,  true,  false, false},
    ["TRICORNER-TOPLEFT"]      = {false, true,  true,  true },
    ["TRICORNER-TOPRIGHT"]     = {true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]   = {true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"]  = {true,  true,  true,  false},
}

local function getQuadrant(cx, cy)
    if cx >= 0 then
        return (cy >= 0) and 1 or 4
    else
        return (cy >= 0) and 2 or 3
    end
end

local function getShape()
    local s = GetMinimapShape and GetMinimapShape()
    return s or "ROUND"
end

-- 초기화 함수
local function InitializeAddon()
    -- DB 초기화
    for key, value in pairs(defaults) do
        if WowPostItDB[key] == nil then
            WowPostItDB[key] = value
        end
    end
    
    -- 노트가 없으면 샘플 노트 생성
    if #WowPostItDB.notes == 0 then
        table.insert(WowPostItDB.notes, {
            id = time(),
            content = L["SAMPLE_NOTE"],
            created = date("%Y-%m-%d %H:%M:%S"),
            modified = date("%Y-%m-%d %H:%M:%S"),
        })
    end
end

-- 미니맵 버튼 생성
local function CreateMinimapButton()
    if minimapButton then return end
    
    -- 미니맵 버튼 프레임
    minimapButton = CreateFrame("Button", "WowPostItMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- 버튼 아이콘 (노트 모양)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    icon:SetVertexColor(1, 1, 0.5, 0.9)  -- 노란색 (포스트잇 색상)
    
    -- 테두리
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("CENTER", 0, 0)
    border:SetSize(28, 28)
    border:SetVertexColor(0.8, 0.8, 0.8, 1)
    
    -- PI 텍스트 라벨 (PostIt)
    local piText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    piText:SetText("|cFF000000PI|r")  -- 검정색 PI
    piText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    piText:SetJustifyH("CENTER")
    piText:SetJustifyV("MIDDLE")
    piText:SetPoint("CENTER", 0, -1)
    
    -- 미니맵 위치 업데이트 (모양 인식 + 가장자리 투영)
    local function UpdateMinimapPosition()
        if not WowPostItDB.minimapButton then
            WowPostItDB.minimapButton = defaults.minimapButton
        end

        if WowPostItDB.minimapButton.hide then
            minimapButton:Hide()
            return
        else
            minimapButton:Show()
        end

        local angle = WowPostItDB.minimapButton.minimapPos or 45
        local angleRad = math.rad(angle)
        local padding = 6  -- 미니맵 테두리로부터의 여유 공간

        -- 반지름: 미니맵 절반 + 여유 패딩
        local r = (Minimap:GetWidth() / 2) + padding

        -- 방향 벡터
        local dx, dy = math.cos(angleRad), math.sin(angleRad)

        -- 현재 모양과 사분면 판정
        local shape = getShape()
        local quad = getQuadrant(dx, dy)
        local round = MinimapShapes[shape] and MinimapShapes[shape][quad]

        local factor
        if round == nil or round == true then
            -- 원형 가장자리: 반지름 그대로
            factor = r
        else
            -- 정사각형/변/코너: 정사각형 경계로 투영
            -- 경계와 만나는 지점까지 스케일링
            local maxc = math.max(math.abs(dx), math.abs(dy))
            factor = r / (maxc > 0 and maxc or 1e-6)
        end

        local x, y = dx * factor, dy * factor

        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- 드래그 기능
    minimapButton:RegisterForDrag("LeftButton", "RightButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            
            local angle = math.deg(math.atan2(py - my, px - mx))
            if not WowPostItDB.minimapButton then
                WowPostItDB.minimapButton = defaults.minimapButton
            end
            WowPostItDB.minimapButton.minimapPos = angle
            UpdateMinimapPosition()
        end)
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    -- 클릭 이벤트
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if addon.ShowNoteWindow then
                addon:ShowNoteWindow()
            end
        elseif button == "RightButton" then
            -- 우클릭 시 새 메모 생성하고 창 열기
            local newNote = addon.CreateNote(L["NEW_NOTE"])
            WowPostItDB.selectedNoteId = newNote.id
            if addon.ShowNoteWindow then
                addon:ShowNoteWindow()
            end
            print("|cFFFFFF00WowPostIt:|r " .. L["NEW_NOTE_CREATED"])
        end
    end)
    
    -- 툴팁
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("WowPostIt", 1, 1, 1)
        GameTooltip:AddLine(L["LEFT_CLICK_OPEN"], 1, 1, 1)
        GameTooltip:AddLine(L["RIGHT_CLICK_NEW"], 1, 1, 1)
        GameTooltip:AddLine(string.format(L["TOTAL_NOTES"], #WowPostItDB.notes), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 주기적으로 미니맵 모양 체크 (Classic에는 MINIMAP_UPDATE_SHAPE 이벤트가 없음)
    local lastShape = nil
    minimapButton:SetScript("OnUpdate", function(self, elapsed)
        -- 드래그 중이면 스킵 (기존 OnUpdate가 있을 수 있음)
        if self.isMoving then return end

        self.shapeCheckTimer = (self.shapeCheckTimer or 0) + elapsed
        if self.shapeCheckTimer > 1 then  -- 1초마다 체크
            self.shapeCheckTimer = 0
            local currentShape = getShape()
            if currentShape ~= lastShape then
                lastShape = currentShape
                UpdateMinimapPosition()
            end
        end
    end)

    -- 초기 위치 설정
    UpdateMinimapPosition()
end

-- 슬래시 커맨드
SLASH_WOWPOSTIT1 = "/postit"
SLASH_WOWPOSTIT2 = "/pi"
SLASH_WOWPOSTIT3 = "/wowpostit"
SlashCmdList["WOWPOSTIT"] = function(msg)
    if msg == "show" then
        if WowPostItDB.minimapButton then
            WowPostItDB.minimapButton.hide = false
            CreateMinimapButton()
        end
    elseif msg == "hide" then
        if WowPostItDB.minimapButton then
            WowPostItDB.minimapButton.hide = true
            if minimapButton then
                minimapButton:Hide()
            end
        end
    else
        if addon.ShowNoteWindow then
            addon:ShowNoteWindow()
        end
    end
end

-- 이벤트 처리
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeAddon()
        CreateMinimapButton()
        print("|cFFFFFF00WowPostIt|r " .. L["ADDON_LOADED"])
    end
end)

-- 전역 함수 노출
addon.GetNotes = function()
    return WowPostItDB.notes or {}
end

addon.SaveNote = function(noteId, content)
    for i, note in ipairs(WowPostItDB.notes) do
        if note.id == noteId then
            note.content = content
            note.modified = date("%Y-%m-%d %H:%M:%S")
            return true
        end
    end
    return false
end

addon.CreateNote = function(content)
    -- 포스트잇 색상 팔레트 (더 부드러운 파스텔톤)
    local postItColors = {
        {0.9, 0.9, 0.5},    -- 부드러운 노란색
        {0.9, 0.6, 0.6},    -- 부드러운 분홍색
        {0.6, 0.9, 0.6},    -- 부드러운 연두색
        {0.6, 0.8, 0.9},    -- 부드러운 하늘색
        {0.8, 0.7, 0.9},    -- 부드러운 연보라색
        {0.9, 0.8, 0.6},    -- 부드러운 연주황색
        {0.8, 0.9, 0.7},    -- 부드러운 라임색
        {0.9, 0.7, 0.8},    -- 부드러운 핑크색
    }
    
    -- 랜덤 색상 선택
    local randomColor = postItColors[math.random(#postItColors)]
    
    local newNote = {
        id = time() .. math.random(1000), -- 고유 ID
        content = content or L["NEW_NOTE"],
        created = date("%Y-%m-%d %H:%M:%S"),
        modified = date("%Y-%m-%d %H:%M:%S"),
        color = randomColor, -- 배경색 저장
    }
    table.insert(WowPostItDB.notes, 1, newNote) -- 최신 노트를 앞에 추가
    return newNote
end

addon.DeleteNote = function(noteId)
    for i, note in ipairs(WowPostItDB.notes) do
        if note.id == noteId then
            table.remove(WowPostItDB.notes, i)
            return true
        end
    end
    return false
end

-- 채팅으로 노트 보내기
function addon:SendNoteToChat(chatType)
    if not WowPostItDB.selectedNoteId then 
        print("|cFFFFFF00WowPostIt:|r " .. L["NO_NOTE_SELECTED"])
        return 
    end
    
    -- 현재 선택된 노트 찾기
    local noteToSend = nil
    for _, note in ipairs(WowPostItDB.notes) do
        if note.id == WowPostItDB.selectedNoteId then
            noteToSend = note
            break
        end
    end
    
    if not noteToSend then 
        print("|cFFFFFF00WowPostIt:|r " .. L["NOTE_NOT_FOUND"])
        return 
    end
    
    -- 채팅 타입 확인 (파티/레이드/길드 가입 여부)
    if chatType == "GUILD" and not IsInGuild() then
        print("|cFFFFFF00WowPostIt:|r " .. L["NOT_IN_GUILD"])
        return
    elseif chatType == "PARTY" and not IsInGroup() then
        print("|cFFFFFF00WowPostIt:|r " .. L["NOT_IN_PARTY"])
        return
    elseif chatType == "RAID" and not IsInRaid() then
        print("|cFFFFFF00WowPostIt:|r " .. L["NOT_IN_RAID"])
        return
    end
    
    -- 노트 내용을 줄별로 분리
    local lines = {}
    for line in noteToSend.content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- 빈 노트 체크
    if #lines == 0 then
        print("|cFFFFFF00WowPostIt:|r " .. L["EMPTY_NOTE"])
        return
    end
    
    -- 각 줄을 개별적으로 전송 (WoW는 한 메시지에 여러 줄을 보낼 수 없음)
    -- 순서 보장을 위해 타이머 사용
    local delay = 0
    for i, line in ipairs(lines) do
        -- 빈 줄은 공백으로 대체
        if line:match("^%s*$") then
            line = " "
        end
        -- 255자 제한 (WoW 채팅 제한)
        if #line > 255 then
            line = line:sub(1, 252) .. "..."
        end
        
        -- 각 메시지를 0.1초 간격으로 전송
        local currentLine = line
        C_Timer.After(delay, function()
            SendChatMessage(currentLine, chatType)
        end)
        delay = delay + 0.1
    end
    
    -- 완료 메시지도 지연 후 표시
    C_Timer.After(delay, function()
        print(string.format("|cFFFFFF00WowPostIt:|r " .. L["NOTE_SENT_TO"], L["CHANNEL_" .. chatType] or chatType))
    end)
end

-- 전역 노출
WowPostIt = addon