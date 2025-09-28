-- FoxChat 설정 관리 유틸리티
local addonName, addon = ...

-- 설정 검증 및 복구 함수
function addon:ValidateSettings()
    if not FoxChatDB then
        FoxChatDB = {}
    end

    local defaults = {
        -- 자동 탭 설정
        autoTrade = true,
        autoPartyGreetMyJoin = false,
        autoPartyGreetOthersJoin = false,
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
        autoReplyAFK = false,
        autoReplyCombat = false,
        autoReplyInstance = false,
        combatReplyMessage = "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!",
        instanceReplyMessage = "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!",
        autoReplyCooldown = 5,
        rollTrackerEnabled = false,
        rollSessionDuration = 20,
        rollTopK = 0,
    }

    -- 누락된 설정 복구
    for key, value in pairs(defaults) do
        if FoxChatDB[key] == nil then
            FoxChatDB[key] = value
        end
    end

    -- 배열 타입 검증
    if type(FoxChatDB.partyGreetMyJoinMessages) ~= "table" then
        FoxChatDB.partyGreetMyJoinMessages = defaults.partyGreetMyJoinMessages
    end
    if type(FoxChatDB.partyGreetOthersJoinMessages) ~= "table" then
        FoxChatDB.partyGreetOthersJoinMessages = defaults.partyGreetOthersJoinMessages
    end

    -- 빈 배열 처리
    if #FoxChatDB.partyGreetMyJoinMessages == 0 then
        FoxChatDB.partyGreetMyJoinMessages = defaults.partyGreetMyJoinMessages
    end
    if #FoxChatDB.partyGreetOthersJoinMessages == 0 then
        FoxChatDB.partyGreetOthersJoinMessages = defaults.partyGreetOthersJoinMessages
    end

    -- 숫자 값 검증
    if type(FoxChatDB.autoReplyCooldown) ~= "number" or FoxChatDB.autoReplyCooldown < 1 then
        FoxChatDB.autoReplyCooldown = defaults.autoReplyCooldown
    end
    if type(FoxChatDB.rollSessionDuration) ~= "number" or FoxChatDB.rollSessionDuration < 5 then
        FoxChatDB.rollSessionDuration = defaults.rollSessionDuration
    end
    if type(FoxChatDB.rollTopK) ~= "number" or FoxChatDB.rollTopK < 0 then
        FoxChatDB.rollTopK = defaults.rollTopK
    end

    -- 문자열 값 검증
    if type(FoxChatDB.combatReplyMessage) ~= "string" or FoxChatDB.combatReplyMessage == "" then
        FoxChatDB.combatReplyMessage = defaults.combatReplyMessage
    end
    if type(FoxChatDB.instanceReplyMessage) ~= "string" or FoxChatDB.instanceReplyMessage == "" then
        FoxChatDB.instanceReplyMessage = defaults.instanceReplyMessage
    end
end

-- 설정 내보내기 (디버그용)
function addon:ExportSettings()
    local settings = {}

    -- 자동 탭 설정만 내보내기
    local autoTabKeys = {
        "autoTrade",
        "autoPartyGreetMyJoin",
        "autoPartyGreetOthersJoin",
        "partyGreetMyJoinMessages",
        "partyGreetOthersJoinMessages",
        "autoReplyAFK",
        "autoReplyCombat",
        "autoReplyInstance",
        "combatReplyMessage",
        "instanceReplyMessage",
        "autoReplyCooldown",
        "rollTrackerEnabled",
        "rollSessionDuration",
        "rollTopK"
    }

    for _, key in ipairs(autoTabKeys) do
        settings[key] = FoxChatDB[key]
    end

    return settings
end

-- 설정 가져오기 (디버그용)
function addon:ImportSettings(settings)
    if not settings or type(settings) ~= "table" then
        return false
    end

    for key, value in pairs(settings) do
        FoxChatDB[key] = value
    end

    -- 설정 검증
    addon:ValidateSettings()

    return true
end

-- 설정 초기화 (특정 탭만)
function addon:ResetAutoTabSettings()
    FoxChatDB.autoTrade = true
    FoxChatDB.autoPartyGreetMyJoin = false
    FoxChatDB.autoPartyGreetOthersJoin = false
    FoxChatDB.partyGreetMyJoinMessages = {
        "안녕하세요! {me}입니다. 잘 부탁드려요!",
        "반갑습니다~ 함께 모험해요!",
        "파티 초대 감사합니다!"
    }
    FoxChatDB.partyGreetOthersJoinMessages = {
        "{target}님 환영합니다!",
        "{target}님 반갑습니다~",
        "어서오세요 {target}님!"
    }
    FoxChatDB.autoReplyAFK = false
    FoxChatDB.autoReplyCombat = false
    FoxChatDB.autoReplyInstance = false
    FoxChatDB.combatReplyMessage = "[자동응답] 전투 중입니다. 잠시 후 답변드리겠습니다!"
    FoxChatDB.instanceReplyMessage = "[자동응답] 인던 중입니다. 나중에 답변드리겠습니다!"
    FoxChatDB.autoReplyCooldown = 5
    FoxChatDB.rollTrackerEnabled = false
    FoxChatDB.rollSessionDuration = 20
    FoxChatDB.rollTopK = 0
end

-- 설정 변경 콜백 (UI 업데이트용)
local callbacks = {}

function addon:RegisterCallback(name, func)
    callbacks[name] = func
end

function addon:UnregisterCallback(name)
    callbacks[name] = nil
end

function addon:FireCallbacks()
    for name, func in pairs(callbacks) do
        pcall(func)
    end
end

-- 설정 변경 감지
function addon:OnSettingChanged(key, value)
    -- 설정이 변경되면 콜백 실행
    addon:FireCallbacks()

    -- 디버그 모드일 때 로그
    if addon.DebugMode then
        print("|cFFFF7D0A[FoxChat]|r 설정 변경: " .. tostring(key) .. " = " .. tostring(value))
    end
end