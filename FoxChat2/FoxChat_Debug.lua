-- FoxChat 디버그 명령어
local addonName, addon = ...

-- 슬래시 명령어 등록
SLASH_FOXCHATDEBUG1 = "/fcdbg"
SLASH_FOXCHATDEBUG2 = "/foxchatdebug"

SlashCmdList["FOXCHATDEBUG"] = function(msg)
    local command = msg:lower()

    if command == "autoreply" or command == "ar" then
        -- 자동응답 디버그 모드 토글
        FoxChatDB = FoxChatDB or {}
        FoxChatDB.debugAutoReply = not FoxChatDB.debugAutoReply
        if FoxChatDB.debugAutoReply then
            print("|cFFFF7D0A[FoxChat Debug]|r 자동응답 디버그 모드가 |cFF00FF00활성화|r되었습니다.")
            print("  파티/공대원 체크 과정이 출력됩니다.")
        else
            print("|cFFFF7D0A[FoxChat Debug]|r 자동응답 디버그 모드가 |cFFFF0000비활성화|r되었습니다.")
        end

    elseif command == "settings" or command == "s" then
        -- 현재 자동 탭 설정 출력
        print("|cFFFF7D0A[FoxChat Debug]|r 자동 탭 설정:")
        print("  autoTrade: " .. tostring(FoxChatDB.autoTrade))
        print("  autoPartyGreetMyJoin: " .. tostring(FoxChatDB.autoPartyGreetMyJoin))
        print("  autoPartyGreetOthersJoin: " .. tostring(FoxChatDB.autoPartyGreetOthersJoin))
        print("  autoReplyAFK: " .. tostring(FoxChatDB.autoReplyAFK))
        print("  autoReplyCombat: " .. tostring(FoxChatDB.autoReplyCombat))
        print("  autoReplyInstance: " .. tostring(FoxChatDB.autoReplyInstance))
        print("  autoReplyCooldown: " .. tostring(FoxChatDB.autoReplyCooldown) .. "분")
        print("  rollTrackerEnabled: " .. tostring(FoxChatDB.rollTrackerEnabled))
        print("  rollSessionDuration: " .. tostring(FoxChatDB.rollSessionDuration) .. "초")
        print("  rollTopK: " .. tostring(FoxChatDB.rollTopK))

    elseif command == "messages" or command == "m" then
        -- 인사말 메시지 출력
        print("|cFFFF7D0A[FoxChat Debug]|r 파티 인사말:")
        print("내가 참가할 때:")
        if FoxChatDB.partyGreetMyJoinMessages then
            for i, msg in ipairs(FoxChatDB.partyGreetMyJoinMessages) do
                print("  " .. i .. ". " .. msg)
            end
        end
        print("다른 사람이 참가할 때:")
        if FoxChatDB.partyGreetOthersJoinMessages then
            for i, msg in ipairs(FoxChatDB.partyGreetOthersJoinMessages) do
                print("  " .. i .. ". " .. msg)
            end
        end

    elseif command == "reply" or command == "r" then
        -- 자동응답 메시지 출력
        print("|cFFFF7D0A[FoxChat Debug]|r 자동응답 메시지:")
        print("  전투 중: " .. (FoxChatDB.combatReplyMessage or "없음"))
        print("  인던 중: " .. (FoxChatDB.instanceReplyMessage or "없음"))

    elseif command == "validate" or command == "v" then
        -- 설정 검증
        if addon.ValidateSettings then
            addon:ValidateSettings()
            print("|cFFFF7D0A[FoxChat Debug]|r 설정 검증 완료")
        else
            print("|cFFFF7D0A[FoxChat Debug]|r 설정 검증 함수를 찾을 수 없습니다")
        end

    elseif command == "reset" then
        -- 자동 탭 설정 초기화
        if addon.ResetAutoTabSettings then
            addon:ResetAutoTabSettings()
            print("|cFFFF7D0A[FoxChat Debug]|r 자동 탭 설정이 초기화되었습니다")
            -- UI 업데이트
            if FoxChatConfigFrame and FoxChatConfigFrame.RefreshUI then
                FoxChatConfigFrame:RefreshUI()
            end
        else
            print("|cFFFF7D0A[FoxChat Debug]|r 초기화 함수를 찾을 수 없습니다")
        end

    elseif command == "export" or command == "e" then
        -- 설정 내보내기
        if addon.ExportSettings then
            local settings = addon:ExportSettings()
            print("|cFFFF7D0A[FoxChat Debug]|r 설정 내보내기:")
            for k, v in pairs(settings) do
                if type(v) == "table" then
                    print("  " .. k .. ": [table with " .. #v .. " items]")
                else
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        end

    elseif command == "test combat" then
        -- 전투 시뮬레이션
        print("|cFFFF7D0A[FoxChat Debug]|r 전투 시뮬레이션 시작")
        autoEventFrame:GetScript("OnEvent")(autoEventFrame, "PLAYER_REGEN_DISABLED")
        C_Timer.After(3, function()
            autoEventFrame:GetScript("OnEvent")(autoEventFrame, "PLAYER_REGEN_ENABLED")
            print("|cFFFF7D0A[FoxChat Debug]|r 전투 시뮬레이션 종료")
        end)

    elseif command == "test whisper" then
        -- 귓속말 시뮬레이션
        local testSender = "TestPlayer"
        print("|cFFFF7D0A[FoxChat Debug]|r " .. testSender .. "로부터 귓속말 시뮬레이션")
        autoEventFrame:GetScript("OnEvent")(autoEventFrame, "CHAT_MSG_WHISPER", "테스트 메시지", testSender)

    else
        -- 도움말
        print("|cFFFF7D0A[FoxChat Debug]|r 명령어:")
        print("  /fcdbg autoreply (ar) - 자동응답 디버그 모드 토글")
        print("  /fcdbg settings - 현재 설정 표시")
        print("  /fcdbg messages - 인사말 메시지 표시")
        print("  /fcdbg reply - 자동응답 메시지 표시")
        print("  /fcdbg validate - 설정 검증")
        print("  /fcdbg test combat - 전투 시뮬레이션 테스트")
        print("  /fcdbg reset - 자동 탭 설정 초기화")
        print("  /fcdbg export - 설정 내보내기")
        print("  /fcdbg test combat - 전투 시뮬레이션")
        print("  /fcdbg test whisper - 귓속말 시뮬레이션")
    end
end

-- 설정 변경 감지를 위한 후킹
local function HookSettingChanges()
    -- 설정이 변경될 때 로그 출력
    if addon.OnSettingChanged then
        local orig = addon.OnSettingChanged
        addon.OnSettingChanged = function(self, key, value)
            orig(self, key, value)
            if addon.DebugMode then
                print("|cFFFF7D0A[FoxChat]|r 설정 변경: " .. tostring(key) .. " = " .. tostring(value))
            end
        end
    end
end

-- 초기화 시 후킹
C_Timer.After(1, HookSettingChanges)