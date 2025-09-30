local addonName, addon = ...

-- 기본 설정 탭 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Tabs = FoxChat.UI.Tabs or {}
FoxChat.UI.Tabs.Basic = {}

local BasicTab = FoxChat.UI.Tabs.Basic
local L = addon.L
local Components = FoxChat.UI.Components

-- 탭 내부 요소들
local elements = {}

-- 초기화
function BasicTab:Initialize(parent)
    elements.parent = parent

    -- 제목
    local title = Components:CreateLabel(parent, L["BASIC_SETTINGS"], "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)

    -- 구분선
    local separator1 = Components:CreateSeparator(parent)
    separator1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -10, -10)
    separator1:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

    -- 전체 활성화 체크박스
    local enableCheckbox = Components:CreateCheckbox(parent, L["ENABLE_FOXCHAT"])
    enableCheckbox:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 10, -15)
    enableCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.enabled = self:GetChecked()
        end
    end)
    elements.enableCheckbox = enableCheckbox

    -- 채팅 필터링 활성화
    local filterCheckbox = Components:CreateCheckbox(parent, L["ENABLE_FILTER"])
    filterCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -10)
    filterCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.filterEnabled = self:GetChecked()
        end
    end)
    elements.filterCheckbox = filterCheckbox

    -- 말머리/말꼬리 활성화
    local prefixSuffixCheckbox = Components:CreateCheckbox(parent, L["ENABLE_PREFIX_SUFFIX"])
    prefixSuffixCheckbox:SetPoint("TOPLEFT", filterCheckbox, "BOTTOMLEFT", 0, -10)
    prefixSuffixCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.prefixSuffixEnabled = self:GetChecked()
        end
    end)
    elements.prefixSuffixCheckbox = prefixSuffixCheckbox

    -- 사운드 설정 섹션
    local soundTitle = Components:CreateLabel(parent, L["SOUND_SETTINGS"], "GameFontNormal")
    soundTitle:SetPoint("TOPLEFT", prefixSuffixCheckbox, "BOTTOMLEFT", -10, -25)

    local separator2 = Components:CreateSeparator(parent)
    separator2:SetPoint("TOPLEFT", soundTitle, "BOTTOMLEFT", 0, -5)
    separator2:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

    -- 사운드 재생 체크박스
    local playSoundCheckbox = Components:CreateCheckbox(parent, L["PLAY_SOUND"])
    playSoundCheckbox:SetPoint("TOPLEFT", separator2, "BOTTOMLEFT", 10, -15)
    playSoundCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB then
            FoxChatDB.playSound = self:GetChecked()
        end
    end)
    elements.playSoundCheckbox = playSoundCheckbox

    -- 사운드 볼륨 슬라이더
    local volumeSlider = Components:CreateSlider(parent, L["SOUND_VOLUME"], 0, 1, 0.1)
    volumeSlider:SetPoint("TOPLEFT", playSoundCheckbox, "BOTTOMLEFT", 0, -20)
    volumeSlider:SetScript("OnValueChanged", function(self, value)
        if FoxChatDB then
            FoxChatDB.soundVolume = value
        end
    end)
    elements.volumeSlider = volumeSlider

    -- 채널 그룹 설정
    local channelTitle = Components:CreateLabel(parent, L["CHANNEL_GROUPS"], "GameFontNormal")
    channelTitle:SetPoint("TOPLEFT", volumeSlider, "BOTTOMLEFT", -10, -35)

    local separator3 = Components:CreateSeparator(parent)
    separator3:SetPoint("TOPLEFT", channelTitle, "BOTTOMLEFT", 0, -5)
    separator3:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

    -- 채널 그룹 체크박스들
    local channelGroups = {
        { key = "GUILD", label = L["GUILD_CHANNEL"] },
        { key = "PUBLIC", label = L["PUBLIC_CHANNEL"] },
        { key = "PARTY_RAID", label = L["PARTY_RAID_CHANNEL"] },
        { key = "LFG", label = L["LFG_CHANNEL"] }
    }

    local lastCheckbox = separator3
    elements.channelCheckboxes = {}

    for i, group in ipairs(channelGroups) do
        local checkbox = Components:CreateCheckbox(parent, group.label)
        if i == 1 then
            checkbox:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", 10, -15)
        else
            checkbox:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", 0, -10)
        end

        checkbox.channelKey = group.key
        checkbox:SetScript("OnClick", function(self)
            if FoxChatDB and FoxChatDB.channelGroups then
                FoxChatDB.channelGroups[self.channelKey] = self:GetChecked()
            end
        end)

        elements.channelCheckboxes[group.key] = checkbox
        lastCheckbox = checkbox
    end

    -- 미니맵 버튼 설정
    local minimapTitle = Components:CreateLabel(parent, L["MINIMAP_BUTTON"], "GameFontNormal")
    minimapTitle:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", -10, -25)

    local separator4 = Components:CreateSeparator(parent)
    separator4:SetPoint("TOPLEFT", minimapTitle, "BOTTOMLEFT", 0, -5)
    separator4:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

    -- 미니맵 버튼 표시 체크박스
    local minimapCheckbox = Components:CreateCheckbox(parent, L["SHOW_MINIMAP_BUTTON"])
    minimapCheckbox:SetPoint("TOPLEFT", separator4, "BOTTOMLEFT", 10, -15)
    minimapCheckbox:SetScript("OnClick", function(self)
        if FoxChatDB and FoxChatDB.minimapButton then
            FoxChatDB.minimapButton.hide = not self:GetChecked()

            -- 미니맵 버튼 업데이트
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

    -- 이벤트 등록
    self:RegisterEvents()

    -- 초기 설정 로드
    self:LoadSettings()
end

-- 이벤트 등록
function BasicTab:RegisterEvents()
    if FoxChat.Events then
        -- 설정 로드
        FoxChat.Events:Register("FOXCHAT_LOAD_SETTINGS", function()
            BasicTab:LoadSettings()
        end, 100)  -- 높은 우선순위

        -- 설정 저장
        FoxChat.Events:Register("FOXCHAT_SAVE_SETTINGS", function()
            BasicTab:SaveSettings()
        end, 100)
    end
end

-- 설정 로드
function BasicTab:LoadSettings()
    if not FoxChatDB then return end

    -- 체크박스 상태 설정
    if elements.enableCheckbox then
        elements.enableCheckbox:SetChecked(FoxChatDB.enabled ~= false)
    end

    if elements.filterCheckbox then
        elements.filterCheckbox:SetChecked(FoxChatDB.filterEnabled ~= false)
    end

    if elements.prefixSuffixCheckbox then
        elements.prefixSuffixCheckbox:SetChecked(FoxChatDB.prefixSuffixEnabled == true)
    end

    if elements.playSoundCheckbox then
        elements.playSoundCheckbox:SetChecked(FoxChatDB.playSound ~= false)
    end

    -- 볼륨 슬라이더
    if elements.volumeSlider then
        elements.volumeSlider:SetValue(FoxChatDB.soundVolume or 0.5)
    end

    -- 채널 그룹
    if elements.channelCheckboxes and FoxChatDB.channelGroups then
        for key, checkbox in pairs(elements.channelCheckboxes) do
            checkbox:SetChecked(FoxChatDB.channelGroups[key] ~= false)
        end
    end

    -- 미니맵 버튼
    if elements.minimapCheckbox and FoxChatDB.minimapButton then
        elements.minimapCheckbox:SetChecked(not FoxChatDB.minimapButton.hide)
    end
end

-- 설정 저장
function BasicTab:SaveSettings()
    -- UI 요소들의 현재 상태는 이미 OnClick 등의 이벤트에서 실시간으로 저장됨
    -- 추가 처리가 필요한 경우 여기에 작성

    -- 모듈들에게 설정 변경 알림
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_SETTINGS_CHANGED")
    end
end