local addonName, addon = ...

-- 광고 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.Advertisement = {}

local Advertisement = FoxChat.Features.Advertisement
local L = addon.L

-- 광고 시스템 변수
local adCooldownTimer = nil
local adLastClickTime = 0
local isAdvertisementMessage = false

-- 초기화
function Advertisement:Initialize()
    -- 전역 플래그 설정 (말머리/말꼬리 모듈과의 통신)
    _G.FoxChatIsAdvertisementMessage = false

    -- 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_SEND_ADVERTISEMENT", function()
            self:SendAdvertisement()
        end)

        FoxChat.Events:Register("FOXCHAT_AD_COOLDOWN_RESET", function()
            self:ResetCooldown()
        end)

        FoxChat.Events:Register("GROUP_ROSTER_UPDATE", function()
            -- 파티 정보 업데이트 시 버튼 상태 업데이트
            if FoxChat.UI and FoxChat.UI.AdButton then
                FoxChat.UI.AdButton:UpdateState()
            end
        end)
    end

    FoxChat:Debug("Advertisement 모듈 초기화 완료")
end

-- 광고 메시지 전송
function Advertisement:SendAdvertisement()
    -- 쿨다운 체크
    if self:IsOnCooldown() then
        FoxChat:Print("광고는 쿨다운 중입니다. " .. math.floor(self:GetCooldownRemaining()) .. "초 후에 다시 시도해주세요.")
        return false
    end

    -- 메시지 생성
    local message = self:BuildMessage()
    if not message or message == "" then
        FoxChat:Print("광고 메시지를 먼저 설정해주세요.")
        return false
    end

    -- 채널 찾기
    local channel = self:FindChannel()
    if not channel then
        local channelName = FoxChatDB and FoxChatDB.adChannel or "파티찾기"
        FoxChat:Print(channelName .. " 채널을 찾을 수 없습니다.")
        return false
    end

    -- 메시지 전송
    if self:SendMessage(message, channel) then
        -- 쿨다운 적용
        self:StartCooldown()
        return true
    end

    return false
end

-- 광고 메시지 생성
function Advertisement:BuildMessage()
    if not FoxChatDB then
        return ""
    end

    local baseMessage = FoxChatDB.adMessage or ""
    if baseMessage == "" or FoxChat.Utils.Common:IsEmptyOrWhitespace(baseMessage) then
        return ""
    end

    local message = tostring(baseMessage)

    -- 선입 메시지 추가
    if FoxChatDB.firstComeEnabled and FoxChatDB.firstComeMessage and FoxChatDB.firstComeMessage ~= "" then
        if message ~= "" and string.sub(message, -1) ~= " " then
            message = message .. " "
        end
        message = message .. "(" .. tostring(FoxChatDB.firstComeMessage) .. ")"
    end

    -- 파티 정보 추가 (자동 모드인 경우)
    local maxMembers = tonumber(FoxChatDB.partyMaxSize) or 5
    if maxMembers > 0 then
        local currentMembers = self:GetPartyMemberCount()

        if message ~= "" and string.sub(message, -1) ~= " " then
            message = message .. " "
        end
        message = message .. "(" .. currentMembers .. "/" .. maxMembers .. ")"
    end

    -- 메시지 길이 제한 (255바이트)
    if FoxChat.Utils and FoxChat.Utils.UTF8 then
        message = FoxChat.Utils.UTF8:TrimByBytes(message, 255)
    elseif #message > 255 then
        message = string.sub(message, 1, 255)
    end

    return message
end

-- 현재 파티/공격대 인원 수 확인
function Advertisement:GetPartyMemberCount()
    if IsInRaid() then
        return GetNumGroupMembers()  -- 공격대 인원
    elseif IsInGroup() then
        return GetNumGroupMembers()  -- 파티 인원
    else
        return 1  -- 나 혼자
    end
end

-- 파티가 가득 찼는지 확인
function Advertisement:IsPartyFull()
    if not FoxChatDB or not FoxChatDB.autoStopAtFull then
        return false
    end

    local maxMembers = tonumber(FoxChatDB.partyMaxSize) or 5
    if maxMembers <= 0 then
        return false  -- 수동 모드
    end

    return self:GetPartyMemberCount() >= maxMembers
end

-- 광고 채널 찾기
function Advertisement:FindChannel()
    local targetChannelName = FoxChatDB and FoxChatDB.adChannel or "파티찾기"
    local channels = {GetChannelList()}

    -- 정확한 채널명 매칭
    for i = 1, #channels, 3 do
        local id, name = channels[i], channels[i+1]
        if name then
            -- 선택된 채널명과 일치하는지 확인
            if string.find(name, targetChannelName) or
               (targetChannelName == "파티찾기" and string.find(name, "LookingForGroup")) or
               (targetChannelName == "공개" and (string.find(name, "General") or string.find(name, "일반"))) or
               (targetChannelName == "거래" and string.find(name, "Trade")) then
                return id
            end
        end
    end

    -- 폴백: 파티찾기 못 찾으면 공개 채널
    if targetChannelName == "파티찾기" then
        for i = 1, #channels, 3 do
            local id, name = channels[i], channels[i+1]
            if name and (string.find(name, "General") or string.find(name, "일반") or string.find(name, "공개")) then
                return id
            end
        end
    end

    return nil
end

-- 메시지 전송
function Advertisement:SendMessage(message, channel)
    if not message or message == "" then
        return false
    end

    -- 광고 메시지 플래그 설정 (말머리/말꼬리 방지)
    _G.FoxChatIsAdvertisementMessage = true
    isAdvertisementMessage = true

    -- 원본 SendChatMessage 사용
    local success, err = pcall(function()
        if _G.originalSendChatMessage then
            _G.originalSendChatMessage(message, "CHANNEL", nil, channel)
        else
            SendChatMessage(message, "CHANNEL", nil, channel)
        end
    end)

    -- 플래그 해제
    _G.FoxChatIsAdvertisementMessage = false
    isAdvertisementMessage = false

    if not success then
        FoxChat:Debug("광고 전송 실패:", err)
        return false
    end

    return true
end

-- 쿨다운 관련 함수
function Advertisement:StartCooldown()
    local cooldownTime = FoxChatDB and FoxChatDB.adCooldown or 30
    adLastClickTime = GetTime()

    -- 쿨다운 타이머 시작
    if adCooldownTimer then
        adCooldownTimer:Cancel()
    end

    adCooldownTimer = C_Timer.NewTimer(cooldownTime, function()
        adCooldownTimer = nil

        -- 쿨다운 종료 이벤트
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_AD_COOLDOWN_END")
        end
    end)

    -- 쿨다운 시작 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_AD_COOLDOWN_START", adLastClickTime, cooldownTime)
    end
end

function Advertisement:ResetCooldown()
    if adCooldownTimer then
        adCooldownTimer:Cancel()
        adCooldownTimer = nil
    end
    adLastClickTime = 0

    -- 쿨다운 리셋 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_AD_COOLDOWN_RESET")
    end
end

function Advertisement:IsOnCooldown()
    return adCooldownTimer ~= nil
end

function Advertisement:GetCooldownRemaining()
    if not adCooldownTimer or adLastClickTime == 0 then
        return 0
    end

    local cooldownTime = FoxChatDB and FoxChatDB.adCooldown or 30
    local elapsed = GetTime() - adLastClickTime
    local remaining = cooldownTime - elapsed

    return remaining > 0 and remaining or 0
end

function Advertisement:GetLastClickTime()
    return adLastClickTime
end

-- 설정 관련 함수
function Advertisement:SetMessage(message)
    if FoxChatDB then
        FoxChatDB.adMessage = message or ""
    end
end

function Advertisement:GetMessage()
    return FoxChatDB and FoxChatDB.adMessage or ""
end

function Advertisement:SetChannel(channel)
    if FoxChatDB then
        FoxChatDB.adChannel = channel or "파티찾기"
    end
end

function Advertisement:GetChannel()
    return FoxChatDB and FoxChatDB.adChannel or "파티찾기"
end

function Advertisement:SetCooldown(seconds)
    if FoxChatDB then
        FoxChatDB.adCooldown = seconds or 30
    end
end

function Advertisement:GetCooldown()
    return FoxChatDB and FoxChatDB.adCooldown or 30
end

function Advertisement:SetPartyMaxSize(size)
    if FoxChatDB then
        FoxChatDB.partyMaxSize = size or 5
    end
end

function Advertisement:GetPartyMaxSize()
    return FoxChatDB and FoxChatDB.partyMaxSize or 5
end

function Advertisement:SetAutoStop(enabled)
    if FoxChatDB then
        FoxChatDB.autoStopAtFull = enabled
    end
end

function Advertisement:IsAutoStopEnabled()
    return FoxChatDB and FoxChatDB.autoStopAtFull
end

-- 활성화/비활성화
function Advertisement:Enable()
    if FoxChatDB then
        FoxChatDB.adEnabled = true

        -- 버튼 업데이트
        if FoxChat.UI and FoxChat.UI.AdButton then
            FoxChat.UI.AdButton:UpdateState()
        end
    end
end

function Advertisement:Disable()
    if FoxChatDB then
        FoxChatDB.adEnabled = false

        -- 버튼 숨기기
        if FoxChat.UI and FoxChat.UI.AdButton then
            FoxChat.UI.AdButton:Hide()
        end
    end
end

function Advertisement:IsEnabled()
    return FoxChatDB and FoxChatDB.adEnabled
end