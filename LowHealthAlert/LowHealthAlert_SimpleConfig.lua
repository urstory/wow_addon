local addonName, addon = ...

local configFrame = nil
local macroEditBox = nil
local thresholdSlider = nil
local thresholdValue = nil
local enabledCheckbox = nil  
local flashCheckbox = nil

local defaults = {
    macroText = "/use 치유 물약",
    threshold = 0.35,
    enabled = true,
    useFlash = true,
    flashIntensity = 0.5,
    buttonX = 100,
    buttonY = 0,
    buttonIcon = "Interface\\Icons\\INV_Potion_54"
}

function LowHealthAlert.ShowSimpleConfig()
    local L = addon.L
    if configFrame then
        configFrame:Show()
        return
    end
    
    -- 메인 프레임 생성 (BackdropTemplate 상속)
    configFrame = CreateFrame("Frame", "LowHealthAlertSimpleConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(500, 650)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    
    -- 배경 (BackdropTemplate 확인)
    if configFrame.SetBackdrop then
        configFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
    else
        -- 구버전 호환을 위한 대체 배경
        local bg = configFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    
    -- 제목
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -20)
    title:SetText(L["CONFIG_TITLE"])
    
    -- 체력 임계값 레이블
    local thresholdLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thresholdLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 30, -60)
    thresholdLabel:SetText(L["HEALTH_THRESHOLD"])
    
    -- 체력 슬라이더 (수동 생성)
    thresholdSlider = CreateFrame("Slider", "LHASimpleThresholdSlider", configFrame)
    thresholdSlider:SetSize(300, 20)
    thresholdSlider:SetPoint("TOPLEFT", thresholdLabel, "BOTTOMLEFT", 0, -10)
    thresholdSlider:SetOrientation("HORIZONTAL")
    thresholdSlider:SetMinMaxValues(1, 100)
    thresholdSlider:SetValue((LowHealthAlertDB.threshold or defaults.threshold) * 100)
    thresholdSlider:SetValueStep(1)
    thresholdSlider:SetObeyStepOnDrag(true)
    
    -- 슬라이더 배경 (SetBackdrop 제거, 텍스처로 대체)
    local sliderBg = thresholdSlider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    sliderBg:SetSize(300, 8)
    sliderBg:SetPoint("CENTER")
    
    -- 슬라이더 썸
    local thumb = thresholdSlider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(32, 32)
    thresholdSlider:SetThumbTexture(thumb)
    
    -- 슬라이더 값 표시
    thresholdValue = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thresholdValue:SetPoint("TOP", thresholdSlider, "BOTTOM", 0, -5)
    thresholdValue:SetText(string.format(L["CURRENT_VALUE"], thresholdSlider:GetValue()))
    
    -- 슬라이더 최소/최대 표시
    local minText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minText:SetPoint("TOPLEFT", thresholdSlider, "BOTTOMLEFT", 0, 3)
    minText:SetText("1%")
    
    local maxText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxText:SetPoint("TOPRIGHT", thresholdSlider, "BOTTOMRIGHT", 0, 3)
    maxText:SetText("100%")
    
    thresholdSlider:SetScript("OnValueChanged", function(self, value)
        LowHealthAlertDB.threshold = value / 100
        thresholdValue:SetText(string.format(L["CURRENT_VALUE"], value))
        if LowHealthAlert.CheckHealth then
            LowHealthAlert.CheckHealth()
        end
    end)
    
    -- 매크로 레이블
    local macroLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroLabel:SetPoint("TOPLEFT", thresholdSlider, "BOTTOMLEFT", 0, -40)
    macroLabel:SetText(L["MACRO_LABEL"])
    
    -- 매크로 입력 배경
    local macroBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    macroBackground:SetSize(440, 100)
    macroBackground:SetPoint("TOPLEFT", macroLabel, "BOTTOMLEFT", 0, -10)
    if macroBackground.SetBackdrop then
        macroBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        macroBackground:SetBackdropColor(0, 0, 0, 0.8)
    else
        -- 대체 배경
        local bg = macroBackground:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.8)
    end
    
    -- 매크로 EditBox (스크롤 없이 간단하게)
    macroEditBox = CreateFrame("EditBox", nil, macroBackground)
    macroEditBox:SetSize(420, 90)
    macroEditBox:SetPoint("TOPLEFT", 10, -5)
    macroEditBox:SetAutoFocus(false)
    macroEditBox:SetMultiLine(true)
    macroEditBox:SetMaxLetters(1024)
    macroEditBox:SetFontObject(GameFontHighlight)
    macroEditBox:SetText(LowHealthAlertDB.macroText or defaults.macroText)
    
    macroEditBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        -- 텍스트를 DB에 저장만 하고, 실제 매크로 업데이트는 저장 버튼이나 포커스 잃을 때
        LowHealthAlertDB.macroText = text
    end)
    
    -- 포커스를 잃을 때 매크로 업데이트
    macroEditBox:SetScript("OnEditFocusLost", function(self)
        local text = self:GetText()
        if LowHealthAlert.UpdateMacro then
            LowHealthAlert.UpdateMacro(text)
        end
    end)
    
    macroEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    macroEditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    
    -- 활성화 체크박스 (수동 생성)
    enabledCheckbox = CreateFrame("CheckButton", nil, configFrame)
    enabledCheckbox:SetSize(24, 24)
    enabledCheckbox:SetPoint("TOPLEFT", macroBackground, "BOTTOMLEFT", 0, -20)
    enabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    enabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    enabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    enabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    enabledCheckbox:SetChecked(LowHealthAlertDB.enabled ~= false)
    
    local enabledLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
    enabledLabel:SetText(L["ENABLE_ADDON"])
    
    enabledCheckbox:SetScript("OnClick", function(self)
        LowHealthAlertDB.enabled = self:GetChecked()
        if not LowHealthAlertDB.enabled then
            if LowHealthAlert.HideButton then
                LowHealthAlert.HideButton()
            end
            if LowHealthAlert.StopFlashing then
                LowHealthAlert.StopFlashing()
            end
        else
            if LowHealthAlert.CheckHealth then
                LowHealthAlert.CheckHealth()
            end
        end
    end)
    
    -- 깜빡임 체크박스 (수동 생성)
    flashCheckbox = CreateFrame("CheckButton", nil, configFrame)
    flashCheckbox:SetSize(24, 24)
    flashCheckbox:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -10)
    flashCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    flashCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    flashCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    flashCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    flashCheckbox:SetChecked(LowHealthAlertDB.useFlash ~= false)
    
    local flashLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flashLabel:SetPoint("LEFT", flashCheckbox, "RIGHT", 5, 0)
    flashLabel:SetText(L["USE_FLASH"])
    
    flashCheckbox:SetScript("OnClick", function(self)
        LowHealthAlertDB.useFlash = self:GetChecked()
    end)
    
    -- 미니맵 버튼 체크박스
    local minimapCheckbox = CreateFrame("CheckButton", nil, configFrame)
    minimapCheckbox:SetSize(24, 24)
    minimapCheckbox:SetPoint("TOPLEFT", flashCheckbox, "BOTTOMLEFT", 0, -10)
    minimapCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    minimapCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    minimapCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    minimapCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    -- 미니맵 버튼 설정 초기화
    if not LowHealthAlertDB.minimapButton then
        LowHealthAlertDB.minimapButton = {
            hide = false,
            minimapPos = 45,
            radius = 80
        }
    end
    minimapCheckbox:SetChecked(not LowHealthAlertDB.minimapButton.hide)

    local minimapLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
    minimapLabel:SetText(L["SHOW_MINIMAP_BUTTON"] or "Show Minimap Button")

    minimapCheckbox:SetScript("OnClick", function(self)
        LowHealthAlertDB.minimapButton.hide = not self:GetChecked()
        if LowHealthAlert.UpdateMinimapButton then
            LowHealthAlert.UpdateMinimapButton()
        end
    end)

    -- 깜빡임 강도 슬라이더
    local flashIntensityLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flashIntensityLabel:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -15)
    flashIntensityLabel:SetText(L["FLASH_INTENSITY"])
    
    local flashSlider = CreateFrame("Slider", "LHAFlashIntensitySlider", configFrame)
    flashSlider:SetSize(200, 20)
    flashSlider:SetPoint("TOPLEFT", flashIntensityLabel, "BOTTOMLEFT", 0, -10)
    flashSlider:SetOrientation("HORIZONTAL")
    flashSlider:SetMinMaxValues(10, 100)
    flashSlider:SetValue((LowHealthAlertDB.flashIntensity or defaults.flashIntensity or 0.5) * 100)
    flashSlider:SetValueStep(10)
    flashSlider:SetObeyStepOnDrag(true)
    
    -- 슬라이더 배경
    local sliderBg = flashSlider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    sliderBg:SetSize(200, 8)
    sliderBg:SetPoint("CENTER")
    
    -- 슬라이더 썸
    local thumb = flashSlider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(32, 32)
    flashSlider:SetThumbTexture(thumb)
    
    -- 슬라이더 값 표시
    local flashValue = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    flashValue:SetPoint("TOP", flashSlider, "BOTTOM", 0, -5)
    flashValue:SetText(string.format(L["CURRENT_VALUE"], flashSlider:GetValue()))
    
    -- 최소/최대 표시
    local minFlashText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minFlashText:SetPoint("TOPLEFT", flashSlider, "BOTTOMLEFT", 0, 3)
    minFlashText:SetText("10%")
    
    local maxFlashText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxFlashText:SetPoint("TOPRIGHT", flashSlider, "BOTTOMRIGHT", 0, 3)
    maxFlashText:SetText("100%")
    
    flashSlider:SetScript("OnValueChanged", function(self, value)
        LowHealthAlertDB.flashIntensity = value / 100
        flashValue:SetText(string.format(L["CURRENT_VALUE"], value))
    end)
    
    -- 버튼 위치 설정 섹션
    local positionLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    positionLabel:SetPoint("TOPLEFT", flashSlider, "BOTTOMLEFT", 0, -30)
    positionLabel:SetText(L["BUTTON_POSITION"] .. " (" .. L["CENTER"] .. ": 0, 0):")
    
    -- X 좌표 입력
    local xLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xLabel:SetPoint("TOPLEFT", positionLabel, "BOTTOMLEFT", 0, -10)
    xLabel:SetText(L["X_COORD"] .. " (- ← | → +):")
    
    local xEditBox = CreateFrame("EditBox", nil, configFrame, "BackdropTemplate")
    xEditBox:SetSize(60, 20)
    xEditBox:SetPoint("LEFT", xLabel, "RIGHT", 10, 0)
    if xEditBox.SetBackdrop then
        xEditBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        xEditBox:SetBackdropColor(0, 0, 0, 0.5)
        xEditBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    else
        local bg = xEditBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
    end
    xEditBox:SetFontObject(GameFontHighlight)
    xEditBox:SetAutoFocus(false)
    xEditBox:SetNumeric(false)
    xEditBox:SetMaxLetters(6)
    xEditBox:SetText(tostring(LowHealthAlertDB.buttonX or defaults.buttonX or 100))
    
    xEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            LowHealthAlertDB.buttonX = value
            if LowHealthAlert.UpdateButtonPosition then
                LowHealthAlert.UpdateButtonPosition()
            end
        end
    end)
    
    xEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    xEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    -- Y 좌표 입력
    local yLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    yLabel:SetPoint("LEFT", xEditBox, "RIGHT", 20, 0)
    yLabel:SetText(L["Y_COORD"] .. " (- ↓ | ↑ +):")
    
    local yEditBox = CreateFrame("EditBox", nil, configFrame, "BackdropTemplate")
    yEditBox:SetSize(60, 20)
    yEditBox:SetPoint("LEFT", yLabel, "RIGHT", 10, 0)
    if yEditBox.SetBackdrop then
        yEditBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        yEditBox:SetBackdropColor(0, 0, 0, 0.5)
        yEditBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    else
        local bg = yEditBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
    end
    yEditBox:SetFontObject(GameFontHighlight)
    yEditBox:SetAutoFocus(false)
    yEditBox:SetNumeric(false)
    yEditBox:SetMaxLetters(6)
    yEditBox:SetText(tostring(LowHealthAlertDB.buttonY or defaults.buttonY or 0))
    
    yEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            LowHealthAlertDB.buttonY = value
            if LowHealthAlert.UpdateButtonPosition then
                LowHealthAlert.UpdateButtonPosition()
            end
        end
    end)
    
    yEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    yEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    -- 아이콘 선택 섹션
    local iconLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -25)
    iconLabel:SetText(L["BUTTON_ICON"] .. ":")
    
    local iconEditBox = CreateFrame("EditBox", nil, configFrame, "BackdropTemplate")
    iconEditBox:SetSize(300, 20)
    iconEditBox:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -5)
    if iconEditBox.SetBackdrop then
        iconEditBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        iconEditBox:SetBackdropColor(0, 0, 0, 0.5)
        iconEditBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    else
        local bg = iconEditBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
    end
    iconEditBox:SetFontObject(GameFontHighlight)
    iconEditBox:SetAutoFocus(false)
    iconEditBox:SetMaxLetters(200)
    iconEditBox:SetText(LowHealthAlertDB.buttonIcon or defaults.buttonIcon or "Interface\\Icons\\INV_Potion_54")
    
    iconEditBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            -- 아이템 이름인 경우 아이콘 찾기
            local itemName, itemLink = GetItemInfo(text)
            if itemName then
                local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(text)
                if itemTexture then
                    LowHealthAlertDB.buttonIcon = itemTexture
                    if LowHealthAlert.UpdateButtonIcon then
                        LowHealthAlert.UpdateButtonIcon(itemTexture)
                    end
                end
            else
                -- 직접 경로 입력
                LowHealthAlertDB.buttonIcon = text
                if LowHealthAlert.UpdateButtonIcon then
                    LowHealthAlert.UpdateButtonIcon(text)
                end
            end
        end
    end)
    
    iconEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    iconEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    -- 아이콘 프리셋 버튼들
    local iconPresetLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconPresetLabel:SetPoint("TOPLEFT", iconEditBox, "BOTTOMLEFT", 0, -5)
    iconPresetLabel:SetText(L["QUICK_SELECT"] or "Quick Select:")
    
    local presetButtons = {}
    local presets = {
        {name = "Healing Potion", icon = "Interface\\Icons\\INV_Potion_54"},
        {name = "Bandage", icon = "Interface\\Icons\\INV_Misc_Bandage_08"},
        {name = "Food", icon = "Interface\\Icons\\INV_Misc_Food_15"},
        {name = "Healthstone", icon = "Interface\\Icons\\INV_Stone_04"}
    }
    
    -- 한국어 클라이언트일 경우 이름 변경
    if GetLocale() == "koKR" then
        presets = {
            {name = "치유 물약", icon = "Interface\\Icons\\INV_Potion_54"},
            {name = "붕대", icon = "Interface\\Icons\\INV_Misc_Bandage_08"},
            {name = "음식", icon = "Interface\\Icons\\INV_Misc_Food_15"},
            {name = "치유석", icon = "Interface\\Icons\\INV_Stone_04"}
        }
    end
    
    for i, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, configFrame)
        btn:SetSize(32, 32)
        if i == 1 then
            btn:SetPoint("LEFT", iconPresetLabel, "RIGHT", 10, 0)
        else
            btn:SetPoint("LEFT", presetButtons[i-1], "RIGHT", 5, 0)
        end
        btn:SetNormalTexture(preset.icon)
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        btn:SetScript("OnClick", function()
            iconEditBox:SetText(preset.icon)
            LowHealthAlertDB.buttonIcon = preset.icon
            if LowHealthAlert.UpdateButtonIcon then
                LowHealthAlert.UpdateButtonIcon(preset.icon)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(preset.name)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        presetButtons[i] = btn
    end
    
    -- 버튼들
    -- 테스트 버튼
    local testButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 25)
    testButton:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 30, 20)
    testButton:SetText(L["TEST_BUTTON"])
    testButton:SetScript("OnClick", function()
        if LowHealthAlert.TestMode then
            LowHealthAlert.TestMode()
        end
    end)
    
    -- 기본값 복원 버튼
    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("LEFT", testButton, "RIGHT", 10, 0)
    resetButton:SetText(L["RESET_BUTTON"])
    resetButton:SetScript("OnClick", function()
        LowHealthAlertDB = CopyTable(defaults)
        macroEditBox:SetText(defaults.macroText)
        thresholdSlider:SetValue(defaults.threshold * 100)
        enabledCheckbox:SetChecked(true)
        flashCheckbox:SetChecked(true)
        flashSlider:SetValue((defaults.flashIntensity or 0.5) * 100)
        xEditBox:SetText(tostring(defaults.buttonX))
        yEditBox:SetText(tostring(defaults.buttonY))
        iconEditBox:SetText(defaults.buttonIcon)
        if LowHealthAlert.UpdateMacro then
            LowHealthAlert.UpdateMacro(defaults.macroText)
        end
        if LowHealthAlert.UpdateButtonPosition then
            LowHealthAlert.UpdateButtonPosition()
        end
        if LowHealthAlert.UpdateButtonIcon then
            LowHealthAlert.UpdateButtonIcon(defaults.buttonIcon)
        end
        if LowHealthAlert.CheckHealth then
            LowHealthAlert.CheckHealth()
        end
        print(L["DEFAULTS_RESTORED"] or "Low Health Alert: Settings restored to defaults")
    end)
    
    -- 닫기 버튼 (X)
    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    -- 취소 버튼
    local cancelButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -30, 20)
    cancelButton:SetText(L["CLOSE_BUTTON"])
    cancelButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    configFrame:Show()
end

-- 설정창 열기 함수 (미니맵 버튼에서 호출용)
function LowHealthAlert.OpenConfig()
    LowHealthAlert.ShowSimpleConfig()
end