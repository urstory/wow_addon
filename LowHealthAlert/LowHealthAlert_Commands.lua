-- 슬래시 명령어를 별도 파일로 분리하여 등록 문제 해결
local addonName, addon = ...

-- 명령어 처리 함수
local function HandleSlashCommand(msg)
    local L = addon.L
    msg = msg:lower()
    
    if msg == "test" then
        if LowHealthAlert and LowHealthAlert.TestMode then
            LowHealthAlert.TestMode()
        else
            print(L["TEST_START_ERROR"])
        end
    elseif msg == "status" then
        print(L["STATUS_HEADER"])
        local enabled = LowHealthAlertDB and LowHealthAlertDB.enabled ~= false
        print(string.format(L["STATUS_ENABLED"], enabled and L["YES"] or L["NO"]))
        print(string.format(L["STATUS_THRESHOLD"], (LowHealthAlertDB and LowHealthAlertDB.threshold or 0.35) * 100))
        local flash = LowHealthAlertDB and LowHealthAlertDB.useFlash ~= false
        print(string.format(L["STATUS_FLASH"], flash and L["YES"] or L["NO"]))
        print(string.format(L["STATUS_MACRO"], LowHealthAlertDB and LowHealthAlertDB.macroText or L["NONE"]))
        print(string.format(L["STATUS_POSITION"], LowHealthAlertDB and LowHealthAlertDB.buttonX or 100, LowHealthAlertDB and LowHealthAlertDB.buttonY or 0))
    elseif msg == "macro" then
        -- 현재 매크로 확인
        if LowHealthAlertDB and LowHealthAlertDB.macroText then
            print(L["CURRENT_MACRO"])
            print(LowHealthAlertDB.macroText)
        else
            print(L["NO_MACRO"])
        end
    elseif msg == "config" or msg == "" then
        -- 간단한 독립 설정창 열기
        if LowHealthAlert and LowHealthAlert.ShowSimpleConfig then
            LowHealthAlert.ShowSimpleConfig()
        else
            print(L["CONFIG_ERROR"])
        end
    else
        print(L["COMMANDS_HEADER"])
        print(L["COMMAND_CONFIG"])
        print(L["COMMAND_TEST"])
        print(L["COMMAND_STATUS"])
    end
end

-- 슬래시 명령어 등록 (PLAYER_LOGIN 이벤트에서 실행)
local cmdFrame = CreateFrame("Frame")
cmdFrame:RegisterEvent("PLAYER_LOGIN")
cmdFrame:SetScript("OnEvent", function()
    SLASH_LOWHEALTHALERT1 = "/lha"
    SLASH_LOWHEALTHALERT2 = "/lowhealthalert"
    SlashCmdList["LOWHEALTHALERT"] = HandleSlashCommand
end)