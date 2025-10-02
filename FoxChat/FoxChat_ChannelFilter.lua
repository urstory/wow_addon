local addonName, addon = ...

-- 채널별 필터링 로직 모듈
local ChannelFilter = {}
addon.ChannelFilter = ChannelFilter

-- 채널 타입을 필터 키로 매핑
local function GetFilterKey(channelType, channelName)
    -- LFG 채널 디버그 출력 (간소화)
    --[[
    if channelType == "CHANNEL" and channelName then
        print(string.format("|cFFFFFF00[GetFilterKey DEBUG]|r Type: %s, Name: %s",
            channelType or "nil",
            channelName or "nil"))

        -- LFG 채널 매칭 테스트
        local isLFG_EN = string.find(channelName, "LookingForGroup") ~= nil
        local isLFG_KR = string.find(channelName, "파티찾기") ~= nil
        print(string.format("|cFFFFFF00[GetFilterKey DEBUG]|r LFG 매칭 - EN: %s, KR: %s",
            tostring(isLFG_EN), tostring(isLFG_KR)))
    end
    --]]

    if channelType == "GUILD" or channelType == "OFFICER" then
        return "GUILD"
    elseif channelType == "PARTY" or channelType == "PARTY_LEADER" or
           channelType == "RAID" or channelType == "RAID_LEADER" or
           channelType == "RAID_WARNING" or channelType == "INSTANCE_CHAT" then
        return "PARTY"
    elseif channelType == "CHANNEL" and channelName then
        -- LFG 채널 체크 (영어 및 한국어)
        if string.find(channelName, "LookingForGroup") or string.find(channelName, "파티찾기") then
            return "LFG"
        -- 거래 채널 체크 (영어 및 한국어)
        elseif string.find(channelName, "Trade") or string.find(channelName, "거래") then
            return "TRADE"
        else
            -- 다른 채널은 공개(SAY)로 처리
            return "SAY"
        end
    elseif channelType == "SAY" or channelType == "YELL" then
        return "SAY"
    end
    -- WHISPER, LOOT, SYSTEM 등은 nil 반환 (필터링 대상 아님)
    return nil
end

-- 채널별 필터링이 활성화되어 있는지 확인
function ChannelFilter:IsChannelEnabled(channelType, channelName)
    local filterKey = GetFilterKey(channelType, channelName)

    -- LFG 채널에 대한 기본 설정이 없으면 생성 (디버그 제거)
    if filterKey == "LFG" then
        if FoxChatDB and not FoxChatDB.channelFilters then
            FoxChatDB.channelFilters = {}
        end

        if FoxChatDB and FoxChatDB.channelFilters and not FoxChatDB.channelFilters.LFG then
            FoxChatDB.channelFilters.LFG = {
                enabled = true,
                keywords = "",
                ignoreKeywords = ""
            }
        end
    end

    if not filterKey then
        return false
    end

    -- 전체 필터링이 비활성화면 false
    if not FoxChatDB or not FoxChatDB.filterEnabled then
        return false
    end

    -- 새로운 채널별 필터 구조 확인
    if FoxChatDB.channelFilters and FoxChatDB.channelFilters[filterKey] then
        return FoxChatDB.channelFilters[filterKey].enabled
    end

    -- 기존 구조 폴백 (하위 호환성)
    if filterKey == "GUILD" and FoxChatDB.channelGroups then
        return FoxChatDB.channelGroups.GUILD
    elseif filterKey == "SAY" and FoxChatDB.channelGroups then
        return FoxChatDB.channelGroups.PUBLIC
    elseif filterKey == "PARTY" and FoxChatDB.channelGroups then
        return FoxChatDB.channelGroups.PARTY_RAID
    elseif filterKey == "LFG" and FoxChatDB.channelGroups then
        return FoxChatDB.channelGroups.LFG
    end

    return false
end

-- 채널별 키워드 가져오기
function ChannelFilter:GetKeywords(channelType, channelName)
    local filterKey = GetFilterKey(channelType, channelName)
    if not filterKey then
        return {}
    end

    local keywordTable = {}

    -- LFG 채널 키워드 디버그 (간소화)

    -- 새로운 채널별 필터 구조에서 키워드 가져오기
    if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[filterKey] then
        local keywordString = FoxChatDB.channelFilters[filterKey].keywords
        if keywordString and keywordString ~= "" then
            -- 쉼표로 구분된 키워드를 테이블로 변환
            for keyword in string.gmatch(keywordString, "[^,]+") do
                keyword = string.trim(keyword)
                if keyword ~= "" then
                    -- 대소문자 구분 없이 저장
                    keywordTable[string.lower(keyword)] = keyword
                end
            end

            -- 디버그 제거
        end
    end

    -- 키워드가 없으면 기존 전역 키워드 사용 (하위 호환성)
    if next(keywordTable) == nil and FoxChatDB and FoxChatDB.keywords then
        if type(FoxChatDB.keywords) == "table" then
            for _, keyword in ipairs(FoxChatDB.keywords) do
                if keyword and keyword ~= "" then
                    local trimmed = string.trim(keyword)
                    if trimmed ~= "" then
                        keywordTable[string.lower(trimmed)] = trimmed
                    end
                end
            end
        elseif type(FoxChatDB.keywords) == "string" then
            for keyword in string.gmatch(FoxChatDB.keywords, "[^,]+") do
                keyword = string.trim(keyword)
                if keyword ~= "" then
                    keywordTable[string.lower(keyword)] = keyword
                end
            end
        end

    end

    -- 키워드 디버그 (간소화)
    if debugMode and channelType == "CHANNEL" and filterKey == "LFG" then
        local count = 0
        for _ in pairs(keywordTable) do count = count + 1 end
        if count > 0 then
            print(string.format("|cFFFF8000[GetKeywords]|r LFG %d개 키워드 로드됨", count))
        end
    end

    return keywordTable
end

-- 채널별 무시 키워드 가져오기
function ChannelFilter:GetIgnoreKeywords(channelType, channelName)
    local filterKey = GetFilterKey(channelType, channelName)
    if not filterKey then
        return {}
    end

    local ignoreTable = {}

    -- 새로운 채널별 필터 구조에서 무시 키워드 가져오기
    if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters[filterKey] then
        local ignoreString = FoxChatDB.channelFilters[filterKey].ignoreKeywords
        if ignoreString and ignoreString ~= "" then
            -- 쉼표로 구분된 키워드를 테이블로 변환
            for keyword in string.gmatch(ignoreString, "[^,]+") do
                keyword = string.trim(keyword)
                if keyword ~= "" then
                    -- 대소문자 구분 없이 저장
                    ignoreTable[string.lower(keyword)] = keyword
                end
            end
        end
    end

    -- 무시 키워드가 없으면 기존 전역 무시 키워드 사용 (하위 호환성)
    if next(ignoreTable) == nil and FoxChatDB and FoxChatDB.ignoreKeywords then
        if type(FoxChatDB.ignoreKeywords) == "table" then
            for _, keyword in ipairs(FoxChatDB.ignoreKeywords) do
                if keyword and keyword ~= "" then
                    local trimmed = string.trim(keyword)
                    if trimmed ~= "" then
                        ignoreTable[string.lower(trimmed)] = trimmed
                    end
                end
            end
        elseif type(FoxChatDB.ignoreKeywords) == "string" then
            for keyword in string.gmatch(FoxChatDB.ignoreKeywords, "[^,]+") do
                keyword = string.trim(keyword)
                if keyword ~= "" then
                    ignoreTable[string.lower(keyword)] = keyword
                end
            end
        end
    end

    return ignoreTable
end

-- 메시지 필터링 검사
function ChannelFilter:ShouldFilter(message, channelType, channelName)
    -- 채널이 활성화되어 있는지 확인
    if not self:IsChannelEnabled(channelType, channelName) then
        return false, nil
    end

    -- 메시지가 없으면 필터링 안 함
    if not message or message == "" then
        return false, nil
    end

    -- 소문자로 변환하여 검색
    local lowerMessage = string.lower(message)

    -- LFG 채널 디버그 (간소화)

    -- 무시 키워드 확인
    local ignoreKeywords = self:GetIgnoreKeywords(channelType, channelName)
    for lowerKeyword, _ in pairs(ignoreKeywords) do
        if string.find(lowerMessage, lowerKeyword, 1, true) then
            return false, nil  -- 무시 키워드가 있으면 필터링하지 않음
        end
    end

    -- 필터 키워드 확인
    local keywords = self:GetKeywords(channelType, channelName)

    -- "수도원" 특별 체크
    if debugMode and string.find(lowerMessage, "수도원") then
        print("|cFF00FF00[ShouldFilter]|r 메시지에 '수도원' 발견!")
        local hasKeyword = false
        for k, v in pairs(keywords) do
            if k == "수도원" or v == "수도원" then
                hasKeyword = true
                print(string.format("|cFF00FF00[ShouldFilter]|r 키워드 리스트에 '수도원' 있음: k='%s', v='%s'", k, v))
                break
            end
        end
        if not hasKeyword then
            print("|cFFFF0000[ShouldFilter]|r 키워드 리스트에 '수도원' 없음!")
        end
    end

    -- 모든 키워드 순회하며 체크
    for lowerKeyword, originalKeyword in pairs(keywords) do
        -- 한글의 경우 lower가 동작하지 않으므로 원본 키워드로도 검색
        local matchPos = string.find(lowerMessage, lowerKeyword, 1, true)
        if not matchPos then
            -- 원본 키워드로 다시 검색 (한글 등 대소문자 구분이 없는 문자)
            matchPos = string.find(message, originalKeyword, 1, true)
        end

        if matchPos then
            if debugMode then
                print(string.format("|cFF00FF00[ShouldFilter]|r 키워드 매치! '%s'", originalKeyword))
            end
            return true, originalKeyword  -- 키워드 찾음
        end
    end

    return false, nil
end

-- 채널 그룹 가져오기 (색상 등에 사용)
function ChannelFilter:GetChannelGroup(channelType, channelName)
    local filterKey = GetFilterKey(channelType, channelName)

    -- 필터 키를 기존 그룹 이름으로 매핑
    local groupMapping = {
        GUILD = "GUILD",
        SAY = "PUBLIC",
        PARTY = "PARTY_RAID",
        LFG = "LFG",
        TRADE = "TRADE"
    }

    local result = groupMapping[filterKey]

    -- 디버그는 비활성화 (너무 자주 호출됨)
    --[[
    if debugMode and channelType == "CHANNEL" then
        print(string.format("|cFF00FFFF[GetChannelGroup]|r Type: %s, Name: %s -> %s",
            channelType or "nil", channelName or "nil", result or "nil"))
    end
    --]]

    return result
end

-- 디버그용: 현재 설정 출력
function ChannelFilter:DebugPrint()
    if not FoxChatDB then
        print("|cFFFF0000[ChannelFilter]|r FoxChatDB가 없습니다")
        return
    end

    print("|cFF00FF00[ChannelFilter]|r 현재 설정:")
    print("  전체 필터링:", FoxChatDB.filterEnabled and "활성화" or "비활성화")

    if FoxChatDB.channelFilters then
        print("  채널별 필터:")
        for channel, settings in pairs(FoxChatDB.channelFilters) do
            print(string.format("    %s: %s, 키워드 수: %d, 무시 키워드 수: %d",
                channel,
                settings.enabled and "O" or "X",
                settings.keywords and #string.gsub(settings.keywords, "[^,]+", "") + 1 or 0,
                settings.ignoreKeywords and #string.gsub(settings.ignoreKeywords, "[^,]+", "") + 1 or 0
            ))
        end
    else
        print("  채널별 필터 설정이 없습니다 (기존 방식 사용)")
    end
end

return ChannelFilter