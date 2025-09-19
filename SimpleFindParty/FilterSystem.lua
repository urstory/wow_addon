SimpleFindPartyFilteredMessages = {}
SimpleFindPartyFilterKeywords = {}
SimpleFindPartyIgnoreKeywords = {}

function UpdateFilterKeywords()
    SimpleFindPartyFilterKeywords = {}
    if SimpleFindPartyDB.filterKeywords and SimpleFindPartyDB.filterKeywords ~= "" then
        -- Use gfind for WoW Classic 1.12 compatibility
        local iterator = string.gmatch or string.gfind
        for keyword in iterator(SimpleFindPartyDB.filterKeywords, "[^,]+") do
            keyword = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
            if keyword ~= "" then
                table.insert(SimpleFindPartyFilterKeywords, string.lower(keyword))
            end
        end

        -- Clear messages that don't match the new filter
        if table.getn(SimpleFindPartyFilterKeywords) > 0 then
            for i = table.getn(SimpleFindPartyFilteredMessages), 1, -1 do
                local msg = SimpleFindPartyFilteredMessages[i]
                if not ShouldFilterMessage(msg.message) then
                    table.remove(SimpleFindPartyFilteredMessages, i)
                end
            end
            RefreshMessageDisplay()
        end
    end
end

function UpdateIgnoreKeywords()
    SimpleFindPartyIgnoreKeywords = {}
    if SimpleFindPartyDB.ignoreKeywords and SimpleFindPartyDB.ignoreKeywords ~= "" then
        -- Use gfind for WoW Classic 1.12 compatibility
        local iterator = string.gmatch or string.gfind
        for keyword in iterator(SimpleFindPartyDB.ignoreKeywords, "[^,]+") do
            keyword = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
            if keyword ~= "" then
                table.insert(SimpleFindPartyIgnoreKeywords, string.lower(keyword))
            end
        end
    end
end

function ShouldFilterMessage(message)
    if not message or message == "" then
        return false
    end

    local lowerMessage = string.lower(message)

    -- Check ignore keywords first - if any match, don't show
    if SimpleFindPartyIgnoreKeywords and table.getn(SimpleFindPartyIgnoreKeywords) > 0 then
        for _, keyword in ipairs(SimpleFindPartyIgnoreKeywords) do
            if string.find(lowerMessage, keyword, 1, true) then
                return false
            end
        end
    end

    -- If no filter keywords, show all messages (that aren't ignored)
    if table.getn(SimpleFindPartyFilterKeywords) == 0 then
        return true
    end

    -- Check filter keywords - must match at least one
    for _, keyword in ipairs(SimpleFindPartyFilterKeywords) do
        if string.find(lowerMessage, keyword, 1, true) then
            return true
        end
    end

    return false
end

function HighlightKeywords(message)
    if not message then
        return message
    end

    -- Don't highlight if no keywords
    if table.getn(SimpleFindPartyFilterKeywords) == 0 then
        return message
    end

    local result = message
    for _, keyword in ipairs(SimpleFindPartyFilterKeywords) do
        local pattern = "(" .. string.gsub(keyword, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1") .. ")"
        result = string.gsub(result, pattern, function(match)
            return "|cffffff00" .. match .. "|r"
        end)

        pattern = "(" .. string.gsub(string.upper(keyword), "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1") .. ")"
        result = string.gsub(result, pattern, function(match)
            return "|cffffff00" .. match .. "|r"
        end)

        local firstUpper = string.upper(string.sub(keyword, 1, 1)) .. string.lower(string.sub(keyword, 2))
        pattern = "(" .. string.gsub(firstUpper, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1") .. ")"
        result = string.gsub(result, pattern, function(match)
            return "|cffffff00" .. match .. "|r"
        end)
    end

    return result
end

function AddFilteredMessage(author, message, timestamp, guid)
    if SimpleFindPartyDB.blockedUsers and SimpleFindPartyDB.blockedUsers[author] then
        return
    end

    -- Filter out messages with 5 or fewer characters
    if string.len(message) <= 5 then
        return
    end

    -- Filter out phase-related messages
    local lowerMessage = string.lower(message)
    if string.find(lowerMessage, "일위상", 1, true) or
       string.find(lowerMessage, "이위상", 1, true) or
       string.find(lowerMessage, "삼위상", 1, true) then
        return
    end

    -- Process quest links - remove all brackets and parentheses, keep only quest name
    -- [[27D]격노(378)] -> 격노
    -- [[50+] 고대의 알] -> 고대의 알
    -- [뾰족부리 구출 (2994)] -> 뾰족부리 구출

    -- First, handle double bracket format: [[anything] quest name (number)]
    message = string.gsub(message, "%[%[[^%]]+%]%s*([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")
    -- Handle double bracket format without parentheses: [[anything] quest name]
    message = string.gsub(message, "%[%[[^%]]+%]%s*([^%[%]]+)%]", "%1")
    -- Handle single bracket with parentheses: [quest name (number)]
    message = string.gsub(message, "%[([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")

    -- Trim any extra spaces from quest names
    message = string.gsub(message, "(%S)%s+(%S)", "%1 %2")

    -- Always remove old message from same author (only keep latest)
    for i, msg in ipairs(SimpleFindPartyFilteredMessages) do
        if msg.author == author then
            table.remove(SimpleFindPartyFilteredMessages, i)
            break
        end
    end

    table.insert(SimpleFindPartyFilteredMessages, 1, {
        author = author,
        message = message,
        timestamp = timestamp or time(),
        highlighted = HighlightKeywords(message),
        guid = guid
    })

    if table.getn(SimpleFindPartyFilteredMessages) > 50 then
        table.remove(SimpleFindPartyFilteredMessages, 51)
    end

    -- Play sound if enabled and message was filtered by keywords
    if SimpleFindPartyDB.soundEnabled and table.getn(SimpleFindPartyFilterKeywords) > 0 then
        -- Play custom ring.wav sound file
        PlaySoundFile("Interface\\AddOns\\SimpleFindParty\\ring.wav")
    end

    RefreshMessageDisplay()
end

function RemoveFilteredMessage(index)
    if SimpleFindPartyFilteredMessages[index] then
        table.remove(SimpleFindPartyFilteredMessages, index)
        RefreshMessageDisplay()
    end
end

function BlockUser(username)
    if not SimpleFindPartyDB.blockedUsers then
        SimpleFindPartyDB.blockedUsers = {}
    end

    SimpleFindPartyDB.blockedUsers[username] = true

    for i = table.getn(SimpleFindPartyFilteredMessages), 1, -1 do
        if SimpleFindPartyFilteredMessages[i].author == username then
            table.remove(SimpleFindPartyFilteredMessages, i)
        end
    end

    RefreshMessageDisplay()

    if SimpleFindPartySettingsFrame and SimpleFindPartySettingsFrame:IsShown() then
        SimpleFindPartySettingsFrame.RefreshBlockedList()
    end
end