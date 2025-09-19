local addonName, addon = ...

-- 기본 영어 문자열
local L = {
    -- 메인 메시지
    ["ADDON_LOADED"] = "DruidManaBar loaded. Type /dmb or /druidmanabar to open settings.",
    ["SETTINGS_SAVED"] = "DruidManaBar: Settings saved",
    ["DEFAULTS_RESTORED"] = "DruidManaBar: Settings restored to defaults",
    
    -- 설정창
    ["CONFIG_TITLE"] = "DruidManaBar Settings",
    ["ENABLED"] = "Enable DruidManaBar",
    ["SHOW_HEALTH_BAR"] = "Show Health Bar",
    ["VISIBILITY_MODE"] = "Display Mode:",
    ["VISIBILITY_ALWAYS"] = "Always Show",
    ["VISIBILITY_FORMS"] = "Only in Forms",
    ["VISIBILITY_COMBAT"] = "Only in Combat",
    ["SHOW_IN_FORMS"] = "Show in Specific Forms:",
    ["BEAR_FORM"] = "Bear/Dire Bear",
    ["CAT_FORM"] = "Cat",
    ["AQUATIC_FORM"] = "Aquatic",
    ["TRAVEL_FORM"] = "Travel/Cheetah",
    ["MOONKIN_FORM"] = "Moonkin",
    ["HEALTH_DISPLAY_MODE"] = "Health Display:",
    ["MANA_DISPLAY_MODE"] = "Mana Display:",
    ["DISPLAY_NUMBER"] = "Numbers",
    ["DISPLAY_PERCENT"] = "Percentage",
    ["DISPLAY_BOTH"] = "Both",
    ["POSITION_LABEL"] = "Bar Position:",
    ["SIZE_LABEL"] = "Bar Size:",
    ["BAR_WIDTH"] = "Bar Width:",
    ["MANA_BAR_HEIGHT"] = "Mana Bar Height:",
    ["HEALTH_BAR_HEIGHT"] = "Health Bar Height:",
    ["FLASH_THRESHOLD"] = "Health Flash Threshold:",
    ["MANA_COSTS_LABEL"] = "Shapeshift Mana Costs:",
    ["MANA_COSTS_HELP"] = "Enter mana costs manually if auto-detection fails",
    ["BEAR_FORM_COST"] = "Bear/Dire Bear:",
    ["CAT_FORM_COST"] = "Cat Form:",
    ["TEST_BUTTON"] = "Test",
    ["SAVE_BUTTON"] = "Save",
    ["CLOSE_BUTTON"] = "Close",
    ["RESET_BUTTON"] = "Reset to Defaults",
    
    -- 테스트 모드
    ["TEST_MODE_START"] = "DruidManaBar: Test mode started. Shift+drag to move the bar. Test mode will end in 10 seconds.",
    ["TEST_MODE_END"] = "DruidManaBar: Test mode ended.",
    
    -- 명령어
    ["COMMANDS_HEADER"] = "DruidManaBar Commands:",
    ["COMMAND_CONFIG"] = "  /dmb - Open settings",
    ["COMMAND_TEST"] = "  /dmb test - Test mode (allows repositioning)",
    ["COMMAND_DEBUG"] = "  /dmb debug - Check shapeshift spell detection",
}

-- 한국어 번역
local locale = GetLocale()
if locale == "koKR" then
    L = {
        -- 메인 메시지
        ["ADDON_LOADED"] = "DruidManaBar 로드됨. /dmb 또는 /druidmanabar로 설정창을 열 수 있습니다.",
        ["SETTINGS_SAVED"] = "DruidManaBar: 설정이 저장되었습니다",
        ["DEFAULTS_RESTORED"] = "DruidManaBar: 기본값으로 복원되었습니다",
        
        -- 설정창
        ["CONFIG_TITLE"] = "DruidManaBar 설정",
        ["ENABLED"] = "DruidManaBar 활성화",
        ["SHOW_HEALTH_BAR"] = "체력 바 표시",
        ["VISIBILITY_MODE"] = "표시 모드:",
        ["VISIBILITY_ALWAYS"] = "항상 표시",
        ["VISIBILITY_FORMS"] = "변신 중에만",
        ["VISIBILITY_COMBAT"] = "전투 중에만",
        ["SHOW_IN_FORMS"] = "특정 변신에서 표시:",
        ["BEAR_FORM"] = "곰/광포한 곰",
        ["CAT_FORM"] = "표범",
        ["AQUATIC_FORM"] = "바다표범",
        ["TRAVEL_FORM"] = "여행/치타",
        ["MOONKIN_FORM"] = "달빛야수",
        ["HEALTH_DISPLAY_MODE"] = "체력 표시:",
        ["MANA_DISPLAY_MODE"] = "마나 표시:",
        ["DISPLAY_NUMBER"] = "숫자",
        ["DISPLAY_PERCENT"] = "퍼센트",
        ["DISPLAY_BOTH"] = "모두",
        ["POSITION_LABEL"] = "바 위치:",
        ["SIZE_LABEL"] = "바 크기:",
        ["BAR_WIDTH"] = "바 너비:",
        ["MANA_BAR_HEIGHT"] = "마나 바 높이:",
        ["HEALTH_BAR_HEIGHT"] = "체력 바 높이:",
        ["FLASH_THRESHOLD"] = "체력 깜빡임 임계값:",
        ["MANA_COSTS_LABEL"] = "변신 마나 비용:",
        ["MANA_COSTS_HELP"] = "자동 감지가 실패하면 수동으로 입력하세요",
        ["BEAR_FORM_COST"] = "곰/광포한 곰:",
        ["CAT_FORM_COST"] = "표범 변신:",
        ["TEST_BUTTON"] = "테스트",
        ["SAVE_BUTTON"] = "저장",
        ["CLOSE_BUTTON"] = "닫기",
        ["RESET_BUTTON"] = "기본값 복원",
        
        -- 테스트 모드
        ["TEST_MODE_START"] = "DruidManaBar: 테스트 모드 시작. Shift+드래그로 바를 이동할 수 있습니다. 10초 후 테스트 모드가 종료됩니다.",
        ["TEST_MODE_END"] = "DruidManaBar: 테스트 모드 종료.",
        
        -- 명령어
        ["COMMANDS_HEADER"] = "DruidManaBar 명령어:",
        ["COMMAND_CONFIG"] = "  /dmb - 설정창 열기",
        ["COMMAND_TEST"] = "  /dmb test - 테스트 모드 (위치 조정 가능)",
        ["COMMAND_DEBUG"] = "  /dmb debug - 변신 스펠 감지 확인",
    }
end

-- 전역 변수로 노출
addon.L = L
DruidManaBar = addon