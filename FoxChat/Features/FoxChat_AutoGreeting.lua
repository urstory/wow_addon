local addonName, addon = ...

-- 자동 인사 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.AutoGreeting = {}

local AutoGreeting = FoxChat.Features.AutoGreeting
local L = addon.L

-- 인사 관련 변수
local partyGreetCooldown = {}  -- 중복 인사 방지용 쿨다운
local hasGreetedMyJoin = false  -- 내가 이미 인사했는지

-- 초기화
function AutoGreeting:Initialize()
    -- 이벤트 등록
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_MEMBER_ENABLE")
    frame:RegisterEvent("PARTY_MEMBER_DISABLE")

    frame:SetScript("OnEvent", function(self, event, ...)
        AutoGreeting:OnEvent(event, ...)
    end)

    -- FoxChat 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_CONFIG_LOADED", function()
            -- 설정 로드 시 상태 초기화
            hasGreetedMyJoin = false
            wipe(partyGreetCooldown)
        end)
    end

    FoxChat:Debug("AutoGreeting 모듈 초기화 완료")
end

-- WoW 이벤트 처리
function AutoGreeting:OnEvent(event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        self:OnGroupRosterUpdate()
    end
end

-- 그룹 명단 업데이트
function AutoGreeting:OnGroupRosterUpdate()
    -- 내가 파티에 참가했는지 체크
    if IsInGroup() and not hasGreetedMyJoin then
        -- 내가 방금 파티에 참가했을 가능성
        C_Timer.After(0.5, function()
            if IsInGroup() then
                self:SendMyJoinGreeting()
            end
        end)
    end

    -- 다른 사람이 참가했는지 체크는 별도 로직 필요
    -- (GROUP_ROSTER_UPDATE만으로는 누가 들어왔는지 알기 어려움)
end

-- 이름 정규화 (서버명 제거)
function AutoGreeting:GetPlainName(unitOrName)
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

-- 내 공격대 역할 확인
function AutoGreeting:GetMyRaidRole()
    if not IsInRaid() then return false, false end

    local myName = self:GetPlainName("player")
    local numMembers = GetNumGroupMembers()

    FoxChat:Debug("공대 권한 체크: 내 이름=" .. (myName or "nil") .. ", 공대원 수=" .. numMembers)

    for i = 1, numMembers do
        local name, rank = GetRaidRosterInfo(i)
        local plainName = name and self:GetPlainName(name)

        if plainName == myName then
            -- rank: 2=공대장, 1=부공대장, 0=일반
            local isLeader = (rank == 2)
            local isAssistant = (rank == 1)

            FoxChat:Debug("내 권한 찾음! rank=" .. rank .. ", 공대장=" .. tostring(isLeader))

            return isLeader, isAssistant
        end
    end

    FoxChat:Debug("내 권한을 찾지 못함")
    return false, false
end

-- 내가 파티에 참가할 때 인사
function AutoGreeting:SendMyJoinGreeting()
    if not self:IsMyJoinEnabled() then return end
    if hasGreetedMyJoin then return end  -- 이미 인사했으면 스킵

    local messages = self:GetMyJoinMessages()
    if #messages == 0 then return end

    hasGreetedMyJoin = true

    -- 랜덤 메시지 선택
    local message = messages[math.random(#messages)]

    -- 변수 치환
    local myName = UnitName("player")
    message = string.gsub(message, "{me}", myName)

    -- 채널 결정
    local channel = IsInRaid() and "RAID" or "PARTY"

    -- 파티 채팅으로 전송 (약간의 딜레이)
    C_Timer.After(1, function()
        SendChatMessage(message, channel)
    end)

    -- 30초 후 플래그 리셋 (재입장 시 인사 가능)
    C_Timer.After(30, function()
        hasGreetedMyJoin = false
    end)
end

-- 다른 사람이 파티에 참가할 때 인사
function AutoGreeting:SendOthersJoinGreeting(targetName)
    if not self:IsOthersJoinEnabled() then return end
    if not targetName or targetName == "" then return end

    -- 쿨다운 체크 (10초)
    local now = GetTime()
    if partyGreetCooldown[targetName] and (now - partyGreetCooldown[targetName]) < 10 then
        return
    end
    partyGreetCooldown[targetName] = now

    -- 리더 체크
    local isRaidLeader, isRaidAssistant = false, false
    local isPartyLeader = false

    if IsInRaid() then
        isRaidLeader, isRaidAssistant = self:GetMyRaidRole()
    elseif IsInGroup() then
        isPartyLeader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    end

    FoxChat:Debug("인사 체크: 대상=" .. targetName ..
                  ", 공대장=" .. tostring(isRaidLeader) ..
                  ", 파티장=" .. tostring(isPartyLeader))

    local messages = {}
    local sendAllLines = false
    local channel = IsInRaid() and "RAID" or "PARTY"

    -- 리더 전용 인사말 체크
    if isRaidLeader then
        messages = self:GetLeaderRaidMessages()
        if #messages > 0 then
            sendAllLines = true
            FoxChat:Debug("공대장 인사말 사용")
        end
    elseif isPartyLeader then
        messages = self:GetLeaderPartyMessages()
        if #messages > 0 then
            sendAllLines = true
            FoxChat:Debug("파티장 인사말 사용")
        end
    end

    -- 일반 인사말 사용
    if #messages == 0 then
        messages = self:GetOthersJoinMessages()
        sendAllLines = false
    end

    if #messages == 0 then return end

    -- 메시지 발송
    if sendAllLines then
        -- 모든 줄 순차적으로 발송 (리더 전용)
        for i, msg in ipairs(messages) do
            -- 변수 치환
            local finalMsg = string.gsub(msg, "{name}", targetName)
            finalMsg = string.gsub(finalMsg, "{target}", targetName)  -- 이전 호환성

            -- 딜레이를 두고 순차 발송
            C_Timer.After(1.5 + (i - 1) * 0.5, function()
                SendChatMessage(finalMsg, channel)
            end)
        end
    else
        -- 랜덤 선택
        local message = messages[math.random(#messages)]

        -- 변수 치환
        message = string.gsub(message, "{name}", targetName)
        message = string.gsub(message, "{target}", targetName)  -- 이전 호환성

        -- 채팅으로 전송
        C_Timer.After(1.5, function()
            SendChatMessage(message, channel)
        end)
    end
end

-- 설정 관련 함수
function AutoGreeting:IsMyJoinEnabled()
    return FoxChatDB and FoxChatDB.autoPartyGreetMyJoin
end

function AutoGreeting:IsOthersJoinEnabled()
    return FoxChatDB and FoxChatDB.autoPartyGreetOthersJoin
end

function AutoGreeting:GetMyJoinMessages()
    if not FoxChatDB then return {} end

    local messages = {}
    if type(FoxChatDB.partyGreetMyJoinMessages) == "table" then
        messages = FoxChatDB.partyGreetMyJoinMessages
    elseif type(FoxChatDB.partyGreetMyJoinMessages) == "string" then
        messages = {strsplit("\n", FoxChatDB.partyGreetMyJoinMessages)}
    end

    -- 유효한 메시지만 필터링
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = FoxChat.Utils and FoxChat.Utils.Common and
                       FoxChat.Utils.Common:Trim(msg) or msg:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(validMessages, trimmed)
        end
    end

    return validMessages
end

function AutoGreeting:GetOthersJoinMessages()
    if not FoxChatDB then return {} end

    local messages = {}
    if type(FoxChatDB.partyGreetOthersJoinMessages) == "table" then
        messages = FoxChatDB.partyGreetOthersJoinMessages
    elseif type(FoxChatDB.partyGreetOthersJoinMessages) == "string" then
        messages = {strsplit("\n", FoxChatDB.partyGreetOthersJoinMessages)}
    end

    -- 유효한 메시지만 필터링
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = FoxChat.Utils and FoxChat.Utils.Common and
                       FoxChat.Utils.Common:Trim(msg) or msg:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(validMessages, trimmed)
        end
    end

    return validMessages
end

function AutoGreeting:GetLeaderRaidMessages()
    if not FoxChatDB or not FoxChatDB.leaderGreetRaidMessages then return {} end

    local messages = {strsplit("\n", FoxChatDB.leaderGreetRaidMessages)}

    -- 유효한 메시지만 필터링
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = FoxChat.Utils and FoxChat.Utils.Common and
                       FoxChat.Utils.Common:Trim(msg) or msg:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(validMessages, trimmed)
        end
    end

    return validMessages
end

function AutoGreeting:GetLeaderPartyMessages()
    if not FoxChatDB or not FoxChatDB.leaderGreetPartyMessages then return {} end

    local messages = {strsplit("\n", FoxChatDB.leaderGreetPartyMessages)}

    -- 유효한 메시지만 필터링
    local validMessages = {}
    for _, msg in ipairs(messages) do
        local trimmed = FoxChat.Utils and FoxChat.Utils.Common and
                       FoxChat.Utils.Common:Trim(msg) or msg:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(validMessages, trimmed)
        end
    end

    return validMessages
end

-- 활성화/비활성화
function AutoGreeting:EnableMyJoin()
    if FoxChatDB then
        FoxChatDB.autoPartyGreetMyJoin = true
    end
end

function AutoGreeting:DisableMyJoin()
    if FoxChatDB then
        FoxChatDB.autoPartyGreetMyJoin = false
    end
end

function AutoGreeting:EnableOthersJoin()
    if FoxChatDB then
        FoxChatDB.autoPartyGreetOthersJoin = true
    end
end

function AutoGreeting:DisableOthersJoin()
    if FoxChatDB then
        FoxChatDB.autoPartyGreetOthersJoin = false
    end
end