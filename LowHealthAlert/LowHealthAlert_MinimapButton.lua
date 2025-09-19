local addonName, addon = ...
local L = addon.L

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

-- 미니맵 버튼 생성
function LowHealthAlert.CreateMinimapButton()
    if minimapButton then return minimapButton end

    -- 미니맵 버튼 생성
    minimapButton = CreateFrame("Button", "LowHealthAlertMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 배경
    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    background:SetPoint("TOPLEFT", 6, -6)

    -- 아이콘 (하트 아이콘 사용)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\Icons\\INV_ValentinesBoxOfChocolates02")
    icon:SetPoint("TOPLEFT", 7, -7)

    -- 테두리
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    -- 위치 업데이트 함수 (모양 인식 + 가장자리 투영)
    local function UpdateMinimapPosition()
        if not LowHealthAlertDB.minimapButton then
            LowHealthAlertDB.minimapButton = {
                hide = false,
                minimapPos = 45,
                radius = 80
            }
        end

        if LowHealthAlertDB.minimapButton.hide then
            minimapButton:Hide()
            return
        else
            minimapButton:Show()
        end

        local angle = LowHealthAlertDB.minimapButton.minimapPos or 45
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

    -- 드래그 이벤트
    minimapButton:RegisterForDrag("LeftButton", "RightButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))

            if not LowHealthAlertDB.minimapButton then
                LowHealthAlertDB.minimapButton = {
                    hide = false,
                    minimapPos = 45,
                    radius = 80
                }
            end
            LowHealthAlertDB.minimapButton.minimapPos = angle
            UpdateMinimapPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- 클릭 이벤트
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- 설정창 열기
            if LowHealthAlert.OpenConfig then
                LowHealthAlert.OpenConfig()
            end
        elseif button == "RightButton" then
            -- 활성화/비활성화 토글
            LowHealthAlertDB.enabled = not LowHealthAlertDB.enabled
            if LowHealthAlertDB.enabled then
                print(L["ADDON_ENABLED"] or "|cff00ff00Low Health Alert: Enabled|r")
            else
                print(L["ADDON_DISABLED"] or "|cffff0000Low Health Alert: Disabled|r")
            end
            LowHealthAlert.CheckHealth()
        end
    end)

    -- 툴팁
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Low Health Alert", 1, 1, 1)
        if LowHealthAlertDB.enabled then
            GameTooltip:AddLine(L["STATUS_ENABLED"] or "Status: |cff00ff00Enabled|r", 1, 1, 1)
        else
            GameTooltip:AddLine(L["STATUS_DISABLED"] or "Status: |cffff0000Disabled|r", 1, 1, 1)
        end
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(L["LEFT_CLICK_CONFIG"] or "Left Click: Open Config", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["RIGHT_CLICK_TOGGLE"] or "Right Click: Toggle On/Off", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["DRAG_TO_MOVE"] or "Drag: Move Button", 0.7, 0.7, 0.7)
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

    UpdateMinimapPosition()
    return minimapButton
end

-- 미니맵 버튼 표시/숨기기
function LowHealthAlert.UpdateMinimapButton()
    if minimapButton then
        if LowHealthAlertDB.minimapButton and LowHealthAlertDB.minimapButton.hide then
            minimapButton:Hide()
        else
            minimapButton:Show()
        end
    end
end