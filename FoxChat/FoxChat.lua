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
        TRADE = {r = 0.8, g = 0.4, b = 1}, -- 거래: 보라색
    },
    highlightStyle = "both", -- "bold", "color", "both"
    channelGroups = {
        GUILD = true,
        PUBLIC = true,
        PARTY_RAID = true,
        LFG = true,
        TRADE = true,
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
        x = 0,  -- X축 오프셋 (0 = 중앙, 좌측 = 음수, 우측 = 양수)
        y = -300,  -- Y축 오프셋 (0 = 중앙, 위 = 음수, 아래 = 양수)
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
    -- 자동 탭 설정
    -- 거래 자동 귓속말
    autoTrade = true,  -- 거래 완료 시 자동 귓속말
    -- 파티 자동 인사
    autoPartyGreetMyJoin = false,  -- 내가 파티 참가 시 자동 인사
    autoPartyGreetOthersJoin = false,  -- 다른 사람 파티 참가 시 자동 인사
    partyGreetMyJoinMessages = {
        "안녕하세요! {me}입니다. 잘 부탁드려요!",
        "반갑습니다~ 함께 모험해요!",
        "파티 초대 감사합니다!"
    },
    partyGreetOthersJoinMessages = {
        "{target}님 환영합니다!",
        "{target}님 반갑습니다~",
        "어서오세요 {target}님!"
    },
    -- 리더 전용 인사말 (여러 줄 전체 출력)
    leaderGreetRaidMessages = "",  -- 내가 공대장일 때 인사말
    leaderGreetPartyMessages = "",  -- 내가 파티장일 때 인사말
    -- AFK/DND/전투/인던 자동응답
    autoReplyAFK = false,  -- AFK/DND 시 자동응답
    autoReplyCombat = false,  -- 전투 중 자동응답
    autoReplyInstance = false,  -- 인던 중 자동응답
    combatReplyMessage = "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!",
    instanceReplyMessage = "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!",
    autoReplyCooldown = 5,  -- 자동응답 쿨다운 (분)
    -- 주사위 자동 집계
    rollTrackerEnabled = false,  -- 주사위 자동 집계 사용
    rollSessionDuration = 20,  -- 집계 시간 (초)
    rollTopK = 0,  -- 0이면 우승자만, 양수면 상위 N명
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

-- 디버그 모드는 이벤트 핸들러 등록 후 설정

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
    -- 디버그: 키워드 업데이트 후 개수 출력
    local count = 0
    for _ in pairs(keywords) do count = count + 1 end
    if debugMode then
        print(string.format("|cFF00FFFF[FoxChat] 키워드 업데이트됨: %d개|r", count))
    end
end

-- 무시 키워드 업데이트
local function UpdateIgnoreKeywords()
    ParseKeywords(FoxChatDB.ignoreKeywords, ignoreKeywords)
    -- 디버그: 무시 키워드 업데이트 후 개수 출력
    local count = 0
    for _ in pairs(ignoreKeywords) do count = count + 1 end
    if debugMode then
        print(string.format("|cFFFF00FF[FoxChat] 무시 키워드 업데이트됨: %d개|r", count))
    end
end

-- 활성화된 토스트들의 위치를 재정렬
local function RepositionToasts()
    local xOffset = (FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0
    local baseYOffset = (FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.y) or -300

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
        -- 풀에서 가져온 프레임도 현재 설정 위치로 초기 위치 설정
        f:ClearAllPoints()
        local xOffset = (FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.x) or 0
        local yOffset = (FoxChatDB and FoxChatDB.toastPosition and FoxChatDB.toastPosition.y) or -300
        f:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
        return f
    end

    -- 새 프레임 생성
    f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    f:SetWidth(450)  -- 고정 너비, 높이는 동적으로 조정
    -- 초기 위치는 RepositionToasts에서 설정됨
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
    -- SetStartDelay는 ShowToast에서 동적으로 설정됨
    f.fadeOut = fadeOut  -- 참조 저장

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

    -- 토스트 표시 시간 동적 설정
    local toastDuration = (FoxChatDB and FoxChatDB.toastDuration) or 5
    if f.fadeOut then
        f.fadeOut:SetStartDelay(toastDuration - 0.5)  -- 토스트 표시 시간 - 페이드 아웃 시간
    end

    -- 표시
    f:Show()
    f.animIn:Play()
    f.animOut:Play()
end

-- 채널 타입을 그룹으로 매핑 (하위 호환성을 위해 유지)
local function GetChannelGroup(channelType, channelName)
    -- LFG 채널 디버그 출력 (비활성화 - 너무 자주 호출됨)
    --[[
    if channelType == "CHANNEL" and channelName then
        print(string.format("|cFF00FFFF[GetChannelGroup DEBUG]|r Type: %s, Name: %s",
            channelType or "nil",
            channelName or "nil"))
    end
    --]]

    -- 새로운 채널 필터 모듈 사용
    if addon.ChannelFilter then
        local result = addon.ChannelFilter:GetChannelGroup(channelType, channelName)
        --[[
        if channelType == "CHANNEL" and channelName then
            print(string.format("|cFF00FFFF[GetChannelGroup DEBUG]|r ChannelFilter result: %s", result or "nil"))
        end
        --]]
        return result
    end

    -- 폴백: 기존 로직
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

    -- 해당 채널이 활성화되어 있는지 확인
    -- 간단하게 처리 (무한 루프 방지)
    if not FoxChatDB.filterEnabled then
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
    else
        -- 콜론이 없는 경우 (테스트 메시지 등) 전체를 메시지로 처리
        msgContent = message
        prefix = ""
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
        -- 모든 채널의 말머리를 확인해서 제거 (필터링을 위해)
        local prefixRemoved = false
        if FoxChatDB.channelPrefixSuffix then
            for _, channelData in pairs(FoxChatDB.channelPrefixSuffix) do
                local myPrefix = channelData.prefix or ""
                if myPrefix ~= "" and not prefixRemoved then
                    -- 메시지 앞의 공백 제거
                    local trimmedMsg = string.gsub(msgContentForCheck, "^%s*", "")
                    -- 말머리와 정확히 일치하는지 확인
                    if string.sub(trimmedMsg, 1, string.len(myPrefix)) == myPrefix then
                        msgContentForCheck = string.sub(trimmedMsg, string.len(myPrefix) + 1)
                        -- 말머리 뒤의 공백도 제거
                        msgContentForCheck = string.gsub(msgContentForCheck, "^%s*", "")
                        prefixRemoved = true
                        if debugMode then
                        end
                    end
                end
            end
        end

        -- 메시지 끝 부분이 말꼬리와 일치하면 제거 (공백 포함하여 비교)
        local mySuffix = FoxChatDB.suffix or ""
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

    -- 채널별 키워드 가져오기 (ChannelFilter 모듈 사용)
    -- channelGroup을 실제 채널 타입으로 변환
    local channelType, channelName = nil, nil
    if channelGroup == "LFG" then
        channelType = "CHANNEL"
        channelName = "파티찾기"
    elseif channelGroup == "TRADE" then
        channelType = "CHANNEL"
        channelName = "거래"
    elseif channelGroup == "GUILD" then
        channelType = "GUILD"
    elseif channelGroup == "PARTY_RAID" then
        channelType = "PARTY"
    elseif channelGroup == "PUBLIC" then
        channelType = "SAY"
    else
        channelType = channelGroup
    end

    local keywords = {}
    local ignoreKeywords = {}

    -- 안전하게 키워드 가져오기
    if addon.ChannelFilter then
        keywords = addon.ChannelFilter:GetKeywords(channelType, channelName) or {}
        ignoreKeywords = addon.ChannelFilter:GetIgnoreKeywords(channelType, channelName) or {}
    end

    -- 디버그: 키워드 개수 확인
    local count = 0
    for _ in pairs(keywords) do count = count + 1 end

    -- 디버그 모드에서만 출력
    if debugMode then
        print(string.format("|cFFFF00FF[HighlightKeywords]|r 채널: %s, 키워드 %d개", channelGroup or "nil", count))

        -- "수도원" 키워드 확인
        if string.find(msgContentForCheck or message, "수도원") then
            print("|cFF00FF00[HighlightKeywords]|r 메시지에 '수도원' 발견!")
            local hasMonastery = false
            for k, v in pairs(keywords) do
                if k == "수도원" or v == "수도원" then
                    hasMonastery = true
                    print(string.format("|cFF00FF00[HighlightKeywords]|r 키워드 테이블에 '수도원' 있음!"))
                    print(string.format("    키(k): [%s] (길이:%d)", k, string.len(k)))
                    print(string.format("    값(v): [%s] (길이:%d)", v, string.len(v)))

                    -- 직접 매칭 테스트
                    local test1 = string.find(lowerMsgContent, k, 1, true)
                    local test2 = string.find(msgContentForCheck, v, 1, true)
                    print(string.format("    lowerMsgContent에서 k 검색: %s", test1 and "찾음" or "못찾음"))
                    print(string.format("    msgContentForCheck에서 v 검색: %s", test2 and "찾음" or "못찾음"))
                    break
                end
            end
            if not hasMonastery then
                print("|cFFFF0000[HighlightKeywords]|r 키워드 테이블에 '수도원' 없음!")
            end
        end
    end

    -- 먼저 작성자가 무시 키워드와 일치하는지 확인
    local authorLower = author and string.lower(author) or ""
    -- 서버명 제거 (하이픈 뒤의 모든 내용 제거)
    local authorClean = authorLower
    local hyphenPos = string.find(authorLower, "%-")
    if hyphenPos then
        authorClean = string.sub(authorLower, 1, hyphenPos - 1)
    end

    -- 작성자 닉네임이 무시 키워드 중 하나와 일치하는지 확인
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if lowerIgnore == authorLower or lowerIgnore == authorClean then
            -- 닉네임이 무시 키워드와 일치하면 필터링하지 않음
            return message, false
        end
    end

    -- 메시지 내용에 무시 키워드가 있는지 체크
    for lowerIgnore, originalIgnore in pairs(ignoreKeywords) do
        if string.find(lowerMsgContent, lowerIgnore, 1, true) then
            -- 디버그: 무시 키워드 매칭
            if debugMode then
                print(string.format("|cFFFF00FF[FoxChat] 무시할 문구 '%s'가 발곬됨. 필터링 건너뜀.|r", originalIgnore))
            end
            -- 메시지에 무시 키워드가 있으면 필터링하지 않음
            return message, false
        end
    end

    -- 하이라이트 색상 설정
    local color = (FoxChatDB.highlightColors and FoxChatDB.highlightColors[channelGroup]) or defaults.highlightColors[channelGroup]
    local colorCode = string.format("|cff%02x%02x%02x",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255))

    -- 모든 매칭된 키워드를 수집
    local matchedKeywords = {}
    for lowerKeyword, originalKeyword in pairs(keywords) do
        -- 메시지에서 이 키워드의 모든 위치를 찾기 (첫 번째만 찾기로 단순화)
        -- lowerKeyword가 실제로 소문자가 아닐 수 있음 (한글의 경우)
        -- 따라서 lowerMsgContent와 원본 메시지 모두에서 찾아봄
        local startPos, endPos = string.find(lowerMsgContent, lowerKeyword, 1, true)

        -- 한글 키워드는 대소문자 변환이 안되므로 원본에서도 찾아봄
        if not startPos then
            startPos, endPos = string.find(msgContentForCheck, originalKeyword, 1, true)
        end

        if startPos then
            -- 실제 텍스트 추출 (msgContentForCheck에서 찾은 위치를 사용)
            local actualKeyword = string.sub(msgContentForCheck, startPos, endPos)
            table.insert(matchedKeywords, {
                start = startPos,
                finish = endPos,
                text = actualKeyword
            })
            foundKeyword = true
        end
    end

    -- 찾은 키워드들을 역순으로 정렬 (뒤에서부터 치환하기 위해)
    table.sort(matchedKeywords, function(a, b) return a.start > b.start end)

    -- 각 키워드를 하이라이트
    -- msgContentForCheck에서 찾은 키워드를 하이라이트
    local highlightedContent = msgContentForCheck
    for _, match in ipairs(matchedKeywords) do
        local beforeText = string.sub(highlightedContent, 1, match.start - 1)
        local keywordText = match.text
        local afterText = string.sub(highlightedContent, match.finish + 1)

        local highlightedKeyword = ""
        if FoxChatDB.highlightStyle == "bold" then
            highlightedKeyword = "|cffffffff" .. keywordText .. "|r"
        elseif FoxChatDB.highlightStyle == "color" then
            highlightedKeyword = colorCode .. keywordText .. "|r"
        else -- both
            highlightedKeyword = colorCode .. keywordText .. "|r"
        end

        highlightedContent = beforeText .. highlightedKeyword .. afterText
    end

    -- 하이라이트된 내용을 msgContent에 할당
    msgContent = highlightedContent

    -- 디버그: 키워드 매칭
    if debugMode and foundKeyword then
        print(string.format("|cFF00FFFF[FoxChat] %d개 키워드 매칭!|r", #matchedKeywords))
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
            -- 디버그 모드에서만 수도원 메시지 출력
            if debugMode and string.find(text, "수도원") then
                print(string.format("|cFF00FF00[HookChatFrame]|r '수도원' 메시지 감지!"))

                -- 채널 링크 패턴 찾기
                local channelLink = string.match(text, "|Hchannel:([^|]+)|h")
                if channelLink then
                    print(string.format("  채널 링크: %s", channelLink))
                end
            end

            -- 메시지에서 채널 타입 추측
            local channelGroup = nil

            -- 채널 링크에서 정확한 채널 정보 추출
            local channelLink = string.match(text, "|Hchannel:([^|]+)|h")

            -- 길드 메시지 패턴
            if string.find(text, "|Hchannel:GUILD") or string.find(text, "|Hchannel:길드") then
                channelGroup = "GUILD"
            -- 파티/공격대 메시지 패턴
            elseif string.find(text, "|Hchannel:PARTY") or string.find(text, "|Hchannel:RAID") or
                   string.find(text, "|Hchannel:파티") or string.find(text, "|Hchannel:공격대") then
                channelGroup = "PARTY_RAID"
            -- LFG 채널 패턴 - 채널 링크 확인 (channel:숫자 형식)
            elseif channelLink then
                -- 채널 링크가 있으면 채널 번호나 이름 확인
                -- 파티찾기는 보통 channel:4, 거래는 channel:2 또는 channel:채널명 형태
                local isLFG = false
                local isTrade = false

                -- 채널 번호가 2인지 확인 (거래 채널)
                if channelLink == "2" or
                   channelLink == "channel2" or
                   channelLink == "CHANNEL:2" or
                   string.find(channelLink, "^channel:?2$") or
                   string.find(channelLink, "^CHANNEL:?2$") then
                    isTrade = true
                end

                -- 채널 번호가 4인지 확인 (파티찾기 채널)
                if channelLink == "4" or
                   channelLink == "channel4" or
                   channelLink == "CHANNEL:4" or
                   string.find(channelLink, "^channel:?4$") or
                   string.find(channelLink, "^CHANNEL:?4$") then
                    isLFG = true
                end

                -- GetChannelName API를 사용하여 실제 채널명 확인
                local _, channelName2 = GetChannelName(2)
                if channelName2 and (string.find(channelName2, "거래") or
                                    string.find(channelName2, "Trade")) then
                    -- 2번 채널이 거래 채널이고, 현재 메시지가 2번 채널이면
                    if channelLink and (channelLink == "2" or string.find(channelLink, "2")) then
                        isTrade = true
                    end
                end

                local _, channelName4 = GetChannelName(4)
                if channelName4 and (string.find(channelName4, "파티찾기") or
                                    string.find(channelName4, "LookingForGroup")) then
                    -- 4번 채널이 파티찾기 채널이고, 현재 메시지가 4번 채널이면
                    if channelLink and (channelLink == "4" or string.find(channelLink, "4")) then
                        isLFG = true
                    end
                end

                -- 텍스트에서 거래 관련 패턴 확인
                if string.find(text, "거래") or
                   string.find(text, "Trade") or
                   string.find(text, "%[2%. ") or  -- [2. 거래] 패턴
                   string.find(text, "%[거래%]") then  -- [거래] 패턴
                    isTrade = true
                end

                -- 텍스트에서 파티찾기 관련 패턴 확인
                if string.find(text, "파티찾기") or
                   string.find(text, "LookingForGroup") or
                   string.find(text, "%[4%. ") or  -- [4. 파티찾기] 패턴
                   string.find(text, "%[파티찾기%]") then  -- [파티찾기] 패턴
                    isLFG = true
                end

                -- 채널 표시명에서도 확인
                local channelDisplay = string.match(text, "|h%[([^%]]+)%]|h")
                if channelDisplay then
                    if string.find(channelDisplay, "거래") or
                       string.find(channelDisplay, "Trade") or
                       string.find(channelDisplay, "^2%. ") or
                       string.find(channelDisplay, "^2 %. ") or
                       channelDisplay == "2" then
                        isTrade = true
                    elseif string.find(channelDisplay, "파티찾기") or
                           string.find(channelDisplay, "LookingForGroup") or
                           string.find(channelDisplay, "^4%. ") or
                           string.find(channelDisplay, "^4 %. ") or
                           channelDisplay == "4" then
                        isLFG = true
                    end
                end

                if isTrade then
                    channelGroup = "TRADE"
                elseif isLFG then
                    channelGroup = "LFG"
                else
                    -- 다른 번호 채널은 PUBLIC으로 분류
                    channelGroup = "PUBLIC"
                end
            -- 일반/외침 메시지 (다양한 패턴 확인)
            elseif string.find(text, "|Hchannel:SAY") or string.find(text, "|Hchannel:YELL") or
                   string.find(text, "|Hchannel:일반") or string.find(text, "|Hchannel:외침") or
                   string.find(text, "%[일반") or string.find(text, "%[외침") or
                   string.find(text, "%[공개") then
                channelGroup = "PUBLIC"
            -- 플레이어 링크만 있고 채널 링크가 없는 경우 (일반적으로 일반/외침 채팅)
            elseif not channelLink and string.find(text, "|Hplayer:") then
                -- 길드나 파티 메시지가 아닌 경우 PUBLIC으로 분류
                if not string.find(text, "%[길드%]") and
                   not string.find(text, "%[파티%]") and
                   not string.find(text, "%[공격대%]") then
                    channelGroup = "PUBLIC"
                end
            -- 공개 채널 (기본값)
            else
                channelGroup = "PUBLIC"
            end


            -- 채널 그룹이 활성화되어 있는 경우만 하이라이트 (새로운 방식 우선 사용)
            local channelEnabled = false
            if addon.ChannelFilter then
                -- channelGroup을 실제 채널 타입으로 변환
                local channelType, channelName = nil, nil
                if channelGroup == "LFG" then
                    channelType = "CHANNEL"
                    channelName = "파티찾기"
                elseif channelGroup == "TRADE" then
                    channelType = "CHANNEL"
                    channelName = "거래"
                elseif channelGroup == "GUILD" then
                    channelType = "GUILD"
                elseif channelGroup == "PARTY_RAID" then
                    channelType = "PARTY"
                elseif channelGroup == "PUBLIC" then
                    channelType = "SAY"
                end
                channelEnabled = addon.ChannelFilter:IsChannelEnabled(channelType, channelName)
            else
                -- 기존 방식 폴백
                channelEnabled = channelGroup and FoxChatDB.channelGroups and FoxChatDB.channelGroups[channelGroup]
            end

            if channelEnabled then
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

                -- 디버그: HookChatFrame에서 결과 확인
                if debugMode and channelGroup == "LFG" then
                    print(string.format("|cFF00FFFF[HookChatFrame]|r LFG 메시지, found: %s", tostring(found)))
                    if string.find(text, "수도원") then
                        print(string.format("|cFF00FFFF[HookChatFrame]|r '수도원' 발견! found: %s", tostring(found)))

                        -- HighlightKeywords가 제대로 작동하는지 확인
                        local testHighlight, testFound = HighlightKeywords(text, channelGroup, author)
                        print(string.format("|cFF00FFFF[HookChatFrame]|r HighlightKeywords 결과: found=%s", tostring(testFound)))
                    end
                end

                if found then
                    -- 소리 재생 (ring.wav 파일 사용)
                    if FoxChatDB.playSound then
                        PlaySoundFile("Interface\\AddOns\\FoxChat\\ring.wav", "Master")
                    end

                    -- 메시지 내용 추출 (순수 텍스트만)
                    local msgContent = text

                    -- 1. 먼저 플레이어 이름 뒤의 콜론 찾기
                    local colonPos = string.find(text, "]|h:", 1, true)
                    if colonPos then
                        msgContent = string.sub(text, colonPos + 4)  -- "]|h:" 이후부터
                    else
                        -- 대체 패턴: 일반 콜론 찾기
                        colonPos = string.find(text, ":", 1, true)
                        if colonPos then
                            msgContent = string.sub(text, colonPos + 1)
                        end
                    end

                    -- 2. 모든 WoW UI 코드 제거 (|c, |r, |H 등)
                    msgContent = string.gsub(msgContent, "|c%x%x%x%x%x%x%x%x", "")  -- 색상 코드 제거
                    msgContent = string.gsub(msgContent, "|r", "")  -- 리셋 코드 제거
                    msgContent = string.gsub(msgContent, "|H.-|h", "")  -- 하이퍼링크 제거
                    msgContent = string.gsub(msgContent, "|h", "")  -- 남은 |h 제거
                    msgContent = string.gsub(msgContent, "|T.-|t", "")  -- 텍스처 제거

                    -- 3. 앞뒤 공백 제거
                    msgContent = string.gsub(msgContent, "^%s+", "")
                    msgContent = string.gsub(msgContent, "%s+$", "")

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

    -- LFG 채널 디버그 출력 (비활성화 - 너무 많은 출력)
    --[[
    if channelType == "CHANNEL" and channelName then
        print(string.format("|cFFFF00FF[FoxChat DEBUG]|r 채널 메시지 - Type: %s, Name: %s, Message: %s",
            channelType or "nil",
            channelName or "nil",
            (msg and string.sub(msg, 1, 50) .. (string.len(msg) > 50 and "..." or "")) or "nil"))
    end
    --]]

    local channelGroup = GetChannelGroup(channelType, channelName)

    -- 디버그 출력 간소화
    if debugMode and channelName then
        local keywordCount = 0
        for _ in pairs(keywords) do keywordCount = keywordCount + 1 end

        print(string.format("|cFFFFFF00[FoxChat] 채널: %s, 그룹: %s, 활성화: %s, 키워드수: %d|r",
            channelName or "nil",
            channelGroup or "nil",
            tostring(FoxChatDB.channelGroups[channelGroup] or false),
            keywordCount))
    end

    -- 새로운 채널 필터 모듈 사용
    local found = false
    local highlightedMsg = msg

    -- ChatFilter는 메시지를 변경하지 않고 통과시킴
    -- 실제 하이라이팅은 HookChatFrame에서 처리
    return false

    --[[ 기존 코드 비활성화 (HookChatFrame이 처리)
    if addon.ChannelFilter then
        local shouldFilter, matchedKeyword = addon.ChannelFilter:ShouldFilter(msg, channelType, channelName)

        -- 디버그 출력
        if debugMode and channelType == "CHANNEL" then
            print(string.format("|cFFFF0000[ChatFilter]|r shouldFilter: %s, matchedKeyword: %s",
                tostring(shouldFilter), matchedKeyword or "nil"))
        end

        if shouldFilter and matchedKeyword then
            -- 키워드가 매치되었을 때만 처리
            found = true

            -- HighlightKeywords 함수를 사용하여 제대로 하이라이트 처리
            highlightedMsg, _ = HighlightKeywords(msg, channelGroup, author)

            -- 디버그 출력
            if debugMode and channelType == "CHANNEL" then
                print(string.format("|cFF00FF00[ChatFilter]|r LFG 필터 작동! 키워드: %s", matchedKeyword))
            end
        else
            -- 키워드가 매치되지 않았으면 필터링하지 않음
            return false
        end
    else
        -- 기존 로직 폴백
        if not channelGroup or not FoxChatDB.channelGroups[channelGroup] then
            return false
        end

        -- 키워드 검색 및 하이라이트
        local foundKeyword
        highlightedMsg, foundKeyword = HighlightKeywords(msg, channelGroup, author)
        if not foundKeyword then
            return false
        end
        found = foundKeyword
    end

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

        -- 디버그: 필터링 성공 출력
        if debugMode then
            print(string.format("|cFF00FF00[ChatFilter]|r 필터링 성공! 채널: %s, 작성자: %s",
                channelGroup or "nil", cleanAuthor or "nil"))
        end

        -- 메시지를 하이라이트된 버전으로 교체
        return false, highlightedMsg, author, ...
    end

    return false  -- 변경 없이 통과
    --]]
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

-- 마부재료 팝업창 생성 함수
local function ShowMabuPopup()
    -- 기존 팝업이 있으면 제거
    if MabuPopupFrame then
        MabuPopupFrame:Hide()
        MabuPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "MabuPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(600)
    frame:SetHeight(400)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700마법 부여 재료 목록|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "MabuScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(540)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 마부재료.txt 내용 로드
    local mabuContent = [[가슴
가슴 - 최상급 생명력: 환상가루 6
가슴 - 일급 생명력: 눈부신 작은 결정 1, 환영가루 6
가슴 - 최상급 마나: 상급 황천의 정수 1, 하급 황천의 정수 2
가슴 - 일급 마나: 눈부신 작은 결정 1, 상급 영원의 정수 3
가슴 - 능력치(+3): 찬란하게 빛나는 큰결정 1, 상급 황천의 정수 2, 꿈가루 3
가슴 - 상급 능력치(+4): 눈부신 큰결정 4, 상급 영원의 정수 10, 환영가루 15

손목
손목 - 체력: 환상가루 5
손목 - 상급 체력: 꿈가루 5
손목 - 최상급 체력: 환영가루 15
손목 - 지능: 하급 황천의 정수 2
손목 - 상급 지능: 하급 영원의 정수 3
손목 - 최상급 정신력: 하급 영원의 정수 3, 꿈가루 10
손목 - 회피: 상급 황천의 정수 1, 꿈가루 2
손목 - 치유 강화: 눈부신 큰결정 2, 상급 영원의 정수 4, 환영가루 20, 생명의 정수 6
손목 - 힘: 환상가루 1
손목 - 상급 힘: 상급 황천의 정수 1, 꿈가루 2
손목 - 최상급 힘: 상급 영원의 정수 6, 환영가루 6

망토
망토 - 최상급 보호: 환영가루 8
망토 - 상급 저항력(모든저항+5): 하급 영원의 정수 2, 물의 보주 1, 불의 심장 1, 대지의 핵 1, 불사의 영액 1, 바람의 숨결 1
망토 - 화염 저항력: 하급 신비의 정수 1, 불의 원소 1
망토 - 하급 민첩성(+3): 하급 황천의 정수 2

장갑
장갑 - 힘(+5): 하급 황천의 정수 2, 환상가루 3
장갑 - 상급 힘(+7): 상급 영원의 정수 4, 환영가루 4
장갑 - 민첩(+5): 상급 황천의 정수 2
장갑 - 상급 민첩(+7): 하급 영원의 정수 3, 환영가루 3
장갑 - 숙련된 조련술: 찬란하게 빛나는 큰결정 2, 꿈가루 3
장갑 - 최하급 신속(공속 1%): 찬란하게 빛나는 큰결정 2, 야생덩굴 2

장화
장화 - 체력(+5): 환상가루 5
장화 - 상급 체력(+7): 꿈가루 10
장화 - 민첩(+5): 상급 황천의 정수 2
장화 - 상급 민첩(+7): 상급 영원의 정수 8
장화 - 최하급 속도(이속): 찬란하게 빛나는 작은 결정 1, 하급 황천의 정수 1, 남옥 1

방패
방패 - 체력(+5): 환상가루 5
방패 - 상급 체력(+7): 꿈가루 10
방패 - 최상급 정신력(+9): 상급 영원의 정수 2, 환영가루 4
방패 - 하급 방어(방어확률 2%): 상급 신비의 정수 2, 환상가루 2, 붉게 빛나는 큰결정 1

양손 무기
양손 - 일급 정신력(+9): 상급 영원의 정수 12, 눈부신 큰결정 2
양손 - 충격(+5): 환상가루 4, 붉게 빛나는 큰결정 1
양손 - 상급 충격(+7): 찬란하게 빛나는 큰결정 2, 꿈가루 2
양손 - 최상급 충격(+9): 눈부신 큰결정 4, 환영가루 10
양손 - 일급 지능(+9): 눈부신 큰결정 2, 상급 영원의 정수 12

무기 (1손/양손 공통 마부 다수 포함)
무기 - 뛰어난 지능(+22): 눈부신 큰결정 15, 상급 영원의 정수 12, 환영가루 20
무기 - 성전사: 눈부신 큰결정 4, 정의의 보주 2
무기 - 공격력(+3): 상급 신비의 정수 2, 붉게 빛나는 큰결정 1
무기 - 상급 공격력(+4): 찬란하게 빛나는 큰결정 2, 상급 황천의 정수 2
무기 - 최상급 공격력(+5): 눈부신 큰결정 2, 상급 영원의 정수 10
무기 - 민첩(+15): 눈부신 큰결정 6, 상급 영원의 정수 6, 환영가루 4, 바람의 정수 2
무기 - 힘(+15): 눈부신 큰결정 6, 상급 영원의 정수 6, 환영가루 5, 대지의 정수 2
무기 - 강한 정신력(+20): 눈부신 큰결정 10, 상급 영원의 정수 8, 환영가루 15
무기 - 생명력 흡수: 눈부신 큰결정 6, 불사의 정수 6
무기 - 불타는 무기: 찬란하게 빛나는 작은 결정 4, 불의 정수 1
무기 - 부정의 무기: 눈부신 큰결정 4, 불사의 정수 4
무기 - 빙결: 눈부신 작은 결정 4, 물의 정수 1, 바람의 정수 1, 얼음송이 1
무기 - 악마 사냥: 악마사냥전문화의 비약 1, 꿈가루 2, 찬란하게 빛나는 작은 결정 2
무기 - 야수 사냥: 붉게 빛나는 작은결정 1, 하급 신비의 정수 1, 큰 송곳니 1
무기 - 정령 사냥: 붉게 빛나는 작은결정 1, 하급 신비의 정수 1, 대지의 원소 1
무기 - 한겨울 추위: 상급 신비의 정수 3, 환상가루 3, 붉게 빛나는 큰결정 1, 겨울서리풀 2
무기 - 치유 강화(+55): 눈부신 큰결정 4, 상급 영원의 정수 8, 생명의 정수 6, 물의 정수 6, 정의의 보주 1
무기 - 주문 강화(+30): 눈부신 큰결정 4, 상급 영원의 정수 12, 물의 정수 4, 불의 정수 4, 바람의 정수 4, 황금 진주 2

머리/다리 (고서/성서, 직업 마부 아님)
머리/다리 - 숙고의 고서(마나+150): 숙고의고서 1, 검은다이아몬드 1, 모래주머니껌 1, 고통받은자의검은피 1, 30골드
머리/다리 - 골격의 고서(생명력+100): 골격의고서 1, 검은다이아몬드 1, 허파즙칵테일 1, 어둠용의숨결 4, 30골드
머리/다리 - 불굴의 고서(방어도+125): 불굴의고서 1, 검은다이아몬드 1, 카잘의눈 1, 수호의수정 4, 30골드
머리/다리 - 탄력의 고서(화저+20): 탄력의고서 1, 검은다이아몬드 1, 불타는정수 1, 돌기의수정 4, 30골드
머리/다리 - 탐욕의 고서(원하는 능력치+8): 탐욕의고서 1, 검은다이아몬드 1, 채찍뿌리줄기 4, 정신력의수정 4, 30골드
머리/다리 - 집중의 성서(주문효과+8): 집중의성서 1, 온전한검은다이아몬드 1, 눈큰 4, 어둠의허물 2
머리/다리 - 보호의 성서(회피+1%): 보호의성서 1, 온전한검은다이아몬드 1, 눈큰 2, 닳아해진누더기골렘조각 1
머리/다리 - 신속의 성서(공속+1%): 신속의성서 1, 온전한검은다이아몬드 1, 눈큰 2, 영웅의피 2

어깨 (여명회 장막)
여명비전장막(비전저항+5): 은빛여명회휘장 10, 9골드 *(매우 우호)*
여명화염장막(화염저항+5): 은빛여명회휘장 10, 9골드 *(매우 우호)*
여명냉기장막(냉기저항+5): 은빛여명회휘장 10, 9골드 *(매우 우호)*
여명암흑장막(암흑저항+5): 은빛여명회휘장 10, 9골드 *(매우 우호)*
여명오색장막(모든저항+5): 은빛여명회휘장 25, 36골드 *(확고한 동맹)*]]

    editBox:SetText(mabuContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    MabuPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "MabuPopupFrame")
end

-- 자물쇠 팝업창 생성 함수
local function ShowLockPopup()
    -- 기존 팝업이 있으면 제거
    if LockPopupFrame then
        LockPopupFrame:Hide()
        LockPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "LockPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(600)
    frame:SetHeight(400)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700도적 자물쇠 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "LockScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(540)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 자물쇠.txt 내용 로드
    local lockContent = [[도적 자물쇠 숙련 올리기 (WoW 클래식 1–300)

[준비물] 물갈퀴/수중 호흡 물약(수중 상자 구간), 은신/기절/군중제어, 자물쇠 상자(소형~중형) 추가로 주운 것들은 틈틈이 따서 보정.

숙련 1–75

* 공통: 각 진영 도적 자물쇠 퀘스트 지역의 연습 상자에서 1→75(최대 100까지도 가능).
* 얼라이언스: 붉은마루 산맥 알더스 제재소(Alther's Mill) 연습 상자.
* 호드: 불모의 땅 상인 해안 남쪽 해적선 내부(라쳇 남쪽) 상자.

숙련 76–120

* 얼라이언스: 붉은마루 산맥 영원의 호수(Lake Everstill) 호숫바닥 '젖은 상자' 반복(125부터 녹색).
* 호드(대체 코스): 돌발톱 산맥 윈드쉬어 채석장/광산(Windshear Crag/Mine) '낡은 상자' 70→120 전후까지, 또는 아즈샤라 만/아샤라 해안가의 수중 상자 100 전후부터 병행.

숙련 120–175

* 얼라이언스: 저습지(웨틀랜즈) 메네실 항구 북쪽 난파선 해안/수중 '젖은 상자' 160까지 느려지지만 175까지 가능.
* 호드: 데솔라스 사르테리스 해안(Sar'theris Strand) 해안·수중 상자 120→170대까지.

숙련 175–240

* 공통: 황야의 땅 배드랜즈 앙고르 요새(Angor Fortress) 내부 상자. 리젠 빠름(정예 있음 주의). 얼라·호드 모두 가능.

숙련 240–300

* 주 코스(공통): 타나리스 남동부 로스트 리거 코브(Lost Rigger Cove) 해적 소굴—오두막/나루터/상자 리젠 빠름. 240→300.
* 보조 코스(혼잡 시): 이글거리는 협곡(Searing Gorge) 슬래그 핏 내부 상자 225→280, 아즈샤라 Bay of Storms 해안/난파선 수중 상자 250→300.

메모

* 수중 구간은 몬스터 레벨이 20대 초중반이므로 저레벨이면 은신 경로 확보 후 진행.
* 상자 리젠이 느리면 인접 스팟(같은 지역 내 다른 배/오두막/난파선)로 순환.
* 상자 숙련이 '녹색'이 되어도 실패→성공 반복으로 소폭 오르니 꾸준히 시도.]]

    editBox:SetText(lockContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    LockPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "LockPopupFrame")
end

-- 연금술 숙련 팝업창 생성 함수
local function ShowAlchemyPopup()
    -- 기존 팝업이 있으면 제거
    if AlchemyPopupFrame then
        AlchemyPopupFrame:Hide()
        AlchemyPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "AlchemyPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(700)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700와우 클래식 연금술 1~300 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "AlchemyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(640)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 연금술숙련.txt 내용 로드
    local alchemyContent = [[와우 클래식 연금술 1~300 숙련 가이드

[준비물]
유리 약병 74개
가연 약병 65개
수정 약병 100개
평온초 59개
은엽수 59개
찔레가시 80개
생체기풀 30개
마법초 15개
갈래물풀 40개
생명의 뿌리 30개
왕꽃잎풀 30개
황금가시 45개
야생 철쭉 5개
태양풀 70개
카드가의 수염 15개
아서스의 눈물 20개
실명초 40개
황금 산삼 75개
은초롱이 40개

[숙련도 작업 방법]

1–60
제작: 최하급 치유 물약 (약 59회)
재료: 평온초 59, 은엽수 59, 유리 약병 59
메모: 최하급 치유 물약 50개는 하급 치유 물약의 재료이므로 보관

60–110
제작: 하급 치유 물약 (약 50회)
재료: 최하급 치유 물약 50, 찔레가시 50

110–140
제작: 치유 물약 (약 30회)
재료: 찔레가시 30, 생체기풀 30, 가연 약병 30

140–155
제작: 하급 마나 물약 (약 15회)
재료: 마법초 15, 갈래물풀 15, 유리 약병 15
대안(갈래물풀이 비싸거나 없을 때):
1. 화염 오일 15개 = 불지느러미통돔 30 + 유리 약병 15
2. 치유 물약을 계속 제작

155–185
제작: 상급 치유 물약 (약 30회)
재료: 왕꽃잎풀 30, 생명의 뿌리 30, 가연 약병 30
보조 루트(140–155에서 화염 오일을 만들었다면):
화염 강화의 비약 7개 = 화염 오일 14 + 왕꽃잎풀 7 + 가연 약병 7, 이후 상급 치유 물약 진행

185–210
제작: 민첩의 비약 (약 25회)
재료: 갈래물풀 25, 황금가시 25, 가연 약병 25
대안(황금가시가 부족할 때):
185–195
1) 마나 물약 = 갈래물풀 + 왕꽃잎풀 + 가연 약병
2) 하급 투명 물약 = 미명초 + 야생 철쭉 + 가연 약병
황금가시가 전혀 없으면 190–210
자연 저항 물약 = 갈래물풀 + 생명의 뿌리 + 가연 약병
도안 위치: 무법항, 가젯잔, 페더문 요새, 모쟈케 야영지의 연금술 상인

210–215
제작: 상급 방어 비약 (약 5회)
재료: 황금가시 5, 야생 철쭉 5, 가연 약병 5

215–230
제작: 최상급 치유 물약 (약 15회)
재료: 태양풀 15, 카드가의 수염 15, 수정 약병 15

230–250
제작: 언데드의 비약 (약 20회)
재료: 아서스의 눈물 20, 수정 약병 20

250–265
제작: 상급 민첩의 비약 (약 15회)
재료: 태양풀 15, 황금가시 15, 수정 약병 15

265–285
제작: 최상급 마나 물약 (약 20회)
재료: 태양풀 40, 실명초 40, 수정 약병 20

285–300
제작: 일급 치유 물약 (약 20회)
재료: 황금 산삼 40, 은초롱이 20, 수정 약병 20

[전문기술 숙련도(트레이너 구간)]

1–75 (요구 레벨 1)
위치: 대도시, 시작 지역의 두 번째 마을(칼바위 언덕, 센진 마을, 블러드후프 마을, 브릴, 골드샤이어, 카라노스, 돌라나르)
칭호: 수습 연금술사

50–150 (요구 레벨 10)
위치: 대도시
칭호: 수습 연금술사

125–225 (요구 레벨 20)
호드: 언더시티, 스토나드(슬픔의 늪)
얼라이언스: 다르나서스, 페더문 요새(페랄라스)
칭호: 숙련 연금술사

200–300 (요구 레벨 35)
호드: 스토나드(슬픔의 늪)
얼라이언스: 페더문 요새(페랄라스)
칭호: 전문 연금술사

[NPC 위치]

150–225 트레이너
호드: 학자 허버스 헤시 – 언더시티(연금술 실험실)
얼라이언스: 에이네실 – 다르나서스(장인의 정원)

225–300 트레이너
호드: 로그바 – 스토나드(슬픔의 늪)
얼라이언스: 킬린나 윈드위스퍼 – 페더문 요새(페랄라스)]]

    editBox:SetText(alchemyContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    AlchemyPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "AlchemyPopupFrame")
end

-- 요리 숙련 팝업창 생성 함수
local function ShowCookingPopup()
    -- 기존 팝업이 있으면 제거
    if CookingPopupFrame then
        CookingPopupFrame:Hide()
        CookingPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "CookingPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(650)
    frame:SetHeight(450)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700와우 클래식 요리 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "CookingScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(590)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 요리숙련.txt 내용 로드
    local cookingContent = [[[기본]

* 요리는 불이 있어야 함(여관 벽난로, 전문 NPC 주변 모닥불). 불이 없으면 '작은 모닥불' 제작해 사용.

[숙련 1–300 고기 루트]

* 1–50: 까맣게 탄 늑대 고기 또는 멧돼지 숯불구이(각각 늑대고기 1, 멧돼지고기 1).
* 50–75: 곰고기 숯불구이(곰고기 1).
* 75–100: 게살 케이크(게살 1 + 부드러운 양념 1) 또는 집게발 요리(집게발 1 + 부드러운 양념 1).
* 100–150: 양념 늑대 케밥(늑대 살코기 2 + 스톰윈드 향초 1) 또는 진기한 맛의 오믈렛(랩터 알 1 + 매운 양념 1).
* 150–175: 진기한 맛의 오믈렛 또는 매운 사자 고기(사자 고기 1 + 매운 양념 1).
* 175–200: 독특한 거북이 비스크(거북이 고기 1 + 독특한 양념 1) 또는 랩터 숯불구이(랩터 고기 1 + 매운 양념 1).
* 200–225: 거미 소시지(하얀 거미 고기 2) 또는 랩터 숯불구이.

[숙련 1–300 생선 루트(낚시 병행용)]

* 1–50: 비단잉어 구이(비단잉어 1).
* 50–100: 긴주둥이진흙퉁돔 구이(긴주둥이진흙퉁돔 1).
* 100–175: 표범메기 구이(표범메기 1).
* 175–225: 미스릴송어 구이(미스릴송어 1).
* 225–250: 점박이놀래기 구이(점박이놀래기 1).
* 250–275: 삶은 해비늘연어(해비늘연어 1).
* 275–300: 망둥어 스테이크(큰 망둥어 1 + 매운 양념 1 + 독특한 양념 1).
  '점박이놀래기/해비늘연어' 레시피는 타나리스 '긱킥스', '망둥어 스테이크' 레시피는 '신드라 톨그래스/비비안나'가 판매.

[전문 단계 승급 정보]

* 150→225(전문): '고급 요리책(Expert Cookbook)' 구매 후 사용
  판매처: 얼라—샨드리나(잿빛 골짜기 50,65) / 호드—울란(잊혀진 땅 26,29), 가격 1골드(또는 경매장).
* 225→300(대가/Artisan): 타나리스 가젯잔의 **더지 퀵클레이브**에게 퀘스트 완료 필요(레벨 35+, 숙련 225+).
  미리 준비하면 빠름: 거대한 알 12, 고소한 조갯살 10, 알터랙 스위스 20.

[참고/메모]

* 낮은 레벨 생선 레시피(비단잉어/긴주둥이진흙퉁돔/표범메기/미스릴송어)는 대체로 낚시용품 상인에게서 구매 가능.
* 생선 루트 총 대략 수량 예시: 비단잉어 50, 긴주둥이진흙퉁돔 50, 표범메기 75, 미스릴송어 50, 점박이놀래기 25, 해비늘연어 25, 큰 망둥어 25(+양념).]]

    editBox:SetText(cookingContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    CookingPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "CookingPopupFrame")
end

-- 낚시 숙련 팝업창 생성 함수
local function ShowFishingPopup()
    -- 기존 팝업이 있으면 제거
    if FishingPopupFrame then
        FishingPopupFrame:Hide()
        FishingPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "FishingPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(700)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700와우 클래식 낚시 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "FishingScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(640)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 낚시숙련.txt 내용 로드
    local fishingContent = [[[요약: 등급/요구조건/비용]

* 수습 낚시(1–75): 캐릭터 레벨 5 필요, 비용 1실버.
* 숙련 낚시(75–150): 캐릭터 레벨 10 필요, 낚시 숙련 50 필요, 비용 5실버.
* 전문 낚시(150–225): 캐릭터 레벨 20 필요, 낚시 숙련 125 이상. 책 사용으로 습득.
* 대가 낚시(225–300): 캐릭터 레벨 35 필요, 낚시 숙련 225 이상. 퀘스트 완료로 습득.

[전문/대가 승급]

* 전문(150–225): 책 "고급 낚시정보" 사용 → 판매 NPC: 무법항(가시덤불 골짜기) 27.4, 77의 상인, 가격 1골드.
* 대가(225–300): 퀘스트 "낚시의 달인 네트 페이글" 수락/완료 → 먼지진흙 습지대 59, 60의 네트 페이글. 요구 어획물 4종:

  1. 페랄라스 참치 – 페랄라스 62, 52 부근.
  2. 안개갈대 황새치 – 슬픔의 늪 동쪽 해안가.
  3. 살데리스 아귀 – 데솔라스 사르테리스 해안.
  4. 폭풍 해안 푸른도루묵 – 가시덤불 골짜기 서쪽 해안가.

[숙련 올리는 코스(권장 루트)]

* 1–75: 각 대도시와 시작 지역 연못/강(언더시티 제외). 비단잉어, 긴주둥이진흙퉁돔, 표범메기 등 낚시. 스킬 1→75까지 충분.
* 75–150: 같은 지역에서 계속 낚시하거나, 100 전후부터 해안·강가로 이동. (숙련 책/트레이너 배우고 진행)
* 130–225: 먼지진흙 습지대 권장. 내륙(호수)에서 미스릴송어, 해안에서 돌비늘대구/점박이놀래기/기름기 많은 아귀/불지느러미퉁돔 등 낚시. 150 이후 전문 책 사용 후 225까지 올림.
* 205–300: 타나리스 스팀휘들 항구 일대 권장. 주 어종은 점박이놀래기(해안). 그 외 빛깔좋은 망둥어, 불지느러미퉁돔, 돌비늘대구, 넙치농어, 겨울오징어, 돌비늘뱀장어 떼 등. 225 달성 후 네트 페이글 퀘스트 완료로 대가 습득, 300까지 지속 낚시.

[전문 낚시꾼(트레이너) 예시 위치]

* 얼라이언스: 스톰윈드(아놀드 리랜드), 아이언포지(그림누르 스톤브랜드), 다르나서스(아스타이아), 메네실 항구(해럴드 리그스), 골드샤이어(리 브라운), 레이크샤이어(매튜 호퍼) 등.
* 호드: 언더시티(알만드 크롬웰), 썬더 블러프(카 미스트러너), 오그리마(루막), 블러드후프 마을(우탄 스위프트워터), 가시덤불 골짜기 무법항(마이즈 럭키캐치) 등.
  *대부분의 수도/거점 낚시꾼에게서 1–150 구간을 배울 수 있음.

[숙련별 추천 낚시터 정리]

* 1–150: 수도/도시 주변 수역(언더시티 제외) – 비단잉어, 긴주둥이진흙퉁돔, 표범메기.
* 130–225: 먼지진흙 습지대 – 미스릴송어(내륙), 돌비늘대구/점박이놀래기(해안), 불지느러미퉁돔, 기름기 많은 아귀.
* 205–300: 타나리스 스팀휘들 항구 – 점박이놀래기 중심, 상황 따라 망둥어·돌비늘대구 등 병행.

[팁]

* 물가 근처 모닥불이나 벽난로에서 요리로 바로 가공하면 가방 압축이 쉬움.
* 특정 어종은 시간/계절의 영향을 받음(예: 겨울오징어는 야간/겨울에 효율적).
* 225 이후 바로 퀘스트를 수락해 둔 뒤 어획물 4종을 모으면 대가 승급이 빠름.]]

    editBox:SetText(fishingContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    FishingPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "FishingPopupFrame")
end

-- 응급치료 숙련 팝업창 생성 함수
local function ShowFirstAidPopup()
    -- 기존 팝업이 있으면 제거
    if FirstAidPopupFrame then
        FirstAidPopupFrame:Hide()
        FirstAidPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "FirstAidPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(650)
    frame:SetHeight(450)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700응급치료 숙련 1~300 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "FirstAidScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(590)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 응급치료숙련.txt 내용 로드
    local firstAidContent = [[응급치료 숙련 1~300

[승급 단계 요약]

* 초급 응급치료: 숙련 한도 75 (도시 응급치료사에게 습득)
* 수습 응급치료: 숙련 50 → 한도 150 (응급치료사에게 습득)
* 고급 응급치료(책): 숙련 125 → 한도 225
  · 호드: 발라이 로크웨인 – 먼지진흙 습지대, 담쟁이 마을
  · 얼라: 데네브 워커 – 아라시 고원, 스트롬가드
* 대가 응급치료(퀘스트): 숙련 225 / 캐릭터 35 → 한도 300
  · 호드 퀘스트 NPC: 그레고리 빅터 – 아라시 고원, 해머폴
  · 얼라 퀘스트 NPC: 구스타프 밴하우젠 – 먼지진흙 습지대, 테라모어

[제작/도안 습득표]

* 리넨 붕대: 리넨 옷감 1개
* 두꺼운 리넨 붕대 (숙련 40): 리넨 옷감 1개
* 해독제 (숙련 80): 작은 독주머니 1개
* 양모 붕대: 양모 옷감 1개
* 두꺼운 양모 붕대 (숙련 115): 양모 옷감 2개
* 비단 붕대 (숙련 150): 비단 옷감 1개
* (책) 처방전: 두꺼운 비단 붕대 (숙련 180): 비단 옷감 2개
* (책) 처방전: 마법 붕대 (숙련 210): 마법 옷감 1개
  · 책 판매처 예시: 얼라—데네브 워커(아라시 고원, 스트롬가드)
* 두꺼운 마법 붕대 (숙련 240): 마법 옷감 2개
  · 호드 트레이너: 그레고리 빅터(해머폴)
* 룬매듭 붕대 (숙련 260): 룬무늬 옷감 1개
  · 얼라 트레이너: 구스타프 밴하우젠(테라모어)
* 두꺼운 룬매듭 붕대 (숙련 290): 룬무늬 옷감 2개
* 강력한 해독제 (숙련 300): (은빛여명회 병참—동/서부 역병지대, 약간 우호) *일반적으로 큰 독주머니 사용*

[올리는 루트 예시]
1–40 리넨 붕대 → 40–80 두꺼운 리넨 붕대 → 80 해독제 몇 개
80–115 양모 붕대 → 115–150 두꺼운 양모 붕대 → 150–180 비단 붕대
180–210 두꺼운 비단 붕대(책) → 210–240 마법 붕대(책)
240–260 두꺼운 마법 붕대(퀘 완료 후 트레이너)
260–290 룬매듭 붕대 → 290–300 두꺼운 룬매듭 붕대
(필요 시 300에서 강력한 해독제 습득)]]

    editBox:SetText(firstAidContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    FirstAidPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "FirstAidPopupFrame")
end

-- 대장 숙련 팝업창 생성 함수
local function ShowBlacksmithPopup()
    -- 기존 팝업이 있으면 제거
    if BlacksmithPopupFrame then
        BlacksmithPopupFrame:Hide()
        BlacksmithPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "BlacksmithPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(750)
    frame:SetHeight(550)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700대장기술 1~300 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "BlacksmithScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(690)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 대장숙련.txt 내용 로드 (긴 내용이므로 일부 요약)
    local blacksmithContent = [[대장기술 1~300 숙련 가이드

[준비물]
작은 암석 150, 일반 암석 150, 큰 암석 105, 견고한 암석 120, 강도 높은 암석 20
은괴 5, 강철 주괴 190, 금괴 5, 마법옷감 150
구리 주괴 150, 청동 주괴 180, 철 주괴 230, 미스릴 주괴 320, 토륨 주괴 540
별루비 20 또는 튼튼한 가죽 160

[숙련 루트]
1–30    조잡한 숫돌 ×33              재료: 작은 암석 33
30–65   조잡한 연마석 ×55            재료: 작은 암석 110 (보관)
65–75   일반 숫돌 ×25                재료: 일반 암석 25
75–90   일반 연마석 ×35              재료: 일반 암석 70 (보관)
90–100  구리 룬문자 허리띠 ×10       재료: 구리 주괴 100
100–105 은마법막대 ×5                재료: 은괴 5, 조잡한 연마석 10
105–110 구리 룬문자 허리띠 ×5        재료: 구리 주괴 50
110–125 청동 다리보호구 ×15          재료: 청동 주괴 75
125–140 단단한 연마석 ×35            재료: 큰 암석 105 (보관)
140–150 청동 무늬 팔보호구 ×10       재료: 청동 주괴 50, 일반 연마석 20
150–155 금마법막대 ×5                재료: 금괴 5, 일반 연마석 10
155–165 녹색 철제 다리보호구 ×10     재료: 철 주괴 80, 단단한 연마석 10, 녹색 염료 10
165–190 녹색 철제 팔보호구 ×25       재료: 철 주괴 150, 녹색 염료 25
190–200 황금 미늘 팔보호구 ×10       재료: 강철 주괴 50, 단단한 연마석 20
200–210 견고한 연마석 ×30            재료: 견고한 암석 120 (보관)
210–225 견고한 미스릴 건틀릿 ×15     재료: 미스릴 주괴 90, 마법옷감 60
225–235 강철 판금 투구 ×10           재료: 강철 주괴 140, 견고한 연마석 10
235–250 미스릴 코이프 ×15            재료: 미스릴 주괴 150, 마법옷감 90
250–260 강도 높은 숫돌 ×20           재료: 강도 높은 암석 20
260–280 토륨 팔보호구 ×25            재료: 토륨 주괴 300, 푸른 마력의 수정 100
280–300 토륨 신발 ×20 또는 토륨 투구 ×20
        토륨 신발: 토륨 주괴 240, 튼튼한 가죽 160
        토륨 투구: 토륨 주괴 240, 별루비 20

[전문기술 승급]
1–75 (요구 레벨 1): 수습 대장장이 – 대도시, 시작 지역
50–150 (요구 레벨 10): 수습 대장장이 – 대도시
125–225 (요구 레벨 20): 숙련 대장장이
  호드: 오그리마 / 얼라: 아이언포지 / 중립: 무법항
200–300 (요구 레벨 35): 전문 대장장이 – 중립: 무법항

[NPC 위치]
150–225 트레이너
* 호드: 사루 스틸퓨리(오그리마, 명예의 골짜기)
* 얼라: 벤구스 딥포지(아이언포지, 대용광로)

225–300 트레이너
* 중립: 브리크 킨크래프트(가시덤불 골짜기, 무법항)

[무기/방어구 제작자 전문화]
레벨 40, 숙련 225 필요
* 무기 제작자: 달의 강철 브로드소드, 큰 철제도끼, 견고한 미스릴 도끼, 검은 대형 철퇴 제작
* 방어구 제작자: 화려한 미스릴 세트 퀘스트 완료

[참고]
* 미스릴 박차를 활용하면 235–270 구간이 빠르고 저렴
* 한정 판매/희귀 도안은 지역 상인 판매(경매장 확인)]]

    editBox:SetText(blacksmithContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    BlacksmithPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "BlacksmithPopupFrame")
end

-- 기계공학 숙련 팝업창 생성 함수
local function ShowEngineeringPopup()
    -- 기존 팝업이 있으면 제거
    if EngineeringPopupFrame then
        EngineeringPopupFrame:Hide()
        EngineeringPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "EngineeringPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(700)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700기계공학 1~300 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "EngineeringScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(640)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 기계공학숙련.txt 내용 로드
    local engineeringContent = [[기계공학 1~300 숙련 가이드

[준비물]
작은 암석 60, 일반 암석 60, 큰 암석 30, 견고한 암석 120, 강도 높은 암석 60
리넨 옷감 40, 양모 옷감 60, 마법 옷감 20, 룬무늬 옷감 35
구리 주괴 66, 청동 주괴 110, 강철 주괴 4, 미스릴 주괴 170, 토륨 주괴 225
은괴 5, 테마노 10(또는 큰 암석 30), 일반 가죽 15

[숙련 루트]
1–30    천연 화약 ×60              재료: 작은 암석 60 (보관)
30–50   구리 나사 한줌 ×30         재료: 구리 주괴 30 (보관)
50–51   만능 스패너 ×1             재료: 구리 주괴 6 (보관)
51–75   천연 구리 폭탄 ×30         재료: 구리 주괴 30, 구리 나사 한줌 30, 천연 화약 60, 리넨 30
75–90   굵은 화약 ×60              재료: 일반 암석 60 (보관)
90–100  일반 다이너마이트 ×20      재료: 굵은 화약 60, 리넨 20
100–105 은 접지 ×5                 재료: 은괴 5
105–125 청동관 ×25                 재료: 청동 주괴 50, 약한 융해촉진제 25
125–135 일반 조준경 ×10            재료: 청동 주괴 10, 테마노 10
135–150 청동 회전 장치 ×15         재료: 청동 주괴 30, 양모 15, 강한 화약 30
150–160 청동 골격 ×15              재료: 청동 주괴 30, 일반 가죽 15, 양모 15 (보관)
160–175 양 폭탄 ×15                재료: 강한 화약 30, 청동 골격 15, 청동 회전 장치 15, 양모 30
175–176 자동회전 초정밀조율기 ×1   재료: 강철 주괴 4 (보관)
176–195 조밀한 화약 ×60            재료: 견고한 암석 120 (보관)
195–200 미스릴 관 ×7               재료: 미스릴 주괴 21 (노움 특화시 6개 보관)
200–216 유동성 제동장치 ×20        재료: 미스릴 주괴 20, 마법 옷감 20, 조밀한 화약 20 (보관)
215–238 미스릴 형틀 ×40            재료: 미스릴 주괴 120 (보관)
238–250 고폭탄 ×20                 재료: 미스릴 형틀 40, 유동성 제동장치 20, 조밀한 화약 40
250–260 강도 높은 화약 ×30         재료: 강도 높은 암석 60
260–285 토륨 부품 ×35              재료: 토륨 주괴 105, 룬무늬 옷감 35
285–300 토륨관 ×20                 재료: 토륨 주괴 120
※ 토륨관 도면: 여명의 설원 눈망루 마을 기계공학 용품 상인 판매

[전문기술 승급]
1–75 (요구 레벨 1): 수습 기계공학자 – 대도시, 시작 지역
50–150 (요구 레벨 10): 수습 기계공학자 – 대도시
125–225 (요구 레벨 20): 숙련 기계공학자
  호드: 오그리마 / 얼라: 아이언포지
200–300 (요구 레벨 35): 전문 기계공학자 – 가젯잔(타나리스)

[특화 – 노움 기계공학] (요구 레벨 30, 숙련 200+)
필수 제작물: 고급 표적 허수아비 2, 미스릴 관 6, 정밀한 조준경 1
시작 NPC: 호드—그레이엄 반 탈렌(언더시티) / 얼라—릴리암 스파크스핀들(스톰윈드)
완료 NPC: 호드—오글소프 오브노티쿠스(무법항) / 얼라—수석땜장이 오버스파크(아이언포지)

[특화 – 고블린 기계공학] (요구 레벨 30, 숙련 200+)
필수 제작물: 대형 철제 폭탄 20, 조밀한 다이너마이트 20, 양 폭탄 5
시작 NPC: 호드—그레이엄 반 탈렌(언더시티) / 얼라—스프링스핀들 피즐기어(아이언포지)
완료 NPC: 닉스 스프로켓스프링(가젯잔)

[참고]
* 화약류/형틀/제동장치/관은 이후 제작에 연계되니 보관 필수
* 융해촉진제 등 소모품은 직업/대장용품 상인에게서 구매]]

    editBox:SetText(engineeringContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    EngineeringPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "EngineeringPopupFrame")
end

-- 재봉술 숙련 팝업창 생성 함수
local function ShowTailoringPopup()
    -- 기존 팝업이 있으면 제거
    if TailoringPopupFrame then
        TailoringPopupFrame:Hide()
        TailoringPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "TailoringPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(700)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700재봉술 1~300 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "TailoringScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(640)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 재봉술숙련.txt 내용 로드
    local tailoringContent = [[재봉술 1~300 숙련 가이드

[준비물]
리넨 옷감 170, 양모 옷감 60, 비단 옷감 760, 마법 옷감 280, 룬무늬 옷감 900
일반 가죽 35, 두꺼운 가죽 75, 튼튼한 가죽 10
청색 염료 35, 붉은 염료 40, 불의 정령 3

[숙련 루트]
1–50    리넨 볼트 ×50               재료: 리넨 옷감 100 (보관)
50–70   리넨 가방 ×20               재료: 리넨 볼트 60, 일반 실 60
70–75   강화 리넨 어깨보호대 ×5     재료: 리넨 볼트 10, 일반 실 10
75–105  양모 볼트 ×45               재료: 양모 옷감 135 (보관)
105–110 회색 양모 셔츠 ×5           재료: 양모 볼트 10, 묵은 염료 5, 일반 실 5
110–125 두배로 짠 양모 어깨보호대 ×15 재료: 양모 볼트 45, 일반 실 30
125–145 비단 볼트 ×50               재료: 비단 옷감 200 (보관)
145–160 연푸른색 비단 가슴보호대 ×15 재료: 비단 볼트 60, 청색 염료 30, 일반 실 30
160–170 비단 머리띠 ×10             재료: 비단 볼트 30, 일반 실 20
170–175 품격있는 고급 셔츠 ×5       재료: 비단 볼트 15, 청색 염료 10, 일반 실 10
175–185 마법 볼트 ×75               재료: 마법 옷감 375 (보관)
185–200 진홍색 비단 바지 ×15        재료: 비단 볼트 60, 붉은 염료 30, 비단 실 30
200–215 진홍색 비단 조끼 ×15        재료: 비단 볼트 60, 붉은 염료 30, 질긴 실 30
215–220 검은 마법 머리띠/장갑 ×5    재료: 마법 볼트 15, 질긴 실 10
220–230 검은 마법 장갑 ×10          재료: 마법 볼트 20, 질긴 실 20
230–250 검은 마법 어깨보호대 ×20    재료: 마법 볼트 60, 질긴 실 40
250–260 룬무늬 볼트 ×75             재료: 룬무늬 옷감 375 (보관)
260–280 룬무늬 가방 ×20             재료: 룬무늬 볼트 100, 질긴 가죽 40, 룬무늬 실 20
280–295 룬무늬 머리띠 ×15           재료: 룬무늬 볼트 60, 황금빛 진주 30, 룬무늬 실 15
295–300 룬무늬 셔츠 ×5              재료: 룬무늬 볼트 25, 룬무늬 실 5

[전문기술 승급]
1–75 (요구 레벨 1): 수습 재봉술사 – 대도시
50–150 (요구 레벨 10): 숙련 재봉술사 – 대도시
125–225 (요구 레벨 20): 전문 재봉술사
  호드: 언더시티, 오그리마 / 얼라: 스톰윈드, 아이언포지
200–300 (요구 레벨 35): 대가 재봉술사
  호드: 언더시티 / 얼라: 스톰윈드

[NPC 위치]
150–225: 호드—마가르(오그리마) / 얼라—조지 캔들러(스톰윈드)
225–300: 호드—다르이스 파인(언더시티) / 얼라—조지 캔들러(스톰윈드)

[참고]
* 볼트는 이후 제작에 필요하니 보관
* 260–280 대안: 룬무늬 장화/바지로 대체 가능]]

    editBox:SetText(tailoringContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    TailoringPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "TailoringPopupFrame")
end

-- 마법부여 숙련 팝업창 생성 함수
local function ShowEnchantingPopup()
    -- 기존 팝업이 있으면 제거
    if EnchantingPopupFrame then
        EnchantingPopupFrame:Hide()
        EnchantingPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "EnchantingPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(750)
    frame:SetHeight(550)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFFD700마법부여 1~300 숙련 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "EnchantingScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(690)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 마법부여숙련.txt 내용 로드
    local enchantingContent = [[마법부여 1~300 숙련 가이드

[준비물]
이상한 가루 125, 하급 마법의 정수 1, 상급 마법의 정수 12
영혼 가루 130, 하급 별의 정수 25, 상급 별의 정수 2
환상 가루 240, 상급 신비의 정수 2
꿈 가루 330, 하급 황천의 정수 5, 상급 황천의 정수 15
환영 가루 40, 상급 영원의 정수 8, 눈부신 큰 결정 8
음영석 1, 오색 진주 1, 검은 진주 1, 황금 진주 1
구리/은/금/진은/아케나이트 마법막대 각 1개

[숙련 루트]
1–2     룬 구리마법막대 ×1           재료: 구리마법막대 1, 이상한 가루 1, 하급 마법의 정수 1
2–50    손목: 최하급 생명력 ×48      재료: 이상한 가루 48
50–90   손목: 최하급 생명력 ×40      재료: 이상한 가루 40
90–100  손목: 최하급 체력 ×10        재료: 이상한 가루 30
100–101 룬 은마법막대 ×1            재료: 은마법막대 1, 이상한 가루 6, 상급 마법의 정수 3, 음영석 1
101–110 상급 마법 마법봉 ×9         재료: 장작나무 9, 상급 마법의 정수 9
110–135 망토: 최하급 민첩 ×25       재료: 하급 별의 정수 25
135–155 손목: 하급 체력 ×40         재료: 영혼 가루 40
155–156 룬 금마법막대 ×1            재료: 금마법막대 1, 영혼 가루 2, 상급 별의 정수 2, 오색 진주 1
156–185 손목: 하급 힘 ×80           재료: 영혼 가루 80
185–200 손목: 힘 ×15               재료: 환상 가루 15
200–201 룬 진은마법막대 ×1          재료: 진은마법막대 1, 검은 진주 1, 환상 가루 2, 상급 신비의 정수 2
201–220 손목: 힘 ×25               재료: 환상 가루 25
220–225 망토: 상급 보호 ×15         재료: 환상 가루 15
225–230 장갑: 민첩 ×5               재료: 환상 가루 5, 하급 황천의 정수 5
230–235 신발: 체력 ×5               재료: 환상 가루 25
235–250 가슴: 최상급 생명력 ×25     재료: 환상 가루 150
250–265 손목: 상급 힘 ×15           재료: 꿈 가루 30, 상급 황천의 정수 15
265–294 방패: 상급 체력 ×30         재료: 꿈 가루 300
294–295 룬문자 아케나이트 막대 ×1   재료: 아케나이트 막대 1, 황금 진주 1, 환상 가루 10, 상급 영원의 정수 4
295–300 망토: 최상급 보호 ×5        재료: 환영 가루 40

[전문기술 승급]
1–75 (요구 레벨 1): 수습 마법부여사 – 대도시
50–150 (요구 레벨 10): 수습 마법부여사 – 대도시
125–225 (요구 레벨 20): 숙련 마법부여사
  호드: 해바위 야영지(돌발톱) / 얼라: 아조라의 탑(엘윈)
200–300 (요구 레벨 35): 전문 마법부여사 – 울다만 내부 '안노라'

[NPC 위치]
150–225: 호드—하가스(해바위 야영지) / 얼라—키타 파이어윈드(아조라 탑)
225–300: 중립—안노라(울다만 인던 내부)

[참고]
* 방패 상급 체력 도안: 언더시티/다르나서스 직업용품 상인 한정판매
* 망토 최하급 민첩 도안: 해바위 야영지/아스트라나르 상인
* 250까지 재료 준비 후 울다만 1회 방문 권장]]

    editBox:SetText(enchantingContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    EnchantingPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "EnchantingPopupFrame")
end

-- 하드코어 위험지역 팝업창 생성 함수
local function ShowHardcorePopup()
    -- 기존 팝업이 있으면 제거
    if HardcorePopupFrame then
        HardcorePopupFrame:Hide()
        HardcorePopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "HardcorePopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(800)
    frame:SetHeight(600)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFFFF0000와우 클래식 하드코어 – 위험 지역 정리|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "HardcoreScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(740)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 하코.txt 내용 로드
    local hardcoreContent = [[와우 클래식 하드코어 – 위험 지역 정리

[전역 공통 주의]
* * 표시는 PVP 플래그 유발 지점. 5분간 전투 미발생 시 해제
* 중립 마을(무법항/가젯잔/눈망루/톱니항) 귀환은 전투 해제 후에만
* 펫/소환수의 전투 상태 반드시 확인
* 길 위의 경비병·정찰병 로밍 주의

[그늘숲]
• 다크샤이어: '누더기(Stitches)' 마을 난입 위험
• 안전 포인트: 그리핀 NPC 옆 → 에바 부인 집 지붕
• 까마귀 언덕~다크샤이어: 누더기 이동 경로 겹침

[스톰윈드]
• 구시가지: '다셸 스톤피스트+불량배 2' 이벤트

[저습지]
• 메네실 항구 여관: '타포케 잔+친구' 이벤트

[힐스브래드 구릉지]
• 사우스쇼어: '어둠의 암살자' 난입
• 타렌 밀농장 방면: '죽음의 경비병' 애드 다발
• 필드: '나릴라산즈' 로밍

[아라시 고원]
• 고셰크 농장→힐스브래드: '포세이큰 급사+경호원' 로밍

[역병지대]
• "영웅의 피" 클릭 시 '영웅의 넋' 소환
• 동부 스트라솔름→티르의 손: '진홍십자군 급사'
• 동부 경비탑 4곳[PVP]: 매복 위험 높음

[모단 호수]
• 길[PVP]: '호드 길잡이 3인방' 로밍

[붉은마루 산맥]
• 길목: 검은바위부족 그런트 매복

[은빛소나무 숲]
• 언더시티 가기 전: '누더기 골렘 2+연금술사'

[슬픔의 늪]
• 스토나드 인근[PVP]: 호드 로밍 경비
• 월드보스 '솜누스' 로밍

[저주받은 땅]
• 월드보스 '파멸의 테레무스' 로밍

[여명의 설원]
• 입구→눈사태 마을: '눈사태일족 정찰꾼' 로밍
• 눈망루[PVP]: 마을 내 PVP 스나이핑 위험

[잊혀진 땅]
• 연안: '깊은바다 거인' 로밍
• 침묵의 초소: 독수리·유령 코도 애드

[페랄라스]
• 모자케 야영지[PVP]: 경비 애드→PVP→고렙 저격

[불모의 땅]
• 크로스로드[PVP]: 경비범위 광범위
• 호드 주의: '얼라이언스 정찰대 4인방' 로밍

[버섯구름 봉우리/소금 평원]
• 엘리베이터 앞: 용사 NPC는 비선공, 오른쪽 선공 NPC 주의
• 북쪽 우회 경로 추천

[잿빛 골짜기]
• 토막나무 주둔지[PVP]: 로밍 정찰병
• 불모의 땅 경계: 오른쪽 '개구멍' 경로 사용

[가시덤불 골짜기]
• 구루바시 투기장[PVP]: 절대 진입 금지
• 양 진영 매복 빈발

[운고로 분화구]
• '폭군 모쉬', '무쇠가죽 데빌사우루스' 로밍

[황야의 땅]
• '자리코틀' 로밍

[동부 내륙지]
• 레반터스크 트롤 마을: 접근 금지

[레벨·이동 팁]
• 노란색(상위) 몹과의 교전 자제
• 하드코어는 던전 입장 레벨 상향 권장]]

    editBox:SetText(hardcoreContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    HardcorePopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "HardcorePopupFrame")
end

-- 인던 정보 팝업창 생성 함수
local function ShowDungeonPopup()
    -- 기존 팝업이 있으면 제거
    if DungeonPopupFrame then
        DungeonPopupFrame:Hide()
        DungeonPopupFrame = nil
    end

    -- 메인 프레임 생성 (BackdropTemplate 상속)
    local frame = CreateFrame("Frame", "DungeonPopupFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(700)
    frame:SetHeight(550)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFF00FFFF적정 인던 레벨 가이드|r")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- 스크롤 프레임 생성
    local scrollFrame = CreateFrame("ScrollFrame", "DungeonScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 20)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetWidth(640)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- 인던.txt 내용 로드
    local dungeonContent = [[적정 인던 레벨 가이드

[기준 설명]
• 권장 레벨은 최종 보스 레벨 -3 기준
• 힐러는 딜러/탱커보다 보통 1레벨 낮아도 가능
• 파티 평균 레벨이 높으면 더 낮은 레벨로도 클리어 가능

[권장 입장 레벨표]
성난불길 협곡: 딜/탱 13+, 힐 12+
죽음의 폐광: 딜/탱 18+, 힐 17+
통곡의 동굴: 딜/탱 19+, 힐 18+
그림자송곳니 성채: 딜/탱 23+, 힐 22+
검은심연 나락: 딜/탱 25+, 힐 24+
스톰윈드 지하감옥: 딜/탱 26+, 힐 25+
가시덩굴 우리: 딜/탱 30+, 힐 29+
놈리건: 딜/탱 31+, 힐 30+

[붉은십자군 수도원]
묘지(4번방): 딜/탱 31+, 힐 30+
도서관(1번방): 딜/탱 34+, 힐 33+
무기고(2번방): 딜/탱 37+, 힐 36+
대성당(3번방): 딜/탱 39+, 힐 38+

[중후반 던전]
가시덩굴 구릉: 딜/탱 38+, 힐 37+
울다만: 딜/탱 43+, 힐 42+ (※내부 레벨 편차 큼)
줄파락: 딜/탱 45+, 힐 44+
마라우돈(퀘팟): 딜/탱 46+, 힐 45+
마라우돈(홀팟): 딜/탱 48+, 힐 47+
가라앉은 사원: 딜/탱 52+, 힐 51+

[검은바위]
나락(퀘/인센/금고): 딜/탱 54+, 힐 53+
나락(릿산 직팟): 딜/탱 56+, 힐 55+
첨탑 하층: 딜/탱 59+, 힐 58+

[혈투의 전장]
1번방(알진방): 딜/탱 59+, 힐 58+
2번방(공물방): 딜/탱 60, 힐 59+
3번방(왕자방): 딜/탱 60, 힐 59+

[만렙 던전]
스트라솔름: 딜/탱 60, 힐 59+
스칼로맨스: 딜/탱 60, 힐 59+
검은바위 첨탑 상층: 딜/탱 60, 힐 59+]]

    editBox:SetText(dungeonContent)
    editBox:SetCursorPosition(0)

    -- 팝업 표시
    frame:Show()
    DungeonPopupFrame = frame

    -- ESC 키로 닫기 위해 UISpecialFrames에 추가
    tinsert(UISpecialFrames, "DungeonPopupFrame")
end

-- SendChatMessage 후킹 (말머리/말꼬리)
local function HookSendChatMessage()
    SendChatMessage = function(message, chatType, language, channel)
        -- 마부재료 명령어 확인
        if message and (message == "!!마부" or message == "!!마부재료") then
            ShowMabuPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 자물쇠 명령어 확인
        if message and (message == "!!자물쇠" or message == "!!자물쇠숙련") then
            ShowLockPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 연금술 숙련 명령어 확인
        if message and message == "!!연금술숙련" then
            ShowAlchemyPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 요리 숙련 명령어 확인
        if message and message == "!!요리숙련" then
            ShowCookingPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 낚시 숙련 명령어 확인
        if message and message == "!!낚시숙련" then
            ShowFishingPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 응급치료 숙련 명령어 확인
        if message and (message == "!!응치숙련" or message == "!!응급치료숙련") then
            ShowFirstAidPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 대장 숙련 명령어 확인
        if message and message == "!!대장숙련" then
            ShowBlacksmithPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 기계공학 숙련 명령어 확인
        if message and (message == "!!기공숙련" or message == "!!기계공학숙련") then
            ShowEngineeringPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 재봉술 숙련 명령어 확인
        if message and (message == "!!재봉숙련" or message == "!!재봉술숙련") then
            ShowTailoringPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 마법부여 숙련 명령어 확인
        if message and (message == "!!마부숙련" or message == "!!마법부여숙련") then
            ShowEnchantingPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 하드코어 위험지역 명령어 확인
        if message and (message == "!!하코" or message == "!!하코위험지역" or message == "!!하드코어위험" or message == "!!하드코어위험지역") then
            ShowHardcorePopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 인던 정보 명령어 확인
        if message and (message == "!!인던" or message == "!!인스턴스던전" or message == "!!던전정보" or message == "!!인던정보") then
            ShowDungeonPopup()
            return -- 메시지를 채팅에 전송하지 않음
        end

        -- 도움말 명령어 확인
        if message and (message == "!!와우위키" or message == "!!와우정보") then
            print("|cFFFFFF00=== FoxChat 명령어 도움말 ===|r")
            print("|cFF00FF00[마법부여 관련]|r")
            print("  !!마부, !!마부재료 - 마법부여 재료 정보")
            print("  !!마부숙련, !!마법부여숙련 - 마법부여 1~300 숙련 가이드")
            print("|cFF00FF00[전문기술 숙련]|r")
            print("  !!자물쇠, !!자물쇠숙련 - 도적 자물쇠 따기 숙련 가이드")
            print("  !!연금술숙련 - 연금술 1~300 숙련 가이드")
            print("  !!요리숙련 - 요리 1~300 숙련 가이드")
            print("  !!낚시숙련 - 낚시 1~300 숙련 가이드")
            print("  !!응치숙련, !!응급치료숙련 - 응급치료 1~300 숙련 가이드")
            print("  !!대장숙련 - 대장기술 1~300 숙련 가이드")
            print("  !!기공숙련, !!기계공학숙련 - 기계공학 1~300 숙련 가이드")
            print("  !!재봉숙련, !!재봉술숙련 - 재봉술 1~300 숙련 가이드")
            print("|cFF00FF00[게임 정보]|r")
            print("  !!하코, !!하코위험지역, !!하드코어위험, !!하드코어위험지역 - 하드코어 위험 지역 정보")
            print("  !!인던, !!인스턴스던전, !!던전정보, !!인던정보 - 적정 인던 레벨 가이드")
            print("|cFF00FF00[도움말]|r")
            print("  !!와우위키, !!와우정보 - 이 도움말 표시")
            return -- 메시지를 채팅에 전송하지 않음
        end

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
                -- 디버그: chatType 확인 (디버그 모드일 때만)
                if debugMode then
                    print(string.format("[FoxChat Debug] SendChat: chatType=%s, channel=%s",
                        tostring(chatType), tostring(channel)))
                end

                -- 채널 그룹 결정
                local channelGroup = nil
                if chatType == "SAY" then
                    channelGroup = "SAY"        -- 일반 대화
                elseif chatType == "YELL" then
                    channelGroup = "YELL"       -- 외치기
                elseif chatType == "CHANNEL" then
                    -- 채널 번호로 구분 (channel 파라미터 사용)
                    if channel then
                        local channelName = select(2, GetChannelName(channel))
                        if debugMode then
                            print(string.format("[FoxChat Debug] CHANNEL: num=%s, name=%s", tostring(channel), tostring(channelName)))
                        end

                        -- 공개 채널 체크 (일반, 공개, General)
                        if channelName and (string.find(channelName, "공개") or string.find(channelName, "일반") or string.find(channelName, "General")) then
                            channelGroup = "YELL"   -- 공개 채널도 YELL 그룹으로 처리
                        elseif channelName and (string.find(channelName, "파티찾기") or string.find(channelName, "LookingForGroup") or string.find(channelName, "LFG")) then
                            channelGroup = "LFG"    -- 파티찾기 채널
                        elseif channelName and (string.find(channelName, "거래") or string.find(channelName, "Trade")) then
                            channelGroup = "TRADE"  -- 거래 채널
                        end
                    end
                elseif chatType == "GUILD" or chatType == "OFFICER" then
                    channelGroup = "GUILD"      -- 길드
                elseif chatType == "PARTY" or chatType == "RAID" or chatType == "INSTANCE_CHAT" or chatType == "RAID_WARNING" then
                    channelGroup = "GROUP"      -- 파티/공격대
                elseif chatType == "WHISPER" or chatType == "WHISPER_INFORM" then
                    channelGroup = "WHISPER"    -- 귓속말
                end

                if channelGroup then
                    -- 채널별 말머리 가져오기
                    local prefix = ""
                    if FoxChatDB.channelPrefixSuffix and FoxChatDB.channelPrefixSuffix[channelGroup] then
                        prefix = FoxChatDB.channelPrefixSuffix[channelGroup].prefix or ""
                    end

                    -- 공통 말꼬리
                    local suffix = FoxChatDB.suffix or ""

                    -- 디버그: 말머리/말꼬리 적용 확인
                    if debugMode then
                        print(string.format("[FoxChat Debug] channelGroup=%s, prefix='%s', suffix='%s'",
                            tostring(channelGroup), tostring(prefix), tostring(suffix)))
                    end

                    -- 말머리와 말꼬리 추가
                    if prefix ~= "" or suffix ~= "" then
                        message = prefix .. message .. suffix
                    end
                else
                    -- 디버그: channelGroup이 없는 경우
                    if debugMode then
                        print(string.format("[FoxChat Debug] No channelGroup for chatType=%s", tostring(chatType)))
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
        GameTooltip:AddLine("|cFFFF6060우클릭: 설정창 열기|r", 1, 1, 1)
        GameTooltip:Show()
    end)

    adButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 클릭 이벤트
    adButton:SetScript("OnClick", function(self, button)
        -- 우클릭 처리 - 설정창 열기 (광고 설정 탭)
        if button == "RightButton" then
            -- 설정창 열기
            if FoxChat and FoxChat.ShowConfig then
                FoxChat:ShowConfig()
                -- 광고 설정 탭으로 전환
                local configFrame = _G["FoxChatConfigFrame"]
                if configFrame and configFrame.SelectTab then
                    configFrame:SelectTab(3)  -- 3번 탭 = 광고 설정
                end
            end
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

        -- 마이그레이션 모듈 초기화
        if addon.Migration then
            addon.Migration:Initialize()
        end

        -- ChannelFilter 모듈 디버그 정보
        if addon.ChannelFilter then
            if debugMode then
                print("|cFF00FF00[FoxChat]|r ChannelFilter 모듈 로드됨")
                addon.ChannelFilter:DebugPrint()
            end

            -- LFG 채널 키워드 확인 (디버그용)
            if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters.LFG then
                local lfgKeywords = FoxChatDB.channelFilters.LFG.keywords or ""
                if lfgKeywords ~= "" then
                    print(string.format("|cFF00FF00[FoxChat]|r LFG 채널 키워드 로드됨: %s",
                        string.sub(lfgKeywords, 1, 50) .. (string.len(lfgKeywords) > 50 and "..." or "")))
                end
            end
        end
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

        -- 리더 전용 인사말 필드 초기화 (기존 DB에 없을 경우)
        if FoxChatDB.leaderGreetRaidMessages == nil then
            FoxChatDB.leaderGreetRaidMessages = defaults.leaderGreetRaidMessages
        end
        if FoxChatDB.leaderGreetPartyMessages == nil then
            FoxChatDB.leaderGreetPartyMessages = defaults.leaderGreetPartyMessages
        end

        -- toastPosition 테이블 확인 및 초기화
        if not FoxChatDB.toastPosition then
            FoxChatDB.toastPosition = defaults.toastPosition
        end

        -- adPosition 테이블 확인 및 초기화
        if not FoxChatDB.adPosition then
            FoxChatDB.adPosition = defaults.adPosition
        end

        -- 자동 탭 설정 초기화
        -- 파티 인사말 메시지 배열 초기화
        if not FoxChatDB.partyGreetMyJoinMessages or type(FoxChatDB.partyGreetMyJoinMessages) ~= "table" then
            FoxChatDB.partyGreetMyJoinMessages = defaults.partyGreetMyJoinMessages
        end
        if not FoxChatDB.partyGreetOthersJoinMessages or type(FoxChatDB.partyGreetOthersJoinMessages) ~= "table" then
            FoxChatDB.partyGreetOthersJoinMessages = defaults.partyGreetOthersJoinMessages
        end

        -- 자동응답 설정 초기화 (개별 체크박스 마이그레이션)
        -- 기존 autoReplyEnabled를 새로운 개별 설정으로 마이그레이션
        if FoxChatDB.autoReplyEnabled ~= nil and FoxChatDB.autoReplyAFK == nil then
            -- 기존 설정이 있으면 AFK에만 적용
            FoxChatDB.autoReplyAFK = FoxChatDB.autoReplyEnabled
            FoxChatDB.autoReplyCombat = FoxChatDB.autoReplyEnabled
            FoxChatDB.autoReplyInstance = FoxChatDB.autoReplyEnabled
            FoxChatDB.autoReplyEnabled = nil  -- 기존 설정 제거
        end

        -- 설정 검증
        if addon.ValidateSettings then
            addon:ValidateSettings()
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
        print("|cFF00FF00[FoxChat]|r !!와우위키 라고 채팅창에 입력해보세요")
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    end
end)

-- 공개 함수들
function FoxChat:UpdateKeywords()
    UpdateKeywords()
    if debugMode then
        local count = 0
        for _ in pairs(keywords) do count = count + 1 end
        print(string.format("|cFF00FFFF[FoxChat:UpdateKeywords] 키워드 업데이트 완료: %d개|r", count))
    end
end

-- ShowToast 함수를 FoxChat 테이블에 추가
FoxChat.ShowToast = ShowToast

-- 토스트 미리보기 함수 (설정 화면에서 사용)
function ShowToastPreview(duration)
    local testMessage = "토스트 알림 테스트입니다"
    local testAuthor = "테스트"


    -- 토스트 표시
    ShowToast(testAuthor, testMessage, "GUILD", true)

    -- 지정된 시간 후 자동으로 사라지도록 설정
    if duration and activeToasts[1] then
        C_Timer.After(duration, function()
            if activeToasts[1] and activeToasts[1]:IsShown() then
                activeToasts[1].fadeOutTimer = C_Timer.NewTimer(0.5, function()
                    -- activeToasts가 여전히 존재하고 첫 번째 요소가 있는지 확인
                    if activeToasts and activeToasts[1] then
                        local toast = activeToasts[1]
                        -- 풀에 반환
                        table.insert(toastPool, toast)
                        -- activeToasts에서 제거
                        table.remove(activeToasts, 1)
                        -- 토스트 숨기기
                        toast:Hide()
                        -- 위치 재정렬
                        RepositionToasts()
                    end
                end)
            end
        end)
    end
end

-- addon 테이블에도 추가
addon.ShowToastPreview = ShowToastPreview

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

-- 디버그 명령어 추가
SLASH_FOXCHATDEBUG1 = "/fcdbg"
SLASH_FOXCHATDEBUG2 = "/foxchatdebug"
SlashCmdList["FOXCHATDEBUG"] = function()
    debugMode = not debugMode
    if debugMode then
        print("|cFF00FF00[FoxChat] 디버그 모드 활성화됨|r")

        -- 키워드 개수와 목록 출력
        local keywordList = {}
        local keywordCount = 0
        for lower, original in pairs(keywords) do
            table.insert(keywordList, original)
            keywordCount = keywordCount + 1
        end
        print("|cFFFFFF00[FoxChat] 키워드 개수: " .. keywordCount .. "|r")
        if keywordCount > 0 then
            print("|cFF00FF00[FoxChat] 현재 키워드: " .. table.concat(keywordList, ", ") .. "|r")
        end

        -- 무시 키워드 개수와 목록 출력
        local ignoreList = {}
        local ignoreCount = 0
        for lower, original in pairs(ignoreKeywords) do
            table.insert(ignoreList, original)
            ignoreCount = ignoreCount + 1
        end
        if ignoreCount > 0 then
            print("|cFFFF00FF[FoxChat] 무시할 문구: " .. table.concat(ignoreList, ", ") .. "|r")
        end
    else
        print("|cFFFF0000[FoxChat] 디버그 모드 비활성화됨|r")
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
    elseif cmd == "lfg" then
        -- LFG 채널 설정 확인
        if FoxChatDB and FoxChatDB.channelFilters and FoxChatDB.channelFilters.LFG then
            local lfg = FoxChatDB.channelFilters.LFG
            print("|cFF00FF00[FoxChat LFG 설정]|r")
            print(string.format("  활성화: %s", tostring(lfg.enabled)))

            -- 원본 키워드 문자열 표시
            local rawKeywords = lfg.keywords or "없음"
            print(string.format("  원본 키워드 문자열: %s", rawKeywords))

            -- 키워드 문자열 길이 확인
            if rawKeywords ~= "없음" then
                print(string.format("  문자열 길이: %d", string.len(rawKeywords)))

                -- 각 키워드 개별 확인
                local kwCount = 0
                for keyword in string.gmatch(rawKeywords, "[^,]+") do
                    kwCount = kwCount + 1
                    local trimmed = string.trim(keyword)
                    print(string.format("    %d. '%s' (길이: %d)", kwCount, trimmed, string.len(trimmed)))
                    if trimmed == "수도원" then
                        print("      -> '수도원' 발견!")
                    end
                end
            end

            print(string.format("  무시 키워드: %s", lfg.ignoreKeywords or "없음"))

            -- 실제 ChannelFilter 모듈에서 가져오는 키워드 테스트
            print("|cFFFFFF00[ChannelFilter 테스트]|r")
            local keywords = addon.ChannelFilter:GetKeywords("CHANNEL", "파티찾기")
            local count = 0
            local hasMonastery = false
            print("  로드된 키워드:")
            for lowerKey, originalValue in pairs(keywords) do
                count = count + 1
                if count <= 15 then
                    print(string.format("    %d. 소문자:'%s' → 원본:'%s'", count, lowerKey, originalValue))
                end
                if lowerKey == "수도원" or originalValue == "수도원" then
                    hasMonastery = true
                    print(string.format("    |cFF00FF00'수도원' 발견! 소문자:'%s' 원본:'%s'|r", lowerKey, originalValue))
                end
            end
            print(string.format("  키워드 개수: %d개", count))
            print(string.format("  '수도원' 포함 여부: %s", hasMonastery and "O" or "X"))

            -- 테스트 메시지로 실제 매칭 테스트
            local testMsg = "수도원 테스트"
            local shouldFilter, matchedKeyword = addon.ChannelFilter:ShouldFilter(testMsg, "CHANNEL", "파티찾기")
            print(string.format("  '수도원 테스트' 메시지 필터링: %s", shouldFilter and ("O - 매치된 키워드: " .. (matchedKeyword or "nil")) or "X"))
        else
            print("|cFFFF0000[FoxChat]|r LFG 채널 설정이 없습니다")
        end
    elseif cmd == "test" then
        -- 테스트 메시지를 지정된 채널에 시뮬레이션
        local channel, message = nil, nil
        if args then
            local spacePos = string.find(args, " ")
            if spacePos then
                channel = string.sub(args, 1, spacePos - 1)
                message = string.sub(args, spacePos + 1)
            else
                message = args
            end
        end

        -- 채널 매핑
        local channelMap = {
            ["lfg"] = "LFG",
            ["파티찾기"] = "LFG",
            ["trade"] = "TRADE",
            ["거래"] = "TRADE",
            ["guild"] = "GUILD",
            ["길드"] = "GUILD",
            ["say"] = "SAY",
            ["공개"] = "SAY",
            ["일반"] = "SAY",
            ["party"] = "PARTY",
            ["파티"] = "PARTY"
        }

        local targetChannel = channel and channelMap[string.lower(channel)] or "LFG"
        local testMessage = message or "수도원 테스트 메시지"

        print("|cFFFFFF00[FoxChat 테스트]|r")
        print(string.format("  채널: %s", targetChannel))
        print(string.format("  메시지: %s", testMessage))

        -- 필터링 활성화 상태 확인
        print(string.format("  전체 필터링: %s", FoxChatDB.filterEnabled and "O" or "X"))

        -- 채널별 매핑
        local channelType, channelName = nil, nil
        if targetChannel == "LFG" then
            channelType, channelName = "CHANNEL", "파티찾기"
        elseif targetChannel == "TRADE" then
            channelType, channelName = "CHANNEL", "거래"
        elseif targetChannel == "GUILD" then
            channelType = "GUILD"
        elseif targetChannel == "SAY" then
            channelType = "SAY"
        elseif targetChannel == "PARTY" then
            channelType = "PARTY"
        end

        -- 채널 활성화 상태 확인
        local channelEnabled = addon.ChannelFilter:IsChannelEnabled(channelType, channelName)
        print(string.format("  %s 채널 필터링: %s", targetChannel, channelEnabled and "O" or "X"))

        -- ChannelFilter로 테스트
        local shouldFilter, matchedKeyword = addon.ChannelFilter:ShouldFilter(testMessage, channelType, channelName)
        print(string.format("  필터링 결과: %s", shouldFilter and ("O - 키워드: " .. (matchedKeyword or "nil")) or "X"))

        -- HighlightKeywords로 직접 키워드 확인
        print("|cFFFFFF00[키워드 디버그]|r")
        local testKeywords = addon.ChannelFilter:GetKeywords(channelType, channelName)
        local keywordCount = 0
        local hasMonastery = false
        for k, v in pairs(testKeywords) do
            keywordCount = keywordCount + 1
            if keywordCount <= 20 then  -- 모든 키워드 표시
                print(string.format("    키워드 %d: '%s' -> '%s'", keywordCount, k, v))
            end
            if k == "수도원" or v == "수도원" then
                hasMonastery = true
            end
        end
        print(string.format("  총 키워드 수: %d개", keywordCount))
        print(string.format("  '수도원' 포함 여부: %s", hasMonastery and "O" or "X"))

        -- HighlightKeywords로 테스트 (디버그 출력 활성화)
        print("|cFFFFFF00[하이라이트 테스트]|r")

        -- 함수 호출 전 확인
        print("  HighlightKeywords 함수 호출 시작...")

        -- 오류 처리를 위한 pcall 사용
        local success, highlighted, foundKeyword = pcall(HighlightKeywords, testMessage, targetChannel, "테스트유저")

        if not success then
            print(string.format("  |cFFFF0000오류 발생: %s|r", highlighted))
            print("  하이라이트 결과: X")
        else
            print(string.format("  하이라이트 결과: %s", foundKeyword and "O" or "X"))
            if foundKeyword then
                print("  하이라이트된 텍스트: " .. highlighted)

                -- 토스트 테스트도 같이 표시
                print("|cFFFFFF00[토스트 테스트]|r")
                print("  토스트 표시 중...")
                ShowToast("테스트유저", testMessage, targetChannel, true)
            else
                print("  |cFFFF0000하이라이트 실패 - 키워드를 찾지 못함|r")
            end
        end
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

-- 이름 정규화(서버명 제거)
local function GetPlainName(unitOrName)
    local name = unitOrName
    if UnitExists(unitOrName) then
        name = UnitName(unitOrName)
    end
    if Ambiguate then
        name = Ambiguate(name, "none")
    end
    -- 서버명 제거
    if name then
        name = string.gsub(name, "%-.*$", "")
    end
    return name
end

-- GetRaidRosterInfo를 사용한 확실한 공대장/부공대장 체크
local function GetMyRaidRole()
    if not IsInRaid() then return false, false end

    local myName = GetPlainName("player")
    local numMembers = GetNumGroupMembers()

    if debugMode then
        print(string.format("|cFF00FFFF[FoxChat Debug] 공대 권한 체크 시작: 내 이름=%s, 공대원 수=%d|r",
            myName or "nil", numMembers))
    end

    for i = 1, numMembers do
        local name, rank = GetRaidRosterInfo(i)
        local plainName = name and GetPlainName(name)

        if debugMode and i <= 5 then  -- 처음 5명만 디버그 출력
            print(string.format("|cFF00FFFF[FoxChat Debug] 멤버[%d]: %s (rank=%s)|r",
                i, plainName or "nil", tostring(rank)))
        end

        if plainName == myName then
            -- rank: 2=공대장, 1=부공대장, 0=일반
            local isLeader = (rank == 2)
            local isAssistant = (rank == 1)

            if debugMode then
                print(string.format("|cFF00FF00[FoxChat Debug] 내 권한 찾음! rank=%d, 공대장=%s, 부공대장=%s|r",
                    rank, tostring(isLeader), tostring(isAssistant)))
            end

            return isLeader, isAssistant
        end
    end

    if debugMode then
        print("|cFFFF0000[FoxChat Debug] 내 권한을 찾지 못함|r")
    end

    return false, false
end

-- 내가 파티에 참가할 때 인사
local function SendMyJoinGreeting()
    if not FoxChatDB or not FoxChatDB.autoGreetOnMyJoin then return end
    if not FoxChatDB.myJoinMessages or FoxChatDB.myJoinMessages == "" then return end
    if hasGreetedMyJoin then return end  -- 이미 인사했으면 스킵

    -- 줄바꿈으로 구분된 문자열을 테이블로 변환
    local messages = {strsplit("\n", FoxChatDB.myJoinMessages)}

    -- 유효한 메시지만 필터링 (공백 제거)
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(validMessages, trimmed)
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
    if not FoxChatDB or not FoxChatDB.autoGreetOnOthersJoin then return end
    if not targetName or targetName == "" then return end

    -- 리더 체크 (개선된 방식)
    local isRaidLeader, isRaidAssistant = false, false
    local isPartyLeader = false

    if IsInRaid() then
        -- GetRaidRosterInfo를 사용한 확실한 공대장 체크
        isRaidLeader, isRaidAssistant = GetMyRaidRole()
    elseif IsInGroup() then
        -- 파티장 체크
        isPartyLeader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    end

    -- 디버그 출력 (테스트용)
    if debugMode then
        print(string.format("|cFF00FF00[FoxChat Debug] 인사 체크: 대상=%s, 공대장=%s, 부공대장=%s, 파티장=%s|r",
            targetName or "nil",
            tostring(isRaidLeader),
            tostring(isRaidAssistant),
            tostring(isPartyLeader)))
    end

    local messages = {}
    local sendAllLines = false  -- 전체 발송 여부
    local channel = "PARTY"  -- 기본 채널

    -- 리더 전용 인사말 체크
    if isRaidLeader and FoxChatDB.leaderGreetRaidMessages and FoxChatDB.leaderGreetRaidMessages ~= "" then
        -- 공대장 전용 인사말 사용
        messages = {strsplit("\n", FoxChatDB.leaderGreetRaidMessages)}
        sendAllLines = true
        -- 공대장도 일반 RAID 채널 사용 (/공)
        channel = "RAID"
        if debugMode then
            print("|cFFFF00FF[FoxChat Debug] 공대장 인사말 사용, 채널: " .. channel .. "|r")
        end
    elseif isPartyLeader and FoxChatDB.leaderGreetPartyMessages and FoxChatDB.leaderGreetPartyMessages ~= "" then
        -- 파티장 전용 인사말 사용
        messages = {strsplit("\n", FoxChatDB.leaderGreetPartyMessages)}
        sendAllLines = true
        channel = "PARTY"
        if debugMode then
            print("|cFFFF00FF[FoxChat Debug] 파티장 인사말 사용, 채널: " .. channel .. "|r")
        end
    else
        -- 기존 로직: 일반 인사말 사용 (랜덤)
        if not FoxChatDB.othersJoinMessages or FoxChatDB.othersJoinMessages == "" then return end
        messages = {strsplit("\n", FoxChatDB.othersJoinMessages)}
        sendAllLines = false

        -- 공격대/파티 구분하여 채널 설정
        if IsInRaid() then
            channel = "RAID"
        else
            channel = "PARTY"
        end
    end

    -- 유효한 메시지만 필터링 (공백 제거)
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(validMessages, trimmed)
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

    -- 메시지 발송
    if sendAllLines then
        -- 모든 줄 순차적으로 발송 (리더 전용)
        for i, msg in ipairs(validMessages) do
            -- {name} 치환
            local finalMsg = string.gsub(msg, "{name}", targetName)
            finalMsg = string.gsub(finalMsg, "{target}", targetName)  -- 이전 호환성

            -- 딜레이를 두고 순차 발송 (스팸 방지)
            C_Timer.After(1.5 + (i - 1) * 0.5, function()
                SendChatMessage(finalMsg, channel)
            end)
        end
    else
        -- 기존 로직: 랜덤 선택
        local message = validMessages[math.random(#validMessages)]

        -- 변수 치환
        message = string.gsub(message, "{name}", targetName)
        message = string.gsub(message, "{target}", targetName)  -- 이전 호환성

        -- 파티 채팅으로 전송 (약간의 딜레이)
        C_Timer.After(1.5, function()
            SendChatMessage(message, channel)
        end)
    end
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
autoEventFrame:RegisterEvent("CHAT_MSG_WHISPER")  -- 귓속말 받음
autoEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- 전투 시작
autoEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- 전투 종료

local lastGroupSize = 0
local partyMembers = {}  -- 현재 파티 멤버 추적
local wasInvited = false  -- 초대받았는지 여부

-- AFK/DND 자동응답 시스템
local autoReplyCooldowns = {}  -- 플레이어별 쿨다운 추적 {playerName = lastReplyTime}
local inCombat = false  -- 전투 중 상태

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
            --             -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 시작 - 상대: " .. (tradePartnerName or "알 수 없음")) -- 디버그용 주석 처리
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

        -- 디버그 메시지 주석 처리
        -- if FoxChatDB and FoxChatDB.autoTrade then
        --     DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 수락 상태 - Player: %d, Target: %d",
        --         arg1 or 0, arg2 or 0))
        -- end

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
            --                 DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공 예정 - 데이터 스냅샷 완료") -- 디버그용 주석 처리
            end
        end
        -- else 부분 제거: tradeWillComplete를 false로 되돌리지 않음

    elseif event == "TRADE_REQUEST_CANCEL" then

        -- 양쪽 모두 골드를 올려놓았는지 확인
        if tradeSnapshot and tradeSnapshot.givenMoney > 0 and tradeSnapshot.gotMoney > 0 and tradePartnerName then
            --             DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[FoxChat]|r 양쪽 모두 골드를 올려놓아 거래 실패!") -- 디버그용 주석 처리

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
            --                         DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. targetName) -- 디버그용 주석 처리
                    end
                end)
            else
                SendChatMessage(failMessage, "WHISPER", nil, tradePartnerName)
            --                 DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. tradePartnerName) -- 디버그용 주석 처리
            end
        end

        -- 거래 취소 명시
        tradeWillComplete = false
        if FoxChatDB and FoxChatDB.autoTrade then
            --             -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 취소 이벤트") -- 디버그용 주석 처리
        end

    elseif event == "TRADE_CLOSED" then
        -- 디버그 메시지
        if FoxChatDB and FoxChatDB.autoTrade then
            -- DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF7D0A[FoxChat]|r 거래 종료 - 성공예정=%s, 파트너=%s",
            --     tostring(tradeWillComplete), tostring(tradePartnerName)))
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
            --                         DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. targetName) -- 디버그용 주석 처리
                    end
                end)
            else
                SendChatMessage(failMessage, "WHISPER", nil, tradePartnerName)
            --                 DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 실패 안내 메시지 전송: " .. tradePartnerName) -- 디버그용 주석 처리
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
            --                 DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 성공!") -- 디버그용 주석 처리
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
            --                     -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 거래 취소 또는 실패") -- 디버그용 주석 처리
                elseif not tradePartnerName then
                    -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r 상대 이름 식별 실패")
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
                        -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 거래 완료 - 귓속말 전송: " .. tradePartnerName)
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
                    -- DEFAULT_CHAT_FRAME:AddMessage("|cFFFF7D0A[FoxChat]|r ✓ 거래 완료 - 귓속말 전송: " .. lastTradePartnerName)
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
        -- 그룹 멤버 변경 감지
        local currentSize = GetNumGroupMembers()

        if IsInGroup() then  -- 파티나 공격대 모두 처리
            if lastGroupSize == 0 and currentSize > 0 then
                -- 내가 파티에 참가함 (초대받아서 들어간 경우만)
                if wasInvited then
                    SendMyJoinGreeting()
                    wasInvited = false  -- 플래그 리셋
                end

                -- 현재 그룹 멤버 목록 초기화
                wipe(partyMembers)
                if IsInRaid() then
                    -- 공격대 멤버 초기화
                    for i = 1, currentSize do
                        local name = GetRaidRosterInfo(i)
                        if name and name ~= "" and name ~= UnitName("player") then
                            partyMembers[name] = true
                        end
                    end
                else
                    -- 파티 멤버 초기화
                    for i = 1, currentSize - 1 do
                        local unit = "party" .. i
                        if UnitExists(unit) then
                            local name = UnitName(unit)
                            if name and name ~= "" then
                                partyMembers[name] = true
                            end
                        end
                    end
                end
            elseif currentSize > lastGroupSize and lastGroupSize > 0 then
                -- 다른 사람이 파티에 참가함
                -- 약간의 딜레이 후 새 멤버 찾기 (파티 정보 업데이트 대기)
                C_Timer.After(0.5, function()
                    if IsInGroup() then
                        local newMembers = {}

                        if IsInRaid() then
                            -- 공격대 새 멤버 확인
                            for i = 1, GetNumGroupMembers() do
                                local name = GetRaidRosterInfo(i)
                                if name and name ~= "" and name ~= UnitName("player") and not partyMembers[name] then
                                    -- 새 멤버 발견
                                    table.insert(newMembers, name)
                                    partyMembers[name] = true
                                end
                            end
                        else
                            -- 파티 새 멤버 확인
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
                        end

                        -- 새 멤버들에게 인사
                        for _, memberName in ipairs(newMembers) do
                            SendOthersJoinGreeting(memberName)
                        end
                    end
                end)
            elseif currentSize < lastGroupSize then
                -- 누군가 그룹을 떠남 - 멤버 목록 업데이트
                local currentMembers = {}
                if IsInRaid() then
                    -- 공격대 멤버 업데이트
                    for i = 1, currentSize do
                        local name = GetRaidRosterInfo(i)
                        if name and name ~= "" and name ~= UnitName("player") then
                            currentMembers[name] = true
                        end
                    end
                else
                    -- 파티 멤버 업데이트
                    for i = 1, currentSize - 1 do
                        local unit = "party" .. i
                        if UnitExists(unit) then
                            local name = UnitName(unit)
                            if name and name ~= "" then
                                currentMembers[name] = true
                            end
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

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 전투 시작
        inCombat = true

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 전투 종료
        inCombat = false

    elseif event == "CHAT_MSG_WHISPER" then
        -- 귓속말 받음 - 자동응답 처리
        local message, sender = ...

        -- 파티원/공대원인지 확인
        local isGroupMember = false

        -- 발신자 이름 정규화 (서버명 제거)
        local senderName = sender
        if senderName then
            senderName = senderName:match("([^-]+)") or senderName  -- 서버명 제거
        end

        if IsInGroup() or IsInRaid() then
            -- 디버그 모드일 때 체크 과정 출력
            local debugMode = FoxChatDB and FoxChatDB.debugAutoReply
            if debugMode then
                print("|cFFFFFF00[자동응답 체크]|r 발신자:", senderName, "IsInRaid:", IsInRaid(), "IsInGroup:", IsInGroup())
            end

            -- 파티/공대원 체크
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    local unitName = UnitName("raid"..i)
                    if unitName then
                        unitName = unitName:match("([^-]+)") or unitName  -- 서버명 제거
                        if unitName == senderName then
                            isGroupMember = true
                            if debugMode then
                                print("|cFFFFFF00[자동응답]|r", senderName, "는 공대원입니다.")
                            end
                            break
                        end
                    end
                end
            elseif IsInGroup() then
                -- 자기 자신 체크
                local myName = UnitName("player")
                if myName then
                    myName = myName:match("([^-]+)") or myName  -- 서버명 제거
                    if myName == senderName then
                        isGroupMember = true
                        if debugMode then
                            print("|cFFFFFF00[자동응답]|r", senderName, "는 나 자신입니다.")
                        end
                    end
                end

                -- 파티원 체크
                if not isGroupMember then
                    for i = 1, GetNumGroupMembers() - 1 do
                        local unitName = UnitName("party"..i)
                        if unitName then
                            unitName = unitName:match("([^-]+)") or unitName  -- 서버명 제거
                            if unitName == senderName then
                                isGroupMember = true
                                if debugMode then
                                    print("|cFFFFFF00[자동응답]|r", senderName, "는 파티원입니다.")
                                end
                                break
                            end
                        end
                    end
                end
            end

            if debugMode and not isGroupMember then
                print("|cFFFFFF00[자동응답]|r", senderName, "는 그룹 멤버가 아닙니다.")
            end
        end

        -- AFK/DND 상태이거나 전투 중이거나 인던에 있는지 확인
        local isAFK = UnitIsAFK("player")
        local isDND = UnitIsDND("player")
        local isInInstance = IsInInstance()

        -- 응답이 필요한지 확인 (개별 체크박스 기반)
        local shouldRespond = false
        local replyMessage = nil

        -- AFK/DND 체크 (항상 활성화)
        if (isAFK or isDND) then
            shouldRespond = true
            if isAFK then
                replyMessage = "[자동응답] 현재 자리를 비웠습니다. 돌아오면 답변드리겠습니다!"
            else
                replyMessage = "[자동응답] 현재 방해금지 모드입니다. 나중에 답변드리겠습니다!"
            end
        end

        -- 전투 중 체크 (파티원/공대원 제외)
        if not shouldRespond and inCombat and FoxChatDB and FoxChatDB.autoReplyCombat then
            -- 같은 파티/공대원이면 자동응답 하지 않음
            if not isGroupMember then
                shouldRespond = true
                replyMessage = (FoxChatDB and FoxChatDB.combatReplyMessage) or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
            end
        end

        -- 인던 중 체크 (파티원/공대원 제외)
        if not shouldRespond and isInInstance and FoxChatDB and FoxChatDB.autoReplyInstance then
            -- 같은 파티/공대원이면 자동응답 하지 않음
            if not isGroupMember then
                shouldRespond = true
                replyMessage = (FoxChatDB and FoxChatDB.instanceReplyMessage) or "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
            end
        end

        -- 응답이 필요 없으면 종료
        if not shouldRespond or not replyMessage then
            return
        end

        -- 쿨다운 확인
        local currentTime = GetTime()
        local cooldownMinutes = (FoxChatDB and FoxChatDB.autoReplyCooldown) or 5
        local cooldownSeconds = cooldownMinutes * 60

        if autoReplyCooldowns[sender] then
            if currentTime - autoReplyCooldowns[sender] < cooldownSeconds then
                -- 아직 쿨다운 중
                return
            end
        end

        -- 메시지 전송
        SendChatMessage(replyMessage, "WHISPER", nil, sender)
        autoReplyCooldowns[sender] = currentTime

        -- 디버그 메시지
        if debugMode then
            print("|cFFFF7D0A[FoxChat]|r 자동응답 발송: " .. sender .. " - " .. replyMessage)
        end
    end
end)