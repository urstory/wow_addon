-- FoxGuildCal Minimap Button
local addonName, addon = ...

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

-- LibDataBroker 객체 생성
local dataObj = {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    OnClick = function(self, button)
        if button == "LeftButton" then
            addon:ToggleCalendar()
        elseif button == "RightButton" then
            addon:ShowOptionsMenu(self)
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText("FoxGuildCal")
        tooltip:AddLine("클릭: 캘린더 열기/닫기", 1, 1, 1)
        tooltip:AddLine("우클릭: 옵션 메뉴", 1, 1, 1)
        
        local guildKey = addon:GetGuildKey()
        if guildKey then
            local events = addon.db.events[guildKey]
            if events then
                local count = 0
                local today = addon:GetCurrentDate()
                local todayStr = addon:FormatDate(today.year, today.month, today.day)
                
                for _, event in pairs(events) do
                    if not event.deleted and event.date == todayStr then
                        count = count + 1
                    end
                end
                
                if count > 0 then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(string.format("오늘의 일정: %d개", count), 0, 1, 0)
                end
            end
        end
    end,
}

-- 미니맵 버튼 초기화
local function InitializeMinimapButton()
    if addon.minimapButton then
        addon:Print("미니맵 버튼이 이미 존재합니다.")
        return
    end
    -- 기본 미니맵 버튼 생성 (LibStub 체크 제거)
    local button = CreateFrame("Button", "FoxGuildCalMinimapButton", Minimap)
        button:SetSize(32, 32)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(8)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetSize(20, 20)
        background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        background:SetPoint("TOPLEFT", 6, -6)
        
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        icon:SetPoint("TOPLEFT", 7, -7)
        
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT")
        
        -- 위치 설정 (모양 인식 + 가장자리 투영)
        local function UpdatePosition()
            local angle = addon.db.settings.minimap.minimapPos or 220
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

            button:ClearAllPoints()
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
        
        UpdatePosition()
        
        -- 드래그 기능
        button:RegisterForDrag("LeftButton")
        button:SetMovable(true)
        button:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() and not addon.db.settings.minimap.lock then
                self.isMoving = true
                self:SetScript("OnUpdate", function(self)
                    local mx, my = Minimap:GetCenter()
                    local px, py = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    px, py = px / scale, py / scale
                    local angle = math.deg(math.atan2(py - my, px - mx))
                    addon.db.settings.minimap.minimapPos = angle
                    UpdatePosition()
                end)
            end
        end)
        
        button:SetScript("OnDragStop", function(self)
            self.isMoving = false
            self:SetScript("OnUpdate", nil)
        end)
        
        -- 클릭 이벤트
        button:SetScript("OnClick", function(self, btn)
            if btn == "LeftButton" then
                addon:ToggleCalendar()
            elseif btn == "RightButton" then
                addon:ShowOptionsMenu(self)
            end
        end)
        
        -- 툴팁
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("FoxGuildCal")
            GameTooltip:AddLine("클릭: 캘린더 열기/닫기", 1, 1, 1)
            GameTooltip:AddLine("우클릭: 옵션 메뉴", 1, 1, 1)
            GameTooltip:AddLine("Shift+드래그: 버튼 이동", 1, 1, 1)
            
            local guildKey = addon:GetGuildKey()
            if guildKey then
                local events = addon.db.events[guildKey]
                if events then
                    local count = 0
                    local todayEvents = {}
                    local today = addon:GetCurrentDate()
                    local todayStr = addon:FormatDate(today.year, today.month, today.day)
                    
                    for _, event in pairs(events) do
                        if not event.deleted and event.date == todayStr then
                            count = count + 1
                            table.insert(todayEvents, event)
                        end
                    end
                    
                    if count > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(string.format("오늘의 일정: %d개", count), 0, 1, 0)
                        
                        -- 최대 3개까지 표시
                        table.sort(todayEvents, function(a, b)
                            local timeA = (a.hour or 0) * 60 + (a.minute or 0)
                            local timeB = (b.hour or 0) * 60 + (b.minute or 0)
                            return timeA < timeB
                        end)
                        
                        for i = 1, math.min(3, #todayEvents) do
                            local event = todayEvents[i]
                            local timeStr = string.format("%02d:%02d", event.hour or 0, event.minute or 0)
                            GameTooltip:AddLine(string.format("  %s - %s", timeStr, event.title), 0.7, 0.7, 1)
                        end
                        
                        if #todayEvents > 3 then
                            GameTooltip:AddLine(string.format("  ... 외 %d개", #todayEvents - 3), 0.5, 0.5, 0.5)
                        end
                    end
                end
            end
            
            GameTooltip:Show()
        end)
        
        button:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        -- 주기적으로 미니맵 모양 체크 (Classic에는 MINIMAP_UPDATE_SHAPE 이벤트가 없음)
        local lastShape = nil
        button:SetScript("OnUpdate", function(self, elapsed)
            -- 드래그 중일 때는 스킵
            if self.isMoving then return end

            self.shapeTimer = (self.shapeTimer or 0) + elapsed
            if self.shapeTimer > 1 then  -- 1초마다 체크
                self.shapeTimer = 0
                local currentShape = getShape()
                if currentShape ~= lastShape then
                    lastShape = currentShape
                    UpdatePosition()
                end
            end
        end)

        -- 표시/숨김
        if addon.db.settings.minimap.hide then
            button:Hide()
        else
            button:Show()
        end
        
    addon.minimapButton = button
    addon:Print("미니맵 버튼이 생성되었습니다.")
end

-- 옵션 메뉴
function addon:ShowOptionsMenu(anchor)
    local menu = CreateFrame("Frame", "FoxGuildCalOptionsMenu", UIParent, "UIDropDownMenuTemplate")
    
    local menuItems = {
        {
            text = "FoxGuildCal 옵션",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "캘린더 열기",
            notCheckable = true,
            func = function()
                addon:ToggleCalendar()
            end,
        },
        {
            text = "오늘 일정 동기화",
            notCheckable = true,
            func = function()
                addon:StartSync()
                addon:Print("동기화를 시작합니다...")
            end,
        },
        {
            text = " ",
            disabled = true,
            notCheckable = true,
        },
        {
            text = "미니맵 버튼 잠금",
            checked = addon.db.settings.minimap.lock,
            func = function()
                addon.db.settings.minimap.lock = not addon.db.settings.minimap.lock
                if addon.db.settings.minimap.lock then
                    addon:Print("미니맵 버튼이 잠겼습니다.")
                else
                    addon:Print("미니맵 버튼 잠금이 해제되었습니다. Shift+드래그로 이동 가능합니다.")
                end
            end,
        },
        {
            text = "미니맵 버튼 숨기기",
            checked = addon.db.settings.minimap.hide,
            func = function()
                addon.db.settings.minimap.hide = not addon.db.settings.minimap.hide
                if addon.minimapButton then
                    if addon.db.settings.minimap.hide then
                        addon.minimapButton:Hide()
                        addon:Print("미니맵 버튼이 숨겨졌습니다. /foxcal show 명령으로 다시 표시할 수 있습니다.")
                    else
                        addon.minimapButton:Show()
                    end
                end
            end,
        },
        {
            text = " ",
            disabled = true,
            notCheckable = true,
        },
        {
            text = "자동 동기화",
            checked = addon.db.settings.sync.autoSync,
            func = function()
                addon.db.settings.sync.autoSync = not addon.db.settings.sync.autoSync
                if addon.db.settings.sync.autoSync then
                    addon:Print("자동 동기화가 활성화되었습니다.")
                else
                    addon:Print("자동 동기화가 비활성화되었습니다.")
                end
            end,
        },
        {
            text = " ",
            disabled = true,
            notCheckable = true,
        },
        {
            text = "닫기",
            notCheckable = true,
            func = function()
                CloseDropDownMenus()
            end,
        },
    }
    
    EasyMenu(menuItems, menu, anchor, 0, 0, "MENU")
end

-- 슬래시 명령어
SLASH_FOXGUILDCAL1 = "/foxcal"
SLASH_FOXGUILDCAL2 = "/fgc"

SlashCmdList["FOXGUILDCAL"] = function(msg)
    local cmd = msg:lower()
    
    -- 디버그: 명령어 확인
    if not addon then
        print("|cffff0000[FoxGuildCal] 애드온 객체를 찾을 수 없습니다.|r")
        return
    end
    
    if cmd == "show" then
        if addon.minimapButton then
            addon.minimapButton:Show()
            addon.db.settings.minimap.hide = false
            addon:Print("미니맵 버튼이 표시됩니다.")
        end
    elseif cmd == "hide" then
        if addon.minimapButton then
            addon.minimapButton:Hide()
            addon.db.settings.minimap.hide = true
            addon:Print("미니맵 버튼이 숨겨졌습니다.")
        end
    elseif cmd == "lock" then
        addon.db.settings.minimap.lock = not addon.db.settings.minimap.lock
        if addon.db.settings.minimap.lock then
            addon:Print("미니맵 버튼이 잠겼습니다.")
        else
            addon:Print("미니맵 버튼 잠금이 해제되었습니다.")
        end
    elseif cmd == "sync" then
        addon:Print("동기화를 시작합니다...")
        addon:StartSync(true)  -- true는 수동 동기화를 의미
    elseif cmd == "metrics" or cmd == "stats" then
        -- 동기화 메트릭스 표시
        if addon.GetSyncMetrics then
            local metrics = addon:GetSyncMetrics()
            addon:Print("=== 동기화 통계 ===")
            print(string.format("  성공률: %.1f%%", metrics.successRate * 100))
            print(string.format("  평균 동기화 시간: %.1f초", metrics.averageSyncTime))
            print(string.format("  총 동기화 횟수: %d", metrics.totalSyncs))
            print(string.format("  평균 네트워크 지연: %.0fms", metrics.averageLatency))

            if metrics.recentHistory and #metrics.recentHistory > 0 then
                print("  최근 동기화 이력:")
                for i = 1, math.min(5, #metrics.recentHistory) do
                    local entry = metrics.recentHistory[i]
                    local timeStr = date("%H:%M:%S", entry.timestamp)
                    print(string.format("    [%s] %s (%d개 타겟)", timeStr, entry.event, entry.targets))
                end
            end
        else
            addon:Print("동기화 메트릭스를 사용할 수 없습니다.")
        end
    elseif cmd == "help" then
        addon:Print("명령어:")
        print("  /foxcal - 캘린더 열기")
        print("  /foxcal show - 미니맵 버튼 표시")
        print("  /foxcal hide - 미니맵 버튼 숨기기")
        print("  /foxcal lock - 미니맵 버튼 잠금 토글")
        print("  /foxcal sync - 수동 동기화")
        print("  /foxcal metrics - 동기화 통계 보기")
        print("  /foxcal help - 도움말")
    else
        -- 빈 명령어 또는 기타 명령어면 캘린더 토글
        if addon.ToggleCalendar then
            addon:ToggleCalendar()
        else
            addon:Print("캘린더 기능을 찾을 수 없습니다.")
        end
    end
end

-- addon 네임스페이스에 함수 노출
addon.InitializeMinimapButton = InitializeMinimapButton

-- 초기화 확인
local initialized = false
local function EnsureInitialized()
    if initialized then return end
    if not addon.db then
        C_Timer.After(0.5, EnsureInitialized)
        return
    end
    initialized = true
    InitializeMinimapButton()
end

-- 애드온 로드 시 초기화
C_Timer.After(1, EnsureInitialized)