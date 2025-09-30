local addonName, addon = ...

-- 말머리/말꼬리 설정 탭 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Tabs = FoxChat.UI.Tabs or {}
FoxChat.UI.Tabs.PrefixSuffix = {}

local PrefixSuffixTab = FoxChat.UI.Tabs.PrefixSuffix
local L = addon.L
local Components = FoxChat.UI.Components

-- 탭 내부 요소들
local elements = {}

-- 초기화
function PrefixSuffixTab:Initialize(parent)
    elements.parent = parent
    
    -- 활성화 체크박스
    self:CreateEnableCheckbox(parent)
    
    -- 설명 텍스트
    local helpText = Components:CreateLabel(parent, L["PREFIX_SUFFIX_HELP"], "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", elements.enableCheckbox, "BOTTOMLEFT", 0, -10)
    
    -- 구분선
    local separator1 = Components:CreateSeparator(parent)
    separator1:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", -10, -10)
    separator1:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    -- 말머리/말꼬리 입력 영역
    self:CreatePrefixSuffixInput(parent, separator1)
    
    -- 채널 선택 영역
    self:CreateChannelSelection(parent)
    
    -- 예시 텍스트
    self:CreateExampleSection(parent)
    
    -- 팁 텍스트
    self:CreateTipSection(parent)
    
    -- 이벤트 등록
    self:RegisterEvents()
    
    -- 초기 설정 로드
    self:LoadSettings()
end

-- 활성화 체크박스
function PrefixSuffixTab:CreateEnableCheckbox(parent)
    local checkbox = Components:CreateCheckbox(parent, L["PREFIX_SUFFIX_ENABLE"])
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    checkbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.prefixSuffixEnabled = self:GetChecked()
        end
    end)
    elements.enableCheckbox = checkbox
end

-- 말머리/말꼬리 입력 영역
function PrefixSuffixTab:CreatePrefixSuffixInput(parent, separator)
    -- 말머리 입력
    local prefixLabel = Components:CreateLabel(parent, L["PREFIX_LABEL"], "GameFontNormal")
    prefixLabel:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 10, -15)
    
    local prefixBg, prefixEditBox = Components:CreateEditBox(parent, 250, 30)
    prefixBg:SetPoint("LEFT", prefixLabel, "RIGHT", 10, 0)
    prefixEditBox:SetMaxLetters(50)
    
    prefixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.prefix = self:GetText()
        end
        PrefixSuffixTab:UpdateExampleText()
        PrefixSuffixTab:NotifyAdvertisementTab()
    end)
    
    elements.prefixEditBox = prefixEditBox
    
    -- 말꼬리 입력
    local suffixLabel = Components:CreateLabel(parent, L["SUFFIX_LABEL"], "GameFontNormal")
    suffixLabel:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -15)
    
    local suffixBg, suffixEditBox = Components:CreateEditBox(parent, 250, 30)
    suffixBg:SetPoint("LEFT", suffixLabel, "RIGHT", 10, 0)
    suffixEditBox:SetMaxLetters(50)
    
    suffixEditBox:SetScript("OnTextChanged", function(self)
        if FoxChatDB then
            FoxChatDB.suffix = self:GetText()
        end
        PrefixSuffixTab:UpdateExampleText()
        PrefixSuffixTab:NotifyAdvertisementTab()
    end)
    
    elements.suffixEditBox = suffixEditBox
end

-- 채널 선택 영역
function PrefixSuffixTab:CreateChannelSelection(parent)
    local channelsLabel = Components:CreateLabel(parent, L["PREFIX_SUFFIX_CHANNELS"], "GameFontNormal")
    channelsLabel:SetPoint("TOPLEFT", elements.suffixEditBox:GetParent(), "BOTTOMLEFT", -10, -20)
    
    local channelOptions = {
        {key = "SAY", text = L["CHANNEL_SAY"], x = 0, y = 0},
        {key = "YELL", text = L["CHANNEL_YELL"], x = 140, y = 0},
        {key = "PARTY", text = L["CHANNEL_PARTY"], x = 280, y = 0},
        {key = "GUILD", text = L["CHANNEL_GUILD"], x = 420, y = 0},
        {key = "RAID", text = L["CHANNEL_RAID"], x = 0, y = -30},
        {key = "INSTANCE_CHAT", text = L["CHANNEL_INSTANCE"], x = 140, y = -30},
        {key = "WHISPER", text = L["CHANNEL_WHISPER"], x = 280, y = -30},
        {key = "CHANNEL", text = L["CHANNEL_GENERAL"], x = 420, y = -30},
    }
    
    elements.channelCheckboxes = {}
    
    for _, channel in ipairs(channelOptions) do
        local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkbox:SetSize(20, 20)
        checkbox:SetPoint("TOPLEFT", channelsLabel, "BOTTOMLEFT", channel.x, channel.y - 15)
        
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
        label:SetText(channel.text)
        
        checkbox.channelKey = channel.key
        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB then
                if not FoxChatDB.prefixSuffixChannels then
                    FoxChatDB.prefixSuffixChannels = {}
                end
                FoxChatDB.prefixSuffixChannels[self.channelKey] = self:GetChecked()
            end
        end)
        
        elements.channelCheckboxes[channel.key] = checkbox
    end
end

-- 예시 섹션
function PrefixSuffixTab:CreateExampleSection(parent)
    local exampleLabel = Components:CreateLabel(parent, "예시:", "GameFontNormal")
    exampleLabel:SetPoint("TOPLEFT", elements.channelCheckboxes["SAY"], "BOTTOMLEFT", 0, -50)
    
    local exampleText = Components:CreateLabel(parent, "", "GameFontHighlight")
    exampleText:SetPoint("LEFT", exampleLabel, "RIGHT", 10, 0)
    
    elements.exampleText = exampleText
    
    -- 초기 예시 텍스트 업데이트
    self:UpdateExampleText()
end

-- 팁 섹션
function PrefixSuffixTab:CreateTipSection(parent)
    local tipLabel = Components:CreateLabel(
        parent,
        "|cFFFFFF00팁:|r 위상 메시지(일위상, 이위상, 삼위상)는 자동으로 제외됩니다.",
        "GameFontNormalSmall"
    )
    tipLabel:SetPoint("TOPLEFT", elements.exampleText, "BOTTOMLEFT", -10, -20)
    tipLabel:SetJustifyH("LEFT")
end

-- 예시 텍스트 업데이트
function PrefixSuffixTab:UpdateExampleText()
    if not elements.exampleText then return end
    
    local prefix = (FoxChatDB and FoxChatDB.prefix) or ""
    local suffix = (FoxChatDB and FoxChatDB.suffix) or ""
    local example = prefix .. "안녕하세요!" .. suffix
    
    elements.exampleText:SetText(example)
end

-- 광고 탭에 알림 (말머리/말꼬리 바이트 수 업데이트)
function PrefixSuffixTab:NotifyAdvertisementTab()
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_PREFIX_SUFFIX_CHANGED")
    end
end

-- 이벤트 등록
function PrefixSuffixTab:RegisterEvents()
    if FoxChat.Events then
        -- 설정 로드
        FoxChat.Events:Register("FOXCHAT_LOAD_SETTINGS", function()
            PrefixSuffixTab:LoadSettings()
        end)
        
        -- 설정 저장
        FoxChat.Events:Register("FOXCHAT_SAVE_SETTINGS", function()
            PrefixSuffixTab:SaveSettings()
        end)
    end
end

-- 설정 로드
function PrefixSuffixTab:LoadSettings()
    if not FoxChatDB then return end
    
    -- 활성화 체크박스
    if elements.enableCheckbox then
        elements.enableCheckbox:SetChecked(FoxChatDB.prefixSuffixEnabled == true)
    end
    
    -- 말머리/말꼬리
    if elements.prefixEditBox then
        elements.prefixEditBox:SetText(FoxChatDB.prefix or "")
    end
    
    if elements.suffixEditBox then
        elements.suffixEditBox:SetText(FoxChatDB.suffix or "")
    end
    
    -- 채널 체크박스
    if elements.channelCheckboxes and FoxChatDB.prefixSuffixChannels then
        for key, checkbox in pairs(elements.channelCheckboxes) do
            checkbox:SetChecked(FoxChatDB.prefixSuffixChannels[key] == true)
        end
    else
        -- 기본값 설정 (SAY, PARTY, GUILD, RAID, INSTANCE_CHAT는 기본 활성화)
        local defaults = {
            SAY = true,
            YELL = false,
            PARTY = true,
            GUILD = true,
            RAID = true,
            INSTANCE_CHAT = true,
            WHISPER = false,
            CHANNEL = false
        }
        
        for key, checkbox in pairs(elements.channelCheckboxes or {}) do
            checkbox:SetChecked(defaults[key] == true)
        end
    end
    
    -- 예시 텍스트 업데이트
    self:UpdateExampleText()
end

-- 설정 저장
function PrefixSuffixTab:SaveSettings()
    -- 대부분의 설정은 OnClick/OnTextChanged 이벤트에서 실시간으로 저장됨
    
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_SETTINGS_CHANGED")
    end
end