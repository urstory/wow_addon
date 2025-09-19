local addonName, addon = ...
local L = addon.L

-- 기본 설정값
local defaults = {
    enabled = true,  -- 전체 활성화 (미니맵 버튼용으로만 사용)
    filterEnabled = true,  -- 채팅 필터링 기능 활성화
    prefixSuffixEnabled = true,  -- 말머리/말꼬리 기능 활성화
    keywords = nil,  -- 나중에 지역화된 값으로 설정
    ignoreKeywords = "",  -- 무시할 문구
    playSound = true,
    soundVolume = 0.5,
    highlightColors = {
        GUILD = {r = 0, g = 1, b = 0}, -- 길드: 초록색
        PUBLIC = {r = 1, g = 1, b = 0}, -- 공개: 노란색
        PARTY_RAID = {r = 0, g = 0.5, b = 1}, -- 파티/공격대: 파란색
        LFG = {r = 1, g = 0.5, b = 0}, -- 파티찾기: 주황색
    },
    highlightStyle = "both", -- "bold", "color", "both"
    channelGroups = {
        GUILD = true,
        PUBLIC = true,
        PARTY_RAID = true,
        LFG = true,
    },
    prefix = "",  -- 말머리
    suffix = "",  -- 말꼬리
    prefixSuffixChannels = {
        SAY = true,
        YELL = false,
        PARTY = true,
        GUILD = true,
        RAID = true,
        INSTANCE_CHAT = true,
        WHISPER = false,
        CHANNEL = false,
    },
    minimapButton = {
        hide = false,
        minimapPos = 45,
        radius = 80,  -- 미니맵 테두리까지의 거리
    },
    toastPosition = {
        x = 0,  -- X축 오프셋 (0 = 중앙)
        y = -320,  -- Y축 오프셋 (기본값 -320)
    }
}

-- 키워드 테이블 (빠른 검색을 위해)
local keywords = {}
local ignoreKeywords = {}

-- 디버그 모드
local debugMode = false

-- 원본 AddMessage 함수들을 저장
local originalAddMessage = {}
local originalSendChatMessage = SendChatMessage

-- 토스트 알림 시스템
local activeToasts = {}  -- 현재 활성화된 토스트 목록
local toastPool = {}     -- 재사용 가능한 토스트 프레임 풀
local authorCooldowns = {}  -- 사용자별 쿨다운 추적
local MAX_TOASTS = 3    -- 최대 토스트 개수
local ShowToast  -- forward declaration

-- 키워드 파싱 함수
local function ParseKeywords(keywordString, targetTable)
    wipe(targetTable)
    if not keywordString or keywordString == "" then
        return
    end

    -- 쉼표로 분리하고 공백 제거
    for keyword in string.gmatch(keywordString, "[^,]+") do
        keyword = string.trim(keyword)
        if keyword ~= "" then
            -- 대소문자 구분 없이 저장
            targetTable[string.lower(keyword)] = keyword
        end
    end
end

-- 필터링 키워드 업데이트
local function UpdateKeywords()
    ParseKeywords(FoxChatDB.keywords, keywords)
end

-- 무시 키워드 업데이트
local function UpdateIgnoreKeywords()
    ParseKeywords(FoxChatDB.ignoreKeywords, ignoreKeywords)
end

-- 활성화된 토스트들의 위치를 재정렬
local function RepositionToasts()
    local xOffset = FoxChatDB.toastPosition and FoxChatDB.toastPosition.x or 0
    local baseYOffset = FoxChatDB.toastPosition and FoxChatDB.toastPosition.y or -320

    for i, f in ipairs(activeToasts) do
        f:ClearAllPoints()
        -- 첫 번째 토스트는 설정된 위치에, 나머지는 위로 쌓임
        local yOffset = baseYOffset + ((i - 1) * (f:GetHeight() + 5))
        f:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    end
end

-- 토스트 프레임을 풀에서 가져오거나 새로 생성
local function GetToastFrame()
    local f = table.remove(toastPool)
    if f then
        return f
    end

    -- 새 프레임 생성
    local f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    f:SetWidth(450)  -- 고정 너비, 높이는 동적으로 조정
    local xOffset = FoxChatDB.toastPosition and FoxChatDB.toastPosition.x or 0
    local yOffset = FoxChatDB.toastPosition and FoxChatDB.toastPosition.y or -320
    f:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:Hide()
    f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp")

    -- 배경
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.8)

    -- 테두리 (BackdropTemplate이 있는 경우에만)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    -- 작성자 텍스트
    f.author = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.author:SetPoint("TOPLEFT", 15, -10)
    f.author:SetPoint("TOPRIGHT", -15, -10)
    f.author:SetJustifyH("LEFT")
    f.author:SetWordWrap(false)

    -- 메시지 텍스트
    f.message = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.message:SetPoint("TOPLEFT", f.author, "BOTTOMLEFT", 0, -5)
    f.message:SetPoint("TOPRIGHT", f.author, "BOTTOMRIGHT", 0, -5)
    f.message:SetJustifyH("LEFT")
    f.message:SetJustifyV("TOP")
    f.message:SetTextColor(1, 1, 1)
    f.message:SetWordWrap(true)
    f.message:SetMaxLines(4)  -- 최대 4줄까지 표시

    -- 애니메이션 그룹
    f.animIn = f:CreateAnimationGroup()
    local fadeIn = f.animIn:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3)
    fadeIn:SetSmoothing("OUT")

    f.animOut = f:CreateAnimationGroup()
    local fadeOut = f.animOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.5)
    fadeOut:SetSmoothing("IN")
    fadeOut:SetStartDelay(3)  -- 3초 대기 후 페이드 아웃

    f.animOut:SetScript("OnFinished", function(self)
        local frame = self:GetParent()
        frame:Hide()
        frame.currentAuthor = nil  -- 현재 저자 초기화

        -- activeToasts에서 제거
        for i, toast in ipairs(activeToasts) do
            if toast == frame then
                table.remove(activeToasts, i)
                break
            end
        end

        -- 프레임을 풀에 반환
        table.insert(toastPool, frame)

        -- 모든 토스트 위치 재정렬
        RepositionToasts()
    end)

    -- 토스트 클릭 시 귓속말 열기
    f:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and self.currentAuthor then
            -- 채팅창에 /w 닉네임 설정
            ChatFrame_OpenChat("/w " .. self.currentAuthor .. " ", DEFAULT_CHAT_FRAME)
        end
    end)

    -- 마우스 오버 시 커서 변경
    f:SetScript("OnEnter", function(self)
        if self.currentAuthor then
            SetCursor("Interface\\Cursor\\Speak")
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("클릭하면 " .. self.currentAuthor .. "님에게 귓속말", 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    f:SetScript("OnLeave", function(self)
        SetCursor(nil)
        GameTooltip:Hide()
    end)

    return f
end

-- 토스트 알림 표시 함수
ShowToast = function(author, message, channelGroup, isTest)
    -- 동일 사용자 쿨다운 체크 (10초) - 테스트인 경우 스킵
    local currentTime = GetTime()
    if not isTest and author and authorCooldowns[author] then
        if currentTime - authorCooldowns[author] < 10 then
            return  -- 10초 이내에 동일 사용자 메시지는 무시
        end
    end

    -- 최대 토스트 개수 체크
    if #activeToasts >= MAX_TOASTS then
        -- 가장 오래된 토스트 제거
        local oldestToast = activeToasts[1]
        if oldestToast and oldestToast.animOut then
            oldestToast.animOut:Stop()
            oldestToast:Hide()
            table.remove(activeToasts, 1)
            table.insert(toastPool, oldestToast)
            RepositionToasts()
        end
    end

    -- 쿨다운 업데이트 (테스트가 아닌 경우에만)
    if not isTest and author then
        authorCooldowns[author] = currentTime
        -- 30초 후에 쿨다운 데이터 제거 (메모리 관리)
        C_Timer.After(30, function()
            if authorCooldowns[author] and GetTime() - authorCooldowns[author] >= 30 then
                authorCooldowns[author] = nil
            end
        end)
    end

    -- 토스트 프레임 가져오기
    local f = GetToastFrame()

    -- 채널별 색상 설정
    local color = (FoxChatDB.highlightColors and FoxChatDB.highlightColors[channelGroup]) or defaults.highlightColors[channelGroup]
    if color then
        f.bg:SetColorTexture(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
        f.author:SetTextColor(color.r, color.g, color.b)
    end

    -- 작성자 설정 (서버명 제거)
    local displayAuthor = author or "Unknown"
    -- "-서버명" 패턴 제거
    displayAuthor = string.gsub(displayAuthor, "%-[^%-]+$", "")
    f.author:SetText(displayAuthor)
    f.currentAuthor = displayAuthor  -- 현재 작성자 저장

    -- 메시지에서 색상 코드 제거
    local cleanMessage = message
    if cleanMessage then
        -- Process quest links - remove all brackets and parentheses, keep only quest name
        -- [[27D]격노(378)] -> 격노
        -- [[50+] 고대의 알] -> 고대의 알
        -- [뾰족부리 구출 (2994)] -> 뾰족부리 구출

        -- First, handle double bracket format: [[anything] quest name (number)]
        cleanMessage = string.gsub(cleanMessage, "%[%[[^%]]+%]%s*([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")
        -- Handle double bracket format without parentheses: [[anything] quest name]
        cleanMessage = string.gsub(cleanMessage, "%[%[[^%]]+%]%s*([^%[%]]+)%]", "%1")
        -- Handle single bracket with parentheses: [quest name (number)]
        cleanMessage = string.gsub(cleanMessage, "%[([^%(%)%[%]]+)%s*%(%d+%)%]", "%1")

        -- Trim any extra spaces from quest names
        cleanMessage = string.gsub(cleanMessage, "(%S)%s+(%S)", "%1 %2")

        cleanMessage = string.gsub(cleanMessage, "|c%x%x%x%x%x%x%x%x", "")
        cleanMessage = string.gsub(cleanMessage, "|r", "")
        cleanMessage = string.gsub(cleanMessage, "|H.-|h(.-)|h", "%1")
        -- 공백 정리
        cleanMessage = string.trim(cleanMessage)
        -- 메시지가 너무 길면 자르기 (여러 줄 고려)
        if string.len(cleanMessage) > 200 then
            cleanMessage = string.sub(cleanMessage, 1, 197) .. "..."
        end
    end
    f.message:SetText(cleanMessage or "")

    -- 프레임 높이 자동 조절
    local messageHeight = f.message:GetStringHeight()
    local totalHeight = 10 + f.author:GetStringHeight() + 5 + messageHeight + 10
    f:SetHeight(math.max(60, totalHeight))

    -- activeToasts에 추가
    table.insert(activeToasts, f)

    -- 모든 토스트 위치 재정렬
    RepositionToasts()

    -- 표시
    f:Show()
    f.animIn:Play()
    f.animOut:Play()
end

-- 채널 타입을 그룹으로 매핑
local function GetChannelGroup(channelType, channelName)
    if channelType == "GUILD" then
        return "GUILD"
    elseif channelType == "PARTY" or channelType == "RAID" or channelType == "INSTANCE_CHAT" or channelType == "RAID_LEADER" or channelType == "RAID_WARNING" then
        return "PARTY_RAID"
    elseif channelType == "CHANNEL" and channelName then
        -- LFG 채널 체크 (영어 및 한국어)
        if string.find(channelName, "LookingForGroup") or string.find(channelName, "파티찾기") then
            return "LFG"
        else
            return "PUBLIC"
        end
    elseif channelType == "SAY" or channelType == "YELL" then
        return "PUBLIC"
    end
    return nil
end

-- 메시지에서 키워드 찾기 및 하이라이트
local function HighlightKeywords(message, channelGroup, author)
    if not FoxChatDB.enabled or not channelGroup then
        return message, false
    end

    -- 해당 채널 그룹이 활성화되어 있는지 확인
    if not FoxChatDB.channelGroups[channelGroup] then
        return message, false
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
    
    -- 채팅 메시지에서 플레이어 이름 부분을 분리
    -- 일반적인 채팅 형식: [채널] [플레이어]: 메시지
    -- 또는: |Hplayer:이름|h[이름]|h: 메시지
    local prefix, msgContent = "", message
    
    -- 플레이어 링크 패턴 찾기: |Hplayer:이름...|h[이름]|h 형태
    local colonPos = nil
    
    -- |h] 다음에 오는 |h: 패턴 찾기
    local linkEnd = string.find(message, "|h%]|h:", 1, false)
    if linkEnd then
        -- "|h]|h:" 패턴의 마지막 콜론 위치
        colonPos = linkEnd + 5
    else
        -- |h 다음의 콜론 찾기 (다른 형태의 링크)
        local hPos = string.find(message, "|h:", 1, false)
        if hPos then
            colonPos = hPos + 2
        else
            -- 링크가 없는 경우 [이름]: 형태 찾기
            local bracketPos = string.find(message, "%]:", 1, false)
            if bracketPos then
                colonPos = bracketPos + 1
            else
                -- 마지막 수단: 첫 번째 콜론 찾기
                colonPos = string.find(message, ":", 1, true)
            end
        end
    end
    
    if colonPos then
        -- 콜론 이전 부분 (플레이어 이름 등)과 이후 부분 (실제 메시지) 분리
        prefix = string.sub(message, 1, colonPos)
        msgContent = string.sub(message, colonPos + 1)
    end
    
    local foundKeyword = false
    local lowerMsgContent = string.lower(msgContent)

    -- 먼저 작성자가 무시 키워드와 일치하는지 확인
    local authorLower = author and string.lower(author) or ""
    -- 서버명 제거 (하이픈 뒤의 모든 내용 제거)
    local authorClean = authorLower
    local hyphenPos = string.find(authorLower, "%-")
    if hyphenPos then
        authorClean = string.sub(authorLower, 1, hyphenPos - 1)
    end

    -- 디버그: 무시 키워드 체크 전 작성자 정보 출력
    if debugMode and author then
        print(string.format("[FoxChat Debug] Checking author: '%s' (clean: '%s') against ignore keywords", authorLower, authorClean))
    end

    -- 작성자 닉네임이 무시 키워드 중 하나와 일치하는지 확인
    -- 일치하면 이 메시지는 전혀 필터링하지 않음
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if debugMode and author then
            if lowerIgnore == authorClean then
                print(string.format("[FoxChat Debug] Author '%s' matches ignore keyword '%s' - NOT filtering", authorClean, originalIgnore))
            end
        end
        if lowerIgnore == authorLower or lowerIgnore == authorClean then
            -- 닉네임이 무시 키워드와 일치하면 필터링하지 않음
            return message, false
        end
    end

    -- 메시지 내용에 무시 키워드가 있는지 체크
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if string.find(lowerMsgContent, lowerIgnore, 1, true) then
            -- 메시지에 무시 키워드가 있으면 필터링하지 않음
            return message, false
        end
    end

    for lowerKeyword, originalKeyword in pairs(keywords) do
        if string.find(lowerMsgContent, lowerKeyword, 1, true) then
            foundKeyword = true
            
            -- 키워드를 하이라이트
            local pattern = "(" .. string.gsub(originalKeyword, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. ")"
            local replacement = ""
            
            local color = (FoxChatDB.highlightColors and FoxChatDB.highlightColors[channelGroup]) or defaults.highlightColors[channelGroup]
            local colorCode = string.format("|cff%02x%02x%02x",
                math.floor(color.r * 255),
                math.floor(color.g * 255),
                math.floor(color.b * 255))
            
            if FoxChatDB.highlightStyle == "bold" then
                replacement = "|cffffffff%1|r"  -- 흰색 굵은 글씨 효과
            elseif FoxChatDB.highlightStyle == "color" then
                replacement = colorCode .. "%1|r"
            else -- both
                replacement = "|cffffffff" .. colorCode .. "%1|r|r"  -- 색상 + 굵게 (흰색 레이어로 굵게 효과)
            end
            
            -- 대소문자 구분 없이 치환 (메시지 내용 부분만)
            local function replacer(match)
                return string.gsub(replacement, "%%1", match)
            end
            msgContent = string.gsub(msgContent, pattern, replacer)
        end
    end
    
    -- 플레이어 이름 부분과 하이라이트된 메시지 부분을 다시 결합
    local result = prefix .. msgContent
    
    return result, foundKeyword
end

-- 채팅 메시지 후킹 함수
local function HookChatFrame(chatFrame)
    if not chatFrame or originalAddMessage[chatFrame] then
        return
    end
    
    originalAddMessage[chatFrame] = chatFrame.AddMessage
    
    chatFrame.AddMessage = function(self, text, r, g, b, ...)
        if text and FoxChatDB.filterEnabled then
            -- 메시지에서 채널 타입 추측
            local channelGroup = nil

            -- 길드 메시지 패턴
            if string.find(text, "|Hchannel:GUILD") or string.find(text, "길드") then
                channelGroup = "GUILD"
            -- 파티/공격대 메시지 패턴
            elseif string.find(text, "|Hchannel:PARTY") or string.find(text, "|Hchannel:RAID") or
                   string.find(text, "파티") or string.find(text, "공격대") then
                channelGroup = "PARTY_RAID"
            -- LFG 채널 패턴
            elseif string.find(text, "LookingForGroup") or string.find(text, "파티찾기") then
                channelGroup = "LFG"
            -- 공개 채널 (기본값)
            else
                channelGroup = "PUBLIC"
            end

            -- 채널 그룹이 활성화되어 있는 경우만 하이라이트
            if channelGroup and FoxChatDB.channelGroups and FoxChatDB.channelGroups[channelGroup] then
                -- 먼저 작성자를 추출
                local author = nil

                -- |Hplayer:이름:서버 패턴에서 이름 추출 (서버명 포함 가능)
                local playerPattern = "|Hplayer:([^|]+)|h%[([^%]]+)%]|h"
                local playerLink, playerDisplay = string.match(text, playerPattern)
                if playerLink then
                    -- playerLink는 "이름" 또는 "이름-서버명" 형태
                    author = playerLink
                    if debugMode then
                        print(string.format("[FoxChat Debug HookChatFrame] Author: '%s'", playerLink))
                    end
                else
                    -- 대체 패턴: |Hplayer:이름 형태
                    local simplePattern = "|Hplayer:([^:|]+)"
                    local simpleName = string.match(text, simplePattern)
                    if simpleName then
                        author = simpleName
                        if debugMode then
                            print(string.format("[FoxChat Debug HookChatFrame] Author: '%s'", simpleName))
                        end
                    else
                        -- [이름] 패턴 찾기
                        local bracketPattern = "%[([^%]]+)%]"
                        local bracketName = string.match(text, bracketPattern)
                        if bracketName and not string.find(bracketName, "파티") and not string.find(bracketName, "공격대") then
                            author = bracketName
                            if debugMode then
                                print(string.format("[FoxChat Debug HookChatFrame] Author: '%s'", bracketName))
                            end
                        else
                            if debugMode then
                                print("[FoxChat Debug HookChatFrame] No author found in message")
                            end
                        end
                    end
                end

                local highlightedText, found = HighlightKeywords(text, channelGroup, author)

                if found then
                    -- 소리 재생 (ring.wav 파일 사용)
                    if FoxChatDB.playSound then
                        PlaySoundFile("Interface\\AddOns\\FoxChat\\ring.wav", "Master")
                    end

                    -- 메시지 내용 추출 (콜론 이후)
                    local msgContent = text
                    local colonPos = string.find(text, ":", 1, true)
                    if colonPos then
                        msgContent = string.sub(text, colonPos + 1)
                    end

                    -- 토스트 알림 표시 (서버명 제거)
                    local cleanAuthor = author or "Unknown"
                    cleanAuthor = string.gsub(cleanAuthor, "%-[^%-]+$", "")
                    ShowToast(cleanAuthor, msgContent, channelGroup)

                    -- 하이라이트된 텍스트 표시
                    originalAddMessage[self](self, highlightedText, r, g, b, ...)
                    return
                end
            end
        end

        originalAddMessage[self](self, text, r, g, b, ...)
    end
end

-- 채팅 이벤트 필터
local function ChatFilter(self, event, msg, author, ...)
    if not FoxChatDB.filterEnabled then
        return false
    end

    -- 디버그: ChatFilter에서 받은 author 출력
    if debugMode and author then
        print(string.format("[FoxChat Debug] Author: '%s'", author))
    end

    -- 채널 확인 및 그룹 결정
    local channelType = event:match("CHAT_MSG_(.+)")
    local channelName = select(7, ...) -- 채널 이름 (번호 채널용)
    local channelGroup = GetChannelGroup(channelType, channelName)

    if not channelGroup or not FoxChatDB.channelGroups[channelGroup] then
        return false
    end

    -- 키워드 검색 및 하이라이트
    local highlightedMsg, found = HighlightKeywords(msg, channelGroup, author)

    if found then
        -- 소리 재생
        if FoxChatDB.playSound and not self.soundPlayed then
            PlaySoundFile("Interface\\AddOns\\FoxChat\\ring.wav", "Master")
            self.soundPlayed = true
            C_Timer.After(0.1, function() self.soundPlayed = false end)
        end

        -- 토스트 알림 표시 (서버명 제거)
        local cleanAuthor = author
        if cleanAuthor then
            cleanAuthor = string.gsub(cleanAuthor, "%-[^%-]+$", "")
        end
        ShowToast(cleanAuthor, msg, channelGroup)

        -- 메시지를 하이라이트된 버전으로 교체
        return false, highlightedMsg, author, ...
    end

    return false  -- 변경 없이 통과
end

-- SendChatMessage 후킹 (말머리/말꼬리)
local function HookSendChatMessage()
    SendChatMessage = function(message, chatType, language, channel)
        if FoxChatDB.prefixSuffixEnabled and message and message ~= "" then
            -- 위상 메시지는 말머리/말꼬리 제외
            local phaseMessages = {"일위상", "이위상", "삼위상"}
            local isPhaseMessage = false
            for _, phase in ipairs(phaseMessages) do
                if message == phase then
                    isPhaseMessage = true
                    break
                end
            end
            
            -- 위상 메시지가 아닌 경우에만 말머리/말꼬리 처리
            if not isPhaseMessage then
                -- 채널 타입 확인
                local channelKey = chatType
                if chatType == "CHANNEL" then
                    channelKey = "CHANNEL"
                elseif chatType == "INSTANCE_CHAT" then
                    channelKey = "INSTANCE_CHAT"
                end
                
                -- 해당 채널에 말머리/말꼬리 적용 여부 확인
                if FoxChatDB.prefixSuffixChannels and FoxChatDB.prefixSuffixChannels[channelKey] then
                    local prefix = FoxChatDB.prefix or ""
                    local suffix = FoxChatDB.suffix or ""
                    
                    -- 말머리와 말꼬리 추가
                    if prefix ~= "" or suffix ~= "" then
                        message = prefix .. message .. suffix
                    end
                end
            end
        end
        
        -- 원본 함수 호출
        originalSendChatMessage(message, chatType, language, channel)
    end
end

-- 미니맵 버튼 생성
local minimapButton = nil
-- FoxChat 전역 테이블 생성
if not _G["FoxChat"] then
    _G["FoxChat"] = {}
end
FoxChat = _G["FoxChat"]

-- 각 모양별 사분면이 원형(true)/각짐(false)인지 표
local MinimapShapes = {
    ["ROUND"]                  = {true,  true,  true,  true },
    ["SQUARE"]                 = {false, false, false, false},
    ["CORNER-TOPLEFT"]         = {false, false, false, true },
    ["CORNER-TOPRIGHT"]        = {false, false, true,  false},
    ["CORNER-BOTTOMLEFT"]      = {false, true,  false, false},
    ["CORNER-BOTTOMRIGHT"]     = {true,  false, false, false},
    ["SIDE-LEFT"]              = {false, true,  false, true },
    ["SIDE-RIGHT"]             = {true,  false, true,  false},
    ["SIDE-TOP"]               = {false, false, true,  true },
    ["SIDE-BOTTOM"]            = {true,  true,  false, false},
    ["TRICORNER-TOPLEFT"]      = {false, true,  true,  true },
    ["TRICORNER-TOPRIGHT"]     = {true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]   = {true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"]  = {true,  true,  true,  false},
}

local function getQuadrant(cx, cy)
    if cx >= 0 then
        return (cy >= 0) and 1 or 4
    else
        return (cy >= 0) and 2 or 3
    end
end

local function getShape()
    local s = GetMinimapShape and GetMinimapShape()
    return s or "ROUND"
end

local function CreateMinimapButton()
    if minimapButton then return end

    -- 미니맵 버튼 프레임
    minimapButton = CreateFrame("Button", "FoxChatMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 버튼 아이콘 (중앙의 오렌지색 원)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    icon:SetVertexColor(1, 0.5, 0, 0.9)

    -- FC 텍스트 라벨 (버튼 정중앙에)
    local fcText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fcText:SetText("|cFFFFFFFFFC|r")
    fcText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    fcText:SetJustifyH("CENTER")
    fcText:SetJustifyV("MIDDLE")
    fcText:SetPoint("CENTER", 0, -1)

    -- 방법 B: 대칭 원형 링 텍스처 사용 (정중앙 정렬)
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("CENTER", 0, 0)
    border:SetSize(28, 28)  -- 아이콘 18 기준 적당한 링 두께
    border:SetVertexColor(1, 0.9, 0.6, 1)  -- 금색 테두리

    -- 미니맵 위치 업데이트 (모양 인식 + 가장자리 투영)
    local function UpdateMinimapPosition()
        if not FoxChatDB.minimapButton then
            FoxChatDB.minimapButton = defaults.minimapButton
        end

        if FoxChatDB.minimapButton.hide then
            minimapButton:Hide()
            return
        else
            minimapButton:Show()
        end

        local angle = math.rad(FoxChatDB.minimapButton.minimapPos or 45)
        local padding = 6  -- 미니맵 테두리로부터의 여유 공간

        -- 반지름: 미니맵 절반 + 여유 패딩
        local r = (Minimap:GetWidth() / 2) + padding

        -- 방향 벡터
        local dx, dy = math.cos(angle), math.sin(angle)

        -- 현재 모양과 사분면 판정
        local shape = getShape()
        local quad = getQuadrant(dx, dy)
        local round = MinimapShapes[shape] and MinimapShapes[shape][quad]

        local factor
        if round == nil or round == true then
            -- 원형 가장자리: 반지름 그대로
            factor = r
        else
            -- 정사각형/변/코너: 정사각형 경계로 투영
            -- 경계와 만나는 지점까지 스케일링
            local maxc = math.max(math.abs(dx), math.abs(dy))
            factor = r / (maxc > 0 and maxc or 1e-6)
        end

        local x, y = dx * factor, dy * factor

        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- 드래그 기능
    minimapButton:RegisterForDrag("LeftButton", "RightButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            
            local angle = math.deg(math.atan2(py - my, px - mx))
            if not FoxChatDB.minimapButton then
                FoxChatDB.minimapButton = defaults.minimapButton
            end
            FoxChatDB.minimapButton.minimapPos = angle
            UpdateMinimapPosition()
        end)
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    -- 클릭 이벤트
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            FoxChat:Toggle()
            -- 툴팁이 표시 중이면 즉시 업데이트
            if GameTooltip:IsVisible() and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
                self:GetScript("OnEnter")(self)
            end
        elseif button == "RightButton" then
            FoxChat:OpenConfig()
        end
    end)
    
    -- 툴팁
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("FoxChat", 1, 1, 1)
        if FoxChatDB.filterEnabled then
            GameTooltip:AddLine(L["FILTER_STATUS_ENABLED"], 0, 1, 0)
        else
            GameTooltip:AddLine(L["FILTER_STATUS_DISABLED"], 1, 0, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["LEFT_CLICK_TOGGLE_FILTER"], 1, 1, 1)
        GameTooltip:AddLine(L["RIGHT_CLICK_CONFIG"], 1, 1, 1)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 주기적으로 미니맵 모양 체크 (Classic에는 MINIMAP_UPDATE_SHAPE 이벤트가 없음)
    local lastShape = nil
    minimapButton:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer > 1 then  -- 1초마다 체크
            self.timer = 0
            local currentShape = getShape()
            if currentShape ~= lastShape then
                lastShape = currentShape
                UpdateMinimapPosition()
            end
        end
    end)

    UpdateMinimapPosition()
end

-- 초기화
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 지역화된 기본 키워드 설정
        defaults.keywords = L["DEFAULT_KEYWORDS"]
        
        -- 설정 로드
        FoxChatDB = FoxChatDB or {}
        for k, v in pairs(defaults) do
            if FoxChatDB[k] == nil then
                FoxChatDB[k] = v
            end
        end
        
        -- prefixSuffixChannels 테이블 확인 및 초기화
        if not FoxChatDB.prefixSuffixChannels then
            FoxChatDB.prefixSuffixChannels = defaults.prefixSuffixChannels
        end
        
        -- minimapButton 테이블 확인 및 초기화
        if not FoxChatDB.minimapButton then
            FoxChatDB.minimapButton = defaults.minimapButton
        end

        -- toastPosition 테이블 확인 및 초기화
        if not FoxChatDB.toastPosition then
            FoxChatDB.toastPosition = defaults.toastPosition
        end
        
        -- 키워드 파싱
        UpdateKeywords()
        UpdateIgnoreKeywords()
        
    elseif event == "PLAYER_LOGIN" then
        -- SendChatMessage 후킹
        HookSendChatMessage()
        
        -- 모든 채팅 프레임에 후킹
        for i = 1, NUM_CHAT_WINDOWS do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame then
                HookChatFrame(chatFrame)
            end
        end
        
        -- 임시 채팅 윈도우를 위한 후킹
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, chatFrame in pairs(CHAT_FRAMES) do
                HookChatFrame(_G[chatFrame])
            end
        end)
        
        -- 채팅 필터 등록
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter)
        
        -- 미니맵 버튼 생성
        CreateMinimapButton()
        
        print(L["ADDON_LOADED"])
    end
end)

-- 공개 함수들
function FoxChat:UpdateKeywords()
    UpdateKeywords()
end

-- ShowToast 함수를 FoxChat 테이블에 추가
FoxChat.ShowToast = ShowToast

function FoxChat:UpdateIgnoreKeywords()
    UpdateIgnoreKeywords()
end

function FoxChat:OpenConfig()
    -- ShowConfig 함수 호출 (FoxChat_Config.lua에서 정의됨)
    if FoxChat.ShowConfig then
        FoxChat:ShowConfig()
    end
end

function FoxChat:Toggle()
    -- 채팅 필터링 기능 토글
    FoxChatDB.filterEnabled = not FoxChatDB.filterEnabled
    if FoxChatDB.filterEnabled then
        print("|cFFFF7D0A[FoxChat]|r " .. L["FILTER_ENABLED"])
    else
        print("|cFFFF7D0A[FoxChat]|r " .. L["FILTER_DISABLED"])
    end
end

function FoxChat:AddKeyword(keyword)
    if not keyword or keyword == "" then return end
    
    keyword = string.trim(keyword)
    local current = FoxChatDB.keywords or ""
    
    -- 이미 있는지 확인
    ParseKeywords(current)
    if keywords[string.lower(keyword)] then
        return
    end
    
    if current == "" then
        FoxChatDB.keywords = keyword
    else
        FoxChatDB.keywords = current .. "," .. keyword
    end
    
    ParseKeywords(FoxChatDB.keywords)
    print(string.format(L["KEYWORD_ADDED"], keyword))
end

function FoxChat:RemoveKeyword(keyword)
    if not keyword or keyword == "" then return end
    
    keyword = string.trim(keyword)
    local current = FoxChatDB.keywords or ""
    
    ParseKeywords(current)
    if not keywords[string.lower(keyword)] then
        print(string.format(L["KEYWORD_NOT_FOUND"], keyword))
        return
    end
    
    -- 키워드 제거
    local newKeywords = {}
    for _, kw in ipairs({strsplit(",", current)}) do
        kw = string.trim(kw)
        if string.lower(kw) ~= string.lower(keyword) then
            table.insert(newKeywords, kw)
        end
    end
    
    FoxChatDB.keywords = table.concat(newKeywords, ",")
    ParseKeywords(FoxChatDB.keywords)
    print(string.format(L["KEYWORD_REMOVED"], keyword))
end

function FoxChat:ListKeywords()
    local current = FoxChatDB.keywords or ""
    if current == "" then
        print(L["NO_KEYWORDS"])
    else
        print(string.format(L["CURRENT_KEYWORDS"], current))
    end
end

function FoxChat:TestHighlight()
    local testMsg = L["TEST_MESSAGE"]
    
    -- 키워드 추가
    for keyword, _ in pairs(keywords) do
        testMsg = testMsg .. " " .. keyword
        break  -- 첫 번째 키워드만 추가
    end
    
    -- 테스트 메시지 표시 (길드 채널로 테스트)
    local highlightedMsg, found = HighlightKeywords(testMsg, "GUILD", "TestPlayer")
    if found and FoxChatDB.playSound then
        PlaySoundFile("Interface\\AddOns\\FoxChat\\ring.wav", "Master")
    end
    DEFAULT_CHAT_FRAME:AddMessage(highlightedMsg)
end

-- 슬래시 명령어
SLASH_FOXCHAT1 = "/fc"
SLASH_FOXCHAT2 = "/foxchat"

SlashCmdList["FOXCHAT"] = function(msg)
    msg = msg:lower()
    local cmd, arg = strsplit(" ", msg, 2)
    
    if cmd == "toggle" then
        FoxChat:Toggle()
    elseif cmd == "add" and arg then
        FoxChat:AddKeyword(arg)
    elseif cmd == "remove" and arg then
        FoxChat:RemoveKeyword(arg)
    elseif cmd == "list" then
        FoxChat:ListKeywords()
    elseif cmd == "ignorelist" then
        -- 무시 키워드 목록 출력
        print("|cFFFF7D0A[FoxChat]|r 무시 키워드 목록:")
        for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
            print(string.format("  - '%s' (원본: '%s')", lowerIgnore, originalIgnore))
        end
        if next(ignoreKeywords) == nil then
            print("  무시 키워드가 없습니다.")
        end
    elseif cmd == "debug" then
        -- 디버그 모드 토글
        debugMode = not debugMode
        if debugMode then
            print("|cFFFF7D0A[FoxChat]|r 디버그 모드가 활성화되었습니다.")
        else
            print("|cFFFF7D0A[FoxChat]|r 디버그 모드가 비활성화되었습니다.")
        end
    elseif cmd == "test" then
        FoxChat:TestHighlight()
    elseif cmd == "" or cmd == "config" then
        if FoxChat.ShowConfig then
            FoxChat:ShowConfig()
        end
    else
        print(L["COMMANDS_HEADER"])
        print(L["COMMAND_CONFIG"])
        print(L["COMMAND_TOGGLE"])
        print(L["COMMAND_ADD"])
        print(L["COMMAND_REMOVE"])
        print(L["COMMAND_LIST"])
    end
end