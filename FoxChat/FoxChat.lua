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
        minimapPos = 180,  -- 미니맵 아래쪽에 초기 위치
        radius = 80,  -- 미니맵 테두리까지의 거리
    },
    toastPosition = {
        x = 0,  -- X축 오프셋 (0 = 중앙)
        y = -320,  -- Y축 오프셋 (기본값 -320)
    },
    -- 광고 설정
    adEnabled = false,  -- 광고 기능 활성화
    adMessage = "",  -- 광고 메시지
    adPosition = {
        x = 350,  -- X축 오프셋 (기본 350)
        y = -150,  -- Y축 오프셋 (기본 -150)
    },
    adCooldown = 30,  -- 광고 버튼 쿨다운 (초, 기본 30초)
    adChannel = "파티찾기",  -- 광고 채널 (기본 파티찾기)
    partyMaxSize = 5,  -- 구하는 파티원 수 (기본 5명)
    autoStopAtFull = true,  -- 목표 인원 도달 시 자동 중지
    -- 선입 설정
    firstComeEnabled = false,  -- 선입 메시지 알림 활성화 상태
    firstComeMessage = "",  -- 선입 메시지
    firstComeCooldown = 5,  -- 선입 버튼 쿨다운 (초, 기본 5초)
}

-- 키워드 테이블 (빠른 검색을 위해)
local keywords = {}
local ignoreKeywords = {}

-- 유틸리티 함수: 문자열이 비어있거나 공백만 있는지 확인
local function IsEmptyOrWhitespace(str)
    return not str or string.gsub(str, "%s+", "") == ""
end

-- UTF-8 문자열의 바이트 길이 계산
function GetUTF8ByteLength(str)
    if not str then return 0 end
    return string.len(str)
end

-- 디버그 모드
local debugMode = false

-- 원본 AddMessage 함수들을 저장
local originalAddMessage = {}
local originalSendChatMessage = SendChatMessage
local isAdvertisementMessage = false  -- 광고 메시지 전송 중인지 플래그

-- 토스트 알림 시스템
local activeToasts = {}  -- 현재 활성화된 토스트 목록
local toastPool = {}     -- 재사용 가능한 토스트 프레임 풀
local authorCooldowns = {}  -- 사용자별 쿨다운 추적
local MAX_TOASTS = 3    -- 최대 토스트 개수
local ShowToast  -- forward declaration

-- 광고 시스템
local adButton = nil  -- 광고 버튼
local adCooldownTimer = nil  -- 광고 쿨다운 타이머
local adLastClickTime = 0  -- 마지막 광고 클릭 시간

-- 키워드 파싱 함수
local function ParseKeywords(keywordData, targetTable)
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
    if channelType == "GUILD" or channelType == "OFFICER" then
        return "GUILD"
    elseif channelType == "PARTY" or channelType == "PARTY_LEADER" or
           channelType == "RAID" or channelType == "RAID_LEADER" or
           channelType == "RAID_WARNING" or channelType == "INSTANCE_CHAT" then
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
    -- WHISPER, LOOT, SYSTEM 등은 nil 반환 (필터링 대상 아님)
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

    -- 현재 플레이어 이름 가져오기 (서버명 제거)
    local myName = UnitName("player")
    local myNameLower = string.lower(myName)

    -- 작성자가 본인인지 확인 (서버명 제거하여 비교)
    local isMyMessage = false
    if author then
        local authorClean = string.gsub(author, "%-[^%-]+$", "")  -- 서버명 제거
        local authorLower = string.lower(authorClean)

        if authorLower == myNameLower then
            isMyMessage = true

            -- 본인이 쓴 메시지는 필터링하지 않음
            return message, false
        end
    end

    -- 말머리와 말꼬리를 메시지 내용에서 제거하여 필터링 체크
    local msgContentForCheck = msgContent
    local originalMsgContent = msgContent  -- 디버그용

    if FoxChatDB.prefixSuffixEnabled then
        local myPrefix = FoxChatDB.prefix or ""
        local mySuffix = FoxChatDB.suffix or ""

        -- 메시지 시작 부분이 말머리와 일치하면 제거 (공백 포함하여 비교)
        if myPrefix ~= "" then
            -- 메시지 앞의 공백 제거
            local trimmedMsg = string.gsub(msgContentForCheck, "^%s*", "")
            -- 말머리와 정확히 일치하는지 확인
            if string.sub(trimmedMsg, 1, string.len(myPrefix)) == myPrefix then
                msgContentForCheck = string.sub(trimmedMsg, string.len(myPrefix) + 1)
                -- 말머리 뒤의 공백도 제거
                msgContentForCheck = string.gsub(msgContentForCheck, "^%s*", "")

                if debugMode then
                end
            end
        end

        -- 메시지 끝 부분이 말꼬리와 일치하면 제거 (공백 포함하여 비교)
        if mySuffix ~= "" then
            -- 메시지 끝의 공백 제거
            local trimmedMsg = string.gsub(msgContentForCheck, "%s*$", "")
            -- 말꼬리와 정확히 일치하는지 확인
            if string.sub(trimmedMsg, -string.len(mySuffix)) == mySuffix then
                msgContentForCheck = string.sub(trimmedMsg, 1, -string.len(mySuffix) - 1)
                -- 말꼬리 앞의 공백도 제거
                msgContentForCheck = string.gsub(msgContentForCheck, "%s*$", "")

                if debugMode then
                end
            end
        end

        if debugMode and (myPrefix ~= "" or mySuffix ~= "") then
        end
    end

    local foundKeyword = false
    local lowerMsgContent = string.lower(msgContentForCheck)

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
    end

    -- 작성자 닉네임이 무시 키워드 중 하나와 일치하는지 확인
    -- 일치하면 이 메시지는 전혀 필터링하지 않음
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if debugMode and author then
            if lowerIgnore == authorClean then
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

            -- 키워드를 하이라이트 (원본 msgContent에 적용)
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
                    end
                else
                    -- 대체 패턴: |Hplayer:이름 형태
                    local simplePattern = "|Hplayer:([^:|]+)"
                    local simpleName = string.match(text, simplePattern)
                    if simpleName then
                        author = simpleName
                        if debugMode then
                        end
                    else
                        -- [이름] 패턴 찾기
                        local bracketPattern = "%[([^%]]+)%]"
                        local bracketName = string.match(text, bracketPattern)
                        if bracketName and not string.find(bracketName, "파티") and not string.find(bracketName, "공격대") then
                            author = bracketName
                            if debugMode then
                            end
                        else
                            if debugMode then
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

-- UTF-8 유틸리티 모듈
local UTF8 = {}

-- UTF-8 문자열의 글자 수를 계산하는 함수 (WoW 내장 함수 활용)
function UTF8.len(str)
    if not str then return 0 end
    -- WoW에 내장된 strlenutf8 함수 사용
    if type(_G.strlenutf8) == "function" then
        return strlenutf8(str)
    end
    -- 폴백: 순수 Lua 구현
    local len, i = 0, 1
    local bytes = #str
    while i <= bytes do
        local c = str:byte(i)
        local n
        if c < 0x80 then
            n = 1
        elseif c < 0xE0 then
            n = 2
        elseif c < 0xF0 then
            n = 3
        elseif c < 0xF5 then
            n = 4
        else
            n = 1
        end
        i = i + n
        len = len + 1
    end
    return len
end

-- UTF-8 문자열을 바이트 수 기준으로 안전하게 자르는 함수
function UTF8.trimByBytes(str, byteLimit)
    if not str or str == "" then return "" end
    byteLimit = byteLimit or 255

    -- 이미 제한 내에 있으면 그대로 반환
    if #str <= byteLimit then
        return str
    end

    -- 유효한 UTF-8 경계를 찾아서 자르기
    local validPos = 0  -- 마지막으로 확인된 유효한 위치
    local i = 1

    while i <= #str and i <= byteLimit do
        local b = str:byte(i)
        if not b then
            break
        end

        local charLen = 1
        if b < 0x80 then
            -- ASCII 문자 (1바이트)
            charLen = 1
        elseif b >= 0xF0 then
            -- 4바이트 문자
            charLen = 4
        elseif b >= 0xE0 then
            -- 3바이트 문자 (한글 등)
            charLen = 3
        elseif b >= 0xC0 then
            -- 2바이트 문자
            charLen = 2
        else
            -- 잘못된 UTF-8 시작 바이트
            break
        end

        -- 전체 문자가 byteLimit 내에 들어가는지 확인
        if i + charLen - 1 <= byteLimit then
            -- 이 문자를 포함할 수 있음
            validPos = i + charLen - 1
            i = i + charLen
        else
            -- 이 문자를 포함할 수 없음
            break
        end
    end

    -- 유효한 위치까지 자르기
    if validPos > 0 then
        return str:sub(1, validPos)
    else
        -- 첫 문자도 들어갈 수 없는 경우 (매우 드물지만)
        -- 최소한 빈 문자열이 아닌 적절한 처리
        return ""
    end
end

-- 메시지 검증 함수 (글자수와 바이트수 체크)
function UTF8.validate(str)
    if not str then
        return { charLen = 0, byteLen = 0, okForChat = true }
    end
    return {
        charLen = UTF8.len(str),
        byteLen = #str,
        okForChat = (#str <= 255)
    }
end

-- SendChatMessage 후킹 (말머리/말꼬리)
local function HookSendChatMessage()
    SendChatMessage = function(message, chatType, language, channel)
        -- 광고 메시지는 훅을 적용하지 않음
        if isAdvertisementMessage then
            originalSendChatMessage(message, chatType, language, channel)
            return
        end

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

        -- WoW 메시지 길이 제한: 255바이트
        -- 바이트 수가 255를 초과하면 UTF-8 경계를 고려하여 자르기
        if #message > 255 then
            message = UTF8.trimByBytes(message, 255)
        end

        -- 원본 함수 호출
        if message and message ~= "" then
            originalSendChatMessage(message, chatType, language, channel)
        end
    end
end

-- 광고 버튼 생성 함수
local function CreateAdButton()
    if adButton then return end

    -- 광고 버튼 프레임
    adButton = CreateFrame("Button", "FoxChatAdButton", UIParent)
    adButton:SetSize(60, 60)
    adButton:SetFrameStrata("HIGH")
    adButton:SetFrameLevel(100)
    adButton:EnableMouse(true)
    adButton:SetMovable(true)
    adButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")  -- 우클릭도 등록
    adButton:Hide()  -- 기본적으로 숨김

    -- 버튼 배경 (스피커 아이콘)
    local icon = adButton:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Horn_01")  -- 나팔 아이콘

    -- 버튼 테두리 (아이콘보다 크게)
    local border = adButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", 5, -5)

    -- 쿨다운 오버레이
    local cooldown = CreateFrame("Cooldown", nil, adButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    adButton.cooldown = cooldown

    -- 위치 업데이트
    local function UpdateAdButtonPosition()
        if not FoxChatDB.adPosition then
            FoxChatDB.adPosition = defaults.adPosition
        end
        adButton:ClearAllPoints()
        adButton:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
    end

    -- 드래그 기능
    adButton:RegisterForDrag("LeftButton")
    adButton.isDragging = false

    adButton:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
            self.isDragging = true
        end
    end)

    adButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false

        -- 화면 중심 기준 좌표 계산
        local centerX, centerY = self:GetCenter()
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()
        local x = centerX - (screenWidth / 2)
        local y = centerY - (screenHeight / 2)

        FoxChatDB.adPosition.x = x
        FoxChatDB.adPosition.y = y

        -- 다시 위치 설정 (CENTER 기준으로)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)

        -- 선입 버튼도 업데이트
        if firstComeButton and firstComeButton:IsVisible() then
            firstComeButton:ClearAllPoints()
            firstComeButton:SetPoint("CENTER", UIParent, "CENTER", x + 65, y + 5)
        end

        -- 설정창 EditBox 업데이트
        local adXEditBox = _G["FoxChatConfigFrame"] and _G["FoxChatConfigFrame"].adXEditBox
        local adYEditBox = _G["FoxChatConfigFrame"] and _G["FoxChatConfigFrame"].adYEditBox
        if adXEditBox then
            adXEditBox:SetText(tostring(math.floor(x + 0.5)))
        end
        if adYEditBox then
            adYEditBox:SetText(tostring(math.floor(y + 0.5)))
        end
    end)

    -- 드래그 중 실시간 업데이트
    adButton:SetScript("OnUpdate", function(self)
        if self.isDragging then
            -- 화면 중심 기준 좌표 계산
            local centerX, centerY = self:GetCenter()
            local screenWidth = GetScreenWidth()
            local screenHeight = GetScreenHeight()
            local x = centerX - (screenWidth / 2)
            local y = centerY - (screenHeight / 2)

            FoxChatDB.adPosition.x = x
            FoxChatDB.adPosition.y = y

            -- 설정창 EditBox 업데이트
            local adXEditBox = _G["FoxChatConfigFrame"] and _G["FoxChatConfigFrame"].adXEditBox
            local adYEditBox = _G["FoxChatConfigFrame"] and _G["FoxChatConfigFrame"].adYEditBox
            if adXEditBox then
                adXEditBox:SetText(tostring(math.floor(x + 0.5)))
            end
            if adYEditBox then
                adYEditBox:SetText(tostring(math.floor(y + 0.5)))
            end

            -- 선입 버튼도 함께 이동
            if firstComeButton and firstComeButton:IsVisible() then
                firstComeButton:ClearAllPoints()
                firstComeButton:SetPoint("CENTER", UIParent, "CENTER", x + 65, y + 5)
            end
        end
    end)

    -- 툴팁 이벤트
    adButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("광고 전송", 1, 1, 1)
        GameTooltip:AddLine("파티찾기 채널에 광고 메시지를 전송합니다.", 0.8, 0.8, 0.8, true)
        if FoxChatDB.adMessage and FoxChatDB.adMessage ~= "" then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("메시지:", 1, 0.8, 0)
            GameTooltip:AddLine(FoxChatDB.adMessage, 0.8, 0.8, 0.8, true)
        end
        local cooldownTime = FoxChatDB.adCooldown or 30
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("쿨다운: " .. cooldownTime .. "초", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFF6060우클릭: 광고 중지|r", 1, 1, 1)
        GameTooltip:Show()
    end)

    adButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 클릭 이벤트
    adButton:SetScript("OnClick", function(self, button)
        -- 우클릭 처리 - 광고 중지
        if button == "RightButton" then
            FoxChatDB.adEnabled = false
            self:Hide()  -- 버튼 숨김
            -- 쿨다운 초기화
            if FoxChat and FoxChat.ResetAdCooldown then
                FoxChat:ResetAdCooldown()
            end
            -- 설정창의 버튼도 업데이트
            local configFrame = _G["FoxChatConfigFrame"]
            if configFrame and configFrame:IsVisible() then
                -- 탭 컨텐츠 찾기
                if configFrame.tab3 and configFrame.tab3.UpdateAdStartButton then
                    configFrame.tab3.UpdateAdStartButton()
                end
            end
            print("|cFFFF7D0A[FoxChat]|r 광고가 중지되었습니다.")
            return
        end

        -- 좌클릭 처리 - 기존 기능
        if button == "LeftButton" and not adCooldownTimer then
            -- 파티찾기 채널에 메시지 전송 (광고 메시지 + [선입 메시지] + 파티 정보)
            local baseMessage = FoxChatDB.adMessage or ""

            -- 메시지 복사본 생성 (문자열이 제대로 전달되도록)
            local message = ""
            if baseMessage and baseMessage ~= "" then
                message = tostring(baseMessage)
            end

            -- 선입 메시지가 있으면 추가
            local firstComeMessage = FoxChatDB.firstComeMessage or ""
            if firstComeMessage ~= "" then
                -- 메시지 뒤에 공백이 없으면 추가
                if message ~= "" and string.sub(message, -1) ~= " " then
                    message = message .. " "
                end
                message = message .. "(" .. tostring(firstComeMessage) .. ")"
            end

            -- 파티원수가 0이면 수동 모드 (파티 정보 추가하지 않음)
            local maxMembers = tonumber(FoxChatDB.partyMaxSize) or 5

            if maxMembers > 0 then
                -- 자동 모드: 현재 파티/공격대 인원 확인
                local currentMembers = 1  -- 기본값 (나 혼자)

                if IsInRaid() then
                    currentMembers = GetNumGroupMembers()  -- 공격대 인원
                elseif IsInGroup() then
                    currentMembers = GetNumGroupMembers()  -- 파티 인원
                end

                -- 메시지에 파티 정보 추가 (띄어쓰기 확인)
                if message ~= "" and string.sub(message, -1) ~= " " then
                    message = message .. " "
                end
                message = message .. "(" .. currentMembers .. "/" .. maxMembers .. ")"
            end

            if not IsEmptyOrWhitespace(message) then
                -- 선택된 채널 찾기
                local targetChannelName = FoxChatDB.adChannel or "파티찾기"
                local channels = {GetChannelList()}
                local targetChannel = nil

                for i = 1, #channels, 3 do
                    local id, name = channels[i], channels[i+1]
                    if name then
                        -- 선택된 채널명과 일치하는지 확인
                        if string.find(name, targetChannelName) or
                           (targetChannelName == "파티찾기" and string.find(name, "LookingForGroup")) or
                           (targetChannelName == "공개" and (string.find(name, "General") or string.find(name, "일반"))) or
                           (targetChannelName == "거래" and string.find(name, "Trade")) then
                            targetChannel = id
                            break
                        end
                    end
                end

                -- 못 찾았으면 기본 채널로 폴백
                if not targetChannel and targetChannelName == "파티찾기" then
                    -- 파티찾기 없으면 공개 채널 찾기
                    for i = 1, #channels, 3 do
                        local id, name = channels[i], channels[i+1]
                        if name and (string.find(name, "General") or string.find(name, "일반") or string.find(name, "공개")) then
                            targetChannel = id
                            break
                        end
                    end
                end

                if targetChannel then
                    -- 메시지 길이 체크 (255바이트 제한)
                    if #message > 255 then
                        message = UTF8.trimByBytes(message, 255)
                    end

                    -- 빈 메시지 체크
                    if not message or message == "" then
                        print("|cFFFF7D0A[FoxChat]|r 광고 메시지가 너무 길어 전송할 수 없습니다.")
                        return
                    end

                    -- 광고 메시지 플래그 설정
                    isAdvertisementMessage = true

                    -- 광고 메시지는 말머리/말꼬리 없이 원본 함수로 전송
                    originalSendChatMessage(message, "CHANNEL", nil, targetChannel)

                    -- 플래그 해제
                    isAdvertisementMessage = false
                else
                    print("|cFFFF7D0A[FoxChat]|r " .. targetChannelName .. " 채널을 찾을 수 없습니다.")
                end

                -- 쿨다운 적용 (15, 30, 45, 60초 중 선택, 기본 15초)
                local cooldownTime = FoxChatDB.adCooldown or 30
                adLastClickTime = GetTime()  -- 마지막 클릭 시간 먼저 업데이트
                self.cooldown:SetCooldown(adLastClickTime, cooldownTime)
                self:Hide()

                -- 쿨다운 타이머
                adCooldownTimer = C_Timer.NewTimer(cooldownTime, function()
                    adCooldownTimer = nil
                    if FoxChatDB.adEnabled then
                        self:Show()
                    end
                end)
            else
                print("|cFFFF7D0A[FoxChat]|r 광고 메시지를 먼저 설정해주세요.")
            end
        end
    end)

    -- 툴팁
    adButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("광고 전송", 1, 1, 1)
        GameTooltip:AddLine("클릭: 파티찾기 채널에 광고 전송", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift+드래그: 위치 이동", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    adButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    UpdateAdButtonPosition()
end

-- 선입 버튼 생성 함수
local function CreateFirstComeButton()
    if firstComeButton then return end

    -- 선입외치기 버튼 프레임 (아이콘 스타일)
    firstComeButton = CreateFrame("Button", "FoxChatFirstComeButton", UIParent)
    firstComeButton:SetSize(50, 50)  -- 아이콘 크기
    firstComeButton:SetFrameStrata("HIGH")
    firstComeButton:SetFrameLevel(101)
    firstComeButton:EnableMouse(true)
    firstComeButton:SetMovable(false)
    firstComeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")  -- 우클릭도 등록
    firstComeButton:Hide()  -- 기본적으로 숨김

    -- 버튼 배경 (스피커 아이콘)
    local icon = firstComeButton:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_Silence")  -- 스피커 아이콘

    -- 버튼 테두리
    local border = firstComeButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", 5, -5)

    -- 쿨다운 오버레이
    local cooldown = CreateFrame("Cooldown", nil, firstComeButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    firstComeButton.cooldown = cooldown

    -- 툴팁 이벤트
    firstComeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("선입외치기", 1, 1, 1)
        GameTooltip:AddLine("파티/공격대원에게 선입 메시지를 전송합니다.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("파티: /파로 전송", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine("공격대: /경보로 전송 (권한 있을 시) 또는 /공", 0.6, 0.6, 0.6, true)
        if FoxChatDB.firstComeMessage and FoxChatDB.firstComeMessage ~= "" then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("메시지:", 1, 0.8, 0)
            GameTooltip:AddLine(FoxChatDB.firstComeMessage, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFF6060우클릭: 선입 알림 비활성화|r", 1, 1, 1)
        GameTooltip:Show()
    end)

    firstComeButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 클릭 이벤트
    firstComeButton:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() then return end  -- Shift 클릭은 무시

        -- 우클릭 처리 - 선입 알림 비활성화
        if button == "RightButton" then
            FoxChatDB.firstComeEnabled = false
            self:Hide()  -- 버튼 직접 숨김
            -- 설정창의 버튼도 업데이트
            local configFrame = _G["FoxChatConfigFrame"]
            if configFrame and configFrame:IsVisible() then
                -- 탭 컨텐츠 찾기
                if configFrame.tab3 and configFrame.tab3.UpdateFirstComeStartButton then
                    configFrame.tab3.UpdateFirstComeStartButton()
                end
            end
            print("|cFFFF7D0A[FoxChat]|r 선입 메시지 알림이 비활성화되었습니다.")
            return
        end

        -- 좌클릭 처리 - 기존 기능

        -- 선입 메시지가 있는지 확인
        local message = FoxChatDB.firstComeMessage
        if not message or IsEmptyOrWhitespace(message) then
            print("|cFFFF7D0A[FoxChat]|r 선입 메시지가 설정되지 않았습니다.")
            return
        end

        -- 파티 또는 공격대 확인
        local channel = nil
        if IsInRaid() then
            -- 공격대 리더나 승급자인지 확인 (Classic 호환)
            local isLeaderOrAssistant = false

            -- 방법 1: UnitIsGroupLeader와 UnitIsGroupAssistant 사용 (더 최신 API)
            if UnitIsGroupLeader and UnitIsGroupLeader("player") then
                isLeaderOrAssistant = true
            elseif UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
                isLeaderOrAssistant = true
            else
                -- 방법 2: GetRaidRosterInfo 사용 (Classic 호환)
                for i = 1, GetNumGroupMembers() do
                    local name, rank = GetRaidRosterInfo(i)
                    if name == UnitName("player") then
                        if rank >= 1 then  -- rank 2 = 리더, rank 1 = 승급자
                            isLeaderOrAssistant = true
                        end
                        break
                    end
                end
            end

            if isLeaderOrAssistant then
                channel = "RAID_WARNING"  -- 공격대에서는 /경보 (공격대 경보)
            else
                channel = "RAID"  -- 권한이 없으면 /공 (공격대 채팅)
            end
        elseif IsInGroup() then
            channel = "PARTY"  -- 파티에서는 /파 (파티 채팅)
        else
            print("|cFFFF7D0A[FoxChat]|r 파티나 공격대에 속해있지 않습니다.")
            return
        end

        -- 메시지 길이 체크 (255바이트 제한)
        if #message > 255 then
            message = UTF8.trimByBytes(message, 255)
        end

        -- 메시지 전송
        SendChatMessage(message, channel)

        -- 쿨다운 설정
        local cooldownTime = FoxChatDB.firstComeCooldown or 5
        firstComeLastClickTime = GetTime()
        self.cooldown:SetCooldown(firstComeLastClickTime, cooldownTime)

        -- 쿨다운 타이머 설정
        if firstComeCooldownTimer then
            firstComeCooldownTimer:Cancel()
        end
        firstComeCooldownTimer = C_Timer.NewTimer(cooldownTime, function()
            firstComeCooldownTimer = nil
        end)
    end)
end

-- 선입 버튼 위치 및 표시 업데이트
local function UpdateFirstComeButton()
    if not firstComeButton then
        CreateFirstComeButton()
    end

    -- 선입 메시지 알림이 활성화되어 있고, 선입 메시지가 있을 때 표시 (파티/공격대 여부와 무관)
    if FoxChatDB.firstComeEnabled
       and FoxChatDB.firstComeMessage and not IsEmptyOrWhitespace(FoxChatDB.firstComeMessage) then

        -- 광고 버튼의 위치를 기준으로 선입 버튼 위치 설정
        if not FoxChatDB.adPosition then
            FoxChatDB.adPosition = defaults.adPosition
        end

        firstComeButton:ClearAllPoints()
        -- 광고 버튼의 위치에서 우측으로 65 픽셀 떨어진 곳에 배치 (아이콘 크기 조정)
        firstComeButton:SetPoint("CENTER", UIParent, "CENTER",
                                FoxChatDB.adPosition.x + 65,
                                FoxChatDB.adPosition.y + 5)  -- 약간 위로 조정
        firstComeButton:Show()
    else
        firstComeButton:Hide()
    end
end

-- 광고 버튼 표시/숨김
local function UpdateAdButton()
    if not adButton then
        CreateAdButton()
    end

    -- 위치 업데이트
    if adButton then
        if not FoxChatDB.adPosition then
            FoxChatDB.adPosition = defaults.adPosition
        end
        adButton:ClearAllPoints()
        adButton:SetPoint("CENTER", UIParent, "CENTER", FoxChatDB.adPosition.x, FoxChatDB.adPosition.y)
    end

    -- 자동 중지 기능 제거 - 목표 인원 체크 없이 광고 계속 가능

    if FoxChatDB.adEnabled and FoxChatDB.adMessage and not IsEmptyOrWhitespace(FoxChatDB.adMessage) then
        -- 쿨다운 체크 (마지막 클릭 시간이 0보다 클 때만)
        if adLastClickTime > 0 then
            local currentTime = GetTime()
            local cooldownTime = FoxChatDB.adCooldown or 30
            local timeSinceLastClick = currentTime - adLastClickTime

            if timeSinceLastClick >= cooldownTime then
                -- 쿨다운이 끝난 경우
                if adCooldownTimer then
                    adCooldownTimer:Cancel()
                    adCooldownTimer = nil
                end
                adButton:Show()
            else
                -- 아직 쿨다운 중인 경우
                adButton:Hide()
                if not adCooldownTimer then
                    local remainingTime = cooldownTime - timeSinceLastClick
                    adCooldownTimer = C_Timer.NewTimer(remainingTime, function()
                        adCooldownTimer = nil
                        if FoxChatDB.adEnabled then
                            adButton:Show()
                        end
                    end)
                    -- 쿨다운 UI 업데이트
                    if adButton.cooldown then
                        adButton.cooldown:SetCooldown(adLastClickTime, cooldownTime)
                    end
                end
            end
        else
            -- 쿨다운이 없는 경우 (처음 시작하거나 초기화된 경우)
            adButton:Show()
        end
    else
        adButton:Hide()
    end

    -- 광고 버튼 위치가 변경될 때 선입 버튼도 업데이트
    UpdateFirstComeButton()
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

-- 그룹 상태 변경 이벤트 처리
local function OnGroupRosterUpdate()
    -- 광고 버튼 업데이트
    UpdateAdButton()
    -- 선입 버튼 업데이트
    if UpdateFirstComeButton then
        UpdateFirstComeButton()
    end
end

-- 초기화
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

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

        -- adPosition 테이블 확인 및 초기화
        if not FoxChatDB.adPosition then
            FoxChatDB.adPosition = defaults.adPosition
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
        
        -- 채팅 필터 등록 (플레이어 대화만 필터링, 시스템 메시지 제외)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", ChatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter)
        -- 귓속말은 제외 (WHISPER 이벤트 제거)
        
        -- 미니맵 버튼 생성
        CreateMinimapButton()

        -- 광고 버튼 생성 및 업데이트
        CreateAdButton()
        UpdateAdButton()

        -- 선입 버튼 생성 및 업데이트
        CreateFirstComeButton()
        UpdateFirstComeButton()

        print(L["ADDON_LOADED"])
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    end
end)

-- 공개 함수들
function FoxChat:UpdateKeywords()
    UpdateKeywords()
end

-- ShowToast 함수를 FoxChat 테이블에 추가
FoxChat.ShowToast = ShowToast

-- UpdateAdButton 함수를 FoxChat 테이블에 추가
FoxChat.UpdateAdButton = UpdateAdButton
FoxChat.UpdateFirstComeButton = UpdateFirstComeButton

-- 광고 쿨다운 초기화 함수
function FoxChat:ResetAdCooldown()
    -- 쿨다운 타이머 취소
    if adCooldownTimer then
        adCooldownTimer:Cancel()
        adCooldownTimer = nil
    end
    -- 마지막 클릭 시간 초기화
    adLastClickTime = 0
    -- 광고 버튼 쿨다운 UI 초기화
    if adButton and adButton.cooldown then
        adButton.cooldown:Clear()
    end
end

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

-- =============================================
-- 자동 기능들
-- =============================================

-- 거래 완료 시 자동 귓속말
local tradePartnerName = nil
local tradePlayerAccepted = false
local tradeTargetAccepted = false
local tradeWillComplete = false  -- 거래 성공 예정 플래그
local tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }

-- 거래 정보 백업 (UI_INFO_MESSAGE에서 사용)
local lastTradePartnerName = nil
local lastTradeMessage = nil
local lastTradeSentTime = 0  -- 중복 전송 방지용 타임스탬프

-- 도우미: 동전(코퍼) → 골드/실버/코퍼 문자열
local function FormatMoney(copper)
    copper = copper or 0
    if copper == 0 then return "" end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local parts = {}
    if gold > 0 then table.insert(parts, string.format("%d골드", gold)) end
    if silver > 0 then table.insert(parts, string.format("%d실버", silver)) end
    if c > 0 then table.insert(parts, string.format("%d코퍼", c)) end

    if #parts == 0 then return "" end
    return table.concat(parts, " ")
end

-- 파트너 이름 얻기
local function ResolvePartnerName()

    -- TradeFrameRecipientNameText가 가장 정확
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() then
        local name = TradeFrameRecipientNameText:GetText()
        if name and name ~= "" then
            return name
        end
    else
    end

    -- NPC 타겟 체크
    local npcTarget = UnitName("NPC")
    if npcTarget and npcTarget ~= "" then
        if npcTarget ~= UnitName("player") then
            return npcTarget
        end
    end

    -- 대체 방법: 타겟 (플레이어 체크 제거하여 안전성 향상)
    local targetName = UnitName("target")
    if targetName and targetName ~= UnitName("player") then
        return targetName
    end

    return nil
end

-- 이름 정규화 (서버명, 색코드, 공백 제거)
local function NormalizeName(name)
    if not name or name == "" then
        return nil
    end

    -- Ambiguate 함수가 있으면 서버명 제거
    if Ambiguate then
        name = Ambiguate(name, "none")
    else
        -- 수동으로 서버명 제거: "Name-Realm" → "Name"
        name = name:gsub("%-.+$", "")
    end

    -- 색코드 제거
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    -- 앞뒤 공백 제거
    name = name:match("^%s*(.-)%s*$")

    return name ~= "" and name or nil
end

-- 거래 정보 스냅샷 (TRADE_CLOSED 시점에 정보가 사라질 수 있으므로 미리 저장)
local function SnapshotTradeData()
    tradeSnapshot.givenItems = {}
    tradeSnapshot.gotItems = {}

    -- 상수명 충돌 방지: 다른 변수명 사용
    local TRADE_SLOTS = (_G.MAX_TRADE_ITEMS and _G.MAX_TRADE_ITEMS) or 6  -- 클래식은 보통 6개 슬롯

    -- 내가 준 아이템들
    for i = 1, TRADE_SLOTS do
        local name, texture, quantity, quality, isUsable, enchant = GetTradePlayerItemInfo(i)
        local link = GetTradePlayerItemLink(i)
        if name then
            local label = link or name
            if (quantity or 1) > 1 then
                table.insert(tradeSnapshot.givenItems, string.format("%s(%d)", label, quantity))
            else
                table.insert(tradeSnapshot.givenItems, label)
            end
        end
    end

    -- 내가 받은 아이템들
    for i = 1, TRADE_SLOTS do
        local name, texture, quantity, quality, isUsable, enchant = GetTradeTargetItemInfo(i)
        local link = GetTradeTargetItemLink(i)
        if name then
            local label = link or name
            if (quantity or 1) > 1 then
                table.insert(tradeSnapshot.gotItems, string.format("%s(%d)", label, quantity))
            else
                table.insert(tradeSnapshot.gotItems, label)
            end
        end
    end

    -- 금액 (문자열로 반환될 수 있으므로 숫자로 변환)
    local givenMoney = GetPlayerTradeMoney()
    local gotMoney = GetTargetTradeMoney()

    -- 문자열이면 숫자로 변환, nil이면 0
    if type(givenMoney) == "string" then
        tradeSnapshot.givenMoney = tonumber(givenMoney) or 0
    else
        tradeSnapshot.givenMoney = givenMoney or 0
    end

    if type(gotMoney) == "string" then
        tradeSnapshot.gotMoney = tonumber(gotMoney) or 0
    else
        tradeSnapshot.gotMoney = gotMoney or 0
    end

end

-- 거래 메시지 생성
local function FormatTradeMessage()
    if not tradePartnerName then
        return nil
    end

    local myName = UnitName("player")
    local givenItemsStr = #tradeSnapshot.givenItems > 0 and table.concat(tradeSnapshot.givenItems, ", ") or "없음"
    local gotItemsStr = #tradeSnapshot.gotItems > 0 and table.concat(tradeSnapshot.gotItems, ", ") or "없음"
    local givenMoneyStr = FormatMoney(tradeSnapshot.givenMoney)
    local gotMoneyStr = FormatMoney(tradeSnapshot.gotMoney)

    -- 메시지 조합
    local givenParts = {}
    if givenItemsStr ~= "없음" then table.insert(givenParts, givenItemsStr) end
    if givenMoneyStr ~= "" then table.insert(givenParts, givenMoneyStr) end
    local givenTotal = #givenParts > 0 and table.concat(givenParts, ", ") or "없음"

    local gotParts = {}
    if gotItemsStr ~= "없음" then table.insert(gotParts, gotItemsStr) end
    if gotMoneyStr ~= "" then table.insert(gotParts, gotMoneyStr) end
    local gotTotal = #gotParts > 0 and table.concat(gotParts, ", ") or "없음"

    -- 거래 방향에 따른 메시지 분기
    local message
    if gotTotal ~= "없음" and givenTotal == "없음" then
        -- 받기만 한 경우
        message = string.format(
            "[거래] %s님께서 %s 주셨습니다.",
            tradePartnerName,
            gotTotal
        )
    elseif gotTotal == "없음" and givenTotal ~= "없음" then
        -- 주기만 한 경우
        message = string.format(
            "[거래] %s님께 %s 전달했습니다.",
            tradePartnerName,
            givenTotal
        )
    else
        -- 양방향 거래 - 메시지 길이 체크
        local fullMessage = string.format(
            "[거래] %s님과 거래 완료! (받음: %s / 드림: %s)",
            tradePartnerName,
            gotTotal,
            givenTotal
        )

        -- WoW 메시지 길이 제한 (대략 255자)
        if string.len(fullMessage) > 240 then
            -- 아이템 목록을 줄여서 표시
            local shortGotItems = {}
            local shortGivenItems = {}
            local gotMoneyStr = FormatMoney(tradeSnapshot.gotMoney)
            local givenMoneyStr = FormatMoney(tradeSnapshot.givenMoney)

            -- 받은 아이템 최대 3개까지만 표시
            for i = 1, math.min(3, #tradeSnapshot.gotItems) do
                table.insert(shortGotItems, tradeSnapshot.gotItems[i])
            end
            if #tradeSnapshot.gotItems > 3 then
                table.insert(shortGotItems, string.format("외 %d개", #tradeSnapshot.gotItems - 3))
            end

            -- 준 아이템 최대 2개까지만 표시
            for i = 1, math.min(2, #tradeSnapshot.givenItems) do
                table.insert(shortGivenItems, tradeSnapshot.givenItems[i])
            end
            if #tradeSnapshot.givenItems > 2 then
                table.insert(shortGivenItems, string.format("외 %d개", #tradeSnapshot.givenItems - 2))
            end

            -- 짧은 버전 조합
            local shortGotParts = {}
            if #shortGotItems > 0 then
                table.insert(shortGotParts, table.concat(shortGotItems, ", "))
            end
            if gotMoneyStr ~= "" then
                table.insert(shortGotParts, gotMoneyStr)
            end
            local shortGotTotal = #shortGotParts > 0 and table.concat(shortGotParts, ", ") or "없음"

            local shortGivenParts = {}
            if #shortGivenItems > 0 then
                table.insert(shortGivenParts, table.concat(shortGivenItems, ", "))
            end
            if givenMoneyStr ~= "" then
                table.insert(shortGivenParts, givenMoneyStr)
            end
            local shortGivenTotal = #shortGivenParts > 0 and table.concat(shortGivenParts, ", ") or "없음"

            message = string.format(
                "[거래] %s님과 거래 완료! (받음: %s / 드림: %s)",
                tradePartnerName,
                shortGotTotal,
                shortGivenTotal
            )
        else
            message = fullMessage
        end
    end

    return message
end

-- 파티 자동 인사
local partyGreetCooldown = {}  -- 중복 인사 방지용 쿨다운
local hasGreetedMyJoin = false  -- 내가 이미 인사했는지

-- 내가 파티에 참가할 때 인사
local function SendMyJoinGreeting()
    if not FoxChatDB or not FoxChatDB.autoPartyGreetMyJoin then return end
    if not FoxChatDB.partyGreetMyJoinMessages or #FoxChatDB.partyGreetMyJoinMessages == 0 then return end
    if hasGreetedMyJoin then return end  -- 이미 인사했으면 스킵

    -- 유효한 메시지만 필터링 (공백 제거)
    local validMessages = {}
    for _, msg in ipairs(FoxChatDB.partyGreetMyJoinMessages) do
        local trimmed = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(validMessages, msg)
        end
    end

    if #validMessages == 0 then return end  -- 유효한 메시지가 없으면 중단

    hasGreetedMyJoin = true

    -- 랜덤 메시지 선택
    local message = validMessages[math.random(#validMessages)]

    -- 변수 치환
    local myName = UnitName("player")
    message = string.gsub(message, "{me}", myName)

    -- 파티 채팅으로 전송 (약간의 딜레이)
    C_Timer.After(1, function()
        SendChatMessage(message, "PARTY")
    end)

    -- 30초 후 플래그 리셋 (재입장 시 인사 가능)
    C_Timer.After(30, function()
        hasGreetedMyJoin = false
    end)
end

-- 다른 사람이 파티에 참가할 때 인사
local function SendOthersJoinGreeting(targetName)
    if not FoxChatDB or not FoxChatDB.autoPartyGreetOthersJoin then return end
    if not FoxChatDB.partyGreetOthersJoinMessages or #FoxChatDB.partyGreetOthersJoinMessages == 0 then return end
    if not targetName or targetName == "" then return end

    -- 유효한 메시지만 필터링 (공백 제거)
    local validMessages = {}
    for _, msg in ipairs(FoxChatDB.partyGreetOthersJoinMessages) do
        local trimmed = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(validMessages, msg)
        end
    end

    if #validMessages == 0 then return end  -- 유효한 메시지가 없으면 중단

    -- 쿨다운 체크 (10초)
    local now = GetTime()
    if targetName and partyGreetCooldown[targetName] and (now - partyGreetCooldown[targetName]) < 10 then
        return
    end
    if targetName then
        partyGreetCooldown[targetName] = now
    end

    -- 랜덤 메시지 선택
    local message = validMessages[math.random(#validMessages)]

    -- 변수 치환
    message = string.gsub(message, "{target}", targetName)

    -- 파티 채팅으로 전송 (약간의 딜레이)
    C_Timer.After(1.5, function()
        SendChatMessage(message, "PARTY")
    end)
end

-- 자동 수리 알림
local lastRepairWarning = 0
local repairWarningCooldown = 300  -- 5분 쿨다운

local function CheckDurability()
    if not FoxChatDB or not FoxChatDB.autoRepairAlert then return end

    local threshold = (FoxChatDB.repairThreshold or 30) / 100
    local lowestDurability = 1.0
    local needsRepair = false
    local brokenItems = {}

    -- 각 장비 슬롯 확인
    for i = 1, 18 do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 then
            local percent = current / max
            if percent < lowestDurability then
                lowestDurability = percent
            end
            if percent <= threshold then
                needsRepair = true
                local itemLink = GetInventoryItemLink("player", i)
                if itemLink then
                    table.insert(brokenItems, string.format("%s (%.0f%%)", itemLink, percent * 100))
                end
            end
        end
    end

    -- 경고 메시지 전송
    if needsRepair then
        local now = GetTime()
        if (now - lastRepairWarning) > repairWarningCooldown then
            lastRepairWarning = now

            local message = string.format("|cFFFF0000[수리 필요]|r 내구도가 %.0f%% 이하입니다!", lowestDurability * 100)

            -- 파티/레이드 중이면 해당 채팅에 알림
            if IsInRaid() then
                SendChatMessage(message, "RAID")
            elseif IsInGroup() then
                SendChatMessage(message, "PARTY")
            else
                -- 혼자일 때는 시스템 메시지로 표시
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r " .. message)
            end

            -- 손상된 아이템 목록 표시 (로컬)
            if #brokenItems > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 손상된 장비: " .. table.concat(brokenItems, ", "))
            end
        end
    end
end


-- 이벤트 핸들러 추가
local autoEventFrame = CreateFrame("Frame")
autoEventFrame:RegisterEvent("TRADE_SHOW")
autoEventFrame:RegisterEvent("TRADE_REQUEST")  -- 거래 요청 받음
autoEventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
autoEventFrame:RegisterEvent("TRADE_CLOSED")
autoEventFrame:RegisterEvent("TRADE_REQUEST_CANCEL")  -- 거래 취소 처리
autoEventFrame:RegisterEvent("UI_INFO_MESSAGE")  -- 거래 완료 메시지 감지
autoEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
autoEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoEventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
autoEventFrame:RegisterEvent("PARTY_INVITE_REQUEST")  -- 파티 초대 받음

local lastGroupSize = 0
local partyMembers = {}  -- 현재 파티 멤버 추적
local wasInvited = false  -- 초대받았는지 여부

autoEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SHOW" or event == "TRADE_REQUEST" then

        -- TRADE_REQUEST 이벤트일 때 요청자 정보 확인
        if event == "TRADE_REQUEST" then
            local requester = ...
            -- 요청자가 있으면 바로 파트너로 저장
            if requester and requester ~= "" then
                tradePartnerName = NormalizeName(requester)
            end
        end

        -- 거래창 열림: 상태 초기화 및 상대 이름 확보
        tradePlayerAccepted = false
        tradeTargetAccepted = false
        tradeWillComplete = false  -- 초기화

        -- TRADE_SHOW일 때만 이름 다시 확인 (이미 TRADE_REQUEST에서 설정했을 수도 있음)
        if event == "TRADE_SHOW" then
            local resolvedName = NormalizeName(ResolvePartnerName())
            if resolvedName then
                tradePartnerName = resolvedName
            end
        end

        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 시작 - 상대: " .. (tradePartnerName or "알 수 없음"))
        end

        -- 거래 시작 시 0.5초 후 초기 백업 (거래창 로드 대기)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                if tradePartnerName then
                    SnapshotTradeData()  -- 초기 스냅샷
                    local tradeMessage = FormatTradeMessage()
                    if tradeMessage then
                        lastTradePartnerName = tradePartnerName
                        lastTradeMessage = tradeMessage
                    end
                end
            end)
        end

    elseif event == "TRADE_ACCEPT_UPDATE" then
        local arg1, arg2 = ...  -- WoW 클래식에서는 arg1, arg2로 전달됨
        tradePlayerAccepted = (arg1 == 1)
        tradeTargetAccepted = (arg2 == 1)

        -- 파트너 이름이 아직 없으면 다시 시도
        if not tradePartnerName or tradePartnerName == "" then
            local resolvedName = NormalizeName(ResolvePartnerName())
            if resolvedName then
                tradePartnerName = resolvedName
            end
        end

        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 수락 상태 - Player: %d, Target: %d",
                arg1 or 0, arg2 or 0))
        end

        -- 한쪽이라도 수락하면 데이터 스냅샷 및 백업 (WoW Classic 특성)
        if tradePlayerAccepted or tradeTargetAccepted then
            SnapshotTradeData()  -- 스냅샷 갱신

            -- 거래 정보 백업
            local tradeMessage = FormatTradeMessage()
            if tradePartnerName and tradeMessage then
                lastTradePartnerName = tradePartnerName
                lastTradeMessage = tradeMessage
            end
        end

        -- 양쪽 모두 수락 직전에 데이터 스냅샷
        -- 중요: 한 번 (1,1)이 되면 tradeWillComplete를 다시 false로 되돌리지 않음
        if tradePlayerAccepted and tradeTargetAccepted then
            tradeWillComplete = true  -- 거래 성공 예정 플래그 설정 (되돌리지 않음)
            SnapshotTradeData()  -- 최종 스냅샷 갱신

            -- 양쪽 수락 시점에 다시 백업 (최신 데이터로 업데이트)
            local tradeMessage = FormatTradeMessage()
            if tradePartnerName and tradeMessage then
                lastTradePartnerName = tradePartnerName
                lastTradeMessage = tradeMessage
            end

            if FoxChatDB and FoxChatDB.autoTrade then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공 예정 - 데이터 스냅샷 완료")
            end
        end
        -- else 부분 제거: tradeWillComplete를 false로 되돌리지 않음

    elseif event == "TRADE_REQUEST_CANCEL" then

        -- 양쪽 모두 골드를 올려놓았는지 확인
        if tradeSnapshot and tradeSnapshot.givenMoney > 0 and tradeSnapshot.gotMoney > 0 and tradePartnerName then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[FoxChat]|r 양쪽 모두 골드를 올려놓아 거래 실패!")

            -- 거래 실패 메시지 전송
            local failMessage = string.format(
                "[거래 실패] %s님, 양쪽 모두 골드를 올려놓으면 거래가 불가능합니다. (나: %s / 상대: %s)",
                tradePartnerName,
                FormatMoney(tradeSnapshot.givenMoney),
                FormatMoney(tradeSnapshot.gotMoney)
            )

            -- 로컬 변수로 저장
            local targetName = tradePartnerName
            local msgToSend = failMessage

            -- 지연 후 전송 (안정성)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    if targetName and msgToSend then
                        SendChatMessage(msgToSend, "WHISPER", nil, targetName)
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. targetName)
                    end
                end)
            else
                SendChatMessage(failMessage, "WHISPER", nil, tradePartnerName)
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. tradePartnerName)
            end
        end

        -- 거래 취소 명시
        tradeWillComplete = false
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 취소 이벤트")
        end

    elseif event == "TRADE_CLOSED" then
        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 거래 종료 - 성공예정=%s, 파트너=%s",
                tostring(tradeWillComplete), tostring(tradePartnerName)))
        end

        -- 양쪽 모두 골드를 올려놓았는지 먼저 확인 (거래 실패 케이스)
        if tradeSnapshot and tradeSnapshot.givenMoney > 0 and tradeSnapshot.gotMoney > 0 and tradePartnerName then
            -- 거래가 실패한 경우
            local failMessage = string.format(
                "[거래 실패] %s님, 양쪽 모두 골드를 올려놓으면 거래가 불가능합니다. (나: %s / 상대: %s)",
                tradePartnerName,
                FormatMoney(tradeSnapshot.givenMoney),
                FormatMoney(tradeSnapshot.gotMoney)
            )

            -- 로컬 변수로 저장
            local targetName = tradePartnerName
            local msgToSend = failMessage

            -- 지연 후 전송 (안정성)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    if targetName and msgToSend then
                        SendChatMessage(msgToSend, "WHISPER", nil, targetName)
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. targetName)
                    end
                end)
            else
                SendChatMessage(failMessage, "WHISPER", nil, tradePartnerName)
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. tradePartnerName)
            end

            -- 상태 초기화하고 종료
            tradePlayerAccepted = false
            tradeTargetAccepted = false
            tradeWillComplete = false
            tradePartnerName = nil
            tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }
            return
        end

        -- 거래 성공 판단 (tradeWillComplete 플래그 확인)
        if tradeWillComplete and tradePartnerName then
            local tradeMessage = FormatTradeMessage()

            -- 거래 정보 백업 (UI_INFO_MESSAGE에서 사용하기 위해)
            lastTradePartnerName = tradePartnerName
            lastTradeMessage = tradeMessage

            -- 디버그 메시지는 토글
            if FoxChatDB and FoxChatDB.autoTrade then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공!")
                if tradeMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 전송 예정 메시지: " .. tradeMessage)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✗ 메시지 생성 실패")
                end
            end

            -- 귓속말 전송은 토글과 무관하게 작동 (기능 자체가 항상 작동)
            if tradeMessage and tradeMessage ~= "" then
                -- 중복 전송 방지: 3초 이내에 같은 메시지를 전송했다면 스킵
                local currentTime = GetTime()
                if lastTradeSentTime and (currentTime - lastTradeSentTime) < 3 then
                    return
                end

                -- 양방향 거래든 일방향 거래든 무조건 메시지 전송
                -- (상대가 애드온 있으면 둘 다 보내지만, 없으면 나만 보냄)

                -- 로컬 변수로 저장 (클로저를 위해)
                local targetName = tradePartnerName
                local msgToSend = tradeMessage
                -- 약간의 지연을 두고 전송 (안정성)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.1, function()
                        -- 타이머 실행 시점에서도 중복 체크
                        local now = GetTime()
                        if lastTradeSentTime and (now - lastTradeSentTime) < 3 then
                            return
                        end

                        if targetName and msgToSend then
                            SendChatMessage(msgToSend, "WHISPER", nil, targetName)
                            lastTradeSentTime = GetTime()  -- 전송 시간 기록
                            if FoxChatDB and FoxChatDB.autoTrade then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 귓속말 전송 완료: " .. targetName)
                            end
                        else
                        end
                    end)
                else
                    SendChatMessage(tradeMessage, "WHISPER", nil, tradePartnerName)
                    lastTradeSentTime = GetTime()  -- 전송 시간 기록
                    if FoxChatDB and FoxChatDB.autoTrade then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 귓속말 전송 완료: " .. tradePartnerName)
                    end
                end
            else
            end
        else
            if FoxChatDB and FoxChatDB.autoTrade then
                if not tradeWillComplete then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 취소 또는 실패")
                elseif not tradePartnerName then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 상대 이름 식별 실패")
                end
            end
        end

        -- 상태 초기화
        tradePlayerAccepted = false
        tradeTargetAccepted = false
        tradeWillComplete = false
        tradePartnerName = nil
        tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }

    elseif event == "UI_INFO_MESSAGE" then
        -- UI 메시지 이벤트 (거래 완료 메시지 포함)
        local messageType, message = ...

        -- 거래 완료 메시지 감지 (영어 및 한국어)
        if message and (string.find(message, "Trade complete") or string.find(message, "거래 완료") or
                       string.find(message, "거래가 완료") or string.find(message, "교역 완료")) then

            -- 중복 전송 방지: 3초 이내에 이미 전송했다면 스킵
            local currentTime = GetTime()
            if lastTradeSentTime and (currentTime - lastTradeSentTime) < 3 then
                -- 정보만 초기화
                tradePlayerAccepted = false
                tradeTargetAccepted = false
                tradeWillComplete = false
                tradePartnerName = nil
                tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }
                lastTradePartnerName = nil
                lastTradeMessage = nil
                return
            end

            -- 현재 거래 정보가 있으면 우선 사용
            if tradePartnerName and tradeWillComplete then
                SnapshotTradeData()  -- 마지막 스냅샷
                local tradeMessage = FormatTradeMessage()
                if tradeMessage and tradeMessage ~= "" then
                    SendChatMessage(tradeMessage, "WHISPER", nil, tradePartnerName)
                    lastTradeSentTime = GetTime()  -- 전송 시간 기록
                    if FoxChatDB and FoxChatDB.autoTrade then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 거래 완료 - 귓속말 전송: " .. tradePartnerName)
                    end
                end
                -- 사용 후 초기화
                tradePlayerAccepted = false
                tradeTargetAccepted = false
                tradeWillComplete = false
                tradePartnerName = nil
                tradeSnapshot = { givenItems = {}, gotItems = {}, givenMoney = 0, gotMoney = 0 }
                lastTradePartnerName = nil
                lastTradeMessage = nil

            -- 백업된 거래 정보 사용
            elseif lastTradePartnerName and lastTradeMessage and lastTradeMessage ~= "" then
                SendChatMessage(lastTradeMessage, "WHISPER", nil, lastTradePartnerName)
                lastTradeSentTime = GetTime()  -- 전송 시간 기록
                if FoxChatDB and FoxChatDB.autoTrade then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 거래 완료 - 귓속말 전송: " .. lastTradePartnerName)
                end
                -- 백업 정보 초기화
                lastTradePartnerName = nil
                lastTradeMessage = nil

            else
            end
        end

    elseif event == "PARTY_INVITE_REQUEST" then
        -- 파티 초대를 받았을 때
        wasInvited = true
        -- 10초 후 플래그 리셋 (초대를 거절했을 경우를 위해)
        C_Timer.After(10, function()
            if not IsInGroup() then
                wasInvited = false
            end
        end)

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- 파티 멤버 변경 감지
        local currentSize = GetNumGroupMembers()

        if IsInGroup() and not IsInRaid() then
            if lastGroupSize == 0 and currentSize > 0 then
                -- 내가 파티에 참가함 (초대받아서 들어간 경우만)
                if wasInvited then
                    SendMyJoinGreeting()
                    wasInvited = false  -- 플래그 리셋
                end

                -- 현재 파티 멤버 목록 초기화
                wipe(partyMembers)
                for i = 1, currentSize - 1 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local name = UnitName(unit)
                        if name and name ~= "" then
                            partyMembers[name] = true
                        end
                    end
                end
            elseif currentSize > lastGroupSize and lastGroupSize > 0 then
                -- 다른 사람이 파티에 참가함
                -- 약간의 딜레이 후 새 멤버 찾기 (파티 정보 업데이트 대기)
                C_Timer.After(0.5, function()
                    if IsInGroup() and not IsInRaid() then
                        local newMembers = {}

                        -- 현재 파티 멤버 확인
                        for i = 1, GetNumGroupMembers() - 1 do
                            local unit = "party" .. i
                            if UnitExists(unit) then
                                local name = UnitName(unit)
                                if name and name ~= "" and not partyMembers[name] then
                                    -- 새 멤버 발견
                                    table.insert(newMembers, name)
                                    partyMembers[name] = true
                                end
                            end
                        end

                        -- 새 멤버들에게 인사
                        for _, memberName in ipairs(newMembers) do
                            SendOthersJoinGreeting(memberName)
                        end
                    end
                end)
            elseif currentSize < lastGroupSize then
                -- 누군가 파티를 떠남 - 멤버 목록 업데이트
                local currentMembers = {}
                for i = 1, currentSize - 1 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local name = UnitName(unit)
                        if name and name ~= "" then
                            currentMembers[name] = true
                        end
                    end
                end
                partyMembers = currentMembers
            end
        else
            -- 파티가 아니면 멤버 목록 초기화
            wipe(partyMembers)
            -- 파티에서 나갔을 때 플래그 리셋
            if lastGroupSize > 0 and currentSize == 0 then
                wasInvited = false
                hasGreetedMyJoin = false  -- 인사 플래그도 리셋
            end
        end

        lastGroupSize = currentSize

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 접속 시 내구도 체크
        C_Timer.After(5, CheckDurability)

    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        -- 내구도 변경 시 체크
        CheckDurability()
    end
end)