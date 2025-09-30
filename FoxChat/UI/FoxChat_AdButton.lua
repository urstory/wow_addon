local addonName, addon = ...

-- 광고 버튼 UI 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.AdButton = {}

local AdButton = FoxChat.UI.AdButton
local L = addon.L

-- 버튼 변수
local button = nil
local isDragging = false
local cooldown = nil

-- 초기화
function AdButton:Initialize()
    self:CreateButton()
    self:UpdatePosition()
    self:UpdateState()

    -- 이벤트 등록
    if FoxChat.Events then
        -- 설정 로드
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            self:UpdatePosition()
            self:UpdateState()
        end)

        -- 쿨다운 이벤트
        FoxChat.Events:Register("FOXCHAT_AD_COOLDOWN_START", function(startTime, duration)
            self:StartCooldown(startTime, duration)
        end)

        FoxChat.Events:Register("FOXCHAT_AD_COOLDOWN_END", function()
            self:EndCooldown()
        end)

        FoxChat.Events:Register("FOXCHAT_AD_COOLDOWN_RESET", function()
            self:EndCooldown()
        end)

        -- 그룹 변경 이벤트
        FoxChat.Events:Register("GROUP_ROSTER_UPDATE", function()
            self:UpdateState()
        end)
    end

    FoxChat:Debug("AdButton 모듈 초기화 완료")
end

-- 버튼 생성
function AdButton:CreateButton()
    if button then return end

    -- 광고 버튼 프레임
    button = CreateFrame("Button", "FoxChatAdButton", UIParent)
    button:SetSize(60, 60)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(100)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:Hide()  -- 기본적으로 숨김

    -- 버튼 아이콘
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Horn_01")  -- 나팔 아이콘

    -- 버튼 테두리
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", 5, -5)

    -- 쿨다운 오버레이
    cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    button.cooldown = cooldown

    -- 드래그 설정
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
            isDragging = true
        end
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        isDragging = false
        AdButton:SavePosition()

        -- 선입 버튼 위치도 업데이트
        if FoxChat.UI.FirstComeButton then
            FoxChat.UI.FirstComeButton:UpdateRelativePosition()
        end
    end)

    -- 드래그 중 실시간 업데이트
    button:SetScript("OnUpdate", function(self)
        if isDragging then
            AdButton:SavePosition()

            -- 설정창 EditBox 업데이트
            AdButton:UpdateConfigUI()

            -- 선입 버튼도 함께 이동
            if FoxChat.UI.FirstComeButton then
                FoxChat.UI.FirstComeButton:UpdateRelativePosition()
            end
        end
    end)

    -- 클릭 이벤트
    button:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            -- 우클릭: 설정창 열기
            AdButton:OpenConfig()
        elseif btn == "LeftButton" then
            -- 좌클릭: 광고 전송
            AdButton:SendAdvertisement()
        end
    end)

    -- 툴팁
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("광고 전송", 1, 1, 1)
        GameTooltip:AddLine("파티찾기 채널에 광고 메시지를 전송합니다.", 0.8, 0.8, 0.8, true)

        if FoxChatDB and FoxChatDB.adMessage and FoxChatDB.adMessage ~= "" then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("메시지:", 1, 0.8, 0)
            GameTooltip:AddLine(FoxChatDB.adMessage, 0.8, 0.8, 0.8, true)
        end

        local cooldownTime = FoxChatDB and FoxChatDB.adCooldown or 30
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("쿨다운: " .. cooldownTime .. "초", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Shift+드래그: 위치 이동", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFF6060우클릭: 설정창 열기|r", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- 위치 업데이트
function AdButton:UpdatePosition()
    if not button then return end

    local x = 350
    local y = -150

    if FoxChatDB and FoxChatDB.adPosition then
        x = FoxChatDB.adPosition.x or x
        y = FoxChatDB.adPosition.y or y
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- 현재 위치 저장
function AdButton:SavePosition()
    if not button then return end

    local centerX, centerY = button:GetCenter()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local x = centerX - (screenWidth / 2)
    local y = centerY - (screenHeight / 2)

    if FoxChatDB then
        FoxChatDB.adPosition = FoxChatDB.adPosition or {}
        FoxChatDB.adPosition.x = x
        FoxChatDB.adPosition.y = y
    end

    -- 위치 변경 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_AD_BUTTON_POSITION_CHANGED", x, y)
    end
end

-- 상태 업데이트
function AdButton:UpdateState()
    if not button then return end

    -- 광고 기능 활성화 여부 확인
    if not FoxChatDB or not FoxChatDB.adEnabled then
        button:Hide()
        return
    end

    -- 메시지 설정 여부 확인
    local message = FoxChatDB.adMessage or ""
    if FoxChat.Utils and FoxChat.Utils.Common then
        if FoxChat.Utils.Common:IsEmptyOrWhitespace(message) then
            button:Hide()
            return
        end
    elseif message == "" then
        button:Hide()
        return
    end

    -- 자동 중지 기능 (파티 가득 참)
    if FoxChat.Features and FoxChat.Features.Advertisement then
        if FoxChat.Features.Advertisement:IsPartyFull() then
            button:Hide()
            return
        end
    end

    -- 쿨다운 체크
    if FoxChat.Features and FoxChat.Features.Advertisement then
        if FoxChat.Features.Advertisement:IsOnCooldown() then
            -- 쿨다운 중에는 숨김 (쿨다운 UI는 표시)
            button:Hide()
            return
        end
    end

    -- 모든 조건 통과: 버튼 표시
    button:Show()
end

-- 쿨다운 시작
function AdButton:StartCooldown(startTime, duration)
    if not button or not cooldown then return end

    cooldown:SetCooldown(startTime, duration)
    button:Hide()
end

-- 쿨다운 종료
function AdButton:EndCooldown()
    if not button then return end

    self:UpdateState()
end

-- 광고 전송
function AdButton:SendAdvertisement()
    if FoxChat.Features and FoxChat.Features.Advertisement then
        FoxChat.Features.Advertisement:SendAdvertisement()
    else
        -- 폴백: 이벤트로 전송 요청
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_SEND_ADVERTISEMENT")
        end
    end
end

-- 설정창 열기
function AdButton:OpenConfig()
    -- 설정창 열기 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_CONFIG_SHOW")
    end

    -- 광고 탭으로 전환
    C_Timer.After(0.1, function()
        local configFrame = _G["FoxChatConfigFrame"]
        if configFrame and configFrame.SelectTab then
            configFrame:SelectTab(3)  -- 3번 탭 = 광고 설정
        end
    end)
end

-- 설정창 UI 업데이트
function AdButton:UpdateConfigUI()
    if not button then return end

    local centerX, centerY = button:GetCenter()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local x = centerX - (screenWidth / 2)
    local y = centerY - (screenHeight / 2)

    -- 설정창 EditBox 업데이트
    local configFrame = _G["FoxChatConfigFrame"]
    if configFrame then
        local adXEditBox = configFrame.adXEditBox
        local adYEditBox = configFrame.adYEditBox

        if adXEditBox then
            adXEditBox:SetText(tostring(math.floor(x + 0.5)))
        end
        if adYEditBox then
            adYEditBox:SetText(tostring(math.floor(y + 0.5)))
        end
    end
end

-- 위치 설정
function AdButton:SetPosition(x, y)
    if FoxChatDB then
        FoxChatDB.adPosition = FoxChatDB.adPosition or {}
        FoxChatDB.adPosition.x = x or 350
        FoxChatDB.adPosition.y = y or -150
        self:UpdatePosition()
    end
end

-- 현재 위치 가져오기
function AdButton:GetPosition()
    if FoxChatDB and FoxChatDB.adPosition then
        return FoxChatDB.adPosition.x or 350, FoxChatDB.adPosition.y or -150
    end
    return 350, -150
end

-- 표시/숨김
function AdButton:Show()
    if button then
        self:UpdateState()
    end
end

function AdButton:Hide()
    if button then
        button:Hide()
    end
end

function AdButton:IsShown()
    return button and button:IsShown()
end