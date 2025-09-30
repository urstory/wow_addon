local addonName, addon = ...

-- 자동 응답 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.AutoReply = {}

local AutoReply = FoxChat.Features.AutoReply
local L = addon.L

-- 자동응답 관련 변수
local autoReplyCooldowns = {}  -- 사용자별 자동응답 쿨다운
local lastAutoReplyTime = 0    -- 마지막 자동응답 시간

-- 초기화
function AutoReply:Initialize()
    -- 이벤트 등록
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_WHISPER")
    frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    frame:RegisterEvent("PLAYER_FLAGS_CHANGED")

    frame:SetScript("OnEvent", function(self, event, ...)
        AutoReply:OnEvent(event, ...)
    end)

    -- FoxChat 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            -- 설정 로드 시 쿨다운 초기화
            wipe(autoReplyCooldowns)
            lastAutoReplyTime = 0
        end)
    end

    FoxChat:Debug("AutoReply 모듈 초기화 완료")
end

-- WoW 이벤트 처리
function AutoReply:OnEvent(event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        self:HandleWhisper(sender, false)
    elseif event == "CHAT_MSG_BN_WHISPER" then
        local message, sender = ...
        self:HandleWhisper(sender, true)
    end
end

-- 귓속말 처리
function AutoReply:HandleWhisper(sender, isBattleNet)
    if not sender then return end

    -- 자동응답 조건 체크
    local shouldReply, replyMessage = self:CheckAutoReplyConditions()
    if not shouldReply then return end

    -- 쿨다운 체크
    if not self:CheckCooldown(sender) then return end

    -- 자동응답 전송
    self:SendAutoReply(sender, replyMessage, isBattleNet)
end

-- 자동응답 조건 체크
function AutoReply:CheckAutoReplyConditions()
    if not FoxChatDB then return false end

    -- AFK/DND 체크
    if FoxChatDB.autoReplyAFK and (UnitIsAFK("player") or UnitIsDND("player")) then
        local afkMessage = UnitIsAFK("player") and GetDefaultLanguage("player") == "koKR" and
                          "[자동응답] 자리 비움 중입니다." or
                          "[AutoReply] Currently AFK."

        local dndMessage = UnitIsDND("player") and GetDefaultLanguage("player") == "koKR" and
                          "[자동응답] 다른 용무 중입니다." or
                          "[AutoReply] Do Not Disturb."

        return true, UnitIsAFK("player") and afkMessage or dndMessage
    end

    -- 전투 중 체크
    if FoxChatDB.autoReplyCombat and UnitAffectingCombat("player") then
        local message = FoxChatDB.combatReplyMessage or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
        return true, message
    end

    -- 인스턴스 체크
    if FoxChatDB.autoReplyInstance and IsInInstance() then
        local message = FoxChatDB.instanceReplyMessage or "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
        return true, message
    end

    return false
end

-- 쿨다운 체크
function AutoReply:CheckCooldown(sender)
    local now = GetTime()

    -- 전역 쿨다운 (1초)
    if now - lastAutoReplyTime < 1 then
        return false
    end

    -- 개인별 쿨다운
    local cooldownMinutes = FoxChatDB and FoxChatDB.autoReplyCooldown or 5
    local cooldownSeconds = cooldownMinutes * 60

    if autoReplyCooldowns[sender] then
        if now - autoReplyCooldowns[sender] < cooldownSeconds then
            return false
        end
    end

    return true
end

-- 자동응답 전송
function AutoReply:SendAutoReply(recipient, message, isBattleNet)
    if not recipient or not message then return end

    -- 메시지 길이 체크
    if FoxChat.Utils and FoxChat.Utils.UTF8 then
        message = FoxChat.Utils.UTF8:TrimByBytes(message, 255)
    elseif #message > 255 then
        message = string.sub(message, 1, 255)
    end

    -- 전송
    if isBattleNet then
        BNSendWhisper(recipient, message)
    else
        SendChatMessage(message, "WHISPER", nil, recipient)
    end

    -- 쿨다운 업데이트
    lastAutoReplyTime = GetTime()
    autoReplyCooldowns[recipient] = GetTime()

    FoxChat:Debug("자동응답 전송: " .. recipient)

    -- 일정 시간 후 쿨다운 데이터 정리 (메모리 관리)
    C_Timer.After(600, function()  -- 10분 후
        if autoReplyCooldowns[recipient] and GetTime() - autoReplyCooldowns[recipient] > 600 then
            autoReplyCooldowns[recipient] = nil
        end
    end)
end

-- 설정 관련 함수
function AutoReply:IsAFKReplyEnabled()
    return FoxChatDB and FoxChatDB.autoReplyAFK
end

function AutoReply:IsCombatReplyEnabled()
    return FoxChatDB and FoxChatDB.autoReplyCombat
end

function AutoReply:IsInstanceReplyEnabled()
    return FoxChatDB and FoxChatDB.autoReplyInstance
end

function AutoReply:SetAFKReply(enabled)
    if FoxChatDB then
        FoxChatDB.autoReplyAFK = enabled
    end
end

function AutoReply:SetCombatReply(enabled)
    if FoxChatDB then
        FoxChatDB.autoReplyCombat = enabled
    end
end

function AutoReply:SetInstanceReply(enabled)
    if FoxChatDB then
        FoxChatDB.autoReplyInstance = enabled
    end
end

function AutoReply:SetCombatMessage(message)
    if FoxChatDB then
        FoxChatDB.combatReplyMessage = message or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
    end
end

function AutoReply:SetInstanceMessage(message)
    if FoxChatDB then
        FoxChatDB.instanceReplyMessage = message or "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
    end
end

function AutoReply:SetCooldown(minutes)
    if FoxChatDB then
        FoxChatDB.autoReplyCooldown = minutes or 5
    end
end

function AutoReply:GetCombatMessage()
    return FoxChatDB and FoxChatDB.combatReplyMessage or "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
end

function AutoReply:GetInstanceMessage()
    return FoxChatDB and FoxChatDB.instanceReplyMessage or "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
end

function AutoReply:GetCooldown()
    return FoxChatDB and FoxChatDB.autoReplyCooldown or 5
end

-- 테스트 함수
function AutoReply:TestReply(condition)
    local message = ""

    if condition == "afk" then
        message = "[자동응답] 자리 비움 중입니다."
    elseif condition == "dnd" then
        message = "[자동응답] 다른 용무 중입니다."
    elseif condition == "combat" then
        message = self:GetCombatMessage()
    elseif condition == "instance" then
        message = self:GetInstanceMessage()
    else
        message = "[자동응답] 테스트 메시지입니다."
    end

    FoxChat:Print("자동응답 테스트:", message)

    -- 실제로 자신에게 귓속말 (테스트)
    SendChatMessage(message, "WHISPER", nil, UnitName("player"))
end

-- 상태 확인 함수
function AutoReply:GetStatus()
    local status = {}

    if UnitIsAFK("player") then
        table.insert(status, "AFK")
    end
    if UnitIsDND("player") then
        table.insert(status, "DND")
    end
    if UnitAffectingCombat("player") then
        table.insert(status, "전투중")
    end
    if IsInInstance() then
        local instanceType = select(2, IsInInstance())
        if instanceType == "pvp" then
            table.insert(status, "전장")
        elseif instanceType == "arena" then
            table.insert(status, "투기장")
        elseif instanceType == "party" then
            table.insert(status, "던전")
        elseif instanceType == "raid" then
            table.insert(status, "레이드")
        else
            table.insert(status, "인스턴스")
        end
    end

    return #status > 0 and table.concat(status, ", ") or "일반"
end

-- 쿨다운 리셋
function AutoReply:ResetCooldowns()
    wipe(autoReplyCooldowns)
    lastAutoReplyTime = 0
    FoxChat:Print("자동응답 쿨다운이 초기화되었습니다.")
end