local addonName, addon = ...

-- 전역 네임스페이스 초기화
FoxChat = FoxChat or {}
FoxChat.Core = FoxChat.Core or {}
FoxChat.Features = FoxChat.Features or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.Utils = FoxChat.Utils or {}
FoxChat.Config = FoxChat.Config or {}

-- 애드온 정보 저장
FoxChat.addonName = addonName
FoxChat.addon = addon

-- 버전 정보
FoxChat.version = GetAddOnMetadata(addonName, "Version") or "Unknown"

-- 디버그 모드
FoxChat.debugMode = false

-- 초기화 상태
FoxChat.initialized = false

-- 메인 프레임
local frame = CreateFrame("Frame", "FoxChatCoreFrame")
FoxChat.Core.frame = frame

-- 초기화 함수
function FoxChat.Core:Initialize()
    if FoxChat.initialized then
        return
    end

    -- 설정 로드
    if FoxChat.Config.Load then
        FoxChat.Config:Load()
    end

    -- 이벤트 시스템 초기화
    if FoxChat.Events and FoxChat.Events.Initialize then
        FoxChat.Events:Initialize()
    end

    -- 각 기능 모듈 초기화
    for moduleName, module in pairs(FoxChat.Features) do
        if module.Initialize then
            module:Initialize()
        end
    end

    -- UI 모듈 초기화
    for moduleName, module in pairs(FoxChat.UI) do
        if module.Initialize then
            module:Initialize()
        end
    end

    -- 초기화 완료 이벤트 발생
    if FoxChat.Events and FoxChat.Events.Trigger then
        FoxChat.Events:Trigger("FOXCHAT_INITIALIZED")
    end

    FoxChat.initialized = true

    -- 초기화 메시지
    if FoxChat.debugMode then
        print("|cffFFA500FoxChat|r v" .. FoxChat.version .. " 초기화 완료")
    end
end

-- 종료 함수
function FoxChat.Core:Shutdown()
    -- 각 모듈 종료
    for moduleName, module in pairs(FoxChat.Features) do
        if module.Shutdown then
            module:Shutdown()
        end
    end

    for moduleName, module in pairs(FoxChat.UI) do
        if module.Shutdown then
            module:Shutdown()
        end
    end

    -- 설정 저장
    if FoxChat.Config.Save then
        FoxChat.Config:Save()
    end
end

-- 이벤트 핸들러
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- 애드온 로드 시 초기화 준비
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- 플레이어 로그인 시 초기화
        FoxChat.Core:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        -- 플레이어 로그아웃 시 종료
        FoxChat.Core:Shutdown()
    end
end)

-- 슬래시 커맨드 등록
SLASH_FOXCHAT1 = "/foxchat"
SLASH_FOXCHAT2 = "/fc"

SlashCmdList["FOXCHAT"] = function(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "debug" then
        FoxChat.debugMode = not FoxChat.debugMode
        print("|cffFFA500FoxChat|r 디버그 모드:", FoxChat.debugMode and "활성화" or "비활성화")
    elseif command == "config" or command == "" then
        if FoxChat.UI.Config and FoxChat.UI.Config.Show then
            FoxChat.UI.Config:Show()
        else
            print("|cffFFA500FoxChat|r 설정창이 아직 로드되지 않았습니다.")
        end
    elseif command == "version" then
        print("|cffFFA500FoxChat|r 버전:", FoxChat.version)
    elseif command == "reload" then
        ReloadUI()
    elseif command == "help" then
        print("|cffFFA500FoxChat|r 명령어:")
        print("  /foxchat 또는 /fc - 설정창 열기")
        print("  /fc debug - 디버그 모드 토글")
        print("  /fc version - 버전 확인")
        print("  /fc reload - UI 재시작")
        print("  /fc help - 도움말")
    else
        -- 다른 모듈에서 추가 명령어 처리
        if FoxChat.Events and FoxChat.Events.Trigger then
            FoxChat.Events:Trigger("FOXCHAT_SLASH_COMMAND", command, rest)
        end
    end
end

-- 전역 함수 (다른 모듈에서 사용)
function FoxChat:Print(...)
    local prefix = "|cffFFA500FoxChat|r:"
    print(prefix, ...)
end

function FoxChat:Debug(...)
    if FoxChat.debugMode then
        local prefix = "|cffFFA500FoxChat Debug|r:"
        print(prefix, ...)
    end
end