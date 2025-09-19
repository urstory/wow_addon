-- 미니맵 헬퍼 로드 (없으면 자체 구현)
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

local function CreateMinimapButton()
    -- Main button that handles BOTH clicks
    local button = CreateFrame("Button", "SimpleFindPartyMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetWidth(33)
    button:SetHeight(33)
    button:SetFrameLevel(8)
    button:SetToplevel(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Register for ALL clicks
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    -- Visual elements
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -6)

    local isDragging = false
    local mouseDownButton = nil

    -- Track which button was pressed down
    button:SetScript("OnMouseDown", function()
        -- In WoW 1.12, we need to check which button through a different method
        -- We'll track it using the current mouse button state
        local leftDown = IsMouseButtonDown("LeftButton")
        local rightDown = IsMouseButtonDown("RightButton")

        if leftDown then
            mouseDownButton = "LeftButton"
        elseif rightDown then
            mouseDownButton = "RightButton"
        end
    end)

    button:SetScript("OnDragStart", function()
        isDragging = true
        button:LockHighlight()
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale

            SimpleFindPartyDB.minimapPos = math.deg(math.atan2(py - my, px - mx))
            UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
        button:UnlockHighlight()
        isDragging = false
    end)

    button:SetScript("OnClick", function()
        if isDragging then
            mouseDownButton = nil
            return
        end

        -- Use the stored button from OnMouseDown
        if mouseDownButton == "RightButton" then
            -- Right click - toggle message frame
            if not SimpleFindPartyMessageFrame then
                InitializeMessageFrame()
            end
            if SimpleFindPartyMessageFrame then
                if SimpleFindPartyMessageFrame:IsShown() then
                    SimpleFindPartyMessageFrame:Hide()
                else
                    SimpleFindPartyMessageFrame:Show()
                end
            end
        else
            -- Left click (default) - toggle settings frame
            if not SimpleFindPartySettingsFrame then
                InitializeSettingsFrame()
            end
            if SimpleFindPartySettingsFrame then
                if SimpleFindPartySettingsFrame:IsShown() then
                    SimpleFindPartySettingsFrame:Hide()
                else
                    SimpleFindPartySettingsFrame:Show()
                end
            end
        end

        mouseDownButton = nil
    end)

    -- Tooltip handlers
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("SimpleFindParty")
        GameTooltip:AddLine("좌클릭: 설정창 열기", 1, 1, 1)
        GameTooltip:AddLine("우클릭: 메시지창 표시/숨기기", 1, 1, 1)
        GameTooltip:AddLine("좌클릭 드래그: 버튼 이동", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 주기적으로 미니맵 모양 체크 (Classic에는 MINIMAP_UPDATE_SHAPE 이벤트가 없음)
    local lastShape = nil
    button.shapeCheckTimer = 0
    local originalOnUpdate = button:GetScript("OnUpdate")

    button:SetScript("OnUpdate", function(self, elapsed)
        -- 기존 OnUpdate 처리 (드래그 등)
        if originalOnUpdate then
            originalOnUpdate(self, elapsed)
        end

        -- 드래그 중이면 스킵
        if isDragging then return end

        self.shapeCheckTimer = (self.shapeCheckTimer or 0) + elapsed
        if self.shapeCheckTimer > 1 then  -- 1초마다 체크
            self.shapeCheckTimer = 0
            local currentShape = getShape()
            if currentShape ~= lastShape then
                lastShape = currentShape
                UpdateMinimapButtonPosition()
            end
        end
    end)

    button:Show()
    return button
end

function UpdateMinimapButtonPosition()
    local button = SimpleFindPartyMinimapButton
    if not button then return end

    local angle = SimpleFindPartyDB.minimapPos or 45
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
    button:Show()
end

function InitializeMinimapButton()
    if not SimpleFindPartyMinimapButton then
        SimpleFindPartyMinimapButton = CreateMinimapButton()
    end
    UpdateMinimapButtonPosition()
end