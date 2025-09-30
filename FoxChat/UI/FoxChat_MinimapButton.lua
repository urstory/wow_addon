local addonName, addon = ...

-- 미니맵 버튼 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.MinimapButton = {}

local MinimapButton = FoxChat.UI.MinimapButton
local L = addon.L

-- 미니맵 버튼 변수
local button = nil
local lastShape = nil

-- 미니맵 모양 테이블 (Classic)
local MinimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

-- 유틸리티 함수
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

-- 초기화
function MinimapButton:Initialize()
    self:CreateButton()
    self:UpdatePosition()

    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            self:UpdatePosition()
        end)

        FoxChat.Events:Register("FOXCHAT_MINIMAP_UPDATE", function()
            self:UpdatePosition()
        end)
    end
end

-- 버튼 생성
function MinimapButton:CreateButton()
    if button then return end

    -- 미니맵 버튼 프레임
    button = CreateFrame("Button", "FoxChatMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 버튼 아이콘 (중앙의 오렌지색 원)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    icon:SetVertexColor(1, 0.5, 0, 0.9)

    -- FC 텍스트 라벨
    local fcText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fcText:SetText("|cFFFFFFFFFC|r")
    fcText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    fcText:SetJustifyH("CENTER")
    fcText:SetJustifyV("MIDDLE")
    fcText:SetPoint("CENTER", 0, -1)

    -- 테두리
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("CENTER", 0, 0)
    border:SetSize(28, 28)
    border:SetVertexColor(1, 0.9, 0.6, 1)  -- 금색 테두리

    -- 드래그 기능
    button:RegisterForDrag("LeftButton", "RightButton")
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale

            local angle = math.deg(math.atan2(py - my, px - mx))

            if FoxChatDB then
                FoxChatDB.minimapButton = FoxChatDB.minimapButton or {}
                FoxChatDB.minimapButton.minimapPos = angle
                MinimapButton:UpdatePosition()
            end
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)

        -- 다시 주기적 체크 활성화
        self.timer = 0
        self:SetScript("OnUpdate", MinimapButton.OnUpdate)
    end)

    -- 클릭 이벤트
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            MinimapButton:ToggleFilter()

            -- 툴팁 업데이트
            if GameTooltip:IsVisible() and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
                self:GetScript("OnEnter")(self)
            end
        elseif btn == "RightButton" then
            MinimapButton:OpenConfig()
        end
    end)

    -- 툴팁
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("FoxChat", 1, 1, 1)

        if FoxChatDB and FoxChatDB.filterEnabled then
            GameTooltip:AddLine(L["FILTER_STATUS_ENABLED"], 0, 1, 0)
        else
            GameTooltip:AddLine(L["FILTER_STATUS_DISABLED"], 1, 0, 0)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["LEFT_CLICK_TOGGLE_FILTER"], 1, 1, 1)
        GameTooltip:AddLine(L["RIGHT_CLICK_CONFIG"], 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 주기적으로 미니맵 모양 체크
    button.timer = 0
    button:SetScript("OnUpdate", self.OnUpdate)
end

-- OnUpdate 핸들러
function MinimapButton.OnUpdate(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 1 then  -- 1초마다 체크
        self.timer = 0
        local currentShape = getShape()
        if currentShape ~= lastShape then
            lastShape = currentShape
            MinimapButton:UpdatePosition()
        end
    end
end

-- 위치 업데이트
function MinimapButton:UpdatePosition()
    if not button then return end

    -- 설정 확인
    local settings = {}
    if FoxChatDB and FoxChatDB.minimapButton then
        settings = FoxChatDB.minimapButton
    else
        settings = {
            hide = false,
            minimapPos = 180,
            radius = 80
        }
    end

    if settings.hide then
        button:Hide()
        return
    else
        button:Show()
    end

    local angle = math.rad(settings.minimapPos or 180)
    local padding = 6  -- 미니맵 테두리로부터의 여유 공간

    -- 반지름: 미니맵 절반 + 여유 패딩
    local r = (Minimap:GetWidth() / 2) + padding

    -- 방향 벡터
    local dx, dy = math.cos(angle), math.sin(angle)

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
        local maxc = math.max(math.abs(dx), math.abs(dy))
        factor = r / (maxc > 0 and maxc or 1e-6)
    end

    local x, y = dx * factor, dy * factor

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- 버튼 표시/숨김
function MinimapButton:Show()
    if button then
        button:Show()
        if FoxChatDB then
            FoxChatDB.minimapButton = FoxChatDB.minimapButton or {}
            FoxChatDB.minimapButton.hide = false
        end
    end
end

function MinimapButton:Hide()
    if button then
        button:Hide()
        if FoxChatDB then
            FoxChatDB.minimapButton = FoxChatDB.minimapButton or {}
            FoxChatDB.minimapButton.hide = true
        end
    end
end

function MinimapButton:Toggle()
    if button then
        if button:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

-- 필터 토글
function MinimapButton:ToggleFilter()
    if FoxChatDB then
        FoxChatDB.filterEnabled = not FoxChatDB.filterEnabled

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_FILTER_TOGGLE", FoxChatDB.filterEnabled)
        end

        -- 메시지 출력
        if FoxChatDB.filterEnabled then
            FoxChat:Print(L["FILTER_ENABLED"])
        else
            FoxChat:Print(L["FILTER_DISABLED"])
        end
    end
end

-- 설정창 열기
function MinimapButton:OpenConfig()
    -- 이벤트 발생
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_CONFIG_SHOW")
    end

    -- UI 모듈이 로드되어 있으면 직접 호출
    if FoxChat.UI.Config and FoxChat.UI.Config.Show then
        FoxChat.UI.Config:Show()
    else
        FoxChat:Print("설정창이 아직 로드되지 않았습니다.")
    end
end

-- 위치 설정
function MinimapButton:SetPosition(angle)
    if FoxChatDB then
        FoxChatDB.minimapButton = FoxChatDB.minimapButton or {}
        FoxChatDB.minimapButton.minimapPos = angle or 180
        self:UpdatePosition()
    end
end

-- 현재 위치 가져오기
function MinimapButton:GetPosition()
    if FoxChatDB and FoxChatDB.minimapButton then
        return FoxChatDB.minimapButton.minimapPos or 180
    end
    return 180
end