local addonName, addon = ...
local L = addon.L

local configFrame = nil
local keywordsEditBox = nil
local ignoreKeywordsEditBox = nil
local prefixEditBox = nil
local suffixEditBox = nil

local defaults = {
    enabled = true,
    keywords = L["DEFAULT_KEYWORDS"],
    ignoreKeywords = "",
    playSound = true,
    soundVolume = 0.5,
    highlightColors = {
        GUILD = {r = 0, g = 1, b = 0}, -- 길드: 초록색
        PUBLIC = {r = 1, g = 1, b = 0}, -- 공개: 노란색
        PARTY_RAID = {r = 0, g = 0.5, b = 1}, -- 파티/공격대: 파란색
        LFG = {r = 1, g = 0.5, b = 0}, -- 파티찾기: 주황색
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
    }
}

-- 구분선 생성 함수
local function CreateSeparator(parent, point, relativeTo, relativePoint, x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.6, 0.6, 0.6, 0.6)
    line:SetPoint(point, relativeTo, relativePoint, x, y)
    line:SetPoint("RIGHT", parent, "RIGHT", -30, y)
    return line
end

-- 섹션 헤더 생성 함수
local function CreateSectionHeader(parent, text, point, relativeTo, relativePoint, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint(point, relativeTo, relativePoint, x, y)
    header:SetText(text)
    header:SetTextColor(1, 0.8, 0)
    return header
end

function FoxChat:ShowConfig()
    if configFrame then
        configFrame:Show()
        configFrame:Raise()  -- 창을 최상위로 올림
        return
    end
    
    -- 메인 프레임
    configFrame = CreateFrame("Frame", "FoxChatConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(520, 850)
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
    if configFrame.SetBackdrop then
        configFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
    end
    
    -- 제목
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -20)
    title:SetText(L["CONFIG_TITLE"])
    
    -- 채팅 필터링 활성화 체크박스
    local filterEnabledCheckbox = CreateFrame("CheckButton", nil, configFrame)
    filterEnabledCheckbox:SetSize(24, 24)
    filterEnabledCheckbox:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 30, -50)
    filterEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    filterEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    filterEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    filterEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    filterEnabledCheckbox:SetChecked(FoxChatDB.filterEnabled)
    
    local filterEnabledLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterEnabledLabel:SetPoint("LEFT", filterEnabledCheckbox, "RIGHT", 5, 0)
    filterEnabledLabel:SetText(L["FILTER_ENABLE"])
    
    filterEnabledCheckbox:SetScript("OnClick", function(self)
        FoxChatDB.filterEnabled = self:GetChecked()
    end)
    
    -- 소리 재생 체크박스
    local soundCheckbox = CreateFrame("CheckButton", nil, configFrame)
    soundCheckbox:SetSize(24, 24)
    soundCheckbox:SetPoint("TOPLEFT", filterEnabledCheckbox, "BOTTOMLEFT", 0, -10)
    soundCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    soundCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    soundCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    soundCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    soundCheckbox:SetChecked(FoxChatDB.playSound)
    
    local soundLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundLabel:SetText(L["PLAY_SOUND"])
    
    soundCheckbox:SetScript("OnClick", function(self)
        FoxChatDB.playSound = self:GetChecked()
    end)
    
    -- 미니맵 버튼 표시 체크박스
    local minimapCheckbox = CreateFrame("CheckButton", nil, configFrame)
    minimapCheckbox:SetSize(24, 24)
    minimapCheckbox:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 0, -10)
    minimapCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    minimapCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    minimapCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    minimapCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    minimapCheckbox:SetChecked(not FoxChatDB.minimapButton.hide)
    
    local minimapLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
    minimapLabel:SetText(L["SHOW_MINIMAP_BUTTON"])
    
    minimapCheckbox:SetScript("OnClick", function(self)
        FoxChatDB.minimapButton.hide = not self:GetChecked()
        if FoxChatDB.minimapButton.hide then
            _G["FoxChatMinimapButton"]:Hide()
        else
            _G["FoxChatMinimapButton"]:Show()
        end
    end)
    
    -- 첫 번째 구분선
    local separator1 = CreateSeparator(configFrame, "TOPLEFT", minimapCheckbox, "BOTTOMLEFT", -5, -15)
    
    -- ======================== 채팅 필터링 섹션 ========================
    local filterHeader = CreateSectionHeader(configFrame, L["SECTION_CHAT_FILTER"], "TOPLEFT", separator1, "BOTTOMLEFT", 5, -10)
    
    -- 필터링 문구 및 무시할 문구 레이블
    local keywordsLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keywordsLabel:SetPoint("TOPLEFT", filterHeader, "BOTTOMLEFT", 0, -10)
    keywordsLabel:SetText(L["KEYWORDS_LABEL"])

    local ignoreLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ignoreLabel:SetPoint("TOPLEFT", keywordsLabel, "TOPRIGHT", 210, 0)
    ignoreLabel:SetText(L["IGNORE_KEYWORDS_LABEL"])

    -- 도움말
    local keywordsHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keywordsHelp:SetPoint("TOPLEFT", keywordsLabel, "BOTTOMLEFT", 0, -3)
    keywordsHelp:SetText(L["KEYWORDS_HELP"])

    local ignoreHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ignoreHelp:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -3)
    ignoreHelp:SetText(L["IGNORE_KEYWORDS_HELP"])

    -- 필터링 키워드 입력 박스
    local keywordsBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    keywordsBackground:SetSize(220, 50)
    keywordsBackground:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)
    if keywordsBackground.SetBackdrop then
        keywordsBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        keywordsBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    keywordsEditBox = CreateFrame("EditBox", nil, keywordsBackground)
    keywordsEditBox:SetSize(200, 40)
    keywordsEditBox:SetPoint("TOPLEFT", 10, -5)
    keywordsEditBox:SetAutoFocus(false)
    keywordsEditBox:SetMultiLine(true)
    keywordsEditBox:SetMaxLetters(500)
    keywordsEditBox:SetFontObject(GameFontHighlight)
    keywordsEditBox:SetText(FoxChatDB.keywords or defaults.keywords)

    -- 무시할 키워드 입력 박스
    local ignoreBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    ignoreBackground:SetSize(210, 50)
    ignoreBackground:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)
    if ignoreBackground.SetBackdrop then
        ignoreBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        ignoreBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    ignoreKeywordsEditBox = CreateFrame("EditBox", nil, ignoreBackground)
    ignoreKeywordsEditBox:SetSize(190, 40)
    ignoreKeywordsEditBox:SetPoint("TOPLEFT", 10, -5)
    ignoreKeywordsEditBox:SetAutoFocus(false)
    ignoreKeywordsEditBox:SetMultiLine(true)
    ignoreKeywordsEditBox:SetMaxLetters(500)
    ignoreKeywordsEditBox:SetFontObject(GameFontHighlight)
    ignoreKeywordsEditBox:SetText(FoxChatDB.ignoreKeywords or defaults.ignoreKeywords)
    
    keywordsEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB.keywords = self:GetText()
        FoxChat:UpdateKeywords()
    end)

    ignoreKeywordsEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB.ignoreKeywords = self:GetText()
        FoxChat:UpdateIgnoreKeywords()
    end)

    ignoreKeywordsEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    keywordsEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- 하이라이트 스타일
    local styleLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", keywordsBackground, "BOTTOMLEFT", 0, -15)
    styleLabel:SetText(L["HIGHLIGHT_STYLE"])
    
    -- 스타일 옵션들
    local styles = {
        {value = "bold", text = L["STYLE_BOLD"], x = 0},
        {value = "color", text = L["STYLE_COLOR"], x = 120},
        {value = "both", text = L["STYLE_BOTH"], x = 240},
    }
    
    local styleButtons = {}
    for i, style in ipairs(styles) do
        local radioButton = CreateFrame("CheckButton", nil, configFrame)
        radioButton:SetSize(24, 24)
        radioButton:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", style.x, -5)
        radioButton:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        radioButton:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        radioButton:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        radioButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        radioButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        local label = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", radioButton, "RIGHT", 3, 0)
        label:SetText(style.text)
        
        radioButton.value = style.value
        radioButton:SetChecked(FoxChatDB.highlightStyle == style.value)
        
        radioButton:SetScript("OnClick", function(self)
            -- 다른 라디오 버튼들 해제
            for _, btn in ipairs(styleButtons) do
                btn:SetChecked(false)
            end
            self:SetChecked(true)
            FoxChatDB.highlightStyle = self.value
        end)
        
        styleButtons[i] = radioButton
    end
    
    -- 채널별 색상 및 모니터링 설정 (한 줄로 배치)
    local colorLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -35)
    colorLabel:SetText(L["CHANNELS_AND_COLORS"])

    -- 채널 그룹 옵션 (색상과 체크박스를 함께 배치)
    local colorSwatches = {}
    local channelCheckboxes = {}
    local channelGroupOptions = {
        {key = "GUILD", text = L["CHANNEL_GROUP_GUILD"], x = 0},
        {key = "PUBLIC", text = L["CHANNEL_GROUP_PUBLIC"], x = 110},
        {key = "PARTY_RAID", text = L["CHANNEL_GROUP_PARTY_RAID"], x = 220},
        {key = "LFG", text = L["CHANNEL_GROUP_LFG"], x = 360},
    }

    for i, group in ipairs(channelGroupOptions) do
        -- 체크박스 먼저 생성
        local checkbox = CreateFrame("CheckButton", nil, configFrame)
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", group.x, -20)
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkbox:SetChecked(FoxChatDB.channelGroups and FoxChatDB.channelGroups[group.key])

        checkbox:SetScript("OnClick", function(self)
            if not FoxChatDB.channelGroups then
                FoxChatDB.channelGroups = {}
            end
            FoxChatDB.channelGroups[group.key] = self:GetChecked()
        end)

        channelCheckboxes[group.key] = checkbox

        -- 채널 이름 레이블
        local groupLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        groupLabel:SetText(group.text)

        -- 색상 선택 버튼
        local colorSwatch = CreateFrame("Button", nil, configFrame)
        colorSwatch:SetSize(20, 20)
        colorSwatch:SetPoint("LEFT", groupLabel, "RIGHT", 5, 0)

        local colorTexture = colorSwatch:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints()
        local color = (FoxChatDB.highlightColors and FoxChatDB.highlightColors[group.key]) or defaults.highlightColors[group.key]
        colorTexture:SetColorTexture(color.r, color.g, color.b)

        local colorBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
        colorBorder:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        colorBorder:SetAllPoints()

        colorSwatches[group.key] = {texture = colorTexture, color = color}

        colorSwatch:SetScript("OnClick", function()
            local groupKey = group.key
            local function OnColorSelect()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                if not FoxChatDB.highlightColors then
                    FoxChatDB.highlightColors = {}
                end
                FoxChatDB.highlightColors[groupKey] = {r = r, g = g, b = b}
                colorTexture:SetColorTexture(r, g, b)
                colorSwatches[groupKey].color = {r = r, g = g, b = b}
            end

            local function OnCancel(previousValues)
                if previousValues then
                    if not FoxChatDB.highlightColors then
                        FoxChatDB.highlightColors = {}
                    end
                    FoxChatDB.highlightColors[groupKey] = {
                        r = previousValues.r,
                        g = previousValues.g,
                        b = previousValues.b
                    }
                    colorTexture:SetColorTexture(previousValues.r, previousValues.g, previousValues.b)
                end
            end

            ColorPickerFrame.swatchFunc = OnColorSelect
            ColorPickerFrame.cancelFunc = OnCancel
            ColorPickerFrame.previousValues = {
                r = color.r,
                g = color.g,
                b = color.b
            }
            ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
            ColorPickerFrame:Show()
        end)
    end

    -- 두 번째 구분선
    local separator2 = CreateSeparator(configFrame, "TOPLEFT", colorLabel, "BOTTOMLEFT", -5, -60)
    
    -- ======================== 말머리/말꼬리 섹션 ========================
    local prefixSuffixHeader = CreateSectionHeader(configFrame, L["SECTION_PREFIX_SUFFIX"], "TOPLEFT", separator2, "BOTTOMLEFT", 5, -10)
    
    -- 말머리/말꼬리 활성화 체크박스
    local prefixSuffixEnabledCheckbox = CreateFrame("CheckButton", nil, configFrame)
    prefixSuffixEnabledCheckbox:SetSize(24, 24)
    prefixSuffixEnabledCheckbox:SetPoint("TOPLEFT", prefixSuffixHeader, "BOTTOMLEFT", 0, -5)
    prefixSuffixEnabledCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    prefixSuffixEnabledCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    prefixSuffixEnabledCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    prefixSuffixEnabledCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    prefixSuffixEnabledCheckbox:SetChecked(FoxChatDB.prefixSuffixEnabled)
    
    local prefixSuffixEnabledLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixSuffixEnabledLabel:SetPoint("LEFT", prefixSuffixEnabledCheckbox, "RIGHT", 5, 0)
    prefixSuffixEnabledLabel:SetText(L["PREFIX_SUFFIX_ENABLE"])
    
    prefixSuffixEnabledCheckbox:SetScript("OnClick", function(self)
        FoxChatDB.prefixSuffixEnabled = self:GetChecked()
    end)
    
    local prefixSuffixLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    prefixSuffixLabel:SetPoint("TOPLEFT", prefixSuffixEnabledCheckbox, "BOTTOMLEFT", 0, -10)
    prefixSuffixLabel:SetText(L["PREFIX_SUFFIX_HELP"])
    
    -- 말머리 입력
    local prefixLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixLabel:SetPoint("TOPLEFT", prefixSuffixLabel, "BOTTOMLEFT", 0, -10)
    prefixLabel:SetText(L["PREFIX_LABEL"])
    
    local prefixBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    prefixBackground:SetSize(200, 24)
    prefixBackground:SetPoint("LEFT", prefixLabel, "RIGHT", 10, 0)
    if prefixBackground.SetBackdrop then
        prefixBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        prefixBackground:SetBackdropColor(0, 0, 0, 0.8)
    end
    
    prefixEditBox = CreateFrame("EditBox", nil, prefixBackground)
    prefixEditBox:SetSize(190, 20)
    prefixEditBox:SetPoint("LEFT", 5, 0)
    prefixEditBox:SetAutoFocus(false)
    prefixEditBox:SetMaxLetters(50)
    prefixEditBox:SetFontObject(GameFontHighlight)
    prefixEditBox:SetText(FoxChatDB.prefix or "")
    
    prefixEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB.prefix = self:GetText()
    end)
    
    prefixEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- 말꼬리 입력
    local suffixLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    suffixLabel:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -10)
    suffixLabel:SetText(L["SUFFIX_LABEL"])
    
    local suffixBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    suffixBackground:SetSize(200, 24)
    suffixBackground:SetPoint("LEFT", suffixLabel, "RIGHT", 10, 0)
    if suffixBackground.SetBackdrop then
        suffixBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        suffixBackground:SetBackdropColor(0, 0, 0, 0.8)
    end
    
    suffixEditBox = CreateFrame("EditBox", nil, suffixBackground)
    suffixEditBox:SetSize(190, 20)
    suffixEditBox:SetPoint("LEFT", 5, 0)
    suffixEditBox:SetAutoFocus(false)
    suffixEditBox:SetMaxLetters(50)
    suffixEditBox:SetFontObject(GameFontHighlight)
    suffixEditBox:SetText(FoxChatDB.suffix or "")
    
    suffixEditBox:SetScript("OnTextChanged", function(self)
        FoxChatDB.suffix = self:GetText()
    end)
    
    suffixEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- 말머리/말꼬리 적용 채널
    local prefixChannelsLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefixChannelsLabel:SetPoint("TOPLEFT", suffixLabel, "BOTTOMLEFT", 0, -15)
    prefixChannelsLabel:SetText(L["PREFIX_SUFFIX_CHANNELS"])
    
    local prefixChannelOptions = {
        {key = "SAY", text = L["CHANNEL_SAY"], x = 0, y = 0},
        {key = "YELL", text = L["CHANNEL_YELL"], x = 100, y = 0},
        {key = "PARTY", text = L["CHANNEL_PARTY"], x = 200, y = 0},
        {key = "GUILD", text = L["CHANNEL_GUILD"], x = 300, y = 0},
        {key = "RAID", text = L["CHANNEL_RAID"], x = 0, y = -25},
        {key = "INSTANCE_CHAT", text = L["CHANNEL_INSTANCE"], x = 100, y = -25},
        {key = "WHISPER", text = L["CHANNEL_WHISPER"], x = 200, y = -25},
        {key = "CHANNEL", text = L["CHANNEL_GENERAL"], x = 300, y = -25},
    }
    
    local prefixChannelFrame = CreateFrame("Frame", nil, configFrame)
    prefixChannelFrame:SetPoint("TOPLEFT", prefixChannelsLabel, "BOTTOMLEFT", 0, -10)
    prefixChannelFrame:SetSize(400, 60)
    
    for _, channel in ipairs(prefixChannelOptions) do
        local checkbox = CreateFrame("CheckButton", nil, prefixChannelFrame)
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", prefixChannelFrame, "TOPLEFT", channel.x, channel.y)
        checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        -- prefixSuffixChannels 초기화 확인
        if not FoxChatDB.prefixSuffixChannels then
            FoxChatDB.prefixSuffixChannels = defaults.prefixSuffixChannels
        end
        checkbox:SetChecked(FoxChatDB.prefixSuffixChannels[channel.key])
        
        local label = prefixChannelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        label:SetText(channel.text)
        
        checkbox:SetScript("OnClick", function(self)
            FoxChatDB.prefixSuffixChannels[channel.key] = self:GetChecked()
        end)
    end
    
    -- ======================== 토스트 위치 섹션 ========================
    -- 구분선
    local separator4 = CreateSeparator(configFrame, "TOPLEFT", prefixChannelFrame, "BOTTOMLEFT", -5, -20)

    -- 토스트 위치 헤더
    local toastHeader = CreateSectionHeader(configFrame, "토스트 위치", "TOPLEFT", separator4, "BOTTOMLEFT", 5, -10)

    -- 설명 텍스트 추가
    local toastDesc = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toastDesc:SetPoint("TOPLEFT", toastHeader, "BOTTOMLEFT", 0, -5)
    toastDesc:SetText("(0, 0)이 화면 정중앙입니다")
    toastDesc:SetTextColor(0.8, 0.8, 0.8)

    -- 토스트 X 위치
    local toastXLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastXLabel:SetPoint("TOPLEFT", toastDesc, "BOTTOMLEFT", 0, -10)
    toastXLabel:SetText("X 위치 (좌우):")

    local toastXBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    toastXBackground:SetSize(80, 24)
    toastXBackground:SetPoint("LEFT", toastXLabel, "RIGHT", 10, 0)
    if toastXBackground.SetBackdrop then
        toastXBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        toastXBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    local toastXEditBox = CreateFrame("EditBox", nil, toastXBackground)
    toastXEditBox:SetSize(70, 20)
    toastXEditBox:SetPoint("LEFT", 5, 0)
    toastXEditBox:SetAutoFocus(false)
    toastXEditBox:SetMaxLetters(6)
    toastXEditBox:SetFontObject(GameFontHighlight)
    toastXEditBox:SetNumeric(false)  -- 음수 입력을 위해 false로 설정
    toastXEditBox:SetText(tostring((FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0))

    toastXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = 0}
            end
            FoxChatDB.toastPosition.x = value
        end
    end)

    toastXEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local toastXHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toastXHelp:SetPoint("LEFT", toastXBackground, "RIGHT", 10, 0)
    toastXHelp:SetText("(-값은 왼쪽, +값은 오른쪽)")

    -- 토스트 Y 위치
    local toastYLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toastYLabel:SetPoint("TOPLEFT", toastXLabel, "BOTTOMLEFT", 0, -15)
    toastYLabel:SetText("Y 위치 (상하):")

    local toastYBackground = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    toastYBackground:SetSize(80, 24)
    toastYBackground:SetPoint("LEFT", toastYLabel, "RIGHT", 10, 0)
    if toastYBackground.SetBackdrop then
        toastYBackground:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        toastYBackground:SetBackdropColor(0, 0, 0, 0.8)
    end

    local toastYEditBox = CreateFrame("EditBox", nil, toastYBackground)
    toastYEditBox:SetSize(70, 20)
    toastYEditBox:SetPoint("LEFT", 5, 0)
    toastYEditBox:SetAutoFocus(false)
    toastYEditBox:SetMaxLetters(6)
    toastYEditBox:SetFontObject(GameFontHighlight)
    toastYEditBox:SetNumeric(false)  -- 음수 입력을 위해 false로 설정
    toastYEditBox:SetText(tostring((FoxChatDB.toastPosition and FoxChatDB.toastPosition.y) or -320))

    toastYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = 0}
            end
            FoxChatDB.toastPosition.y = value
        end
    end)

    toastYEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local toastYHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toastYHelp:SetPoint("LEFT", toastYBackground, "RIGHT", 10, 0)
    toastYHelp:SetText("(-값은 아래쪽, +값은 위쪽)")

    -- 위치 테스트 버튼
    local toastTestButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    toastTestButton:SetSize(120, 22)
    toastTestButton:SetPoint("TOPLEFT", toastYLabel, "BOTTOMLEFT", 0, -15)
    toastTestButton:SetText("위치 테스트")
    toastTestButton:SetScript("OnClick", function()
        -- 테스트 토스트 표시 (isTest 파라미터를 true로 전달)
        if FoxChat.ShowToast then
            _G["ShowToast"] = FoxChat.ShowToast
        end
        local ShowToast = _G["ShowToast"]
        if ShowToast then
            ShowToast("테스트 사용자", "토스트 위치 테스트 메시지입니다.", "GUILD", true)
        end
    end)

    -- 버튼들
    local testButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 25)
    testButton:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 30, 20)
    testButton:SetText(L["TEST_BUTTON"])
    testButton:SetScript("OnClick", function()
        FoxChat:TestHighlight()
    end)
    
    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("LEFT", testButton, "RIGHT", 10, 0)
    resetButton:SetText(L["RESET_BUTTON"])
    resetButton:SetScript("OnClick", function()
        FoxChatDB = CopyTable(defaults)
        keywordsEditBox:SetText("")  -- 키워드를 비움
        ignoreKeywordsEditBox:SetText("")  -- 무시 키워드를 비움
        prefixEditBox:SetText(defaults.prefix)
        suffixEditBox:SetText(defaults.suffix)
        filterEnabledCheckbox:SetChecked(defaults.filterEnabled)
        soundCheckbox:SetChecked(defaults.playSound)
        FoxChatDB.keywords = ""  -- DB에서도 키워드 비움
        FoxChatDB.ignoreKeywords = ""  -- DB에서도 무시 키워드 비움
        FoxChat:UpdateKeywords()
        FoxChat:UpdateIgnoreKeywords()
        -- 스타일 버튼 업데이트
        for _, btn in ipairs(styleButtons) do
            btn:SetChecked(btn.value == defaults.highlightStyle)
        end
        -- 색상 업데이트
        for key, swatch in pairs(colorSwatches) do
            local defaultColor = defaults.highlightColors[key]
            swatch.texture:SetColorTexture(defaultColor.r, defaultColor.g, defaultColor.b)
            swatch.color = defaultColor
        end
        -- 채널 체크박스 업데이트
        for key, checkbox in pairs(channelCheckboxes) do
            checkbox:SetChecked(defaults.channelGroups[key])
        end
        for _, channel in ipairs(prefixChannelOptions) do
            local checkbox = _G["FoxChatPrefixChannel" .. channel.key]
            if checkbox then
                checkbox:SetChecked(defaults.prefixSuffixChannels[channel.key])
            end
        end
        print(L["DEFAULTS_RESTORED"])
    end)
    
    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 25)
    closeButton:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -30, 20)
    closeButton:SetText(L["CLOSE_BUTTON"])
    closeButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    -- X 버튼
    local xButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    xButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
    
    configFrame:Show()
end