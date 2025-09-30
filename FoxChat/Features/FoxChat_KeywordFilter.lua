local addonName, addon = ...

-- 키워드 필터링 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.KeywordFilter = {}

local KeywordFilter = FoxChat.Features.KeywordFilter
local L = addon.L

-- 키워드 저장 테이블
local keywords = {}
local ignoreKeywords = {}

-- 초기화
function KeywordFilter:Initialize()
    -- 키워드 업데이트
    self:UpdateKeywords()
    self:UpdateIgnoreKeywords()

    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            self:UpdateKeywords()
            self:UpdateIgnoreKeywords()
        end)

        FoxChat.Events:Register("FOXCHAT_KEYWORDS_UPDATE", function()
            self:UpdateKeywords()
        end)

        FoxChat.Events:Register("FOXCHAT_IGNORE_KEYWORDS_UPDATE", function()
            self:UpdateIgnoreKeywords()
        end)
    end

    FoxChat:Debug("KeywordFilter 모듈 초기화 완료")
end

-- 키워드 파싱
function KeywordFilter:ParseKeywords(keywordData, targetTable)
    wipe(targetTable)
    if not keywordData then
        return
    end

    -- 테이블인 경우
    if type(keywordData) == "table" then
        for _, keyword in ipairs(keywordData) do
            if keyword and keyword ~= "" then
                -- 앞뒤 공백 제거
                local trimmed = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
                if trimmed ~= "" then
                    -- 대소문자 구분 없이 저장
                    targetTable[string.lower(trimmed)] = trimmed
                end
            end
        end
    -- 문자열인 경우
    elseif type(keywordData) == "string" and keywordData ~= "" then
        -- 쉼표로 분리하고 공백 제거
        for keyword in string.gmatch(keywordData, "[^,]+") do
            keyword = string.trim(keyword)
            if keyword ~= "" then
                -- 대소문자 구분 없이 저장
                targetTable[string.lower(keyword)] = keyword
            end
        end
    end
end

-- 키워드 업데이트
function KeywordFilter:UpdateKeywords()
    if FoxChatDB and FoxChatDB.keywords then
        self:ParseKeywords(FoxChatDB.keywords, keywords)
    else
        -- 기본 키워드 설정
        if L and L["DEFAULT_KEYWORDS"] then
            self:ParseKeywords(L["DEFAULT_KEYWORDS"], keywords)
        end
    end

    -- 디버그: 키워드 개수 출력
    local count = 0
    for _ in pairs(keywords) do count = count + 1 end
    FoxChat:Debug("키워드 업데이트됨:", count, "개")
end

-- 무시 키워드 업데이트
function KeywordFilter:UpdateIgnoreKeywords()
    if FoxChatDB and FoxChatDB.ignoreKeywords then
        self:ParseKeywords(FoxChatDB.ignoreKeywords, ignoreKeywords)
    end

    -- 디버그: 무시 키워드 개수 출력
    local count = 0
    for _ in pairs(ignoreKeywords) do count = count + 1 end
    FoxChat:Debug("무시 키워드 업데이트됨:", count, "개")
end

-- 채널 그룹 판별
function KeywordFilter:GetChannelGroup(channelType, channelName)
    if channelType == "GUILD" or channelType == "OFFICER" then
        return "GUILD"
    elseif channelType == "SAY" or channelType == "YELL" or channelType == "EMOTE" then
        return "PUBLIC"
    elseif channelType == "PARTY" or channelType == "PARTY_LEADER" or
           channelType == "RAID" or channelType == "RAID_LEADER" or
           channelType == "RAID_WARNING" or channelType == "INSTANCE_CHAT" then
        return "PARTY_RAID"
    elseif channelType == "CHANNEL" then
        if channelName then
            local lowerName = string.lower(channelName)
            if string.find(lowerName, "파티찾기") or
               string.find(lowerName, "lookingforgroup") or
               string.find(lowerName, "lfg") then
                return "LFG"
            elseif string.find(lowerName, "일반") or
                   string.find(lowerName, "general") then
                return "PUBLIC"
            elseif string.find(lowerName, "거래") or
                   string.find(lowerName, "trade") then
                return "PUBLIC"
            elseif string.find(lowerName, "지역 방어") or
                   string.find(lowerName, "localdefense") then
                return "PUBLIC"
            end
        end
        return nil
    end
    return nil
end

-- 퀘스트 링크 정리
function KeywordFilter:CleanQuestLinks(message)
    -- [[27D]격노(378)] -> 격노
    -- [[50+] 고대의 알] -> 고대의 알
    -- [뾰족부리 구출 (2994)] -> 뾰족부리 구출

    -- 더블 브라켓 형식: [[anything] quest name (number)]
    message = string.gsub(message, "%[%[[^%]]+%]%s*([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")
    -- 더블 브라켓 형식 (괄호 없음): [[anything] quest name]
    message = string.gsub(message, "%[%[[^%]]+%]%s*([^%[%]]+)%]", "%1")
    -- 싱글 브라켓 형식: [quest name (number)]
    message = string.gsub(message, "%[([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")

    -- 여분의 공백 정리
    message = string.gsub(message, "(%S)%s+(%S)", "%1 %2")

    return message
end

-- 메시지에서 플레이어 이름 부분 분리
function KeywordFilter:SplitMessage(message)
    local prefix, msgContent = "", message
    local colonPos = nil

    -- |h] 다음에 오는 |h: 패턴 찾기
    local linkEnd = string.find(message, "|h%]|h:", 1, false)
    if linkEnd then
        colonPos = linkEnd + 5
    else
        -- |h 다음의 콜론 찾기
        local hPos = string.find(message, "|h:", 1, false)
        if hPos then
            colonPos = hPos + 2
        else
            -- 링크가 없는 경우 [이름]: 형태 찾기
            local bracketPos = string.find(message, "%]:", 1, false)
            if bracketPos then
                colonPos = bracketPos + 1
            else
                -- 첫 번째 콜론 찾기
                colonPos = string.find(message, ":", 1, true)
            end
        end
    end

    if colonPos then
        prefix = string.sub(message, 1, colonPos)
        msgContent = string.sub(message, colonPos + 1)
    end

    return prefix, msgContent
end

-- 말머리/말꼬리 제거
function KeywordFilter:RemovePrefixSuffix(message)
    if not FoxChatDB or not FoxChatDB.prefixSuffixEnabled then
        return message
    end

    local myPrefix = FoxChatDB.prefix or ""
    local mySuffix = FoxChatDB.suffix or ""
    local result = message

    -- 말머리 제거
    if myPrefix ~= "" then
        local trimmedMsg = string.gsub(result, "^%s*", "")
        if string.sub(trimmedMsg, 1, string.len(myPrefix)) == myPrefix then
            result = string.sub(trimmedMsg, string.len(myPrefix) + 1)
            result = string.gsub(result, "^%s*", "")
        end
    end

    -- 말꼬리 제거
    if mySuffix ~= "" then
        local trimmedMsg = string.gsub(result, "%s*$", "")
        if string.sub(trimmedMsg, -string.len(mySuffix)) == mySuffix then
            result = string.sub(trimmedMsg, 1, -string.len(mySuffix) - 1)
            result = string.gsub(result, "%s*$", "")
        end
    end

    return result
end

-- 키워드 하이라이트
function KeywordFilter:HighlightKeywords(message, channelGroup, author)
    if not FoxChatDB then
        return message, false
    end

    -- 필터링 비활성화 상태
    if not FoxChatDB.enabled or not FoxChatDB.filterEnabled then
        return message, false
    end

    -- 채널 그룹이 비활성화 상태
    if not channelGroup or (FoxChatDB.channelGroups and not FoxChatDB.channelGroups[channelGroup]) then
        return message, false
    end

    -- 퀘스트 링크 정리
    message = self:CleanQuestLinks(message)

    -- 메시지 분리
    local prefix, msgContent = self:SplitMessage(message)

    -- 본인이 쓴 메시지는 필터링하지 않음
    local myName = UnitName("player")
    if author then
        local authorClean = string.gsub(author, "%-[^%-]+$", "")
        if string.lower(authorClean) == string.lower(myName) then
            return message, false
        end
    end

    -- 무시 키워드 체크 - 작성자
    if author then
        local authorLower = string.lower(author)
        local authorClean = string.gsub(authorLower, "%-[^%-]+$", "")

        for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
            if lowerIgnore == authorLower or lowerIgnore == authorClean then
                return message, false
            end
        end
    end

    -- 말머리/말꼬리 제거하여 체크
    local msgContentForCheck = self:RemovePrefixSuffix(msgContent)
    local lowerMsgContent = string.lower(msgContentForCheck)

    -- 무시 키워드 체크 - 메시지 내용
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if string.find(lowerMsgContent, lowerIgnore, 1, true) then
            FoxChat:Debug("무시할 문구 발견:", originalIgnore)
            return message, false
        end
    end

    -- 키워드 하이라이트
    local foundKeyword = false
    for lowerKeyword, originalKeyword in pairs(keywords) do
        if string.find(lowerMsgContent, lowerKeyword, 1, true) then
            FoxChat:Debug("키워드 매칭:", originalKeyword)
            foundKeyword = true

            -- 하이라이트 처리
            local pattern = "(" .. string.gsub(originalKeyword, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. ")"
            local replacement = ""

            -- 색상 가져오기
            local color = nil
            if FoxChatDB.highlightColors and FoxChatDB.highlightColors[channelGroup] then
                color = FoxChatDB.highlightColors[channelGroup]
            else
                -- 기본 색상
                local defaultColors = {
                    GUILD = {r = 0, g = 1, b = 0},
                    PUBLIC = {r = 1, g = 1, b = 0},
                    PARTY_RAID = {r = 0, g = 0.5, b = 1},
                    LFG = {r = 1, g = 0.5, b = 0}
                }
                color = defaultColors[channelGroup] or {r = 1, g = 1, b = 1}
            end

            local colorCode = string.format("|cff%02x%02x%02x",
                math.floor(color.r * 255),
                math.floor(color.g * 255),
                math.floor(color.b * 255))

            -- 하이라이트 스타일
            local style = FoxChatDB.highlightStyle or "both"
            if style == "bold" then
                replacement = "|cffffffff%1|r"
            elseif style == "color" then
                replacement = colorCode .. "%1|r"
            else -- both
                replacement = "|cffffffff" .. colorCode .. "%1|r|r"
            end

            -- 대소문자 구분 없이 치환
            local function replacer(match)
                return string.gsub(replacement, "%%1", match)
            end
            msgContent = string.gsub(msgContent, pattern, replacer)
        end
    end

    return prefix .. msgContent, foundKeyword
end

-- 키워드 추가
function KeywordFilter:AddKeyword(keyword)
    if not keyword or keyword == "" then
        return false
    end

    keyword = string.trim(keyword)
    keywords[string.lower(keyword)] = keyword

    -- DB에 저장
    if FoxChatDB then
        if type(FoxChatDB.keywords) == "table" then
            table.insert(FoxChatDB.keywords, keyword)
        else
            FoxChatDB.keywords = (FoxChatDB.keywords or "") .. "," .. keyword
        end
    end

    return true
end

-- 키워드 제거
function KeywordFilter:RemoveKeyword(keyword)
    if not keyword or keyword == "" then
        return false
    end

    keyword = string.trim(keyword)
    keywords[string.lower(keyword)] = nil

    -- DB에서 제거
    if FoxChatDB then
        if type(FoxChatDB.keywords) == "table" then
            for i, k in ipairs(FoxChatDB.keywords) do
                if string.lower(k) == string.lower(keyword) then
                    table.remove(FoxChatDB.keywords, i)
                    break
                end
            end
        else
            local newKeywords = {}
            for k in string.gmatch(FoxChatDB.keywords or "", "[^,]+") do
                k = string.trim(k)
                if string.lower(k) ~= string.lower(keyword) then
                    table.insert(newKeywords, k)
                end
            end
            FoxChatDB.keywords = table.concat(newKeywords, ",")
        end
    end

    return true
end

-- 키워드 목록
function KeywordFilter:GetKeywords()
    local list = {}
    for _, keyword in pairs(keywords) do
        table.insert(list, keyword)
    end
    return list
end

-- 무시 키워드 목록
function KeywordFilter:GetIgnoreKeywords()
    local list = {}
    for _, keyword in pairs(ignoreKeywords) do
        table.insert(list, keyword)
    end
    return list
end