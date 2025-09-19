-- Default saved variables
local defaults = {
    minimapPos = 45,
    selectedChannel = nil,
    filterKeywords = "",
    ignoreKeywords = "",
    blockedUsers = {},
    messageFramePos = nil,
    messageFrameSize = nil,
    showMessageFrame = true,
    soundEnabled = true
}

local frame = CreateFrame("Frame", "SimpleFindPartyFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("CHANNEL_UI_UPDATE")
frame:RegisterEvent("UPDATE_CHAT_WINDOWS")

local function OnChatMessage(message, author, channelNumber, channelName)
    if not SimpleFindPartyDB.selectedChannel then
        return
    end

    -- Check by channel number
    local shouldProcess = false
    if tonumber(channelNumber) == SimpleFindPartyDB.selectedChannel then
        shouldProcess = true
    end

    if shouldProcess then
        -- If no filter keywords, show all messages
        -- If filter keywords exist, only show matching messages
        if table.getn(SimpleFindPartyFilterKeywords) == 0 or ShouldFilterMessage(message) then
            AddFilteredMessage(author, message, time())
        end
    end
end

local addonInitialized = false

local function InitializeAddon()
    if addonInitialized then
        return
    end
    addonInitialized = true

    -- Ensure saved variables
    if not SimpleFindPartyDB then
        SimpleFindPartyDB = {}
    end

    -- Set defaults for missing values
    for k, v in pairs(defaults) do
        if SimpleFindPartyDB[k] == nil then
            SimpleFindPartyDB[k] = v
        end
    end

    -- Create all frames (check if functions exist)
    if InitializeMinimapButton then
        InitializeMinimapButton()
    end

    if InitializeSettingsFrame then
        InitializeSettingsFrame()
        -- Ensure settings frame is on top layer
        if SimpleFindPartySettingsFrame then
            SimpleFindPartySettingsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            SimpleFindPartySettingsFrame:SetFrameLevel(999)
        end
    end

    if InitializeMessageFrame then
        InitializeMessageFrame()
    end

    -- Update filter and ignore keywords
    if UpdateFilterKeywords then
        UpdateFilterKeywords()
    end
    if UpdateIgnoreKeywords then
        UpdateIgnoreKeywords()
    end

    -- Set default channel if not set
    if not SimpleFindPartyDB.selectedChannel then
        local channels = {}
        local partyFindId = nil
        local channelList = {GetChannelList()}

        -- GetChannelList returns: id, name, disabled(boolean) in groups of 3
        for i = 1, table.getn(channelList), 3 do
            local id = channelList[i]
            local name = channelList[i + 1]
            local disabled = channelList[i + 2]
            if type(id) == "number" and type(name) == "string" then
                table.insert(channels, {name = name, id = id})
                if name == "파티찾기" then
                    partyFindId = id
                end
            end
        end

        if partyFindId then
            SimpleFindPartyDB.selectedChannel = partyFindId
            DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 파티찾기 채널 선택됨 (채널 번호: " .. partyFindId .. ")")

            -- Check if we're in the channel
            local isInChannel = false
            for i = 1, table.getn(channelList), 3 do
                if channelList[i] == partyFindId and channelList[i + 2] then
                    isInChannel = true
                    break
                end
            end

            if not isInChannel then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00파티찾기 채널에 참여하지 않은 상태입니다. /join 파티찾기 명령어를 사용하세요.|r")
            end
        elseif table.getn(channels) > 0 then
            table.sort(channels, function(a, b) return a.name < b.name end)
            SimpleFindPartyDB.selectedChannel = channels[1].id
            DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: " .. channels[1].name .. " 채널 선택됨")
        end
    end

    -- Position and size message frame
    if SimpleFindPartyMessageFrame then
        if SimpleFindPartyDB.messageFramePos then
            SimpleFindPartyMessageFrame:ClearAllPoints()
            SimpleFindPartyMessageFrame:SetPoint(
                SimpleFindPartyDB.messageFramePos.point or "CENTER",
                UIParent,
                SimpleFindPartyDB.messageFramePos.point or "CENTER",
                SimpleFindPartyDB.messageFramePos.x or 0,
                SimpleFindPartyDB.messageFramePos.y or 100
            )
        end

        if SimpleFindPartyDB.messageFrameSize then
            SimpleFindPartyMessageFrame:SetWidth(SimpleFindPartyDB.messageFrameSize.width or 500)
            SimpleFindPartyMessageFrame:SetHeight(SimpleFindPartyDB.messageFrameSize.height or 250)
        end
    end

    -- Update minimap button position and ensure it's visible
    if UpdateMinimapButtonPosition then
        UpdateMinimapButtonPosition()
    end

    -- Show frames
    if SimpleFindPartyMinimapButton then
        SimpleFindPartyMinimapButton:Show()
    end

    if SimpleFindPartyMessageFrame then
        SimpleFindPartyMessageFrame:Show()
    end

    -- Re-register chat event to be sure
    frame:RegisterEvent("CHAT_MSG_CHANNEL")

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SimpleFindParty|r 애드온이 로드되었습니다. /sfp 명령어를 사용하세요.", 1, 1, 0)
end

-- Event handler - using parameters for modern WoW API style
frame:SetScript("OnEvent", function(self, eventName, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12 = ...

    -- Initialize on first event
    if not addonInitialized then
        InitializeAddon()
    end

    if eventName == "VARIABLES_LOADED" or eventName == "PLAYER_LOGIN" or eventName == "PLAYER_ENTERING_WORLD" then
        InitializeAddon()
    elseif eventName == "ADDON_LOADED" then
        if arg1 == "SimpleFindParty" then
            InitializeAddon()
        end
    elseif eventName == "CHAT_MSG_CHANNEL" then
        -- arg1: message
        -- arg2: sender
        -- arg3: language
        -- arg4: channel long name (e.g., "5. 파티찾기")
        -- arg5: target (sender without server)
        -- arg6: AFK/DND/GM flags
        -- arg7: zone ID
        -- arg8: channel number
        -- arg9: channel name
        -- arg10: channel flags
        -- arg11: line ID
        -- arg12: GUID

        local message = arg1
        local sender = arg2
        local channelNum = tonumber(arg8)
        local channelName = arg9
        local guid = arg12

        if message and sender then
            -- 서버이름 제거 (arg5를 사용하거나 직접 제거)
            local cleanSender = arg5 or sender
            local dashPos = string.find(cleanSender, "-")
            if dashPos then
                cleanSender = string.sub(cleanSender, 1, dashPos - 1)
            end

            -- 채널 이름으로 파티찾기 채널 확인
            local channelNameLower = string.lower(channelName or "")
            local isPartyFindChannel = string.find(channelNameLower, "파티찾기") or string.find(channelNameLower, "파티 찾기")

            -- 선택된 채널의 메시지이거나 파티찾기 채널인 경우 처리
            if (SimpleFindPartyDB.selectedChannel and channelNum == SimpleFindPartyDB.selectedChannel) or isPartyFindChannel then
                -- 필터링 확인 후 메시지 추가 (GUID 포함)
                if table.getn(SimpleFindPartyFilterKeywords) == 0 or ShouldFilterMessage(message) then
                    AddFilteredMessage(cleanSender, message, time(), guid)
                    RefreshMessageDisplay()
                end
            end
        end
    elseif eventName == "CHANNEL_UI_UPDATE" or eventName == "UPDATE_CHAT_WINDOWS" then
        if SimpleFindPartySettingsFrame and SimpleFindPartySettingsFrame:IsShown() then
            UIDropDownMenu_Initialize(SFP_ChannelDropdown, function()
                local channels = {}
                local channelList = {GetChannelList()}

                for i = 1, table.getn(channelList), 3 do
                    local id = channelList[i]
                    local name = channelList[i + 1]
                    local disabled = channelList[i + 2]
                    if type(id) == "number" and type(name) == "string" then
                        table.insert(channels, {name = name, id = id})
                    end
                end

                -- Sort alphabetically
                table.sort(channels, function(a, b) return a.name < b.name end)

                for _, channel in ipairs(channels) do
                    local channelId = channel.id  -- Create local copy for closure
                    local info = {}
                    info.text = tostring(channel.name)
                    info.value = channel.id
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(SFP_ChannelDropdown, channelId)
                        SimpleFindPartyDB.selectedChannel = channelId
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
        end
    end
end)


SLASH_SIMPLEFINDPARTY1 = "/sfp"
SLASH_SIMPLEFINDPARTY2 = "/simplefindparty"
SlashCmdList["SIMPLEFINDPARTY"] = function(msg)
    -- Ensure frames are created
    if not addonInitialized then
        InitializeAddon()
    end

    if msg == "show" then
        if SimpleFindPartyMessageFrame then
            SimpleFindPartyMessageFrame:Show()
        else
            DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 메시지 프레임을 생성할 수 없습니다.", 1, 0, 0)
        end
    elseif msg == "hide" then
        if SimpleFindPartyMessageFrame then
            SimpleFindPartyMessageFrame:Hide()
        end
    elseif msg == "settings" or msg == "config" then
        if SimpleFindPartySettingsFrame then
            SimpleFindPartySettingsFrame:Show()
        else
            DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 설정 프레임을 생성할 수 없습니다.", 1, 0, 0)
        end
    elseif msg == "join" then
        -- Join the selected channel
        if SimpleFindPartyDB.selectedChannel then
            local channelList = {GetChannelList()}
            local channelName = nil
            for i = 1, table.getn(channelList), 3 do
                if channelList[i] == SimpleFindPartyDB.selectedChannel then
                    channelName = channelList[i + 1]
                    break
                end
            end

            if channelName then
                JoinChannelByName(channelName)
                DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: " .. channelName .. " 채널에 참여 시도", 1, 1, 0)
            else
                DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 선택된 채널을 찾을 수 없습니다.", 1, 0, 0)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 선택된 채널이 없습니다.", 1, 0, 0)
        end
    elseif msg == "test" then
        DEFAULT_CHAT_FRAME:AddMessage("Testing message capture...", 1, 1, 0)
        AddFilteredMessage("TestUser", "This is a test message for SimpleFindParty", time(), nil)
        RefreshMessageDisplay()
        DEFAULT_CHAT_FRAME:AddMessage("Test message added. Check message window.", 1, 1, 0)
    elseif msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty Debug Info:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  Frame exists: " .. tostring(frame ~= nil), 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  CHAT_MSG_CHANNEL registered: " .. tostring(frame:IsEventRegistered("CHAT_MSG_CHANNEL")), 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  Selected Channel ID: " .. tostring(SimpleFindPartyDB.selectedChannel), 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  Filter Keywords: " .. tostring(SimpleFindPartyDB.filterKeywords), 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  Channels (flag=true means you're IN that channel):", 1, 0.8, 0)
        local channelList = {GetChannelList()}
        local inSelectedChannel = false
        for i = 1, table.getn(channelList), 3 do
            local id = channelList[i]
            local name = channelList[i + 1]
            local isJoined = channelList[i + 2]
            if type(id) == "number" and type(name) == "string" then
                local status = isJoined and "JOINED" or "NOT JOINED"
                DEFAULT_CHAT_FRAME:AddMessage("    [" .. id .. "] " .. name .. " - " .. status, 1, 0.8, 0)
                if id == SimpleFindPartyDB.selectedChannel and isJoined then
                    inSelectedChannel = true
                end
            end
        end

        if SimpleFindPartyDB.selectedChannel and not inSelectedChannel then
            DEFAULT_CHAT_FRAME:AddMessage("  |cffff0000WARNING: You are NOT in the selected channel!|r", 1, 0, 0)
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00Type /join 파티찾기 to join the channel|r", 1, 1, 0)
        end
    elseif msg == "reset" then
        SimpleFindPartyDB = {
            minimapPos = 45,
            selectedChannel = nil,
            filterKeywords = "",
            blockedUsers = {},
            messageFramePos = nil,
            messageFrameSize = nil
        }
        SimpleFindPartyFilteredMessages = {}
        UpdateMinimapButtonPosition()
        SimpleFindPartyMessageFrame:ClearAllPoints()
        SimpleFindPartyMessageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        RefreshMessageDisplay()
        DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty: 설정이 초기화되었습니다.", 1, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("SimpleFindParty 명령어:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp show - 메시지창 표시", 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp hide - 메시지창 숨기기", 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp settings - 설정창 열기", 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp join - 선택된 채널 참여", 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp debug - 디버그 정보 표시", 1, 0.8, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/sfp reset - 모든 설정 초기화", 1, 0.8, 0)
    end
end

-- Force initialization after 1 second if not already done
local initTimer = CreateFrame("Frame")
local elapsed = 0
initTimer:SetScript("OnUpdate", function()
    local deltaTime = arg1 or 0.01  -- Fallback if arg1 is nil
    elapsed = elapsed + deltaTime
    if elapsed > 1 then
        initTimer:SetScript("OnUpdate", nil)
        if not addonInitialized then
            InitializeAddon()
        end
    end
end)