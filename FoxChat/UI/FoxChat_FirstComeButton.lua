local addonName, addon = ...

-- 선입 버튼 UI 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.FirstComeButton = {}

local FirstComeButton = FoxChat.UI.FirstComeButton
local L = addon.L

-- 버튼 관련 변수
local buttonFrame = nil
local cooldownFrame = nil
local isMovable = false
local cooldownText = nil

-- 초기화
function FirstComeButton:Initialize()
    -- 버튼 생성
    self:CreateButton()
    
    -- 이벤트 등록
    self:RegisterEvents()
    
    -- 초기 상태 업데이트
    self:UpdateState()
    
    FoxChat:Debug("FirstComeButton 모듈 초기화 완료")
end

-- 버튼 생성
function FirstComeButton:CreateButton()
    -- 메인 버튼 프레임
    buttonFrame = CreateFrame("Button", "FoxChatFirstComeButton", UIParent, "SecureActionButtonTemplate")
    buttonFrame:SetSize(40, 40)
    buttonFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    buttonFrame:SetMovable(true)
    buttonFrame:EnableMouse(true)
    buttonFrame:RegisterForClicks("AnyUp")
    buttonFrame:SetFrameStrata("MEDIUM")
    buttonFrame:SetClampedToScreen(true)
    
    -- 배경
    buttonFrame:SetNormalTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    buttonFrame:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    buttonFrame:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    
    -- 쿨다운 프레임
    cooldownFrame = CreateFrame("Cooldown", nil, buttonFrame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints(buttonFrame)
    cooldownFrame:SetDrawEdge(true)
    cooldownFrame:SetHideCountdownNumbers(false)
    
    -- 쿨다운 텍스트 (추가 표시용)
    cooldownText = buttonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownText:SetPoint("CENTER", 0, 0)
    cooldownText:Hide()
    
    -- 툴팁
    buttonFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FIRSTCOME_BUTTON"] or "선입외치기", 1, 1, 1)
        
        local message = FoxChat.Features.FirstCome:GetMessage()
        if message and message ~= "" then
            GameTooltip:AddLine(message, 0.8, 0.8, 0.8, true)
        end
        
        if FoxChat.Features.FirstCome:IsOnCooldown() then
            local remaining = FoxChat.Features.FirstCome:GetCooldownRemaining()
            GameTooltip:AddLine(string.format("쿨다운: %.1f초", remaining), 1, 0, 0)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("좌클릭: 선입 메시지 전송", 0, 1, 0)
        GameTooltip:AddLine("우클릭: 설정 열기", 0, 1, 0)
        GameTooltip:AddLine("Shift+드래그: 버튼 이동", 0, 1, 0)
        
        GameTooltip:Show()
    end)
    
    buttonFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- 클릭 이벤트
    buttonFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- 선입 메시지 전송
            if FoxChat.Features and FoxChat.Features.FirstCome then
                FoxChat.Features.FirstCome:SendFirstComeMessage()
            end
        elseif button == "RightButton" then
            -- 설정창 열기
            if FoxChat.UI and FoxChat.UI.Config then
                FoxChat.UI.Config:Show()
                -- 선입 탭으로 전환 (있는 경우)
                if FoxChat.UI.TabSystem then
                    FoxChat.UI.TabSystem:SelectTab("firstcome")
                end
            end
        end
    end)
    
    -- 드래그 이벤트
    buttonFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            self:StartMoving()
            isMovable = true
        end
    end)
    
    buttonFrame:SetScript("OnMouseUp", function(self, button)
        if isMovable then
            self:StopMovingOrSizing()
            isMovable = false
            
            -- 위치 저장
            FirstComeButton:SavePosition()
        end
    end)
    
    -- 초기 위치 로드
    self:LoadPosition()
    
    -- 초기 숨김 (설정에 따라 표시)
    buttonFrame:Hide()
end

-- 이벤트 등록
function FirstComeButton:RegisterEvents()
    if FoxChat.Events then
        -- 쿨다운 시작
        FoxChat.Events:Register("FOXCHAT_FIRSTCOME_COOLDOWN_START", function(startTime, duration)
            self:StartCooldown(duration)
        end)
        
        -- 쿨다운 종료
        FoxChat.Events:Register("FOXCHAT_FIRSTCOME_COOLDOWN_END", function()
            self:EndCooldown()
        end)
        
        -- 쿨다운 리셋
        FoxChat.Events:Register("FOXCHAT_FIRSTCOME_COOLDOWN_RESET", function()
            self:EndCooldown()
        end)
        
        -- 설정 변경
        FoxChat.Events:Register("FOXCHAT_SETTINGS_CHANGED", function()
            self:UpdateState()
        end)
    end
    
    -- WoW 이벤트
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- Classic 호환
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        FirstComeButton:UpdateVisibility()
    end)
end

-- 쿨다운 시작
function FirstComeButton:StartCooldown(duration)
    if not cooldownFrame then return end
    
    local startTime = GetTime()
    cooldownFrame:SetCooldown(startTime, duration)
    
    -- 추가 쿨다운 텍스트 업데이트 (선택적)
    self:UpdateCooldownText()
end

-- 쿨다운 종료
function FirstComeButton:EndCooldown()
    if not cooldownFrame then return end
    
    cooldownFrame:Clear()
    
    if cooldownText then
        cooldownText:Hide()
    end
end

-- 쿨다운 텍스트 업데이트
function FirstComeButton:UpdateCooldownText()
    if not FoxChat.Features or not FoxChat.Features.FirstCome then return end
    
    if FoxChat.Features.FirstCome:IsOnCooldown() then
        local remaining = FoxChat.Features.FirstCome:GetCooldownRemaining()
        
        if remaining > 0 and cooldownText then
            cooldownText:SetText(string.format("%.0f", remaining))
            cooldownText:Show()
            
            -- 1초 후 다시 업데이트
            C_Timer.After(0.1, function()
                FirstComeButton:UpdateCooldownText()
            end)
        else
            if cooldownText then
                cooldownText:Hide()
            end
        end
    else
        if cooldownText then
            cooldownText:Hide()
        end
    end
end

-- 상태 업데이트
function FirstComeButton:UpdateState()
    -- 활성화 상태 확인
    local isEnabled = FoxChat.Features and FoxChat.Features.FirstCome and
                     FoxChat.Features.FirstCome:IsEnabled()
    
    -- 그룹 상태 확인
    local isInGroup = IsInGroup() or IsInRaid()
    
    -- 버튼 표시/숨김
    if isEnabled and isInGroup then
        self:Show()
    else
        self:Hide()
    end
end

-- 가시성 업데이트
function FirstComeButton:UpdateVisibility()
    self:UpdateState()
end

-- 버튼 표시
function FirstComeButton:Show()
    if buttonFrame then
        buttonFrame:Show()
    end
end

-- 버튼 숨기기
function FirstComeButton:Hide()
    if buttonFrame then
        buttonFrame:Hide()
    end
end

-- 위치 저장
function FirstComeButton:SavePosition()
    if not buttonFrame or not FoxChatDB then return end
    
    FoxChatDB.firstComeButton = FoxChatDB.firstComeButton or {}
    
    local point, _, relPoint, xOfs, yOfs = buttonFrame:GetPoint()
    FoxChatDB.firstComeButton.point = point
    FoxChatDB.firstComeButton.relPoint = relPoint
    FoxChatDB.firstComeButton.xOfs = xOfs
    FoxChatDB.firstComeButton.yOfs = yOfs
end

-- 위치 로드
function FirstComeButton:LoadPosition()
    if not buttonFrame or not FoxChatDB or not FoxChatDB.firstComeButton then return end
    
    local btn = FoxChatDB.firstComeButton
    if btn.point then
        buttonFrame:ClearAllPoints()
        buttonFrame:SetPoint(
            btn.point or "CENTER",
            UIParent,
            btn.relPoint or "CENTER",
            btn.xOfs or 0,
            btn.yOfs or 0
        )
    end
end

-- 위치 리셋
function FirstComeButton:ResetPosition()
    if buttonFrame then
        buttonFrame:ClearAllPoints()
        buttonFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self:SavePosition()
    end
end

-- 크기 설정
function FirstComeButton:SetSize(size)
    if buttonFrame then
        buttonFrame:SetSize(size, size)
        
        -- 설정 저장
        if FoxChatDB then
            FoxChatDB.firstComeButton = FoxChatDB.firstComeButton or {}
            FoxChatDB.firstComeButton.size = size
        end
    end
end

-- 크기 로드
function FirstComeButton:LoadSize()
    if buttonFrame and FoxChatDB and FoxChatDB.firstComeButton and FoxChatDB.firstComeButton.size then
        buttonFrame:SetSize(FoxChatDB.firstComeButton.size, FoxChatDB.firstComeButton.size)
    end
end

-- 테스트 함수
function FirstComeButton:Test()
    FoxChat:Print("선입 버튼 테스트")
    
    -- 임시로 버튼 표시
    self:Show()
    
    -- 5초 쿨다운 테스트
    self:StartCooldown(5)
    
    C_Timer.After(6, function()
        FoxChat:Print("쿨다운 종료")
        self:EndCooldown()
    end)
end