local addonName, addon = ...

-- 선입 기능 모듈
FoxChat = FoxChat or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.Features.FirstCome = {}

local FirstCome = FoxChat.Features.FirstCome
local L = addon.L

-- 선입 관련 변수
local firstComeLastClickTime = 0
local firstComeCooldownTimer = nil

-- 초기화
function FirstCome:Initialize()
    -- FoxChat 이벤트 등록
    if FoxChat.Events then
        FoxChat.Events:Register("FOXCHAT_SEND_FIRSTCOME", function()
            self:SendFirstComeMessage()
        end)

        FoxChat.Events:Register("FOXCHAT_FIRSTCOME_COOLDOWN_RESET", function()
            self:ResetCooldown()
        end)
    end

    FoxChat:Debug("FirstCome 모듈 초기화 완료")
end

-- 선입 메시지 전송
function FirstCome:SendFirstComeMessage()
    -- 쿨다운 체크
    if self:IsOnCooldown() then
        FoxChat:Print("선입외치기는 쿨다운 중입니다. " .. math.floor(self:GetCooldownRemaining()) .. "초 후에 다시 시도해주세요.")
        return false
    end

    -- 메시지 확인
    local message = self:GetMessage()
    if not message or message == "" then
        FoxChat:Print("선입 메시지가 설정되지 않았습니다.")
        return false
    end

    -- 채널 결정
    local channel = self:GetChannel()
    if not channel then
        FoxChat:Print("파티나 공격대에 속해있지 않습니다.")
        return false
    end

    -- 메시지 길이 체크
    if FoxChat.Utils and FoxChat.Utils.UTF8 then
        message = FoxChat.Utils.UTF8:TrimByBytes(message, 255)
    elseif #message > 255 then
        message = string.sub(message, 1, 255)
    end

    -- 메시지 전송
    SendChatMessage(message, channel)

    -- 쿨다운 시작
    self:StartCooldown()

    FoxChat:Debug("선입 메시지 전송: " .. channel)
    return true
end

-- 채널 결정
function FirstCome:GetChannel()
    if IsInRaid() then
        -- 공격대 리더/승급자 확인
        if self:IsRaidLeaderOrAssistant() then
            return "RAID_WARNING"  -- 공격대 경보
        else
            return "RAID"  -- 일반 공격대 채팅
        end
    elseif IsInGroup() then
        return "PARTY"  -- 파티 채팅
    end

    return nil
end

-- 공격대 리더/승급자 확인
function FirstCome:IsRaidLeaderOrAssistant()
    -- UnitIsGroupLeader와 UnitIsGroupAssistant 사용
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    elseif UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
        return true
    end

    -- GetRaidRosterInfo 사용 (Classic 호환)
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if name == UnitName("player") then
            if rank >= 1 then  -- rank 2 = 리더, rank 1 = 승급자
                return true
            end
            break
        end
    end

    return false
end

-- 쿨다운 관련 함수
function FirstCome:StartCooldown()
    local cooldownTime = self:GetCooldownTime()
    firstComeLastClickTime = GetTime()

    -- 쿨다운 타이머 시작
    if firstComeCooldownTimer then
        firstComeCooldownTimer:Cancel()
    end

    firstComeCooldownTimer = C_Timer.NewTimer(cooldownTime, function()
        firstComeCooldownTimer = nil

        -- 쿨다운 종료 이벤트
        if FoxChat.Events then
            FoxChat.Events:Trigger("FOXCHAT_FIRSTCOME_COOLDOWN_END")
        end
    end)

    -- 쿨다운 시작 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_FIRSTCOME_COOLDOWN_START", firstComeLastClickTime, cooldownTime)
    end
end

function FirstCome:ResetCooldown()
    if firstComeCooldownTimer then
        firstComeCooldownTimer:Cancel()
        firstComeCooldownTimer = nil
    end
    firstComeLastClickTime = 0

    -- 쿨다운 리셋 이벤트
    if FoxChat.Events then
        FoxChat.Events:Trigger("FOXCHAT_FIRSTCOME_COOLDOWN_RESET")
    end
end

function FirstCome:IsOnCooldown()
    return firstComeCooldownTimer ~= nil
end

function FirstCome:GetCooldownRemaining()
    if not firstComeCooldownTimer or firstComeLastClickTime == 0 then
        return 0
    end

    local cooldownTime = self:GetCooldownTime()
    local elapsed = GetTime() - firstComeLastClickTime
    local remaining = cooldownTime - elapsed

    return remaining > 0 and remaining or 0
end

function FirstCome:GetLastClickTime()
    return firstComeLastClickTime
end

-- 설정 관련 함수
function FirstCome:IsEnabled()
    return FoxChatDB and FoxChatDB.firstComeEnabled
end

function FirstCome:Enable()
    if FoxChatDB then
        FoxChatDB.firstComeEnabled = true

        -- 버튼 업데이트
        if FoxChat.UI and FoxChat.UI.FirstComeButton then
            FoxChat.UI.FirstComeButton:UpdateState()
        end
    end
end

function FirstCome:Disable()
    if FoxChatDB then
        FoxChatDB.firstComeEnabled = false

        -- 버튼 숨기기
        if FoxChat.UI and FoxChat.UI.FirstComeButton then
            FoxChat.UI.FirstComeButton:Hide()
        end
    end
end

function FirstCome:GetMessage()
    if FoxChatDB then
        return FoxChatDB.firstComeMessage or ""
    end
    return ""
end

function FirstCome:SetMessage(message)
    if FoxChatDB then
        FoxChatDB.firstComeMessage = message or ""
    end
end

function FirstCome:GetCooldownTime()
    if FoxChatDB then
        return FoxChatDB.firstComeCooldown or 5
    end
    return 5
end

function FirstCome:SetCooldownTime(seconds)
    if FoxChatDB then
        FoxChatDB.firstComeCooldown = seconds or 5
    end
end

-- 파티/공격대 상태 확인
function FirstCome:IsInGroup()
    return IsInGroup() or IsInRaid()
end

function FirstCome:GetGroupType()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return nil
    end
end

-- 테스트 함수
function FirstCome:TestMessage()
    local message = self:GetMessage()
    if not message or message == "" then
        FoxChat:Print("테스트 실패: 선입 메시지가 설정되지 않았습니다.")
        return
    end

    local channel = self:GetChannel()
    if channel then
        FoxChat:Print("테스트: [" .. channel .. "] " .. message)
    else
        FoxChat:Print("테스트: " .. message)
    end

    -- 채널 정보 출력
    local groupType = self:GetGroupType()
    if groupType == "RAID" then
        local isLeaderOrAssistant = self:IsRaidLeaderOrAssistant()
        FoxChat:Print("공격대 " .. (isLeaderOrAssistant and "(권한 있음 - 경보 사용 가능)" or "(일반)"))
    elseif groupType == "PARTY" then
        FoxChat:Print("파티")
    else
        FoxChat:Print("그룹 없음")
    end
end