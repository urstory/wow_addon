local addonName, addon = ...

-- 하이라이트 설정 탭 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Tabs = FoxChat.UI.Tabs or {}
FoxChat.UI.Tabs.Highlight = {}

local HighlightTab = FoxChat.UI.Tabs.Highlight
local L = addon.L
local Components = FoxChat.UI.Components

-- 탭 내부 요소들
local elements = {}

-- 초기화
function HighlightTab:Initialize(parent)
    elements.parent = parent
    
    -- 상단 체크박스들
    self:CreateTopCheckboxes(parent)
    
    -- 구분선
    local separator1 = Components:CreateSeparator(parent)
    separator1:SetPoint("TOPLEFT", elements.filterCheckbox, "BOTTOMLEFT", -10, -15)
    separator1:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    -- 키워드 입력 영역
    self:CreateKeywordSection(parent, separator1)
    
    -- 하이라이트 스타일 선택
    self:CreateStyleSection(parent)
    
    -- 채널별 색상 및 모니터링 설정
    self:CreateChannelSection(parent)
    
    -- 토스트 위치 설정
    self:CreateToastSection(parent)
    
    -- 이벤트 등록
    self:RegisterEvents()
    
    -- 초기 설정 로드
    self:LoadSettings()
end

-- 상단 체크박스들 생성
function HighlightTab:CreateTopCheckboxes(parent)
    -- 필터링 활성화 체크박스
    local filterCheckbox = Components:CreateCheckbox(parent, L["FILTER_ENABLE"])
    filterCheckbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    filterCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.filterEnabled = self:GetChecked()
        end
    end)
    elements.filterCheckbox = filterCheckbox
    
    -- 사운드 재생 체크박스
    local soundCheckbox = Components:CreateCheckbox(parent, L["PLAY_SOUND"])
    soundCheckbox:SetPoint("LEFT", filterCheckbox.text, "RIGHT", 30, 0)
    soundCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.playSound = self:GetChecked()
        end
    end)
    elements.soundCheckbox = soundCheckbox
    
    -- 미니맵 버튼 표시 체크박스
    local minimapCheckbox = Components:CreateCheckbox(parent, L["SHOW_MINIMAP_BUTTON"])
    minimapCheckbox:SetPoint("LEFT", soundCheckbox.text, "RIGHT", 30, 0)
    minimapCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB and FoxChatDB.minimapButton then
            FoxChatDB.minimapButton.hide = not self:GetChecked()
            if FoxChat.UI and FoxChat.UI.MinimapButton then
                if self:GetChecked() then
                    FoxChat.UI.MinimapButton:Show()
                else
                    FoxChat.UI.MinimapButton:Hide()
                end
            end
        end
    end)
    elements.minimapCheckbox = minimapCheckbox
end

-- 키워드 입력 영역 생성
function HighlightTab:CreateKeywordSection(parent, separator)
    -- 필터링 키워드 (왼쪽)
    local keywordsLabel = Components:CreateLabel(parent, L["KEYWORDS_LABEL"], "GameFontNormal")
    keywordsLabel:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 10, -10)
    
    local keywordsHelp = Components:CreateLabel(parent, L["KEYWORDS_HELP"], "GameFontHighlightSmall")
    keywordsHelp:SetPoint("TOPLEFT", keywordsLabel, "BOTTOMLEFT", 0, -3)
    
    -- 필터링 키워드 입력창
    local keywordsEditBox = Components:CreateEditBox(parent, 260, 20)
    keywordsEditBox:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)
    keywordsEditBox:SetMultiLine(true)
    keywordsEditBox:SetMaxLetters(0)
    
    -- 스크롤 프레임으로 감싸기 (높이 120)
    local keywordsScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    keywordsScroll:SetSize(260, 120)
    keywordsScroll:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -5)
    keywordsScroll:SetScrollChild(keywordsEditBox)
    keywordsEditBox:SetWidth(240)
    
    local keywordsBg = Components:CreateBackground(keywordsScroll)
    keywordsBg:SetPoint("TOPLEFT", -5, 5)
    keywordsBg:SetPoint("BOTTOMRIGHT", 25, -5)
    
    keywordsEditBox:SetScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            local text = self:GetText() or ""
            local keywords = {}
            
            for keyword in string.gmatch(text, "[^,]+") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end
            
            FoxChatDB.keywords = keywords
            if FoxChat.Features and FoxChat.Features.KeywordFilter then
                FoxChat.Features.KeywordFilter:UpdateKeywords()
            end
        end
    end)
    elements.keywordsEditBox = keywordsEditBox
    elements.keywordsScroll = keywordsScroll
    
    -- 무시 키워드 (오른쪽)
    local ignoreLabel = Components:CreateLabel(parent, L["IGNORE_KEYWORDS_LABEL"], "GameFontNormal")
    ignoreLabel:SetPoint("TOPLEFT", keywordsLabel, "TOPLEFT", 280, 0)
    
    local ignoreHelp = Components:CreateLabel(parent, L["IGNORE_KEYWORDS_HELP"], "GameFontHighlightSmall")
    ignoreHelp:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -3)
    
    -- 무시 키워드 입력창
    local ignoreEditBox = Components:CreateEditBox(parent, 260, 20)
    ignoreEditBox:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)
    ignoreEditBox:SetMultiLine(true)
    ignoreEditBox:SetMaxLetters(0)
    
    -- 스크롤 프레임으로 감싸기
    local ignoreScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    ignoreScroll:SetSize(260, 120)
    ignoreScroll:SetPoint("TOPLEFT", ignoreHelp, "BOTTOMLEFT", 0, -5)
    ignoreScroll:SetScrollChild(ignoreEditBox)
    ignoreEditBox:SetWidth(240)
    
    local ignoreBg = Components:CreateBackground(ignoreScroll)
    ignoreBg:SetPoint("TOPLEFT", -5, 5)
    ignoreBg:SetPoint("BOTTOMRIGHT", 25, -5)
    
    ignoreEditBox:SetScript("OnTextChanged", function(self, user)
        if FoxChatDB then
            local text = self:GetText() or ""
            local keywords = {}
            
            for keyword in string.gmatch(text, "[^,]+") do
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    table.insert(keywords, trimmed)
                end
            end
            
            FoxChatDB.ignoreKeywords = keywords
            if FoxChat.Features and FoxChat.Features.KeywordFilter then
                FoxChat.Features.KeywordFilter:UpdateIgnoreKeywords()
            end
        end
    end)
    elements.ignoreEditBox = ignoreEditBox
    elements.ignoreScroll = ignoreScroll
end

-- 하이라이트 스타일 선택 영역
function HighlightTab:CreateStyleSection(parent)
    local styleLabel = Components:CreateLabel(parent, L["HIGHLIGHT_STYLE"], "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", elements.keywordsScroll, "BOTTOMLEFT", 0, -15)
    
    local styles = {
        {value = "bold", text = L["STYLE_BOLD"], x = 0},
        {value = "color", text = L["STYLE_COLOR"], x = 120},
        {value = "both", text = L["STYLE_BOTH"], x = 240},
    }
    
    elements.styleButtons = {}
    for i, style in ipairs(styles) do
        local radioButton = Components:CreateRadioButton(parent, style.text)
        radioButton:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", style.x, -5)
        radioButton.value = style.value
        
        radioButton:SetScript("OnClick", function(self)
            for _, btn in ipairs(elements.styleButtons) do
                btn:SetChecked(false)
            end
            self:SetChecked(true)
            if FoxChatDB then
                FoxChatDB.highlightStyle = self.value
            end
        end)
        
        elements.styleButtons[i] = radioButton
    end
end

-- 채널별 색상 및 모니터링 설정
function HighlightTab:CreateChannelSection(parent)
    local colorLabel = Components:CreateLabel(parent, L["CHANNELS_AND_COLORS"], "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", elements.styleButtons[1], "BOTTOMLEFT", 0, -35)
    
    local channelGroups = {
        {key = "GUILD", text = L["CHANNEL_GROUP_GUILD"], x = 0, y = 0},
        {key = "PUBLIC", text = L["CHANNEL_GROUP_PUBLIC"], x = 140, y = 0},
        {key = "PARTY_RAID", text = L["CHANNEL_GROUP_PARTY_RAID"], x = 280, y = 0},
        {key = "LFG", text = L["CHANNEL_GROUP_LFG"], x = 420, y = 0},
    }
    
    elements.channelCheckboxes = {}
    elements.colorSwatches = {}
    
    for i, group in ipairs(channelGroups) do
        -- 체크박스
        local checkbox = Components:CreateCheckbox(parent, "")
        checkbox:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", group.x, -20 + group.y)
        checkbox.channelKey = group.key
        
        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB then
                if not FoxChatDB.channelGroups then
                    FoxChatDB.channelGroups = {}
                end
                FoxChatDB.channelGroups[self.channelKey] = self:GetChecked()
            end
        end)
        
        elements.channelCheckboxes[group.key] = checkbox
        
        -- 채널 이름 레이블 (체크박스 옆에)
        local groupLabel = Components:CreateLabel(parent, group.text, "GameFontNormalSmall")
        groupLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        
        -- 색상 선택 버튼
        local colorSwatch = CreateFrame("Button", nil, parent)
        colorSwatch:SetSize(16, 16)
        colorSwatch:SetPoint("LEFT", groupLabel, "RIGHT", 5, 0)
        
        local colorTexture = colorSwatch:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints()
        
        local colorBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
        colorBorder:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        colorBorder:SetAllPoints()
        
        elements.colorSwatches[group.key] = {button = colorSwatch, texture = colorTexture}
        
        colorSwatch:SetScript("OnClick", function()
            local groupKey = group.key
            local currentColor = FoxChatDB and FoxChatDB.highlightColors and FoxChatDB.highlightColors[groupKey]
                                or {r = 1, g = 1, b = 0}
            
            local function OnColorSelect()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                if FoxChatDB then
                    if not FoxChatDB.highlightColors then
                        FoxChatDB.highlightColors = {}
                    end
                    FoxChatDB.highlightColors[groupKey] = {r = r, g = g, b = b}
                    colorTexture:SetColorTexture(r, g, b)
                end
            end
            
            ColorPickerFrame.func = OnColorSelect
            ColorPickerFrame.cancelFunc = function(previousValues)
                if previousValues and FoxChatDB then
                    FoxChatDB.highlightColors[groupKey] = previousValues
                    colorTexture:SetColorTexture(previousValues.r, previousValues.g, previousValues.b)
                end
            end
            ColorPickerFrame.previousValues = currentColor
            ColorPickerFrame:SetColorRGB(currentColor.r, currentColor.g, currentColor.b)
            ColorPickerFrame:Show()
        end)
    end
end

-- 토스트 위치 설정
function HighlightTab:CreateToastSection(parent)
    local toastPosLabel = Components:CreateLabel(parent, "토스트 위치:", "GameFontNormal")
    toastPosLabel:SetPoint("TOPLEFT", elements.channelCheckboxes["GUILD"], "BOTTOMLEFT", 0, -30)
    
    local toastPosDesc = Components:CreateLabel(parent, "(0, 0)이 화면 정중앙", "GameFontHighlightSmall")
    toastPosDesc:SetPoint("LEFT", toastPosLabel, "RIGHT", 10, 0)
    
    -- X 위치
    local toastXLabel = Components:CreateLabel(parent, "X:", "GameFontNormalSmall")
    toastXLabel:SetPoint("TOPLEFT", toastPosLabel, "BOTTOMLEFT", 0, -10)
    
    local toastXEditBox = Components:CreateEditBox(parent, 60, 20)
    toastXEditBox:SetPoint("LEFT", toastXLabel, "RIGHT", 5, 0)
    toastXEditBox:SetMaxLetters(6)
    toastXEditBox:SetNumeric(false) -- 음수 입력 가능
    
    toastXEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.x = value
        end
    end)
    elements.toastXEditBox = toastXEditBox
    
    -- Y 위치
    local toastYLabel = Components:CreateLabel(parent, "Y:", "GameFontNormalSmall")
    toastYLabel:SetPoint("LEFT", toastXEditBox, "RIGHT", 20, 0)
    
    local toastYEditBox = Components:CreateEditBox(parent, 60, 20)
    toastYEditBox:SetPoint("LEFT", toastYLabel, "RIGHT", 5, 0)
    toastYEditBox:SetMaxLetters(6)
    toastYEditBox:SetNumeric(false) -- 음수 입력 가능
    
    toastYEditBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value and FoxChatDB then
            if not FoxChatDB.toastPosition then
                FoxChatDB.toastPosition = {x = 0, y = -320}
            end
            FoxChatDB.toastPosition.y = value
        end
    end)
    elements.toastYEditBox = toastYEditBox
    
    -- 토스트 테스트 버튼
    local toastTestBtn = Components:CreateButton(parent, "토스트 테스트", 100, 22)
    toastTestBtn:SetPoint("LEFT", toastYEditBox, "RIGHT", 20, 0)
    toastTestBtn:SetScript("OnClick", function()
        if FoxChat.UI and FoxChat.UI.Toast then
            FoxChat.UI.Toast:Show("테스트 사용자", "토스트 위치 테스트 메시지입니다.", "GUILD", true)
        end
    end)
end

-- 이벤트 등록
function HighlightTab:RegisterEvents()
    if FoxChat.Events then
        -- 설정 로드
        FoxChat.Events:Register("FOXCHAT_LOAD_SETTINGS", function()
            HighlightTab:LoadSettings()
        end)
        
        -- 설정 저장
        FoxChat.Events:Register("FOXCHAT_SAVE_SETTINGS", function()
            HighlightTab:SaveSettings()
        end)
    end
end

-- 설정 로드
function HighlightTab:LoadSettings()
    if not FoxChatDB then return end
    
    -- 체크박스들
    if elements.filterCheckbox then
        elements.filterCheckbox:SetChecked(FoxChatDB.filterEnabled ~= false)
    end
    
    if elements.soundCheckbox then
        elements.soundCheckbox:SetChecked(FoxChatDB.playSound ~= false)
    end
    
    if elements.minimapCheckbox and FoxChatDB.minimapButton then
        elements.minimapCheckbox:SetChecked(not FoxChatDB.minimapButton.hide)
    end
    
    -- 키워드
    if elements.keywordsEditBox and FoxChatDB.keywords then
        local keywordText = ""
        if type(FoxChatDB.keywords) == "table" then
            keywordText = table.concat(FoxChatDB.keywords, ", ")
        else
            keywordText = tostring(FoxChatDB.keywords)
        end
        elements.keywordsEditBox:SetText(keywordText)
    end
    
    -- 무시 키워드
    if elements.ignoreEditBox and FoxChatDB.ignoreKeywords then
        local ignoreText = ""
        if type(FoxChatDB.ignoreKeywords) == "table" then
            ignoreText = table.concat(FoxChatDB.ignoreKeywords, ", ")
        else
            ignoreText = tostring(FoxChatDB.ignoreKeywords)
        end
        elements.ignoreEditBox:SetText(ignoreText)
    end
    
    -- 하이라이트 스타일
    if elements.styleButtons then
        local currentStyle = FoxChatDB.highlightStyle or "both"
        for _, btn in ipairs(elements.styleButtons) do
            btn:SetChecked(btn.value == currentStyle)
        end
    end
    
    -- 채널 그룹
    if elements.channelCheckboxes and FoxChatDB.channelGroups then
        for key, checkbox in pairs(elements.channelCheckboxes) do
            checkbox:SetChecked(FoxChatDB.channelGroups[key] ~= false)
        end
    end
    
    -- 채널 색상
    if elements.colorSwatches and FoxChatDB.highlightColors then
        for key, swatch in pairs(elements.colorSwatches) do
            local color = FoxChatDB.highlightColors[key] or {r = 1, g = 1, b = 0}
            swatch.texture:SetColorTexture(color.r, color.g, color.b)
        end
    end
    
    -- 토스트 위치
    if elements.toastXEditBox and FoxChatDB.toastPosition then
        elements.toastXEditBox:SetText(tostring(FoxChatDB.toastPosition.x or 0))
    end
    
    if elements.toastYEditBox and FoxChatDB.toastPosition then
        elements.toastYEditBox:SetText(tostring(FoxChatDB.toastPosition.y or -320))
    end
end

-- 설정 저장
function HighlightTab:SaveSettings()
    -- 대부분의 설정은 OnClick/OnTextChanged 이벤트에서 실시간으로 저장됨
    -- 추가 처리가 필요한 경우 여기에 작성
    
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_SETTINGS_CHANGED")
    end
end