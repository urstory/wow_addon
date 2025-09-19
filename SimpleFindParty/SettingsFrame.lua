local function CreateSettingsFrame()
    local frame = CreateFrame("Frame", "SimpleFindPartySettingsFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(550)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)

    -- Simple dark background
    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    backdrop:SetPoint("TOPLEFT", -5, 5)
    backdrop:SetPoint("BOTTOMRIGHT", 5, -5)

    -- Simple borders
    local borderTop = frame:CreateTexture(nil, "OVERLAY")
    borderTop:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Border")
    borderTop:SetPoint("TOPLEFT", -5, 5)
    borderTop:SetPoint("TOPRIGHT", 5, 5)
    borderTop:SetHeight(2)

    local borderBottom = frame:CreateTexture(nil, "OVERLAY")
    borderBottom:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Border")
    borderBottom:SetPoint("BOTTOMLEFT", -5, -5)
    borderBottom:SetPoint("BOTTOMRIGHT", 5, -5)
    borderBottom:SetHeight(2)

    local borderLeft = frame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Border")
    borderLeft:SetPoint("TOPLEFT", -5, 5)
    borderLeft:SetPoint("BOTTOMLEFT", -5, -5)
    borderLeft:SetWidth(2)

    local borderRight = frame:CreateTexture(nil, "OVERLAY")
    borderRight:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Border")
    borderRight:SetPoint("TOPRIGHT", 5, 5)
    borderRight:SetPoint("BOTTOMRIGHT", 5, -5)
    borderRight:SetWidth(2)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("SimpleFindParty 설정")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local channelLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -50)
    channelLabel:SetText("파티찾기 채널:")

    local channelDropdown = CreateFrame("Frame", "SFP_ChannelDropdown", frame, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", -15, -5)

    local function InitializeChannelDropdown()
        local channels = {}
        local partyFindId = nil
        local selectedExists = false

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
                if SimpleFindPartyDB.selectedChannel == id then
                    selectedExists = true
                end
            end
        end

        -- Sort channels alphabetically
        table.sort(channels, function(a, b) return a.name < b.name end)

        -- Add buttons to dropdown
        for _, channel in ipairs(channels) do
            local info = {}
            info.text = tostring(channel.name)
            info.value = channel.id
            info.func = function()
                UIDropDownMenu_SetSelectedValue(channelDropdown, channel.id)
                SimpleFindPartyDB.selectedChannel = channel.id
            end
            UIDropDownMenu_AddButton(info)
        end

        -- Priority logic for selection
        if SimpleFindPartyDB.selectedChannel and selectedExists then
            -- 1. User's previously selected channel still exists
            UIDropDownMenu_SetSelectedValue(channelDropdown, SimpleFindPartyDB.selectedChannel)
        elseif partyFindId then
            -- 2. No user selection or it doesn't exist, but "파티찾기" exists
            UIDropDownMenu_SetSelectedValue(channelDropdown, partyFindId)
            SimpleFindPartyDB.selectedChannel = partyFindId
        elseif table.getn(channels) > 0 then
            -- 3. Use first channel alphabetically
            UIDropDownMenu_SetSelectedValue(channelDropdown, channels[1].id)
            SimpleFindPartyDB.selectedChannel = channels[1].id
        end
    end

    UIDropDownMenu_SetWidth(channelDropdown, 150)

    -- Initialize and set default on creation
    local function SetupDropdown()
        InitializeChannelDropdown()

        -- Set the displayed text
        if SimpleFindPartyDB.selectedChannel then
            local channelList = {GetChannelList()}
            for i = 1, table.getn(channelList), 3 do
                local id = channelList[i]
                local name = channelList[i + 1]
                local disabled = channelList[i + 2]
                if type(id) == "number" and id == SimpleFindPartyDB.selectedChannel then
                    UIDropDownMenu_SetText(channelDropdown, name)
                    break
                end
            end
        end
    end

    UIDropDownMenu_Initialize(channelDropdown, InitializeChannelDropdown)
    SetupDropdown()

    local filterLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    filterLabel:SetPoint("TOPLEFT", channelDropdown, "BOTTOMLEFT", 15, -20)
    filterLabel:SetText("필터링 키워드 (쉼표로 구분):")

    local filterEditBox = CreateFrame("EditBox", "SFP_FilterEditBox", frame)
    filterEditBox:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -5)
    filterEditBox:SetWidth(350)
    filterEditBox:SetHeight(30)

    local editBg = filterEditBox:CreateTexture(nil, "BACKGROUND")
    editBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBg:SetAllPoints(filterEditBox)
    editBg:SetVertexColor(0, 0, 0, 0.5)

    local editBorderLeft = filterEditBox:CreateTexture(nil, "BORDER")
    editBorderLeft:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBorderLeft:SetPoint("TOPLEFT", -1, 1)
    editBorderLeft:SetPoint("BOTTOMLEFT", -1, -1)
    editBorderLeft:SetWidth(1)
    editBorderLeft:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local editBorderRight = filterEditBox:CreateTexture(nil, "BORDER")
    editBorderRight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBorderRight:SetPoint("TOPRIGHT", 1, 1)
    editBorderRight:SetPoint("BOTTOMRIGHT", 1, -1)
    editBorderRight:SetWidth(1)
    editBorderRight:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local editBorderTop = filterEditBox:CreateTexture(nil, "BORDER")
    editBorderTop:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBorderTop:SetPoint("TOPLEFT", -1, 1)
    editBorderTop:SetPoint("TOPRIGHT", 1, 1)
    editBorderTop:SetHeight(1)
    editBorderTop:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local editBorderBottom = filterEditBox:CreateTexture(nil, "BORDER")
    editBorderBottom:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBorderBottom:SetPoint("BOTTOMLEFT", -1, -1)
    editBorderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
    editBorderBottom:SetHeight(1)
    editBorderBottom:SetVertexColor(0.3, 0.3, 0.3, 0.8)
    filterEditBox:SetFontObject(ChatFontNormal)
    filterEditBox:SetAutoFocus(false)
    filterEditBox:SetTextInsets(5, 5, 3, 3)
    filterEditBox:SetMaxLetters(200)
    filterEditBox:SetText(SimpleFindPartyDB.filterKeywords or "")

    filterEditBox:SetScript("OnTextChanged", function()
        SimpleFindPartyDB.filterKeywords = filterEditBox:GetText()
        UpdateFilterKeywords()
    end)

    filterEditBox:SetScript("OnEscapePressed", function()
        filterEditBox:ClearFocus()
    end)

    -- Ignore keywords section
    local ignoreLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ignoreLabel:SetPoint("TOPLEFT", filterEditBox, "BOTTOMLEFT", 0, -20)
    ignoreLabel:SetText("무시할 키워드 (쉼표로 구분):")

    local ignoreEditBox = CreateFrame("EditBox", "SFP_IgnoreEditBox", frame)
    ignoreEditBox:SetPoint("TOPLEFT", ignoreLabel, "BOTTOMLEFT", 0, -5)
    ignoreEditBox:SetWidth(350)
    ignoreEditBox:SetHeight(30)

    local ignoreBg = ignoreEditBox:CreateTexture(nil, "BACKGROUND")
    ignoreBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ignoreBg:SetAllPoints(ignoreEditBox)
    ignoreBg:SetVertexColor(0, 0, 0, 0.5)

    local ignoreBorderLeft = ignoreEditBox:CreateTexture(nil, "BORDER")
    ignoreBorderLeft:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ignoreBorderLeft:SetPoint("TOPLEFT", -1, 1)
    ignoreBorderLeft:SetPoint("BOTTOMLEFT", -1, -1)
    ignoreBorderLeft:SetWidth(1)
    ignoreBorderLeft:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local ignoreBorderRight = ignoreEditBox:CreateTexture(nil, "BORDER")
    ignoreBorderRight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ignoreBorderRight:SetPoint("TOPRIGHT", 1, 1)
    ignoreBorderRight:SetPoint("BOTTOMRIGHT", 1, -1)
    ignoreBorderRight:SetWidth(1)
    ignoreBorderRight:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local ignoreBorderTop = ignoreEditBox:CreateTexture(nil, "BORDER")
    ignoreBorderTop:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ignoreBorderTop:SetPoint("TOPLEFT", -1, 1)
    ignoreBorderTop:SetPoint("TOPRIGHT", 1, 1)
    ignoreBorderTop:SetHeight(1)
    ignoreBorderTop:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    local ignoreBorderBottom = ignoreEditBox:CreateTexture(nil, "BORDER")
    ignoreBorderBottom:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ignoreBorderBottom:SetPoint("BOTTOMLEFT", -1, -1)
    ignoreBorderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
    ignoreBorderBottom:SetHeight(1)
    ignoreBorderBottom:SetVertexColor(0.3, 0.3, 0.3, 0.8)

    ignoreEditBox:SetFontObject(ChatFontNormal)
    ignoreEditBox:SetAutoFocus(false)
    ignoreEditBox:SetTextInsets(5, 5, 3, 3)
    ignoreEditBox:SetMaxLetters(200)
    ignoreEditBox:SetText(SimpleFindPartyDB.ignoreKeywords or "")

    ignoreEditBox:SetScript("OnTextChanged", function()
        SimpleFindPartyDB.ignoreKeywords = ignoreEditBox:GetText()
        UpdateIgnoreKeywords()
    end)

    ignoreEditBox:SetScript("OnEscapePressed", function()
        ignoreEditBox:ClearFocus()
    end)

    -- Sound toggle checkbox
    local soundCheckbox = CreateFrame("CheckButton", "SFP_SoundCheckbox", frame, "UICheckButtonTemplate")
    soundCheckbox:SetPoint("TOPLEFT", ignoreEditBox, "BOTTOMLEFT", 0, -20)
    soundCheckbox:SetChecked(SimpleFindPartyDB.soundEnabled)

    local soundLabel = soundCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
    soundLabel:SetText("알림 소리 켜기")

    soundCheckbox:SetScript("OnClick", function()
        SimpleFindPartyDB.soundEnabled = soundCheckbox:GetChecked() and true or false
    end)

    local blockedLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    blockedLabel:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 0, -20)
    blockedLabel:SetText("차단된 사용자 목록:")

    local scrollFrame = CreateFrame("ScrollFrame", "SFP_BlockedScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", blockedLabel, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetWidth(320)
    scrollFrame:SetHeight(150)

    local scrollChild = CreateFrame("Frame", "SFP_BlockedScrollChild", scrollFrame)
    scrollChild:SetWidth(320)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    frame.RefreshBlockedList = function()
        for _, child in ipairs({scrollChild:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end

        local yOffset = 0
        if SimpleFindPartyDB.blockedUsers then
            for username, _ in pairs(SimpleFindPartyDB.blockedUsers) do
                local blockFrame = CreateFrame("Frame", nil, scrollChild)
                blockFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
                blockFrame:SetWidth(300)
                blockFrame:SetHeight(20)

                local nameText = blockFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                nameText:SetPoint("LEFT", blockFrame, "LEFT", 5, 0)
                nameText:SetText(username)

                local unblockButton = CreateFrame("Button", nil, blockFrame)
                unblockButton:SetPoint("RIGHT", blockFrame, "RIGHT", -5, 0)
                unblockButton:SetWidth(50)
                unblockButton:SetHeight(18)
                unblockButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
                unblockButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
                unblockButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")

                local buttonText = unblockButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                buttonText:SetPoint("CENTER")
                buttonText:SetText("해제")

                unblockButton:SetScript("OnClick", function()
                    SimpleFindPartyDB.blockedUsers[username] = nil
                    frame.RefreshBlockedList()
                    RefreshMessageDisplay()
                end)

                yOffset = yOffset + 25
            end
        end
        scrollChild:SetHeight(math.max(1, yOffset))
    end

    frame:SetScript("OnShow", function()
        InitializeChannelDropdown()
        frame.RefreshBlockedList()
        soundCheckbox:SetChecked(SimpleFindPartyDB.soundEnabled)

        -- Update displayed text
        if SimpleFindPartyDB.selectedChannel then
            local channelList = {GetChannelList()}
            for i = 1, table.getn(channelList), 3 do
                local id = channelList[i]
                local name = channelList[i + 1]
                local disabled = channelList[i + 2]
                if type(id) == "number" and id == SimpleFindPartyDB.selectedChannel then
                    UIDropDownMenu_SetText(channelDropdown, name)
                    break
                end
            end
        end
    end)

    return frame
end

function InitializeSettingsFrame()
    if not SimpleFindPartySettingsFrame then
        SimpleFindPartySettingsFrame = CreateSettingsFrame()
    end
end