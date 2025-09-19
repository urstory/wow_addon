local addonName, addon = ...
local L = addon.L

local configFrame = nil

local defaults = {
    enabled = true,
    barX = 0,
    barY = -200,
    barWidth = 200,
    barHeight = 20,
    showHealthBar = true,
    healthBarHeight = 15,
    flashHealthThreshold = 0.3,
    bearFormCost = 50,
    direBearFormCost = 50,
    catFormCost = 100,
    manaBarColor = {r = 0, g = 0.5, b = 1},
    manaBarEmptyColor = {r = 0.3, g = 0.3, b = 0.3},
    healthBarColor = {r = 0.8, g = 0.1, b = 0.1},
    bearLineColor = {r = 1, g = 1, b = 0},
    catLineColor = {r = 0, g = 0.5, b = 1},
}

function DruidManaBar:ShowConfig()
    if configFrame then
        configFrame:Show()
        configFrame:Raise()  -- 최상위로 올리기
        return
    end
    
    -- 메인 프레임
    configFrame = CreateFrame("Frame", "DruidManaBarConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(500, 700)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    
    -- 최상위 레벨 설정
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetFrameLevel(100)
    configFrame:SetToplevel(true)
    
    -- 배경
    configFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- 제목
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -20)
    title:SetText(L["CONFIG_TITLE"])

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "DruidManaBarConfigScrollFrame", configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -35, 60)

    -- 스크롤 내용 프레임
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(440, 900)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- 활성화 체크박스
    local enabledCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    enabledCheckbox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -5)
    enabledCheckbox.text = enabledCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledCheckbox.text:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
    enabledCheckbox.text:SetText(L["ENABLED"])
    enabledCheckbox:SetChecked(DruidManaBarDB.enabled)
    enabledCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.enabled = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    -- 체력 바 표시 체크박스
    local healthCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    healthCheckbox:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -10)
    healthCheckbox.text = healthCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    healthCheckbox.text:SetPoint("LEFT", healthCheckbox, "RIGHT", 5, 0)
    healthCheckbox.text:SetText(L["SHOW_HEALTH_BAR"])
    healthCheckbox:SetChecked(DruidManaBarDB.showHealthBar)
    healthCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showHealthBar = self:GetChecked()
        if DruidManaBar.UpdateBars then
            DruidManaBar:UpdateBars()
        end
    end)
    
    -- 버프 모니터링 체크박스
    local buffMonitorCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    buffMonitorCheckbox:SetPoint("TOPLEFT", healthCheckbox, "BOTTOMLEFT", 0, -10)
    buffMonitorCheckbox.text = buffMonitorCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    buffMonitorCheckbox.text:SetPoint("LEFT", buffMonitorCheckbox, "RIGHT", 5, 0)
    buffMonitorCheckbox.text:SetText("버프 모니터링 표시")
    buffMonitorCheckbox:SetChecked(DruidManaBarDB.showBuffMonitor ~= false)
    buffMonitorCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showBuffMonitor = self:GetChecked()
        if DruidManaBar.UpdateBars then
            DruidManaBar:UpdateBars()
        end
    end)

    -- 콤보 포인트 표시 체크박스
    local targetDebuffCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    targetDebuffCheckbox:SetPoint("TOPLEFT", buffMonitorCheckbox, "BOTTOMLEFT", 0, -5)
    targetDebuffCheckbox.text = targetDebuffCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    targetDebuffCheckbox.text:SetPoint("LEFT", targetDebuffCheckbox, "RIGHT", 5, 0)
    targetDebuffCheckbox.text:SetText("콤보 포인트 표시 (표범 폼)")
    targetDebuffCheckbox:SetChecked(DruidManaBarDB.showTargetDebuffs ~= false)
    targetDebuffCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showTargetDebuffs = self:GetChecked()
        if DruidManaBar.UpdateComboPoints then
            DruidManaBar:UpdateComboPoints()
        end
        if DruidManaBar.UpdateTargetDebuffs then
            DruidManaBar:UpdateTargetDebuffs()
        end
    end)
    
    -- 표시 모드 라벨
    local visibilityLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityLabel:SetPoint("TOPLEFT", targetDebuffCheckbox, "BOTTOMLEFT", 0, -15)
    visibilityLabel:SetText(L["VISIBILITY_MODE"])
    
    -- 표시 모드 드롭다운
    local visibilityDropdown = CreateFrame("Frame", "DruidManaBarVisibilityDropdown", scrollChild, "UIDropDownMenuTemplate")
    visibilityDropdown:SetPoint("LEFT", visibilityLabel, "RIGHT", 10, 0)
    
    local function VisibilityDropdown_OnClick(self)
        DruidManaBarDB.visibilityMode = self.value
        UIDropDownMenu_SetSelectedValue(visibilityDropdown, self.value)
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end
    
    local function VisibilityDropdown_Initialize()
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = L["VISIBILITY_ALWAYS"]
        info.value = "always"
        info.func = VisibilityDropdown_OnClick
        info.checked = DruidManaBarDB.visibilityMode == "always"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["VISIBILITY_FORMS"]
        info.value = "forms"
        info.func = VisibilityDropdown_OnClick
        info.checked = DruidManaBarDB.visibilityMode == "forms"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["VISIBILITY_COMBAT"]
        info.value = "combat"
        info.func = VisibilityDropdown_OnClick
        info.checked = DruidManaBarDB.visibilityMode == "combat"
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_SetWidth(visibilityDropdown, 150)
    UIDropDownMenu_Initialize(visibilityDropdown, VisibilityDropdown_Initialize)
    UIDropDownMenu_SetSelectedValue(visibilityDropdown, DruidManaBarDB.visibilityMode or "always")
    
    -- 특정 변신에서 표시 라벨
    local formsLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    formsLabel:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", 0, -40)
    formsLabel:SetText(L["SHOW_IN_FORMS"])
    
    -- 변신 체크박스들
    local bearCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    bearCheckbox:SetPoint("TOPLEFT", formsLabel, "BOTTOMLEFT", 0, -5)
    bearCheckbox.text = bearCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bearCheckbox.text:SetPoint("LEFT", bearCheckbox, "RIGHT", 2, 0)
    bearCheckbox.text:SetText(L["BEAR_FORM"])
    bearCheckbox:SetChecked(DruidManaBarDB.showInBear ~= false)
    bearCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showInBear = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    local catCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    catCheckbox:SetPoint("LEFT", bearCheckbox.text, "RIGHT", 20, 0)
    catCheckbox.text = catCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    catCheckbox.text:SetPoint("LEFT", catCheckbox, "RIGHT", 2, 0)
    catCheckbox.text:SetText(L["CAT_FORM"])
    catCheckbox:SetChecked(DruidManaBarDB.showInCat ~= false)
    catCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showInCat = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    local aquaticCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    aquaticCheckbox:SetPoint("TOPLEFT", bearCheckbox, "BOTTOMLEFT", 0, -5)
    aquaticCheckbox.text = aquaticCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    aquaticCheckbox.text:SetPoint("LEFT", aquaticCheckbox, "RIGHT", 2, 0)
    aquaticCheckbox.text:SetText(L["AQUATIC_FORM"])
    aquaticCheckbox:SetChecked(DruidManaBarDB.showInAquatic ~= false)
    aquaticCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showInAquatic = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    local travelCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    travelCheckbox:SetPoint("LEFT", aquaticCheckbox.text, "RIGHT", 20, 0)
    travelCheckbox.text = travelCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    travelCheckbox.text:SetPoint("LEFT", travelCheckbox, "RIGHT", 2, 0)
    travelCheckbox.text:SetText(L["TRAVEL_FORM"])
    travelCheckbox:SetChecked(DruidManaBarDB.showInTravel ~= false)
    travelCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showInTravel = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    local moonkinCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    moonkinCheckbox:SetPoint("TOPLEFT", aquaticCheckbox, "BOTTOMLEFT", 0, -5)
    moonkinCheckbox.text = moonkinCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    moonkinCheckbox.text:SetPoint("LEFT", moonkinCheckbox, "RIGHT", 2, 0)
    moonkinCheckbox.text:SetText(L["MOONKIN_FORM"])
    moonkinCheckbox:SetChecked(DruidManaBarDB.showInMoonkin ~= false)
    moonkinCheckbox:SetScript("OnClick", function(self)
        DruidManaBarDB.showInMoonkin = self:GetChecked()
        if DruidManaBar.UpdateVisibility then
            DruidManaBar.UpdateVisibility()
        end
    end)
    
    -- 체력 표시 모드 라벨
    local healthDisplayLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    healthDisplayLabel:SetPoint("TOPLEFT", moonkinCheckbox, "BOTTOMLEFT", 0, -20)
    healthDisplayLabel:SetText(L["HEALTH_DISPLAY_MODE"])
    
    -- 체력 표시 드롭다운
    local healthDisplayDropdown = CreateFrame("Frame", "DruidManaBarHealthDisplayDropdown", scrollChild, "UIDropDownMenuTemplate")
    healthDisplayDropdown:SetPoint("LEFT", healthDisplayLabel, "RIGHT", 10, 0)
    
    local function HealthDisplayDropdown_OnClick(self)
        DruidManaBarDB.healthDisplayMode = self.value
        UIDropDownMenu_SetSelectedValue(healthDisplayDropdown, self.value)
        if DruidManaBar.UpdateBars then
            DruidManaBar:UpdateBars()
        end
    end
    
    local function HealthDisplayDropdown_Initialize()
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = L["DISPLAY_NUMBER"]
        info.value = "number"
        info.func = HealthDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.healthDisplayMode == "number"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["DISPLAY_PERCENT"]
        info.value = "percent"
        info.func = HealthDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.healthDisplayMode == "percent"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["DISPLAY_BOTH"]
        info.value = "both"
        info.func = HealthDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.healthDisplayMode == "both"
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_SetWidth(healthDisplayDropdown, 100)
    UIDropDownMenu_Initialize(healthDisplayDropdown, HealthDisplayDropdown_Initialize)
    UIDropDownMenu_SetSelectedValue(healthDisplayDropdown, DruidManaBarDB.healthDisplayMode or "percent")
    
    -- 마나 표시 모드 라벨
    local manaDisplayLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    manaDisplayLabel:SetPoint("TOPLEFT", healthDisplayLabel, "BOTTOMLEFT", 0, -30)
    manaDisplayLabel:SetText(L["MANA_DISPLAY_MODE"])
    
    -- 마나 표시 드롭다운
    local manaDisplayDropdown = CreateFrame("Frame", "DruidManaBarManaDisplayDropdown", scrollChild, "UIDropDownMenuTemplate")
    manaDisplayDropdown:SetPoint("LEFT", manaDisplayLabel, "RIGHT", 10, 0)
    
    local function ManaDisplayDropdown_OnClick(self)
        DruidManaBarDB.manaDisplayMode = self.value
        UIDropDownMenu_SetSelectedValue(manaDisplayDropdown, self.value)
        if DruidManaBar.UpdateBars then
            DruidManaBar:UpdateBars()
        end
    end
    
    local function ManaDisplayDropdown_Initialize()
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = L["DISPLAY_NUMBER"]
        info.value = "number"
        info.func = ManaDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.manaDisplayMode == "number"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["DISPLAY_PERCENT"]
        info.value = "percent"
        info.func = ManaDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.manaDisplayMode == "percent"
        UIDropDownMenu_AddButton(info)
        
        info.text = L["DISPLAY_BOTH"]
        info.value = "both"
        info.func = ManaDisplayDropdown_OnClick
        info.checked = DruidManaBarDB.manaDisplayMode == "both"
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_SetWidth(manaDisplayDropdown, 100)
    UIDropDownMenu_Initialize(manaDisplayDropdown, ManaDisplayDropdown_Initialize)
    UIDropDownMenu_SetSelectedValue(manaDisplayDropdown, DruidManaBarDB.manaDisplayMode or "both")
    
    -- 바 위치 라벨
    local positionLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    positionLabel:SetPoint("TOPLEFT", manaDisplayLabel, "BOTTOMLEFT", 0, -30)
    positionLabel:SetText(L["POSITION_LABEL"])
    
    -- X 좌표
    local xLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    xLabel:SetPoint("TOPLEFT", positionLabel, "BOTTOMLEFT", 0, -5)
    xLabel:SetText("X:")
    
    local xEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    xEditBox:SetSize(60, 20)
    xEditBox:SetPoint("LEFT", xLabel, "RIGHT", 5, 0)
    xEditBox:SetAutoFocus(false)
    xEditBox:SetText(tostring(DruidManaBarDB.barX or 0))
    xEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            DruidManaBarDB.barX = value
            if DruidManaBar.UpdatePosition then
                DruidManaBar:UpdatePosition()
            end
        end
    end)
    
    -- Y 좌표
    local yLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    yLabel:SetPoint("LEFT", xEditBox, "RIGHT", 20, 0)
    yLabel:SetText("Y:")
    
    local yEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    yEditBox:SetSize(60, 20)
    yEditBox:SetPoint("LEFT", yLabel, "RIGHT", 5, 0)
    yEditBox:SetAutoFocus(false)
    yEditBox:SetText(tostring(DruidManaBarDB.barY or -200))
    yEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            DruidManaBarDB.barY = value
            if DruidManaBar.UpdatePosition then
                DruidManaBar:UpdatePosition()
            end
        end
    end)
    
    -- 바 크기 라벨
    local sizeLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -25)
    sizeLabel:SetText(L["SIZE_LABEL"])
    
    -- 바 너비 슬라이더
    local widthSlider = CreateFrame("Slider", "DruidManaBarWidthSlider", scrollChild, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 5, -10)
    widthSlider:SetSize(180, 20)
    widthSlider:SetMinMaxValues(100, 400)
    widthSlider:SetValue(DruidManaBarDB.barWidth or defaults.barWidth)
    widthSlider:SetValueStep(10)
    _G[widthSlider:GetName() .. "Text"]:SetText(L["BAR_WIDTH"])
    _G[widthSlider:GetName() .. "Low"]:SetText("100")
    _G[widthSlider:GetName() .. "High"]:SetText("400")
    widthSlider:SetScript("OnValueChanged", function(self, value)
        DruidManaBarDB.barWidth = value
        _G[self:GetName() .. "Text"]:SetText(L["BAR_WIDTH"] .. " " .. value)
        if DruidManaBar.UpdateSize then
            DruidManaBar:UpdateSize()
        end
    end)
    
    -- 마나 바 높이 슬라이더
    local manaHeightSlider = CreateFrame("Slider", "DruidManaBarHeightSlider", scrollChild, "OptionsSliderTemplate")
    manaHeightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -30)
    manaHeightSlider:SetSize(180, 20)
    manaHeightSlider:SetMinMaxValues(10, 40)
    manaHeightSlider:SetValue(DruidManaBarDB.barHeight or defaults.barHeight)
    manaHeightSlider:SetValueStep(1)
    _G[manaHeightSlider:GetName() .. "Text"]:SetText(L["MANA_BAR_HEIGHT"])
    _G[manaHeightSlider:GetName() .. "Low"]:SetText("10")
    _G[manaHeightSlider:GetName() .. "High"]:SetText("40")
    manaHeightSlider:SetScript("OnValueChanged", function(self, value)
        DruidManaBarDB.barHeight = value
        _G[self:GetName() .. "Text"]:SetText(L["MANA_BAR_HEIGHT"] .. " " .. value)
        if DruidManaBar.UpdateSize then
            DruidManaBar:UpdateSize()
        end
    end)
    
    -- 체력 바 높이 슬라이더
    local healthHeightSlider = CreateFrame("Slider", "DruidManaBarHealthHeightSlider", scrollChild, "OptionsSliderTemplate")
    healthHeightSlider:SetPoint("TOPLEFT", manaHeightSlider, "BOTTOMLEFT", 0, -30)
    healthHeightSlider:SetSize(180, 20)
    healthHeightSlider:SetMinMaxValues(10, 30)
    healthHeightSlider:SetValue(DruidManaBarDB.healthBarHeight or defaults.healthBarHeight)
    healthHeightSlider:SetValueStep(1)
    _G[healthHeightSlider:GetName() .. "Text"]:SetText(L["HEALTH_BAR_HEIGHT"])
    _G[healthHeightSlider:GetName() .. "Low"]:SetText("10")
    _G[healthHeightSlider:GetName() .. "High"]:SetText("30")
    healthHeightSlider:SetScript("OnValueChanged", function(self, value)
        DruidManaBarDB.healthBarHeight = value
        _G[self:GetName() .. "Text"]:SetText(L["HEALTH_BAR_HEIGHT"] .. " " .. value)
        if DruidManaBar.UpdateSize then
            DruidManaBar:UpdateSize()
        end
    end)
    
    -- 체력 깜빡임 임계값 슬라이더
    local flashSlider = CreateFrame("Slider", "DruidManaBarFlashSlider", scrollChild, "OptionsSliderTemplate")
    flashSlider:SetPoint("TOPLEFT", healthHeightSlider, "BOTTOMLEFT", 0, -30)
    flashSlider:SetSize(180, 20)
    flashSlider:SetMinMaxValues(10, 50)
    flashSlider:SetValue((DruidManaBarDB.flashHealthThreshold or defaults.flashHealthThreshold) * 100)
    flashSlider:SetValueStep(5)
    _G[flashSlider:GetName() .. "Text"]:SetText(L["FLASH_THRESHOLD"])
    _G[flashSlider:GetName() .. "Low"]:SetText("10%")
    _G[flashSlider:GetName() .. "High"]:SetText("50%")
    flashSlider:SetScript("OnValueChanged", function(self, value)
        DruidManaBarDB.flashHealthThreshold = value / 100
        _G[self:GetName() .. "Text"]:SetText(L["FLASH_THRESHOLD"] .. " " .. value .. "%")
    end)
    
    -- 변신 마나 비용 섹션
    local manaCostLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    manaCostLabel:SetPoint("TOPLEFT", flashSlider, "BOTTOMLEFT", 0, -30)
    manaCostLabel:SetText(L["MANA_COSTS_LABEL"])
    
    -- 자동 감지 상태 표시 함수
    local function GetAutoDetectedCosts()
        -- GetManaCostFromShapeshiftBar 함수 직접 호출
        local bearCost, direBearCost, catCost
        if DruidManaBar.GetManaCostFromShapeshiftBar then
            bearCost = DruidManaBar.GetManaCostFromShapeshiftBar(5487) or DruidManaBar.GetManaCostFromShapeshiftBar(5488)
            direBearCost = DruidManaBar.GetManaCostFromShapeshiftBar(9634)  -- 광포한 곰
            catCost = DruidManaBar.GetManaCostFromShapeshiftBar(768)
            
            -- 디버그 출력
            -- print(string.format("설정창 자동감지 - 곰: %s, 광폭곰: %s, 표범: %s", 
            --     tostring(bearCost), tostring(direBearCost), tostring(catCost)))
        end
        return bearCost, direBearCost, catCost
    end
    
    -- 자동 감지 상태 표시
    local autoDetectStatus = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoDetectStatus:SetPoint("TOPLEFT", manaCostLabel, "BOTTOMLEFT", 0, -5)
    
    local function UpdateAutoDetectStatus()
        local bearCost, direBearCost, catCost = GetAutoDetectedCosts()

        if bearCost or direBearCost or catCost then
            local statusText = "|cff00ff00자동 감지:|r"
            local detected = {}

            if bearCost then
                table.insert(detected, "곰(" .. bearCost .. ")")
            else
                table.insert(detected, "곰(?)")
            end

            if direBearCost then
                table.insert(detected, "광포한곰(" .. direBearCost .. ")")
            else
                table.insert(detected, "광포한곰(?)")
            end

            if catCost then
                table.insert(detected, "표범(" .. catCost .. ")")
            else
                table.insert(detected, "표범(?)")
            end

            statusText = statusText .. " " .. table.concat(detected, " ")
            autoDetectStatus:SetText(statusText)
        else
            autoDetectStatus:SetText("|cffff0000자동 감지 실패 - 아래에 수동으로 입력하세요|r")
        end
    end
    
    UpdateAutoDetectStatus()
    
    -- 새로고침 버튼
    local refreshButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    refreshButton:SetSize(80, 20)
    refreshButton:SetPoint("LEFT", autoDetectStatus, "RIGHT", 10, 0)
    refreshButton:SetText("새로고침")
    refreshButton:SetScript("OnClick", function()
        UpdateAutoDetectStatus()
    end)
    
    -- 수동 입력 섹션 라벨
    local manualInputLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    manualInputLabel:SetPoint("TOPLEFT", autoDetectStatus, "BOTTOMLEFT", 0, -15)
    manualInputLabel:SetText("|cffffff00수동 마나 비용 설정 (0 = 자동 감지 사용):|r")
    
    -- 곰 변신 마나
    local bearCostLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bearCostLabel:SetPoint("TOPLEFT", manualInputLabel, "BOTTOMLEFT", 0, -10)
    bearCostLabel:SetText(L["BEAR_FORM_COST"])
    
    local bearCostEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    bearCostEditBox:SetSize(60, 20)
    bearCostEditBox:SetPoint("LEFT", bearCostLabel, "RIGHT", 10, 0)
    bearCostEditBox:SetAutoFocus(false)
    bearCostEditBox:SetText(tostring(DruidManaBarDB.bearFormCost or 0))
    bearCostEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 then
            DruidManaBarDB.bearFormCost = value
            -- direBearFormCost는 별도로 관리 (같은 값을 원하면 사용자가 직접 설정)
            if DruidManaBar.UpdateBars then
                DruidManaBar:UpdateBars()
            end
        end
    end)
    
    -- 광포한 곰 변신 마나
    local direBearCostLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    direBearCostLabel:SetPoint("TOPLEFT", bearCostLabel, "BOTTOMLEFT", 0, -10)
    direBearCostLabel:SetText("광포한 곰:")
    
    local direBearCostEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    direBearCostEditBox:SetSize(60, 20)
    direBearCostEditBox:SetPoint("LEFT", direBearCostLabel, "RIGHT", 10, 0)
    direBearCostEditBox:SetAutoFocus(false)
    direBearCostEditBox:SetText(tostring(DruidManaBarDB.direBearFormCost or 0))
    direBearCostEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 then
            DruidManaBarDB.direBearFormCost = value
            if DruidManaBar.UpdateBars then
                DruidManaBar:UpdateBars()
            end
        end
    end)
    
    -- 표범 변신 마나
    local catCostLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    catCostLabel:SetPoint("LEFT", direBearCostEditBox, "RIGHT", 20, 0)
    catCostLabel:SetText(L["CAT_FORM_COST"])
    
    local catCostEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    catCostEditBox:SetSize(60, 20)
    catCostEditBox:SetPoint("LEFT", catCostLabel, "RIGHT", 10, 0)
    catCostEditBox:SetAutoFocus(false)
    catCostEditBox:SetText(tostring(DruidManaBarDB.catFormCost or 0))
    catCostEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 then
            DruidManaBarDB.catFormCost = value
            if DruidManaBar.UpdateBars then
                DruidManaBar:UpdateBars()
            end
        end
    end)

    -- 버튼들 (메인 프레임에 고정)
    local testButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 25)
    testButton:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 90, 20)
    testButton:SetText(L["TEST_BUTTON"])
    testButton:SetScript("OnClick", function()
        DruidManaBar:TestMode()
    end)

    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 20)
    resetButton:SetText(L["RESET_BUTTON"])
    resetButton:SetScript("OnClick", function()
        DruidManaBarDB = CopyTable(defaults)
        -- UI 업데이트
        enabledCheckbox:SetChecked(defaults.enabled)
        healthCheckbox:SetChecked(defaults.showHealthBar)
        xEditBox:SetText(tostring(defaults.barX))
        yEditBox:SetText(tostring(defaults.barY))
        widthSlider:SetValue(defaults.barWidth)
        manaHeightSlider:SetValue(defaults.barHeight)
        healthHeightSlider:SetValue(defaults.healthBarHeight)
        flashSlider:SetValue(defaults.flashHealthThreshold * 100)
        bearCostEditBox:SetText("0")
        direBearCostEditBox:SetText("0")
        catCostEditBox:SetText("0")
        UpdateAutoDetectStatus()

        if DruidManaBar.UpdatePosition then
            DruidManaBar:UpdatePosition()
        end
        if DruidManaBar.UpdateSize then
            DruidManaBar:UpdateSize()
        end

        print(L["DEFAULTS_RESTORED"])
    end)

    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 25)
    closeButton:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -90, 20)
    closeButton:SetText(L["CLOSE_BUTTON"])
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    -- X 버튼
    local xButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    xButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
    
    configFrame:Show()
end

-- 설정 프레임 전역 변수 설정
DruidManaBarConfig = configFrame