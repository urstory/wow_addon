local addonName, addon = ...
LowHealthAlert = addon

local frame = CreateFrame("Frame")
local macroButton = nil
local flashFrame = nil
local isFlashing = false
local isTestMode = false  -- 테스트 모드 플래그

local defaults = {
    macroText = "/use 치유 물약",
    threshold = 0.35,
    enabled = true,
    useFlash = true,
    flashIntensity = 0.5,  -- 깜빡임 강도 (0.1 ~ 1.0)
    buttonX = 100,
    buttonY = 0,
    buttonIcon = "Interface\\Icons\\INV_Potion_54"
}

local function CreateMacroButton()
    -- 이미 버튼이 있으면 위치만 업데이트하고 리턴
    if macroButton then 
        local x = LowHealthAlertDB.buttonX or defaults.buttonX
        local y = LowHealthAlertDB.buttonY or defaults.buttonY
        macroButton:ClearAllPoints()
        macroButton:SetPoint("CENTER", UIParent, "CENTER", x, y)
        return macroButton
    end
    
    -- 글로벌 이름 없이 생성 (중복 방지)
    macroButton = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    macroButton:SetSize(64, 64)
    
    -- 저장된 위치 사용
    local x = LowHealthAlertDB.buttonX or defaults.buttonX
    local y = LowHealthAlertDB.buttonY or defaults.buttonY
    macroButton:SetPoint("CENTER", UIParent, "CENTER", x, y)
    
    -- 아이콘 설정 (크기를 더욱 작게 조정)
    local iconTexture = LowHealthAlertDB.buttonIcon or defaults.buttonIcon
    local icon = macroButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)  -- 아이콘 테두리를 더 많이 자르기
    icon:SetSize(36, 36)  -- 아이콘을 36x36으로 더 작게
    icon:SetPoint("CENTER", macroButton, "CENTER", 0, 0)
    macroButton.icon = icon  -- 나중에 참조하기 위해 저장
    
    -- 테두리 설정
    local border = macroButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetSize(64, 64)
    border:SetPoint("CENTER", macroButton, "CENTER", 0, 0)
    
    -- 누를 때 효과 (투명 텍스처 사용)
    macroButton:SetNormalTexture("")  -- 빈 normal texture
    macroButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    macroButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    
    -- 하이라이트와 푸시 텍스처 크기 조정
    local pushed = macroButton:GetPushedTexture()
    if pushed then
        pushed:SetSize(64, 64)
        pushed:SetPoint("CENTER", 0, 0)
    end
    
    local highlight = macroButton:GetHighlightTexture()
    if highlight then
        highlight:SetSize(64, 64)
        highlight:SetPoint("CENTER", 0, 0)
    end
    
    local cooldown = CreateFrame("Cooldown", nil, macroButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints(macroButton)
    
    macroButton:SetAttribute("type", "macro")
    macroButton:SetAttribute("macrotext", LowHealthAlertDB.macroText or defaults.macroText)
    
    macroButton:EnableMouse(true)
    macroButton:RegisterForClicks("AnyUp")
    
    -- 전투 전에 미리 표시해두고 숨기기 (전투 중 표시 제한 회피)
    macroButton:Show()
    macroButton:SetAlpha(0)
    macroButton:EnableMouse(false)  -- 투명할 때는 클릭 비활성화
    
    -- 위치 조정을 위한 드래그 기능 (설정 모드에서만)
    macroButton:SetMovable(true)
    macroButton:RegisterForDrag("LeftButton")
    macroButton:SetScript("OnDragStart", function(self)
        -- 보이는 상태에서만 드래그 가능
        if IsShiftKeyDown() and self:GetAlpha() > 0 then
            self:StartMoving()
        end
    end)
    macroButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        LowHealthAlertDB.buttonX = x
        LowHealthAlertDB.buttonY = y
    end)
    
    return macroButton
end

local function CreateFlashFrame()
    if flashFrame then return flashFrame end
    
    flashFrame = CreateFrame("Frame", "LowHealthAlertFlash", UIParent)
    flashFrame:SetAllPoints(UIParent)
    flashFrame:SetFrameStrata("FULLSCREEN")
    flashFrame:SetAlpha(0)
    
    local texture = flashFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(flashFrame)
    texture:SetColorTexture(1, 0, 0, 0.3)
    
    flashFrame.texture = texture
    flashFrame:Hide()
    
    return flashFrame
end

local function StartFlashing()
    if isFlashing then return end
    isFlashing = true
    
    if not flashFrame then
        CreateFlashFrame()
    end
    
    flashFrame:Show()
    
    local elapsed = 0
    flashFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        -- 깜빡임 강도를 설정값에 따라 조절
        local intensity = LowHealthAlertDB.flashIntensity or defaults.flashIntensity
        local alpha = (math.sin(elapsed * 6) + 1) / 4 * intensity
        self:SetAlpha(math.min(alpha, intensity))
    end)
end

local function StopFlashing()
    if not isFlashing then return end
    isFlashing = false
    
    if flashFrame then
        flashFrame:SetScript("OnUpdate", nil)
        flashFrame:SetAlpha(0)
        flashFrame:Hide()
    end
end

local function CheckHealth()
    -- 테스트 모드 중에는 체력 체크 건너뛰기
    if isTestMode then
        return
    end
    
    if LowHealthAlertDB.enabled == false then
        return
    end
    
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    local healthPercent = health / maxHealth
    
    if healthPercent <= (LowHealthAlertDB.threshold or defaults.threshold) then
        if not macroButton then
            CreateMacroButton()
        end
        -- 전투 중에는 Show/Hide 대신 Alpha 사용
        macroButton:SetAlpha(1)
        macroButton:EnableMouse(true)  -- 보일 때만 클릭 가능
        if LowHealthAlertDB.useFlash ~= false then
            StartFlashing()
        end
    else
        if macroButton then
            -- 전투 중에는 Show/Hide 대신 Alpha 사용
            macroButton:SetAlpha(0)
            macroButton:EnableMouse(false)  -- 투명할 때는 클릭 비활성화
        end
        StopFlashing()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_HEALTH_FREQUENT")  -- 더 자주 체력 체크
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")  -- 추가 체력 체크 이벤트

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LowHealthAlertDB = LowHealthAlertDB or {}
        for k, v in pairs(defaults) do
            if LowHealthAlertDB[k] == nil then
                LowHealthAlertDB[k] = v
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- 버튼이 없을 때만 생성
        if not macroButton then
            CreateMacroButton()
        end
        CreateFlashFrame()
        -- 미니맵 버튼 생성
        if LowHealthAlert.CreateMinimapButton then
            LowHealthAlert.CreateMinimapButton()
        end
        CheckHealth()
        -- 주기적인 체력 체크 타이머 추가
        if not frame.healthTicker then
            frame.healthTicker = C_Timer.NewTicker(0.5, function()
                CheckHealth()
            end)
        end
    elseif event == "UNIT_HEALTH" and arg1 == "player" then
        CheckHealth()
    elseif event == "UNIT_HEALTH_FREQUENT" and arg1 == "player" then
        CheckHealth()
    end
end)

-- 기존 CreateOptionsPanel 함수는 더 이상 사용하지 않음 (SimpleConfig로 대체)
local optionsPanel = nil

-- 외부 파일에서 호출 가능한 함수들
function LowHealthAlert.TestMode()
    local L = addon.L
    -- 이미 테스트 모드 중이면 무시
    if isTestMode then
        print(L["TEST_MODE_ACTIVE"])
        return
    end
    
    isTestMode = true  -- 테스트 모드 시작
    
    if not macroButton then
        CreateMacroButton()
    end
    macroButton:SetAlpha(1)
    macroButton:EnableMouse(true)  -- 테스트 모드에서는 클릭 가능
    if LowHealthAlertDB.useFlash ~= false then
        StartFlashing()
    end
    
    -- 테스트 모드 동안 이동 가능 메시지
    print(L["TEST_MODE_START"])
    
    -- 10초 후 종료
    C_Timer.After(10, function()
        isTestMode = false  -- 테스트 모드 종료
        if macroButton then
            macroButton:SetAlpha(0)
            macroButton:EnableMouse(false)  -- 테스트 종료 시 클릭 비활성화
        end
        StopFlashing()
        print(L["TEST_MODE_END"])
        CheckHealth()  -- 테스트 후 정상 체력 체크 재개
    end)
end

function LowHealthAlert.CheckHealth()
    CheckHealth()
end

function LowHealthAlert.UpdateMacro(text)
    local L = addon.L
    if macroButton then
        -- 전투 중이 아닐 때만 매크로 업데이트
        if not InCombatLockdown() then
            macroButton:SetAttribute("macrotext", text)
            print(L["MACRO_UPDATED"])
        else
            print(L["COMBAT_MACRO_ERROR"])
        end
    end
end

function LowHealthAlert.HideButton()
    if macroButton then
        macroButton:SetAlpha(0)
        macroButton:EnableMouse(false)  -- 숨길 때 클릭도 비활성화
    end
end

function LowHealthAlert.StopFlashing()
    StopFlashing()
end

function LowHealthAlert.UpdateButtonPosition()
    if macroButton then
        local x = LowHealthAlertDB.buttonX or defaults.buttonX
        local y = LowHealthAlertDB.buttonY or defaults.buttonY
        macroButton:ClearAllPoints()
        macroButton:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

function LowHealthAlert.UpdateButtonIcon(iconPath)
    if macroButton and iconPath then
        LowHealthAlertDB.buttonIcon = iconPath
        if macroButton.icon then
            macroButton.icon:SetTexture(iconPath)
            macroButton.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
            macroButton.icon:SetSize(36, 36)
        end
    end
end

-- 애드온 로드 시 초기화 메시지만 표시
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- 한 번만 실행되도록
        self:UnregisterEvent("PLAYER_LOGIN")
        -- 메시지 출력 제거 (Commands.lua에서 한 번만 출력)
    end
end)