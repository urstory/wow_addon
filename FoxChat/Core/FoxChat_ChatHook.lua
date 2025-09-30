local addonName, addon = ...

-- 채팅 필터 훅 통합 모듈
FoxChat = FoxChat or {}
FoxChat.Core = FoxChat.Core or {}
FoxChat.Core.ChatHook = {}

local ChatHook = FoxChat.Core.ChatHook
local L = addon.L

-- 원본 함수 저장
local originalAddMessage = {}

-- 초기화
function ChatHook:Initialize()
    -- 채팅 프레임 훅 설치
    self:HookChatFrames()
    
    -- 이벤트 등록
    self:RegisterEvents()
    
    FoxChat:Debug("ChatHook 모듈 초기화 완료")
end

-- 채팅 프레임 훅
function ChatHook:HookChatFrames()
    -- 모든 채팅 프레임에 훅 설치
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then
            self:HookSingleFrame(frame)
        end
    end
    
    -- 새로 생성되는 채팅 프레임을 위한 FCF 훅
    local originalFCF_OpenTemporaryWindow = FCF_OpenTemporaryWindow
    FCF_OpenTemporaryWindow = function(...)
        local frame = originalFCF_OpenTemporaryWindow(...)
        if frame then
            ChatHook:HookSingleFrame(frame)
        end
        return frame
    end
end

-- 단일 프레임 훅
function ChatHook:HookSingleFrame(frame)
    if not frame or originalAddMessage[frame] then return end
    
    -- 원본 함수 저장
    originalAddMessage[frame] = frame.AddMessage
    
    -- 새 AddMessage 함수
    frame.AddMessage = function(self, text, ...)
        -- FoxChat 활성화 체크
        if not FoxChatDB or not FoxChatDB.enabled then
            return originalAddMessage[self](self, text, ...)
        end
        
        -- 메시지 처리
        local processedText = ChatHook:ProcessMessage(text, self)
        
        -- nil이면 필터링됨
        if processedText == nil then
            return
        end
        
        -- 원본 함수 호출
        return originalAddMessage[self](self, processedText, ...)
    end
end

-- 메시지 처리
function ChatHook:ProcessMessage(text, frame)
    if not text or text == "" then return text end
    
    local originalText = text
    local processedText = text
    
    -- 채널 및 작성자 정보 추출
    local channelInfo = self:ExtractChannelInfo(text)
    local author = self:ExtractAuthor(text)
    local channelGroup = self:GetChannelGroup(channelInfo)
    
    -- 채널 그룹 필터링
    if not self:IsChannelGroupEnabled(channelGroup) then
        return processedText
    end
    
    -- 각 기능 모듈 호출
    
    -- 1. 키워드 필터링
    if FoxChat.Features and FoxChat.Features.KeywordFilter then
        local filtered, highlighted = FoxChat.Features.KeywordFilter:ProcessMessage(
            processedText, channelGroup, author
        )
        
        if filtered == nil then
            -- 필터링됨
            return nil
        elseif highlighted then
            processedText = highlighted
        end
    end
    
    -- 2. 말머리/말꼬리 처리
    if FoxChat.Features and FoxChat.Features.PrefixSuffix then
        local modified = FoxChat.Features.PrefixSuffix:ProcessMessage(
            processedText, channelGroup, author
        )
        if modified then
            processedText = modified
        end
    end
    
    -- 3. 자동 거래 처리
    if FoxChat.Features and FoxChat.Features.AutoTrade then
        -- 자동 거래는 특정 키워드를 찾아 처리
        FoxChat.Features.AutoTrade:ProcessTradeMessage(processedText, author)
    end
    
    -- 이벤트 트리거
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_MESSAGE_PROCESSED", {
            original = originalText,
            processed = processedText,
            channel = channelInfo,
            author = author,
            channelGroup = channelGroup,
            frame = frame
        })
    end
    
    return processedText
end

-- 채널 정보 추출
function ChatHook:ExtractChannelInfo(text)
    if not text then return nil end
    
    -- 채널 태그 패턴: |Hchannel:...|h[...]
    local channel = string.match(text, "|Hchannel:([^|]+)|h")
    if channel then
        return channel
    end
    
    -- 기타 채턐 패턴 검사
    if string.find(text, "^%[%d+%.%s") then  -- 번호 채널
        local num = string.match(text, "^%[(%d+)%.")
        return "channel:" .. num
    end
    
    return nil
end

-- 작성자 추출
function ChatHook:ExtractAuthor(text)
    if not text then return nil end
    
    -- 플레이어 링크 패턴: |Hplayer:...|h[...]
    local author = string.match(text, "|Hplayer:([^|:]+)[^|]*|h%[([^%]]*)%]|h")
    if author then
        return author
    end
    
    -- 단순 패턴: [Name]:
    author = string.match(text, "%[([^%]]+)%]:")
    if author then
        return author
    end
    
    return nil
end

-- 채널 그룹 판단
function ChatHook:GetChannelGroup(channelInfo)
    if not channelInfo then return "OTHER" end
    
    local lowerChannel = string.lower(channelInfo)
    
    -- 길드
    if string.find(lowerChannel, "guild") or string.find(lowerChannel, "officer") then
        return "GUILD"
    end
    
    -- 파티/공격대
    if string.find(lowerChannel, "party") or string.find(lowerChannel, "raid") or
       string.find(lowerChannel, "instance") then
        return "PARTY_RAID"
    end
    
    -- 파티찾기
    if string.find(lowerChannel, "lookingfor") or string.find(lowerChannel, "lfg") then
        return "LFG"
    end
    
    -- 공개 채널 (일반, 거래, 지역방어 등)
    if string.find(lowerChannel, "channel:") or 
       string.find(lowerChannel, "general") or
       string.find(lowerChannel, "trade") or
       string.find(lowerChannel, "local") or
       string.find(lowerChannel, "world") then
        return "PUBLIC"
    end
    
    return "OTHER"
end

-- 채널 그룹 활성화 확인
function ChatHook:IsChannelGroupEnabled(channelGroup)
    if not FoxChatDB or not FoxChatDB.channelGroups then
        return true  -- 기본값: 모든 채널 활성화
    end
    
    -- channelGroups가 있으면 해당 그룹 확인
    if FoxChatDB.channelGroups[channelGroup] ~= nil then
        return FoxChatDB.channelGroups[channelGroup]
    end
    
    return true  -- 기본값
end

-- 이벤트 등록
function ChatHook:RegisterEvents()
    if FoxChat.Events then
        -- 설정 변경 시
        FoxChat.Events:Register("FOXCHAT_SETTINGS_CHANGED", function()
            -- 필요한 경우 훅 재설치 등 처리
        end)
        
        -- 모듈 리로드 시
        FoxChat.Events:Register("FOXCHAT_MODULE_RELOAD", function()
            self:RefreshHooks()
        end)
    end
end

-- 훅 리프레시
function ChatHook:RefreshHooks()
    -- 필요한 경우 훅을 다시 설치
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not originalAddMessage[frame] then
            self:HookSingleFrame(frame)
        end
    end
end

-- 테스트 함수
function ChatHook:TestFilter()
    local testMessages = {
        "[1. 일반] [테스트]: 테스트 메시지입니다.",
        "[길드] [테스트]: 길드 메시지입니다.",
        "[파티] [테스트]: 파티 메시지입니다.",
        "[4. 파티찾기] [테스트]: LFG 메시지입니다."
    }
    
    FoxChat:Print("채팅 필터 테스트 시작")
    
    for _, msg in ipairs(testMessages) do
        local channelInfo = self:ExtractChannelInfo(msg)
        local author = self:ExtractAuthor(msg)
        local group = self:GetChannelGroup(channelInfo)
        
        FoxChat:Print(string.format(
            "메시지: %s\n  채널: %s\n  작성자: %s\n  그룹: %s\n  활성화: %s",
            msg,
            channelInfo or "N/A",
            author or "N/A",
            group,
            tostring(self:IsChannelGroupEnabled(group))
        ))
    end
    
    FoxChat:Print("채팅 필터 테스트 완료")
end