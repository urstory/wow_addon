local MESSAGE_HEIGHT = 25  -- Reduced height to decrease spacing
local MAX_MESSAGES_SHOWN = 10

-- 직업 색상을 캐시하는 테이블
local classColorCache = {}

-- 직업색 가져오기 (CUSTOM_CLASS_COLORS가 있으면 우선 사용)
local function GetClassColorRGB(englishClass)
    if not englishClass then return 1, 1, 1 end

    -- WoW의 표준 직업 색상 테이블 사용
    local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    if not colorTable then
        -- 폴백: 기본 직업 색상 정의
        colorTable = {
            ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43},
            ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
            ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
            ["ROGUE"] = {r = 1.00, g = 0.96, b = 0.41},
            ["PRIEST"] = {r = 1.00, g = 1.00, b = 1.00},
            ["SHAMAN"] = {r = 0.00, g = 0.44, b = 0.87},
            ["MAGE"] = {r = 0.41, g = 0.80, b = 0.94},
            ["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79},
            ["DRUID"] = {r = 1.00, g = 0.49, b = 0.04}
        }
    end

    local color = colorTable[englishClass]
    if color then
        return color.r, color.g, color.b
    end

    return 0, 1, 0  -- 기본 녹색
end

-- GUID에서 직업색 얻기
local function GetColorByGUID(guid, playerName)
    if not guid then
        return 0, 1, 0  -- 기본 녹색
    end

    -- 캐시 확인
    if classColorCache[guid] then
        local cached = classColorCache[guid]
        return cached.r, cached.g, cached.b
    end

    -- GetPlayerInfoByGUID 함수 확인
    if not GetPlayerInfoByGUID then
        return 0, 1, 0
    end

    -- GetPlayerInfoByGUID 함수 사용
    -- WoW Classic에서 실제 반환 순서: localizedClass, englishClass, localizedRace, englishRace, sex, name, realm
    local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(guid)

    if englishClass then
        local r, g, b = GetClassColorRGB(englishClass)
        -- 캐시에 저장
        classColorCache[guid] = {r = r, g = g, b = b}
        return r, g, b
    end

    return 0, 1, 0  -- 기본 녹색
end

-- 색상을 16진수 문자열로 변환
local function ToHexColor(r, g, b)
    return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

-- 직업 색상 문자열 생성 함수 (GUID 기반)
local function GetClassColorString(playerName, guid)
    local r, g, b = GetColorByGUID(guid, playerName)
    return ToHexColor(r, g, b)
end

local function CreateMessageFrame()
    local frame = CreateFrame("Frame", "SimpleFindPartyMessageFrame", UIParent)
    frame:SetWidth(500)
    frame:SetHeight(250)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetResizable(true)

    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    backdrop:SetAllPoints(frame)
    backdrop:SetVertexColor(0, 0, 0, 0.4)

    local borderLeft = frame:CreateTexture(nil, "BORDER")
    borderLeft:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    borderLeft:SetPoint("LEFT", frame, "LEFT", 0, 0)
    borderLeft:SetPoint("TOP", frame, "TOP", 0, 0)
    borderLeft:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    borderLeft:SetWidth(1)
    borderLeft:SetVertexColor(0.4, 0.4, 0.4, 0.8)

    local borderRight = frame:CreateTexture(nil, "BORDER")
    borderRight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    borderRight:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    borderRight:SetPoint("TOP", frame, "TOP", 0, 0)
    borderRight:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    borderRight:SetWidth(1)
    borderRight:SetVertexColor(0.4, 0.4, 0.4, 0.8)

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    borderTop:SetPoint("TOP", frame, "TOP", 0, 0)
    borderTop:SetPoint("LEFT", frame, "LEFT", 0, 0)
    borderTop:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetVertexColor(0.4, 0.4, 0.4, 0.8)

    local borderBottom = frame:CreateTexture(nil, "BORDER")
    borderBottom:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    borderBottom:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    borderBottom:SetPoint("LEFT", frame, "LEFT", 0, 0)
    borderBottom:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    borderBottom:SetHeight(1)
    borderBottom:SetVertexColor(0.4, 0.4, 0.4, 0.8)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, xOfs, yOfs = frame:GetPoint(1)
        SimpleFindPartyDB.messageFramePos = {point = point, x = xOfs, y = yOfs}
    end)

    frame:SetScript("OnSizeChanged", function()
        local width = frame:GetWidth()
        local height = frame:GetHeight()

        -- Enforce min/max sizes manually
        local changed = false
        if width < 200 then
            width = 200
            changed = true
        elseif width > 800 then
            width = 800
            changed = true
        end

        if height < 100 then
            height = 100
            changed = true
        elseif height > 600 then
            height = 600
            changed = true
        end

        if changed then
            frame:SetWidth(width)
            frame:SetHeight(height)
        end

        SimpleFindPartyDB.messageFrameSize = {width = width, height = height}

        -- Update scroll child width and refresh display
        local scrollFrame = SFP_MessageScrollFrame
        if scrollFrame then
            local scrollChild = scrollFrame:GetScrollChild()
            if scrollChild then
                scrollChild:SetWidth(width - 50)
                RefreshMessageDisplay()  -- Refresh to adjust message widths
            end
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    title:SetText("파티 찾기 메시지")
    title:SetTextColor(1, 1, 0.5)

    -- Sound toggle button (bell icon)
    local soundButton = CreateFrame("Button", nil, frame)
    soundButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -65, -5)
    soundButton:SetWidth(24)
    soundButton:SetHeight(24)

    -- Create bell icon texture
    local bellIcon = soundButton:CreateTexture(nil, "ARTWORK")
    bellIcon:SetAllPoints(soundButton)

    local function UpdateBellIcon()
        if SimpleFindPartyDB.soundEnabled then
            bellIcon:SetTexture("Interface\\AddOns\\SimpleFindParty\\Textures\\Bell")
            if not bellIcon:GetTexture() then
                -- Fallback to built-in icon if custom texture not found
                bellIcon:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
            end
            bellIcon:SetVertexColor(1, 1, 1)
        else
            bellIcon:SetTexture("Interface\\AddOns\\SimpleFindParty\\Textures\\BellMuted")
            if not bellIcon:GetTexture() then
                -- Fallback to built-in icon if custom texture not found
                bellIcon:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
            end
            bellIcon:SetVertexColor(0.5, 0.5, 0.5)
        end
    end
    UpdateBellIcon()

    soundButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    soundButton:SetScript("OnClick", function()
        SimpleFindPartyDB.soundEnabled = not SimpleFindPartyDB.soundEnabled
        UpdateBellIcon()
    end)

    soundButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(soundButton, "ANCHOR_LEFT")
        if SimpleFindPartyDB.soundEnabled then
            GameTooltip:SetText("알림 소리 켜짐")
            GameTooltip:AddLine("클릭하여 끄기", 0.8, 0.8, 0.8)
        else
            GameTooltip:SetText("알림 소리 꺼짐")
            GameTooltip:AddLine("클릭하여 켜기", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    soundButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Store function for external updates
    frame.UpdateSoundButton = UpdateBellIcon

    -- Settings button (gear icon)
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -5)
    settingsButton:SetWidth(24)
    settingsButton:SetHeight(24)

    settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    settingsButton:SetScript("OnClick", function()
        if SimpleFindPartySettingsFrame then
            SimpleFindPartySettingsFrame:Show()
        end
    end)

    settingsButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(settingsButton, "ANCHOR_LEFT")
        GameTooltip:SetText("설정")
        GameTooltip:Show()
    end)

    settingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetWidth(24)
    closeButton:SetHeight(24)

    -- Create custom X button texture
    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    closeBg:SetAllPoints(closeButton)
    closeBg:SetVertexColor(0.5, 0, 0, 0.5)

    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeText:SetText("X")
    closeText:SetTextColor(1, 1, 1, 1)

    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    closeButton:SetScript("OnClick", function()
        SimpleFindPartyMessageFrame:Hide()
    end)

    -- Create resize button
    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resizeButton:SetWidth(16)
    resizeButton:SetHeight(16)
    resizeButton:EnableMouse(true)
    resizeButton:SetFrameLevel(frame:GetFrameLevel() + 10)

    -- Create resize texture that looks like diagonal lines
    local resizeTexture = resizeButton:CreateTexture(nil, "OVERLAY")
    resizeTexture:SetAllPoints(resizeButton)
    resizeTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    local resizeHighlight = resizeButton:CreateTexture(nil, "HIGHLIGHT")
    resizeHighlight:SetAllPoints(resizeButton)
    resizeHighlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

    local resizePushed = resizeButton:CreateTexture(nil, "ARTWORK")
    resizePushed:SetAllPoints(resizeButton)
    resizePushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetPushedTexture(resizePushed)

    resizeButton:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeButton:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        SimpleFindPartyDB.messageFrameSize = {width = width, height = height}
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "SFP_MessageScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(frame:GetWidth() - 50)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    frame.messageFrames = {}

    return frame
end

function RefreshMessageDisplay()
    local frame = SimpleFindPartyMessageFrame
    if not frame then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000RefreshMessageDisplay: Frame not found|r")
        return
    end

    local scrollFrame = SFP_MessageScrollFrame
    if not scrollFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000RefreshMessageDisplay: ScrollFrame not found|r")
        return
    end

    local scrollChild = scrollFrame:GetScrollChild()
    if not scrollChild then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000RefreshMessageDisplay: ScrollChild not found|r")
        return
    end

    -- Clear existing message frames
    for _, msgFrame in ipairs(frame.messageFrames) do
        msgFrame:Hide()
        msgFrame:SetParent(nil)
    end
    frame.messageFrames = {}

    local yOffset = 0
    local shown = 0

    -- Show messages (newest first)
    for i, msgData in ipairs(SimpleFindPartyFilteredMessages) do
        if shown >= MAX_MESSAGES_SHOWN then break end

        local msgFrame = CreateFrame("Frame", nil, scrollChild)
        msgFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        msgFrame:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        msgFrame:SetHeight(MESSAGE_HEIGHT)

        -- Nickname column (fixed width, top-aligned)
        local nicknameText = msgFrame:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
        nicknameText:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 5, -2)
        nicknameText:SetWidth(100)  -- Increased width for 8 Korean characters
        nicknameText:SetJustifyH("LEFT")
        nicknameText:SetJustifyV("TOP")
        -- 직업 색상 적용 (GUID 기반)
        local colorString = GetClassColorString(msgData.author, msgData.guid)
        nicknameText:SetText(colorString .. msgData.author .. "|r")

        -- Message column (flexible width) with click area
        local msgButton = CreateFrame("Button", nil, msgFrame)
        msgButton:SetPoint("TOPLEFT", msgFrame, "TOPLEFT", 110, 0)  -- Adjusted for wider nickname column
        msgButton:SetPoint("BOTTOMRIGHT", msgFrame, "BOTTOMRIGHT", -40, 0)
        msgButton:RegisterForClicks("LeftButtonUp")

        local messageText = msgButton:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
        messageText:SetPoint("TOPLEFT", msgButton, "TOPLEFT", 0, -2)
        messageText:SetPoint("BOTTOMRIGHT", msgButton, "BOTTOMRIGHT", -5, 2)
        messageText:SetJustifyH("LEFT")
        messageText:SetJustifyV("TOP")
        messageText:SetText(msgData.highlighted)

        msgButton:SetScript("OnClick", function()
            -- Open the chat editbox and set whisper command
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME.editBox:Show()
                DEFAULT_CHAT_FRAME.editBox:SetFocus()
                DEFAULT_CHAT_FRAME.editBox:SetText("/귓속말 " .. msgData.author .. " ")
            end
        end)

        msgButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(msgButton, "ANCHOR_LEFT")
            GameTooltip:SetText("클릭: 귓속말 보내기")
            GameTooltip:AddLine(msgData.message, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end)

        msgButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Delete button (X) - aligned with top of frame
        local deleteButton = CreateFrame("Button", nil, msgFrame)
        deleteButton:SetPoint("TOPRIGHT", msgFrame, "TOPRIGHT", -20, -2)
        deleteButton:SetWidth(16)
        deleteButton:SetHeight(16)
        deleteButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        deleteButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        deleteButton:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-Hilight")

        deleteButton:SetScript("OnClick", function()
            RemoveFilteredMessage(i)
        end)

        -- Block button - aligned with top of frame
        local blockButton = CreateFrame("Button", nil, msgFrame)
        blockButton:SetPoint("TOPRIGHT", msgFrame, "TOPRIGHT", -2, -2)
        blockButton:SetWidth(16)
        blockButton:SetHeight(16)
        blockButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        blockButton:SetPushedTexture("Interface\\Buttons\\UI-StopButton")
        blockButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

        blockButton:SetScript("OnClick", function()
            BlockUser(msgData.author)
        end)

        blockButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(blockButton, "ANCHOR_LEFT")
            GameTooltip:SetText("사용자 차단")
            GameTooltip:Show()
        end)

        blockButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(frame.messageFrames, msgFrame)
        yOffset = yOffset + MESSAGE_HEIGHT  -- Removed extra spacing
        shown = shown + 1
    end

    scrollChild:SetHeight(math.max(1, yOffset))
end

-- Auto-cleanup timer frame
local cleanupTimer = CreateFrame("Frame")
local cleanupElapsed = 0

function CleanupOldMessages()
    local currentTime = time()
    local hasChanges = false

    for i = table.getn(SimpleFindPartyFilteredMessages), 1, -1 do
        local msg = SimpleFindPartyFilteredMessages[i]
        -- Remove messages older than 60 seconds
        if currentTime - msg.timestamp > 60 then
            table.remove(SimpleFindPartyFilteredMessages, i)
            hasChanges = true
        end
    end

    if hasChanges then
        RefreshMessageDisplay()
    end
end

cleanupTimer:SetScript("OnUpdate", function()
    local deltaTime = arg1 or 0.01
    cleanupElapsed = cleanupElapsed + deltaTime

    -- Check every 5 seconds
    if cleanupElapsed > 5 then
        cleanupElapsed = 0
        CleanupOldMessages()
    end
end)

function InitializeMessageFrame()
    if not SimpleFindPartyMessageFrame then
        SimpleFindPartyMessageFrame = CreateMessageFrame()
    end
end