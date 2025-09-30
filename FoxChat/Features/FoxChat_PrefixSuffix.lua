local addonName, addon = ...

-- 말머리/말꼬리 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.PrefixSuffix = {}

local PrefixSuffix = FoxChat.Features.PrefixSuffix
local L = addon.L

-- 원본 SendChatMessage 함수 저장
local originalSendChatMessage = nil
local isHooked = false

-- 위상 메시지 목록 (이런 메시지는 말머리/말꼬리를 붙이지 않음)
local phaseMessages = {"일위상", "이위상", "삼위상"}

-- 초기화
function PrefixSuffix:Initialize()
    -- SendChatMessage 훅
    self:HookSendMessage()

    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            -- 설정이 로드되면 훅 상태 업데이트
            self:UpdateHookState()
        end)

        FoxChat.Events:Register("FOXCHAT_PREFIX_SUFFIX_TOGGLE", function(enabled)
            if FoxChatDB then
                FoxChatDB.prefixSuffixEnabled = enabled
                self:UpdateHookState()
            end
        end)
    end

    FoxChat:Debug("PrefixSuffix 모듈 초기화 완료")
end

-- SendChatMessage 훅
function PrefixSuffix:HookSendMessage()
    if isHooked then return end

    originalSendChatMessage = SendChatMessage

    SendChatMessage = function(message, chatType, language, channel)
        -- 말머리/말꼬리 처리
        message = PrefixSuffix:ProcessMessage(message, chatType)

        -- 원본 함수 호출
        if message and message ~= "" then
            originalSendChatMessage(message, chatType, language, channel)
        end
    end

    isHooked = true
    FoxChat:Debug("SendChatMessage 훅 설치 완료")
end

-- 훅 상태 업데이트
function PrefixSuffix:UpdateHookState()
    -- 필요시 훅 재설치 (현재는 항상 활성화)
    if not isHooked then
        self:HookSendMessage()
    end
end

-- 메시지 처리
function PrefixSuffix:ProcessMessage(message, chatType)
    -- 광고 메시지 체크 (광고 시스템에서 플래그 설정)
    if _G.FoxChatIsAdvertisementMessage then
        return message
    end

    -- 말머리/말꼬리 기능 비활성화 상태
    if not FoxChatDB or not FoxChatDB.prefixSuffixEnabled then
        return message
    end

    -- 빈 메시지
    if not message or message == "" then
        return message
    end

    -- 위상 메시지 체크
    if self:IsPhaseMessage(message) then
        return message
    end

    -- 채널 타입 확인
    local channelKey = chatType
    if chatType == "CHANNEL" then
        channelKey = "CHANNEL"
    elseif chatType == "INSTANCE_CHAT" then
        channelKey = "INSTANCE_CHAT"
    end

    -- 해당 채널에 말머리/말꼬리 적용 여부 확인
    if not self:IsChannelEnabled(channelKey) then
        return message
    end

    -- 말머리/말꼬리 추가
    local prefix = FoxChatDB.prefix or ""
    local suffix = FoxChatDB.suffix or ""

    if prefix ~= "" or suffix ~= "" then
        message = prefix .. message .. suffix
    end

    -- 메시지 길이 제한 (255바이트)
    if FoxChat.Utils and FoxChat.Utils.UTF8 then
        message = FoxChat.Utils.UTF8:TrimByBytes(message, 255)
    elseif #message > 255 then
        -- 폴백: 단순 자르기
        message = string.sub(message, 1, 255)
    end

    return message
end

-- 위상 메시지인지 확인
function PrefixSuffix:IsPhaseMessage(message)
    for _, phase in ipairs(phaseMessages) do
        if message == phase then
            return true
        end
    end
    return false
end

-- 채널이 활성화되어 있는지 확인
function PrefixSuffix:IsChannelEnabled(channelKey)
    if not FoxChatDB or not FoxChatDB.prefixSuffixChannels then
        return false
    end

    return FoxChatDB.prefixSuffixChannels[channelKey] == true
end

-- 말머리 설정
function PrefixSuffix:SetPrefix(prefix)
    if FoxChatDB then
        FoxChatDB.prefix = prefix or ""

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_PREFIX_CHANGED", FoxChatDB.prefix)
        end
    end
end

-- 말꼬리 설정
function PrefixSuffix:SetSuffix(suffix)
    if FoxChatDB then
        FoxChatDB.suffix = suffix or ""

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_SUFFIX_CHANGED", FoxChatDB.suffix)
        end
    end
end

-- 말머리 가져오기
function PrefixSuffix:GetPrefix()
    if FoxChatDB then
        return FoxChatDB.prefix or ""
    end
    return ""
end

-- 말꼬리 가져오기
function PrefixSuffix:GetSuffix()
    if FoxChatDB then
        return FoxChatDB.suffix or ""
    end
    return ""
end

-- 특정 채널 활성화/비활성화
function PrefixSuffix:SetChannelEnabled(channelKey, enabled)
    if FoxChatDB then
        FoxChatDB.prefixSuffixChannels = FoxChatDB.prefixSuffixChannels or {}
        FoxChatDB.prefixSuffixChannels[channelKey] = enabled

        -- 이벤트 발생
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_PREFIX_SUFFIX_CHANNEL_CHANGED", channelKey, enabled)
        end
    end
end

-- 모든 채널 설정 가져오기
function PrefixSuffix:GetChannelSettings()
    if FoxChatDB and FoxChatDB.prefixSuffixChannels then
        return FoxChat.Utils.Common:DeepCopy(FoxChatDB.prefixSuffixChannels)
    end

    -- 기본값
    return {
        SAY = true,
        YELL = false,
        PARTY = true,
        GUILD = true,
        RAID = true,
        INSTANCE_CHAT = true,
        WHISPER = false,
        CHANNEL = false,
    }
end

-- 활성화/비활성화
function PrefixSuffix:Enable()
    if FoxChatDB then
        FoxChatDB.prefixSuffixEnabled = true
        FoxChat:Print("말머리/말꼬리 기능이 활성화되었습니다.")
    end
end

function PrefixSuffix:Disable()
    if FoxChatDB then
        FoxChatDB.prefixSuffixEnabled = false
        FoxChat:Print("말머리/말꼬리 기능이 비활성화되었습니다.")
    end
end

function PrefixSuffix:Toggle()
    if FoxChatDB then
        if FoxChatDB.prefixSuffixEnabled then
            self:Disable()
        else
            self:Enable()
        end
    end
end

function PrefixSuffix:IsEnabled()
    return FoxChatDB and FoxChatDB.prefixSuffixEnabled
end

-- 테스트 메시지 전송
function PrefixSuffix:TestMessage(message)
    message = message or "테스트 메시지입니다."

    local prefix = self:GetPrefix()
    local suffix = self:GetSuffix()

    if prefix ~= "" or suffix ~= "" then
        local testMsg = prefix .. message .. suffix
        FoxChat:Print("테스트 결과: " .. testMsg)

        -- UTF-8 체크
        if FoxChat.Utils and FoxChat.Utils.UTF8 then
            local info = FoxChat.Utils.UTF8:Validate(testMsg)
            FoxChat:Print(string.format("글자 수: %d, 바이트 수: %d/255",
                info.charLen, info.byteLen))

            if not info.okForChat then
                FoxChat:Print("|cffff0000경고: 메시지가 255바이트를 초과합니다!|r")
            end
        end
    else
        FoxChat:Print("말머리/말꼬리가 설정되지 않았습니다.")
    end
end