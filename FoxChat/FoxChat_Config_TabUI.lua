local addonName, addon = ...
local L = addon.L

local configFrame = nil
local currentTab = 1  -- 현재 선택된 탭

-- 탭 시스템 변수
local tabs = {}
local tabContents = {}

-- EditBox 변수들 (각 탭에서 사용)
local keywordsEditBox = nil
local ignoreKeywordsEditBox = nil
local prefixEditBox = nil
local suffixEditBox = nil
local adMessageEditBox = nil

-- 기본 설정값
local defaults = {
    enabled = true,
    keywords = L["DEFAULT_KEYWORDS"],
    ignoreKeywords = "",
    playSound = true,
    soundVolume = 0.5,
    highlightColors = {
        GUILD = {r = 0, g = 1, b = 0},
        PUBLIC = {r = 1, g = 1, b = 0},
        PARTY_RAID = {r = 0, g = 0.5, b = 1},
        LFG = {r = 1, g = 0.5, b = 0},
    },
    highlightStyle = "both",
    channelGroups = {
        GUILD = true,
        PUBLIC = true,
        PARTY_RAID = true,
        LFG = true,
    },
    prefix = "",
    suffix = "",
    prefixSuffixChannels = {
        SAY = true,
        YELL = false,
        PARTY = true,
        GUILD = true,
        RAID = true,
        INSTANCE_CHAT = true,
        WHISPER = false,
        CHANNEL = false,
    },
    lastTab = 1,  -- 마지막으로 선택된 탭 저장
}

-- =============================================
-- 유틸리티 함수들
-- =============================================

-- 구분선 생성 함수
local function CreateSeparator(parent, point, relativeTo, relativePoint, x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    line:SetPoint(point, relativeTo, relativePoint, x, y)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, y)
    return line
end

-- =============================================
-- 탭 시스템 함수들
-- =============================================

-- 탭 버튼 생성 함수
local function CreateTabButton(parent, text, index)
    local button = CreateFrame("Button", "FoxChatTab"..index, parent)
    button:SetSize(150, 35)

    -- 위치 설정 (가로로 나열)
    local xOffset = 20 + ((index - 1) * 155)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -50)

    -- 배경 텍스처 (기본 상태)
    button.normalTexture = button:CreateTexture(nil, "BACKGROUND")
    button.normalTexture:SetAllPoints()
    button.normalTexture:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    -- 선택됨 텍스처
    button.selectedTexture = button:CreateTexture(nil, "ARTWORK")
    button.selectedTexture:SetAllPoints()
    button.selectedTexture:SetColorTexture(0.4, 0.35, 0.1, 1)
    button.selectedTexture:Hide()

    -- 하이라이트 텍스처
    button.highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlightTexture:SetAllPoints()
    button.highlightTexture:SetColorTexture(0.3, 0.3, 0.3, 0.5)

    -- 테두리
    button.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.border:SetAllPoints()
    button.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    button.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

    -- 텍스트
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button.text:SetTextColor(0.8, 0.8, 0.8)

    -- 탭 인덱스 저장
    button.tabIndex = index
    button.isSelected = false

    return button
end

-- 탭 컨텐츠 프레임 생성 함수
local function CreateTabContent(parent, index)
    local frame = CreateFrame("Frame", "FoxChatTabContent"..index, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -95)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 55)
    frame:Hide()  -- 기본적으로 숨김

    -- 배경 (선택사항)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.2)

    return frame
end

-- 탭 전환 함수
local function SwitchToTab(index)
    if not tabs[index] or not tabContents[index] then return end

    currentTab = index

    -- 탭 상태 저장
    if FoxChatDB then
        FoxChatDB.lastTab = index
    end

    -- 모든 탭 버튼과 컨텐츠 업데이트
    for i = 1, #tabs do
        local tab = tabs[i]
        local content = tabContents[i]

        if i == index then
            -- 선택된 탭
            tab.isSelected = true
            tab.normalTexture:Hide()
            tab.selectedTexture:Show()
            tab.text:SetTextColor(1, 0.82, 0)  -- 황금색
            tab.border:SetBackdropBorderColor(0.8, 0.65, 0, 1)
            content:Show()
        else
            -- 선택되지 않은 탭
            tab.isSelected = false
            tab.normalTexture:Show()
            tab.selectedTexture:Hide()
            tab.text:SetTextColor(0.8, 0.8, 0.8)  -- 회색
            tab.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            content:Hide()
        end
    end

    -- 테스트 버튼 표시/숨김 (채팅 필터링 탭에서만 표시)
    local configFrame = tabs[1]:GetParent()
    if configFrame and configFrame.testButton then
        if index == 1 then  -- 채팅 필터링 탭
            configFrame.testButton:Show()
        else
            configFrame.testButton:Hide()
        end
    end

    -- 설정에 현재 탭 저장
    if FoxChatDB then
        FoxChatDB.lastTab = index
    end
end

-- =============================================
-- 메인 설정창 함수
-- =============================================

function FoxChat:ShowConfig()
    if configFrame then
        configFrame:Show()
        configFrame:Raise()
        -- 마지막 탭 복원
        local lastTab = (FoxChatDB and FoxChatDB.lastTab) or 1
        SwitchToTab(lastTab)
        return
    end

    -- =============================================
    -- 메인 프레임 생성
    -- =============================================
    configFrame = CreateFrame("Frame", "FoxChatConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(600, 500)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetFrameLevel(999)
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
    title:SetTextColor(1, 0.82, 0)

    -- =============================================
    -- 탭 생성
    -- =============================================

    -- 탭 버튼들 생성
    tabs[1] = CreateTabButton(configFrame, "채팅 필터링", 1)
    tabs[2] = CreateTabButton(configFrame, "말머리/말꼬리", 2)
    tabs[3] = CreateTabButton(configFrame, "광고 설정", 3)

    -- 탭 컨텐츠 프레임들 생성
    tabContents[1] = CreateTabContent(configFrame, 1)
    tabContents[2] = CreateTabContent(configFrame, 2)
    tabContents[3] = CreateTabContent(configFrame, 3)

    -- 탭 버튼 클릭 이벤트
    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function()
            SwitchToTab(i)
        end)
    end

    -- 탭 구분선
    local tabSeparator = CreateSeparator(configFrame, "TOPLEFT", tabs[1], "BOTTOMLEFT", -20, -5)

    -- =============================================
    -- 탭 1: 채팅 필터링
    -- =============================================
    local tab1 = tabContents[1]

    -- 상단 체크박스들 (한 줄로 배치)
    local filterEnabledCheckbox = CreateFrame("CheckButton", nil, tab1)
    filterEnabledCheckbox:SetSize(24, 24)
    filterEnabledCheckbox:SetPoint("TOPLEFT", tab1, "TOPLEFT", 10, -10)
    filterEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    filterEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    filterEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    filterEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    filterEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.filterEnabled)

    local filterEnabledLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterEnabledLabel:SetPoint("LEFT", filterEnabledCheckbox, "RIGHT", 5, 0)
    filterEnabledLabel:SetText(L["FILTER_ENABLE"])

    filterEnabledCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.filterEnabled = self:GetChecked()
        end
    end)

    local soundCheckbox = CreateFrame("CheckButton", nil, tab1)
    soundCheckbox:SetSize(24, 24)
    soundCheckbox:SetPoint("LEFT", filterEnabledLabel, "RIGHT", 30, 0)
    soundCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    soundCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    soundCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    soundCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    soundCheckbox:SetChecked(FoxChatDB and FoxChatDB.playSound)

    local soundLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundLabel:SetText(L["PLAY_SOUND"])

    soundCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.playSound = self:GetChecked()
        end
    end)

    local minimapCheckbox = CreateFrame("CheckButton", nil, tab1)
    minimapCheckbox:SetSize(24, 24)
    minimapCheckbox:SetPoint("LEFT", soundLabel, "RIGHT", 30, 0)
    minimapCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    minimapCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    minimapCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    minimapCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    minimapCheckbox:SetChecked(FoxChatDB and FoxChatDB.minimapButton and not FoxChatDB.minimapButton.hide)

    local minimapLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
    minimapLabel:SetText(L["SHOW_MINIMAP_BUTTON"])

    minimapCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB and FoxChatDB.minimapButton then
            FoxChatDB.minimapButton.hide = not self:GetChecked()
            if FoxChatDB.minimapButton.hide then
                if _G["FoxChatMinimapButton"] then
                    _G["FoxChatMinimapButton"]:Hide()
                end
            else
                if _G["FoxChatMinimapButton"] then
                    _G["FoxChatMinimapButton"]:Show()
                end
            end
        end
    end)

    -- 구분선
    local separator1 = CreateSeparator(tab1, "TOPLEFT", filterEnabledCheckbox, "BOTTOMLEFT", -10, -15)

    -- 필터링 키워드 (왼쪽)
    local keywordsLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keywordsLabel:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 10, -10)
    keywordsLabel:SetText(L["KEYWORDS_LABEL"])

    local keywordsHelp = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordsHelp:SetPoint("TOPLEFT", keywordsLabel, "BOTTOMLEFT", 0, -3)
    keywordsHelp:SetText(L["KEYWORDS_HELP"])

    local keywordsBackground = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    keywordsBackground:SetSize(260, 60)
    keywordsBackground:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)
    keywordsBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    keywordsBackground:SetBackdropColor(0, 0, 0, 0.8)

    keywordsEditBox = CreateFrame("EditBox", nil, keywordsBackground)
    keywordsEditBox:SetSize(240, 50)
    keywordsEditBox:SetPoint("TOPLEFT", 10, -5)
    keywordsEditBox:SetAutoFocus(false)
    keywordsEditBox:SetMultiLine(true)
    keywordsEditBox:SetMaxLetters(500)
    keywordsEditBox:SetFontObject(GameFontHighlight)

    -- 키워드 배열을 문자열로 변환
    local keywordText = ""
    if FoxChatDB and FoxChatDB.keywords then
        if type(FoxChatDB.keywords) == "table" then
            keywordText = table.concat(FoxChatDB.keywords, ", ")
        else
            keywordText = tostring(FoxChatDB.keywords)
        end
    end
    keywordsEditBox:SetText(keywordText)

    -- EditBox 클릭 영역 개선 - 배경을 클릭해도 EditBox에 포커스가 가도록
    keywordsBackground:EnableMouse(true)
    keywordsBackground:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            keywordsEditBox:SetFocus()
            -- 커서 위치는 건드리지 않음
        end
    end)

    keywordsEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            -- 콤마로 구분된 문자열을 배열로 변환
            local text = self:GetText()
            local keywords = {}
            for keyword in string.gmatch(text, "([^,]+)") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end
            FoxChatDB.keywords = keywords
            if FoxChat and FoxChat.UpdateKeywords then
                FoxChat:UpdateKeywords()
            end
        end
    end)

    keywordsEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 무시 키워드 (오른쪽)
    local ignoreLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ignoreLabel:SetPoint("TOPLEFT", keywordsLabel, "TOPLEFT", 280, 0)
    ignoreLabel:SetText(L["IGNORE_KEYWORDS_LABEL"])

    local ignoreHelp = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ignoreHelp:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -3)
    ignoreHelp:SetText(L["IGNORE_KEYWORDS_HELP"])

    local ignoreBackground = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    ignoreBackground:SetSize(260, 60)
    ignoreBackground:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)
    ignoreBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    ignoreBackground:SetBackdropColor(0, 0, 0, 0.8)

    ignoreKeywordsEditBox = CreateFrame("EditBox", nil, ignoreBackground)
    ignoreKeywordsEditBox:SetSize(240, 50)
    ignoreKeywordsEditBox:SetPoint("TOPLEFT", 10, -5)
    ignoreKeywordsEditBox:SetAutoFocus(false)
    ignoreKeywordsEditBox:SetMultiLine(true)
    ignoreKeywordsEditBox:SetMaxLetters(500)
    ignoreKeywordsEditBox:SetFontObject(GameFontHighlight)
    -- 무시 키워드 배열을 문자열로 변환
    local ignoreText = ""
    if FoxChatDB and FoxChatDB.ignoreKeywords then
        if type(FoxChatDB.ignoreKeywords) == "table" then
            ignoreText = table.concat(FoxChatDB.ignoreKeywords, ", ")
        else
            ignoreText = tostring(FoxChatDB.ignoreKeywords)
        end
    end
    ignoreKeywordsEditBox:SetText(ignoreText)

    -- EditBox 클릭 영역 개선 - 배경을 클릭해도 EditBox에 포커스가 가도록
    ignoreBackground:EnableMouse(true)
    ignoreBackground:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            ignoreKeywordsEditBox:SetFocus()
            -- 커서 위치는 건드리지 않음
        end
    end)

    ignoreKeywordsEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            -- 콤마로 구분된 문자열을 배열로 변환
            local text = self:GetText()
            local keywords = {}
            for keyword in string.gmatch(text, "([^,]+)") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end
            FoxChatDB.ignoreKeywords = keywords
            if FoxChat and FoxChat.UpdateIgnoreKeywords then
                FoxChat:UpdateIgnoreKeywords()
            end
        end
    end)

    ignoreKeywordsEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 하이라이트 스타일
    local styleLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", keywordsBackground, "BOTTOMLEFT", 0, -15)
    styleLabel:SetText(L["HIGHLIGHT_STYLE"])

    local styles = {
        {value = "bold", text = L["STYLE_BOLD"], x = 0},
        {value = "color", text = L["STYLE_COLOR"], x = 120},
        {value = "both", text = L["STYLE_BOTH"], x = 240},
    }

    local styleButtons = {}
    for i, style in ipairs(styles) do
        local radioButton = CreateFrame("CheckButton", nil, tab1)
        radioButton:SetSize(20, 20)
        radioButton:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", style.x, -5)
        radioButton:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:SetPushedTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton")
        radioButton:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)

        local label = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", radioButton, "RIGHT", 3, 0)
        label:SetText(style.text)

        radioButton.value = style.value
        radioButton:SetChecked(FoxChatDB and FoxChatDB.highlightStyle == style.value)

        radioButton:SetScript("OnClick", function(self)
            for _, btn in ipairs(styleButtons) do
                btn:SetChecked(false)
            end
            self:SetChecked(true)
            if FoxChatDB then
                FoxChatDB.highlightStyle = self.value
            end
        end)

        styleButtons[i] = radioButton
    end

    -- 채널별 색상 및 모니터링 설정
    local colorLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -35)
    colorLabel:SetText(L["CHANNELS_AND_COLORS"])

    local colorSwatches = {}
    local channelCheckboxes = {}
    local channelGroupOptions = {
        {key = "GUILD", text = L["CHANNEL_GROUP_GUILD"], x = 0, y = 0},
        {key = "PUBLIC", text = L["CHANNEL_GROUP_PUBLIC"], x = 140, y = 0},
        {key = "PARTY_RAID", text = L["CHANNEL_GROUP_PARTY_RAID"], x = 280, y = 0},
        {key = "LFG", text = L["CHANNEL_GROUP_LFG"], x = 420, y = 0},
    }

    for i, group in ipairs(channelGroupOptions) do
        -- 체크박스
        local checkbox = CreateFrame("CheckButton", nil, tab1)
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", group.x, -20 + group.y)
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkbox:SetChecked(FoxChatDB and FoxChatDB.channelGroups and FoxChatDB.channelGroups[group.key])

        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB then
                if not FoxChatDB.channelGroups then
                    FoxChatDB.channelGroups = {}
                end
                FoxChatDB.channelGroups[group.key] = self:GetChecked()
            end
        end)

        channelCheckboxes[group.key] = checkbox

        -- 채널 이름
        local groupLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        groupLabel:SetText(group.text)

        -- 색상 선택 버튼
        local colorSwatch = CreateFrame("Button", nil, tab1)
        colorSwatch:SetSize(16, 16)
        colorSwatch:SetPoint("LEFT", groupLabel, "RIGHT", 5, 0)

        local colorTexture = colorSwatch:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints()
        local color = (FoxChatDB and FoxChatDB.highlightColors and FoxChatDB.highlightColors[group.key]) or defaults.highlightColors[group.key]
        colorTexture:SetColorTexture(color.r, color.g, color.b)

        local colorBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
        colorBorder:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        colorBorder:SetAllPoints()

        colorSwatches[group.key] = {texture = colorTexture, color = color}

        colorSwatch:SetScript("OnClick", function()
            local groupKey = group.key
            local function OnColorSelect()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                if FoxChatDB then
                    if not FoxChatDB.highlightColors then
                        FoxChatDB.highlightColors = {}
                    end
                    FoxChatDB.highlightColors[groupKey] = {r = r, g = g, b = b}
                    colorTexture:SetColorTexture(r, g, b)
                    colorSwatches[groupKey].color = {r = r, g = g, b = b}
                end
            end

            ColorPickerFrame.func = OnColorSelect
            ColorPickerFrame.cancelFunc = function(previousValues)
                if previousValues and FoxChatDB then
                    FoxChatDB.highlightColors[groupKey] = previousValues
                    colorTexture:SetColorTexture(previousValues.r, previousValues.g, previousValues.b)
                end
            end
            ColorPickerFrame.previousValues = color
            ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
            ColorPickerFrame:Show()
        end)
    end

    -- 토스트 위치 설정
    local toastPosLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastPosLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -50)
    toastPosLabel:SetText("토스트 위치:")

    local toastPosDesc = tab1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toastPosDesc:SetPoint("LEFT", toastPosLabel, "RIGHT", 10, 0)
    toastPosDesc:SetText("(0, 0)이 화면 정중앙")

    -- X 위치
    local toastXLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastXLabel:SetPoint("TOPLEFT", toastPosLabel, "BOTTOMLEFT", 0, -10)
    toastXLabel:SetText("X:")

    local toastXEditBox = CreateFrame("EditBox", nil, tab1)
    toastXEditBox:SetSize(60, 20)
    toastXEditBox:SetPoint("LEFT", toastXLabel, "RIGHT", 5, 0)
    toastXEditBox:SetAutoFocus(false)
    toastXEditBox:SetMaxLetters(6)
    toastXEditBox:SetFontObject(GameFontHighlight)
    toastXEditBox:SetText(tostring((FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0))

    local toastXBg = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    toastXBg:SetPoint("TOPLEFT", toastXEditBox, -5, 5)
    toastXBg:SetPoint("BOTTOMRIGHT", toastXEditBox, 5, -5)
    toastXBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    toastXBg:SetBackdropColor(0, 0, 0, 0.8)

    toastXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.x = value
        end
    end)

    -- Y 위치
    local toastYLabel = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastYLabel:SetPoint("LEFT", toastXBg, "RIGHT", 15, 0)
    toastYLabel:SetText("Y:")

    local toastYEditBox = CreateFrame("EditBox", nil, tab1)
    toastYEditBox:SetSize(60, 20)
    toastYEditBox:SetPoint("LEFT", toastYLabel, "RIGHT", 5, 0)
    toastYEditBox:SetAutoFocus(false)
    toastYEditBox:SetMaxLetters(6)
    toastYEditBox:SetFontObject(GameFontHighlight)
    toastYEditBox:SetText(tostring((FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.y) or -320))

    local toastYBg = CreateFrame("Frame", nil, tab1, "BackdropTemplate")
    toastYBg:SetPoint("TOPLEFT", toastYEditBox, -5, 5)
    toastYBg:SetPoint("BOTTOMRIGHT", toastYEditBox, 5, -5)
    toastYBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    toastYBg:SetBackdropColor(0, 0, 0, 0.8)

    toastYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.y = value
        end
    end)

    -- 토스트 테스트 버튼
    local toastTestBtn = CreateFrame("Button", nil, tab1, "UIPanelButtonTemplate")
    toastTestBtn:SetSize(100, 22)
    toastTestBtn:SetPoint("LEFT", toastYBg, "RIGHT", 15, 0)
    toastTestBtn:SetText("토스트 테스트")
    toastTestBtn:SetScript("OnClick", function()
        if FoxChat and FoxChat.ShowToast then
            FoxChat.ShowToast("테스트 사용자", "토스트 위치 테스트 메시지입니다.", "GUILD", true)
        end
    end)

    -- =============================================
    -- 탭 2: 말머리/말꼬리
    -- =============================================
    local tab2 = tabContents[2]

    -- 말머리/말꼬리 활성화 체크박스
    local prefixSuffixEnabledCheckbox = CreateFrame("CheckButton", nil, tab2)
    prefixSuffixEnabledCheckbox:SetSize(24, 24)
    prefixSuffixEnabledCheckbox:SetPoint("TOPLEFT", tab2, "TOPLEFT", 10, -10)
    prefixSuffixEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    prefixSuffixEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    prefixSuffixEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    prefixSuffixEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    prefixSuffixEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.prefixSuffixEnabled)

    local prefixSuffixEnabledLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixSuffixEnabledLabel:SetPoint("LEFT", prefixSuffixEnabledCheckbox, "RIGHT", 5, 0)
    prefixSuffixEnabledLabel:SetText(L["PREFIX_SUFFIX_ENABLE"])

    prefixSuffixEnabledCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.prefixSuffixEnabled = self:GetChecked()
        end
    end)

    -- 설명 텍스트
    local prefixSuffixHelp = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    prefixSuffixHelp:SetPoint("TOPLEFT", prefixSuffixEnabledCheckbox, "BOTTOMLEFT", 0, -10)
    prefixSuffixHelp:SetText(L["PREFIX_SUFFIX_HELP"])

    -- 구분선
    local separator2 = CreateSeparator(tab2, "TOPLEFT", prefixSuffixHelp, "BOTTOMLEFT", -10, -10)

    -- 말머리 입력
    local prefixLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixLabel:SetPoint("TOPLEFT", separator2, "BOTTOMLEFT", 10, -15)
    prefixLabel:SetText(L["PREFIX_LABEL"])

    local prefixBackground = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
    prefixBackground:SetSize(250, 30)
    prefixBackground:SetPoint("LEFT", prefixLabel, "RIGHT", 10, 0)
    prefixBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    prefixBackground:SetBackdropColor(0, 0, 0, 0.8)

    prefixEditBox = CreateFrame("EditBox", nil, prefixBackground)
    prefixEditBox:SetSize(240, 25)
    prefixEditBox:SetPoint("LEFT", 5, 0)
    prefixEditBox:SetAutoFocus(false)
    prefixEditBox:SetMaxLetters(50)
    prefixEditBox:SetFontObject(GameFontHighlight)
    prefixEditBox:SetText((FoxChatDB and FoxChatDB.prefix) or "")

    prefixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.prefix = self:GetText()
        end
    end)

    prefixEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 말꼬리 입력
    local suffixLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    suffixLabel:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -15)
    suffixLabel:SetText(L["SUFFIX_LABEL"])

    local suffixBackground = CreateFrame("Frame", nil, tab2, "BackdropTemplate")
    suffixBackground:SetSize(250, 30)
    suffixBackground:SetPoint("LEFT", suffixLabel, "RIGHT", 10, 0)
    suffixBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    suffixBackground:SetBackdropColor(0, 0, 0, 0.8)

    suffixEditBox = CreateFrame("EditBox", nil, suffixBackground)
    suffixEditBox:SetSize(240, 25)
    suffixEditBox:SetPoint("LEFT", 5, 0)
    suffixEditBox:SetAutoFocus(false)
    suffixEditBox:SetMaxLetters(50)
    suffixEditBox:SetFontObject(GameFontHighlight)
    suffixEditBox:SetText((FoxChatDB and FoxChatDB.suffix) or "")

    suffixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.suffix = self:GetText()
        end
    end)

    suffixEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 말머리/말꼬리 적용 채널
    local prefixChannelsLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixChannelsLabel:SetPoint("TOPLEFT", suffixLabel, "BOTTOMLEFT", 0, -20)
    prefixChannelsLabel:SetText(L["PREFIX_SUFFIX_CHANNELS"])

    -- 채널 체크박스 옵션들
    local prefixChannelOptions = {
        {key = "SAY", text = L["CHANNEL_SAY"], x = 0, y = 0},
        {key = "YELL", text = L["CHANNEL_YELL"], x = 140, y = 0},
        {key = "PARTY", text = L["CHANNEL_PARTY"], x = 280, y = 0},
        {key = "GUILD", text = L["CHANNEL_GUILD"], x = 420, y = 0},
        {key = "RAID", text = L["CHANNEL_RAID"], x = 0, y = -30},
        {key = "INSTANCE_CHAT", text = L["CHANNEL_INSTANCE"], x = 140, y = -30},
        {key = "WHISPER", text = L["CHANNEL_WHISPER"], x = 280, y = -30},
        {key = "CHANNEL", text = L["CHANNEL_GENERAL"], x = 420, y = -30},
    }

    local prefixChannelCheckboxes = {}
    for _, channel in ipairs(prefixChannelOptions) do
        local checkbox = CreateFrame("CheckButton", nil, tab2)
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", prefixChannelsLabel, "BOTTOMLEFT", channel.x, channel.y - 15)
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        -- 체크 상태 설정
        checkbox:SetChecked(FoxChatDB and FoxChatDB.prefixSuffixChannels and FoxChatDB.prefixSuffixChannels[channel.key])

        local label = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        label:SetText(channel.text)

        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB then
                if not FoxChatDB.prefixSuffixChannels then
                    FoxChatDB.prefixSuffixChannels = {}
                end
                FoxChatDB.prefixSuffixChannels[channel.key] = self:GetChecked()
            end
        end)

        prefixChannelCheckboxes[channel.key] = checkbox
    end

    -- 예시 텍스트
    local exampleLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exampleLabel:SetPoint("TOPLEFT", prefixChannelsLabel, "BOTTOMLEFT", 0, -70)
    exampleLabel:SetText("예시:")

    local exampleText = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    exampleText:SetPoint("LEFT", exampleLabel, "RIGHT", 10, 0)

    -- 예시 텍스트 업데이트 함수
    local function UpdateExampleText()
        local prefix = (FoxChatDB and FoxChatDB.prefix) or ""
        local suffix = (FoxChatDB and FoxChatDB.suffix) or ""
        local example = prefix .. "안녕하세요!" .. suffix
        exampleText:SetText(example)
    end

    -- 말머리/말꼬리 변경 시 예시 업데이트
    prefixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.prefix = self:GetText()
        end
        UpdateExampleText()
    end)

    suffixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.suffix = self:GetText()
        end
        UpdateExampleText()
    end)

    -- 초기 예시 텍스트 설정
    UpdateExampleText()

    -- 팁 텍스트
    local tipLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tipLabel:SetPoint("TOPLEFT", exampleLabel, "BOTTOMLEFT", 0, -20)
    tipLabel:SetText("|cFFFFFF00팁:|r 위상 메시지(일위상, 이위상, 삼위상)는 자동으로 제외됩니다.")
    tipLabel:SetJustifyH("LEFT")

    -- =============================================
    -- 탭 3: 광고 설정
    -- =============================================
    local tab3 = tabContents[3]
    configFrame.tab3 = tab3  -- configFrame에 tab3 참조 저장

    -- 광고 메시지 레이블
    local adMessageLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adMessageLabel:SetPoint("TOPLEFT", tab3, "TOPLEFT", 10, -10)
    adMessageLabel:SetText("광고 메시지:")

    local adMessageHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adMessageHelp:SetPoint("TOPLEFT", adMessageLabel, "BOTTOMLEFT", 0, -3)
    adMessageHelp:SetText("Questie 퀘스트는 채팅창에 복사 후 아래에 붙여넣으면 편해요")

    -- 광고 메시지 입력 박스 (절반 크기로 수정)
    local adMessageBackground = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    adMessageBackground:SetSize(260, 60)
    adMessageBackground:SetPoint("TOPLEFT", adMessageHelp, "BOTTOMLEFT", 0, -5)
    adMessageBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    adMessageBackground:SetBackdropColor(0, 0, 0, 0.8)

    adMessageEditBox = CreateFrame("EditBox", "FoxChatAdMessageEditBox", adMessageBackground)
    adMessageEditBox:SetSize(240, 50)
    adMessageEditBox:SetPoint("TOPLEFT", 10, -5)
    adMessageEditBox:SetAutoFocus(false)
    adMessageEditBox:SetMultiLine(true)
    adMessageEditBox:SetMaxLetters(255)
    adMessageEditBox:SetFontObject(GameFontHighlight)
    adMessageEditBox:SetText((FoxChatDB and FoxChatDB.adMessage) or "")

    -- EditBox 클릭 영역 개선 - 배경을 클릭해도 EditBox에 포커스가 가도록
    adMessageBackground:EnableMouse(true)
    adMessageBackground:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            adMessageEditBox:SetFocus()
            -- 커서 위치는 건드리지 않음
        end
    end)

    -- EditBox의 기본 마우스 클릭 동작을 사용 (커서가 클릭한 위치로 이동)

    adMessageEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.adMessage = self:GetText()
            -- 광고 메시지 변경 시 버튼 상태 업데이트
            if tab3.UpdateAdStartButton then
                tab3.UpdateAdStartButton()
            end
            if FoxChat and FoxChat.UpdateAdButton then
                FoxChat:UpdateAdButton()
            end
        end
    end)

    adMessageEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 선입 메시지 레이블
    local firstComeLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    firstComeLabel:SetPoint("TOPLEFT", adMessageLabel, "TOPRIGHT", 280, 0)
    firstComeLabel:SetText("선입 메시지:")

    local firstComeHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    firstComeHelp:SetPoint("TOPLEFT", firstComeLabel, "BOTTOMLEFT", 0, -3)
    firstComeHelp:SetText("파티/공격대원에게 외칠 메시지")

    -- 선입 메시지 입력 박스
    local firstComeBackground = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    firstComeBackground:SetSize(260, 60)
    firstComeBackground:SetPoint("LEFT", adMessageBackground, "RIGHT", 10, 0)
    firstComeBackground:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    firstComeBackground:SetBackdropColor(0, 0, 0, 0.8)

    local firstComeEditBox = CreateFrame("EditBox", "FoxChatFirstComeEditBox", firstComeBackground)
    firstComeEditBox:SetSize(240, 50)
    firstComeEditBox:SetPoint("TOPLEFT", 10, -5)
    firstComeEditBox:SetAutoFocus(false)
    firstComeEditBox:SetMultiLine(true)
    firstComeEditBox:SetMaxLetters(255)
    firstComeEditBox:SetFontObject(GameFontHighlight)
    firstComeEditBox:SetText((FoxChatDB and FoxChatDB.firstComeMessage) or "")

    -- EditBox 클릭 영역 개선 - 배경을 클릭해도 EditBox에 포커스가 가도록
    firstComeBackground:EnableMouse(true)
    firstComeBackground:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            firstComeEditBox:SetFocus()
            -- 커서 위치는 건드리지 않음
        end
    end)

    -- EditBox의 기본 마우스 클릭 동작을 사용 (커서가 클릭한 위치로 이동)

    firstComeEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.firstComeMessage = self:GetText()
            -- 선입 메시지 변경 시 버튼 상태 업데이트
            if tab3.UpdateFirstComeStartButton then
                tab3.UpdateFirstComeStartButton()
            end
            if FoxChat and FoxChat.UpdateFirstComeButton then
                FoxChat:UpdateFirstComeButton()
            end
        end
    end)

    firstComeEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 구분선
    local separator3 = CreateSeparator(tab3, "TOPLEFT", adMessageBackground, "BOTTOMLEFT", -10, -15)

    -- 광고 버튼 위치 설정
    local adPosLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adPosLabel:SetPoint("TOPLEFT", separator3, "BOTTOMLEFT", 10, -15)
    adPosLabel:SetText("광고 버튼 위치:")

    local adPosDesc = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adPosDesc:SetPoint("LEFT", adPosLabel, "RIGHT", 10, 0)
    adPosDesc:SetText("(0, 0)이 화면 정중앙 | Shift+드래그로 버튼 이동 가능")

    -- X 위치
    local adXLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adXLabel:SetPoint("TOPLEFT", adPosLabel, "BOTTOMLEFT", 0, -15)
    adXLabel:SetText("X:")

    local adXEditBox = CreateFrame("EditBox", nil, tab3)
    adXEditBox:SetSize(60, 20)
    adXEditBox:SetPoint("LEFT", adXLabel, "RIGHT", 5, 0)
    adXEditBox:SetAutoFocus(false)
    adXEditBox:SetMaxLetters(6)
    adXEditBox:SetFontObject(GameFontHighlight)
    adXEditBox:SetNumeric(false)
    adXEditBox:SetText(tostring((FoxChatDB and FoxChatDB.adPosition and FoxChatDB.adPosition.x) or 350))
    configFrame.adXEditBox = adXEditBox  -- 참조 저장

    local adXBg = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    adXBg:SetPoint("TOPLEFT", adXEditBox, -5, 5)
    adXBg:SetPoint("BOTTOMRIGHT", adXEditBox, 5, -5)
    adXBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    adXBg:SetBackdropColor(0, 0, 0, 0.8)

    adXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.adPosition then
                FoxChatDB.adPosition = {x = 350, y = -150}
            end
            FoxChatDB.adPosition.x = value
            if _G["FoxChatAdButton"] then
                _G["FoxChatAdButton"]:ClearAllPoints()
                _G["FoxChatAdButton"]:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
            end
        end
    end)

    adXEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Y 위치
    local adYLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adYLabel:SetPoint("LEFT", adXBg, "RIGHT", 15, 0)
    adYLabel:SetText("Y:")

    local adYEditBox = CreateFrame("EditBox", nil, tab3)
    adYEditBox:SetSize(60, 20)
    adYEditBox:SetPoint("LEFT", adYLabel, "RIGHT", 5, 0)
    adYEditBox:SetAutoFocus(false)
    adYEditBox:SetMaxLetters(6)
    adYEditBox:SetFontObject(GameFontHighlight)
    adYEditBox:SetNumeric(false)
    adYEditBox:SetText(tostring((FoxChatDB and FoxChatDB.adPosition and FoxChatDB.adPosition.y) or -150))
    configFrame.adYEditBox = adYEditBox  -- 참조 저장

    local adYBg = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    adYBg:SetPoint("TOPLEFT", adYEditBox, -5, 5)
    adYBg:SetPoint("BOTTOMRIGHT", adYEditBox, 5, -5)
    adYBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    adYBg:SetBackdropColor(0, 0, 0, 0.8)

    adYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.adPosition then
                FoxChatDB.adPosition = {x = 350, y = -150}
            end
            FoxChatDB.adPosition.y = value
            if _G["FoxChatAdButton"] then
                _G["FoxChatAdButton"]:ClearAllPoints()
                _G["FoxChatAdButton"]:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
            end
        end
    end)

    adYEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 쿨타임 설정
    local cooldownLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cooldownLabel:SetPoint("TOPLEFT", adXLabel, "BOTTOMLEFT", 0, -20)
    cooldownLabel:SetText("쿨타임:")

    -- 쿨타임 드롭다운
    local cooldownDropdown = CreateFrame("Frame", "FoxChatCooldownDropdown", tab3, "UIDropDownMenuTemplate")
    cooldownDropdown:SetPoint("LEFT", cooldownLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(cooldownDropdown, 100)

    local cooldownOptions = {
        {value = 30, text = "30초"},
        {value = 45, text = "45초"},
        {value = 60, text = "60초"},
    }

    local function CooldownDropdown_Initialize(self)
        for _, option in ipairs(cooldownOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(cooldownDropdown, option.value)
                UIDropDownMenu_SetText(cooldownDropdown, option.text)
                if FoxChatDB then
                    FoxChatDB.adCooldown = option.value
                end
                -- 안내 텍스트 업데이트
                if tab3.UpdateInfoText then
                    tab3.UpdateInfoText()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(cooldownDropdown, CooldownDropdown_Initialize)
    local currentCooldown = (FoxChatDB and FoxChatDB.adCooldown) or 30
    UIDropDownMenu_SetSelectedValue(cooldownDropdown, currentCooldown)
    UIDropDownMenu_SetText(cooldownDropdown, currentCooldown .. "초")

    -- 파티원 수 설정
    local partyMaxLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partyMaxLabel:SetPoint("LEFT", cooldownDropdown, "RIGHT", 20, 2)
    partyMaxLabel:SetText("파티원수:")

    -- 파티원수 도움말 (0 설명 추가)
    local partyMaxHelp = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partyMaxHelp:SetPoint("TOPLEFT", partyMaxLabel, "BOTTOMLEFT", 0, -2)
    partyMaxHelp:SetText("|cFF808080(0=수동입력)|r")
    partyMaxHelp:SetTextColor(0.7, 0.7, 0.7)

    local partyMaxBackground = CreateFrame("Frame", nil, tab3, "BackdropTemplate")
    partyMaxBackground:SetSize(50, 24)
    partyMaxBackground:SetPoint("LEFT", partyMaxLabel, "RIGHT", 5, -2)
    if partyMaxBackground.SetBackdrop then
        partyMaxBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        partyMaxBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    local partyMaxEditBox = CreateFrame("EditBox", nil, partyMaxBackground)
    partyMaxEditBox:SetSize(40, 20)
    partyMaxEditBox:SetPoint("LEFT", 5, 0)
    partyMaxEditBox:SetAutoFocus(false)
    partyMaxEditBox:SetMaxLetters(2)  -- 최대 2자리 숫자 (0-40)
    partyMaxEditBox:SetFontObject(GameFontHighlight)
    partyMaxEditBox:SetNumeric(false)  -- false로 변경하여 더 유연한 입력 허용
    partyMaxEditBox:SetText(tostring((FoxChatDB and FoxChatDB.partyMaxSize) or 5))

    partyMaxEditBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        -- 숫자가 아닌 문자 제거
        local cleanText = text:gsub("%D", "")
        if cleanText ~= text then
            self:SetText(cleanText)
            return
        end

        local value = tonumber(cleanText)
        if value then
            -- 0부터 40까지 제한
            if value < 0 then
                value = 0
                self:SetText("0")
            elseif value > 40 then
                value = 40
                self:SetText("40")
            end
            if FoxChatDB then
                FoxChatDB.partyMaxSize = value
            end
        end
    end)

    partyMaxEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    partyMaxEditBox:SetScript("OnEditFocusLost", function(self)
        local value = tonumber(self:GetText())
        if not value or value < 0 or value > 40 then
            self:SetText(tostring((FoxChatDB and FoxChatDB.partyMaxSize) or 5))
        end
    end)

    -- 자동 중지 옵션 제거 (더 이상 사용하지 않음)

    -- 광고 채널 선택
    local channelLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", cooldownLabel, "BOTTOMLEFT", 0, -25)
    channelLabel:SetText("광고 채널:")

    -- 채널 드롭다운
    local channelDropdown = CreateFrame("Frame", "FoxChatChannelDropdown", tab3, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(channelDropdown, 150)

    local function ChannelDropdown_Initialize(self)
        -- 현재 참여 중인 채널 목록 가져오기
        local channels = {GetChannelList()}
        local addedChannels = {}

        for i = 1, #channels, 3 do
            local id, name = channels[i], channels[i+1]
            if name then
                -- 채널명 정리 (서버명 제거)
                local cleanName = name
                if string.find(name, "LookingForGroup") then
                    cleanName = "파티찾기"
                elseif string.find(name, "General") or string.find(name, "일반") then
                    cleanName = "공개"
                elseif string.find(name, "Trade") or string.find(name, "거래") then
                    cleanName = "거래"
                elseif string.find(name, "LocalDefense") or string.find(name, "지역방어") then
                    cleanName = "지역방어"
                else
                    -- 사용자 채널 (숫자. 채널명)
                    local customMatch = string.match(name, "%d+%.%s*(.+)")
                    if customMatch then
                        cleanName = customMatch
                    end
                end

                -- 중복 제거
                if not addedChannels[cleanName] then
                    addedChannels[cleanName] = true
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = cleanName
                    info.value = cleanName
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(channelDropdown, cleanName)
                        UIDropDownMenu_SetText(channelDropdown, cleanName)
                        if FoxChatDB then
                            FoxChatDB.adChannel = cleanName
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end

    UIDropDownMenu_Initialize(channelDropdown, ChannelDropdown_Initialize)
    local currentChannel = (FoxChatDB and FoxChatDB.adChannel) or "파티찾기"
    UIDropDownMenu_SetSelectedValue(channelDropdown, currentChannel)
    UIDropDownMenu_SetText(channelDropdown, currentChannel)

    -- 광고 시작/중지 버튼
    local adStartButton = CreateFrame("Button", nil, tab3, "UIPanelButtonTemplate")
    adStartButton:SetSize(100, 25)
    adStartButton:SetPoint("LEFT", channelDropdown, "RIGHT", 20, 2)
    adStartButton:SetText((FoxChatDB and FoxChatDB.adEnabled) and "광고 중지" or "광고 시작")

    -- 선입 메시지 알림 활성화 버튼
    local firstComeStartButton = CreateFrame("Button", nil, tab3, "UIPanelButtonTemplate")
    firstComeStartButton:SetSize(170, 25)
    firstComeStartButton:SetPoint("LEFT", adStartButton, "RIGHT", 10, 0)
    firstComeStartButton:SetText((FoxChatDB and FoxChatDB.firstComeEnabled) and "선입 메시지 알림 비활성화" or "선입 메시지 알림 활성화")

    -- 버튼 상태 업데이트 함수
    local function UpdateAdStartButton()
        local message = FoxChatDB and FoxChatDB.adMessage or ""
        local isEmpty = not message or string.gsub(message, "%s+", "") == ""

        if isEmpty then
            -- 메시지가 비어있으면 버튼 비활성화
            adStartButton:Disable()
            adStartButton:SetText("광고 시작")
            if FoxChatDB and FoxChatDB.adEnabled then
                -- 광고가 실행 중이었다면 중단
                FoxChatDB.adEnabled = false
                if FoxChat and FoxChat.UpdateAdButton then
                    FoxChat:UpdateAdButton()
                end
            end
        else
            -- 메시지가 있으면 버튼 활성화
            adStartButton:Enable()
            if FoxChatDB and FoxChatDB.adEnabled then
                adStartButton:SetText("광고 중지")
            else
                adStartButton:SetText("광고 시작")
            end
        end
    end

    -- 초기 버튼 상태 설정
    UpdateAdStartButton()
    tab3.UpdateAdStartButton = UpdateAdStartButton  -- 참조 저장

    adStartButton:SetScript("OnClick", function(self)
        if FoxChatDB then
            -- 목표 인원 체크 제거 - 항상 광고 시작 가능

            FoxChatDB.adEnabled = not FoxChatDB.adEnabled

            -- 광고 시작 시 선입 메시지 알림도 자동 활성화
            if FoxChatDB.adEnabled then
                -- 선입 메시지가 있으면 선입 알림도 활성화
                local firstComeMessage = FoxChatDB.firstComeMessage or ""
                if firstComeMessage ~= "" and string.gsub(firstComeMessage, "%s+", "") ~= "" then
                    FoxChatDB.firstComeEnabled = true
                    -- 선입 버튼 상태 업데이트
                    if tab3.UpdateFirstComeStartButton then
                        tab3.UpdateFirstComeStartButton()
                    end
                    if FoxChat and FoxChat.UpdateFirstComeButton then
                        FoxChat:UpdateFirstComeButton()
                    end
                end
            else
                -- 광고 중지 시 쿨다운 초기화 (선입 알림은 유지)
                if FoxChat and FoxChat.ResetAdCooldown then
                    FoxChat:ResetAdCooldown()
                end
            end

            UpdateAdStartButton()
            if FoxChat and FoxChat.UpdateAdButton then
                FoxChat:UpdateAdButton()
            end
        end
    end)

    -- 선입 메시지 알림 버튼 상태 업데이트 함수
    local function UpdateFirstComeStartButton()
        local message = FoxChatDB and FoxChatDB.firstComeMessage or ""
        local isEmpty = not message or string.gsub(message, "%s+", "") == ""

        if isEmpty then
            -- 메시지가 비어있으면 버튼 비활성화
            firstComeStartButton:Disable()
            firstComeStartButton:SetText("선입 메시지 알림 활성화")
            if FoxChatDB and FoxChatDB.firstComeEnabled then
                -- 선입 알림이 실행 중이었다면 중단
                FoxChatDB.firstComeEnabled = false
                if FoxChat and FoxChat.UpdateFirstComeButton then
                    FoxChat:UpdateFirstComeButton()
                end
            end
        else
            -- 메시지가 있으면 버튼 활성화
            firstComeStartButton:Enable()
            if FoxChatDB and FoxChatDB.firstComeEnabled then
                firstComeStartButton:SetText("선입 메시지 알림 비활성화")
            else
                firstComeStartButton:SetText("선입 메시지 알림 활성화")
            end
        end
    end

    -- 초기 버튼 상태 설정
    UpdateFirstComeStartButton()
    tab3.UpdateFirstComeStartButton = UpdateFirstComeStartButton  -- 참조 저장

    firstComeStartButton:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.firstComeEnabled = not FoxChatDB.firstComeEnabled
            UpdateFirstComeStartButton()
            if FoxChat and FoxChat.UpdateFirstComeButton then
                FoxChat:UpdateFirstComeButton()
            end
        end
    end)

    -- 안내 메시지
    local infoLabel = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -25)
    infoLabel:SetText("|cFFFFFF00안내:|r")

    local infoText = tab3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -5)
    infoText:SetWidth(540)
    infoText:SetHeight(80)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    tab3.infoText = infoText  -- 참조 저장

    -- 안내 텍스트 업데이트 함수
    local function UpdateInfoText()
        local cooldown = (FoxChatDB and FoxChatDB.adCooldown) or 30
        infoText:SetText(
            "• 광고 버튼을 클릭하면 파티찾기 채널에 메시지가 전송됩니다.\n" ..
            "• " .. cooldown .. "초 쿨다운이 적용되어 스팸을 방지합니다.\n" ..
            "• 파티원수를 0으로 설정하면 (1/13) 같은 인원수를 직접 입력할 수 있습니다.\n" ..
            "• Blizzard EULA 준수: 자동화 없이 수동 클릭만 가능합니다.\n" ..
            "• 광고 버튼은 화면에서 Shift+드래그로 이동할 수 있습니다."
        )
    end

    -- 초기 텍스트 설정
    UpdateInfoText()
    tab3.UpdateInfoText = UpdateInfoText  -- 참조 저장

    -- =============================================
    -- 하단 버튼들
    -- =============================================

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 25)
    closeButton:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -20, 20)
    closeButton:SetText(L["CLOSE_BUTTON"])
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    -- 테스트 버튼 (채팅 필터링 탭에만 표시)
    local testButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 25)
    testButton:SetPoint("RIGHT", closeButton, "LEFT", -10, 0)
    testButton:SetText(L["TEST_BUTTON"])
    testButton:Hide()  -- 기본적으로 숨김
    testButton:SetScript("OnClick", function()
        -- 테스트 메시지 생성
        local testMsg = "[FoxChat 테스트] 하이라이트 테스트 메시지입니다."
        if FoxChatDB and FoxChatDB.keywords and type(FoxChatDB.keywords) == "table" and #FoxChatDB.keywords > 0 then
            testMsg = testMsg .. " 키워드: " .. FoxChatDB.keywords[1]
        end

        -- 채팅창에 테스트 메시지 표시
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A" .. testMsg .. "|r")

        -- 하이라이트 효과 테스트
        if FoxChat and FoxChat.TestHighlight then
            FoxChat:TestHighlight()
        end
    end)
    configFrame.testButton = testButton  -- 참조 저장

    -- 초기화 버튼
    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(80, 25)
    resetButton:SetPoint("RIGHT", testButton, "LEFT", -10, 0)
    resetButton:SetText(L["RESET_BUTTON"])
    resetButton:SetScript("OnClick", function()
        local tabName = {
            [1] = "채팅 필터링",
            [2] = "말머리/말꼬리",
            [3] = "광고 설정"
        }

        -- 초기화 확인 다이얼로그
        StaticPopupDialogs["FOXCHAT_RESET_CONFIRM"] = {
            text = tabName[currentTab] .. " 설정을 초기화하시겠습니까?\n해당 탭의 설정만 기본값으로 되돌아갑니다.",
            button1 = "확인",
            button2 = "취소",
            OnAccept = function()
                if not FoxChatDB then FoxChatDB = {} end

                -- 탭별로 초기화
                if currentTab == 1 then
                    -- 채팅 필터링 초기화
                    FoxChatDB.enabled = true
                    FoxChatDB.keywords = {}
                    FoxChatDB.ignoreKeywords = {}
                    FoxChatDB.soundEnabled = true
                    FoxChatDB.minimapButtonEnabled = true
                    FoxChatDB.highlightStyle = "both"
                    FoxChatDB.toastPosition = {x = 0, y = -320}
                    FoxChatDB.highlightColors = {
                        GUILD = {r = 0, g = 1, b = 0},
                        PUBLIC = {r = 1, g = 1, b = 0},
                        PARTY_RAID = {r = 0, g = 0.5, b = 1},
                        LFG = {r = 1, g = 0.5, b = 0},
                    }
                elseif currentTab == 2 then
                    -- 말머리/말꼬리 초기화
                    FoxChatDB.prefixSuffixEnabled = false
                    FoxChatDB.prefix = ""
                    FoxChatDB.suffix = ""
                    FoxChatDB.prefixChannels = {
                        SAY = true,
                        YELL = false,
                        PARTY = true,
                        GUILD = true,
                        RAID = true,
                        INSTANCE_CHAT = true,
                        WHISPER = false,
                        CHANNEL = false,
                    }
                elseif currentTab == 3 then
                    -- 광고 설정 초기화
                    FoxChatDB.adEnabled = false
                    FoxChatDB.adMessage = ""
                    FoxChatDB.adPosition = {x = 350, y = -150}
                    FoxChatDB.adCooldown = 15
                    FoxChatDB.adChannel = "파티찾기"
                end

                -- UI 업데이트
                if configFrame.RefreshUI then
                    configFrame:RefreshUI()
                end

                -- 메시지 표시
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r " .. tabName[currentTab] .. " 설정이 초기화되었습니다.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("FOXCHAT_RESET_CONFIRM")
    end)

    -- X 버튼 (우측 상단)
    local xButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    xButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
    xButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    -- ESC 키로 닫기
    tinsert(UISpecialFrames, "FoxChatConfigFrame")

    -- =============================================
    -- 초기 탭 선택
    -- =============================================
    local initialTab = (FoxChatDB and FoxChatDB.lastTab) or 1
    SwitchToTab(initialTab)

    -- UI 업데이트 함수
    local function RefreshUI()
        -- 탭 1 - 채팅 필터링 업데이트
        if filterEnabledCheckbox then
            filterEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.enabled)
        end
        if soundEnabledCheckbox then
            soundEnabledCheckbox:SetChecked(FoxChatDB and FoxChatDB.soundEnabled)
        end
        if minimapButtonCheckbox then
            minimapButtonCheckbox:SetChecked(FoxChatDB and FoxChatDB.minimapButtonEnabled)
        end
        if keywordsEditBox then
            local keywordText = ""
            if FoxChatDB and FoxChatDB.keywords then
                if type(FoxChatDB.keywords) == "table" then
                    keywordText = table.concat(FoxChatDB.keywords, ", ")
                else
                    keywordText = tostring(FoxChatDB.keywords)
                end
            end
            keywordsEditBox:SetText(keywordText)
        end
        if ignoreKeywordsEditBox then
            local ignoreText = ""
            if FoxChatDB and FoxChatDB.ignoreKeywords then
                if type(FoxChatDB.ignoreKeywords) == "table" then
                    ignoreText = table.concat(FoxChatDB.ignoreKeywords, ", ")
                else
                    ignoreText = tostring(FoxChatDB.ignoreKeywords)
                end
            end
            ignoreKeywordsEditBox:SetText(ignoreText)
        end

        -- 탭 2 - 말머리/말꼬리 업데이트
        if prefixEditBox then
            prefixEditBox:SetText((FoxChatDB and FoxChatDB.prefix) or "")
        end
        if suffixEditBox then
            suffixEditBox:SetText((FoxChatDB and FoxChatDB.suffix) or "")
        end

        -- 탭 3 - 광고 설정 업데이트
        if adMessageEditBox then
            adMessageEditBox:SetText((FoxChatDB and FoxChatDB.adMessage) or "")
        end
        -- 쿨타임 드롭다운 업데이트
        local cooldownDropdown = _G["FoxChatCooldownDropdown"]
        if cooldownDropdown then
            local currentCooldown = (FoxChatDB and FoxChatDB.adCooldown) or 15
            UIDropDownMenu_SetSelectedValue(cooldownDropdown, currentCooldown)
            UIDropDownMenu_SetText(cooldownDropdown, currentCooldown .. "초")
        end
        -- 채널 드롭다운 업데이트
        local channelDropdown = _G["FoxChatChannelDropdown"]
        if channelDropdown then
            local currentChannel = (FoxChatDB and FoxChatDB.adChannel) or "파티찾기"
            UIDropDownMenu_SetSelectedValue(channelDropdown, currentChannel)
            UIDropDownMenu_SetText(channelDropdown, currentChannel)
        end
        -- 안내 텍스트 업데이트
        if tabContents and tabContents[3] and tabContents[3].UpdateInfoText then
            tabContents[3].UpdateInfoText()
        end
    end

    -- 초기 UI 업데이트
    configFrame.RefreshUI = RefreshUI
    RefreshUI()

    configFrame:Show()
end

-- 디버그용: 새 탭 UI 테스트 명령어
SLASH_FOXCHATTAB1 = "/fctab"
SlashCmdList["FOXCHATTAB"] = function(msg)
    FoxChat:ShowConfig()
end