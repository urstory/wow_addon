local addonName, addon = ...

-- 기본 영어 문자열
local L = {
    -- 메인 메시지
    ["ADDON_LOADED"] = "Low Health Alert loaded. Type /lha to open settings.",
    ["TEST_MODE_ACTIVE"] = "Low Health Alert: Test mode already running",
    ["TEST_MODE_START"] = "Low Health Alert: 10 second test mode - Shift+drag to move button",
    ["TEST_MODE_END"] = "Low Health Alert: Test mode ended",
    ["MACRO_UPDATED"] = "Low Health Alert: Macro has been updated",
    ["COMBAT_MACRO_ERROR"] = "Low Health Alert: Cannot change macro during combat. Try again after combat.",
    ["CONFIG_ERROR"] = "Low Health Alert: Cannot open settings. Try reloading (/reload)",
    ["TEST_START_ERROR"] = "Low Health Alert: Cannot start test mode. Try reloading (/reload)",
    
    -- 설정창
    ["CONFIG_TITLE"] = "Low Health Alert Settings",
    ["HEALTH_THRESHOLD"] = "Health Threshold:",
    ["CURRENT_VALUE"] = "Current: %d%%",
    ["MACRO_LABEL"] = "Macro Command (multiple lines supported):",
    ["ENABLE_ADDON"] = "Enable Addon",
    ["USE_FLASH"] = "Use Screen Flash Warning",
    ["FLASH_INTENSITY"] = "Flash Intensity:",
    ["BUTTON_POSITION"] = "Button Position",
    ["X_COORD"] = "X:",
    ["Y_COORD"] = "Y:",
    ["CENTER"] = "Center",
    ["BUTTON_ICON"] = "Button Icon",
    ["ICON_PATH"] = "Icon Path:",
    ["TEST_BUTTON"] = "Test",
    ["RESET_BUTTON"] = "Reset to Defaults",
    ["CLOSE_BUTTON"] = "Close",
    ["SAVE_BUTTON"] = "Save",
    ["RESET_POSITION"] = "Reset Position",
    ["POSITION_RESET_MSG"] = "Low Health Alert: Button position reset (X=100, Y=0)",
    ["QUICK_SELECT"] = "Quick Select:",
    ["DEFAULTS_RESTORED"] = "Low Health Alert: Settings restored to defaults",
    ["SETTINGS_SAVED"] = "Low Health Alert: Settings saved",
    ["SAVED_MACRO"] = "Saved macro",
    
    -- 상태 메시지
    ["STATUS_HEADER"] = "Low Health Alert Status:",
    ["STATUS_ENABLED"] = "  Enabled: %s",
    ["STATUS_THRESHOLD"] = "  Health Threshold: %d%%",
    ["STATUS_FLASH"] = "  Flash: %s",
    ["STATUS_MACRO"] = "  Macro: %s",
    ["STATUS_POSITION"] = "  Button Position: X=%d, Y=%d",
    ["CURRENT_MACRO"] = "Low Health Alert Current Macro:",
    ["NO_MACRO"] = "No macro configured",
    
    -- 명령어 도움말
    ["COMMANDS_HEADER"] = "Low Health Alert Commands:",
    ["COMMAND_CONFIG"] = "  /lha - Open settings",
    ["COMMAND_TEST"] = "  /lha test - 10 second test",
    ["COMMAND_STATUS"] = "  /lha status - Check current status",
    
    -- 기타
    ["YES"] = "Yes",
    ["NO"] = "No",
    ["NONE"] = "None",

    -- 미니맵 버튼
    ["SHOW_MINIMAP_BUTTON"] = "Show Minimap Button",
    ["STATUS_ENABLED"] = "Status: |cff00ff00Enabled|r",
    ["STATUS_DISABLED"] = "Status: |cffff0000Disabled|r",
    ["ADDON_ENABLED"] = "|cff00ff00Low Health Alert: Enabled|r",
    ["ADDON_DISABLED"] = "|cffff0000Low Health Alert: Disabled|r",
    ["LEFT_CLICK_CONFIG"] = "Left Click: Open Config",
    ["RIGHT_CLICK_TOGGLE"] = "Right Click: Toggle On/Off",
    ["DRAG_TO_MOVE"] = "Drag: Move Button",
}

-- 한국어 클라이언트 감지 및 번역 적용
local locale = GetLocale()
if locale == "koKR" then
    L = {
        -- 메인 메시지
        ["ADDON_LOADED"] = "Low Health Alert 로드됨. /lha 명령어로 설정창을 열 수 있습니다.",
        ["TEST_MODE_ACTIVE"] = "Low Health Alert: 이미 테스트 모드 실행 중입니다",
        ["TEST_MODE_START"] = "Low Health Alert: 10초간 테스트 모드 - Shift+드래그로 버튼 이동 가능",
        ["TEST_MODE_END"] = "Low Health Alert: 테스트 모드 종료",
        ["MACRO_UPDATED"] = "Low Health Alert: 매크로가 업데이트되었습니다",
        ["COMBAT_MACRO_ERROR"] = "Low Health Alert: 전투 중에는 매크로를 변경할 수 없습니다. 전투 후 다시 시도하세요.",
        ["CONFIG_ERROR"] = "Low Health Alert: 설정창을 열 수 없습니다. 애드온을 다시 로드해 보세요 (/reload)",
        ["TEST_START_ERROR"] = "Low Health Alert: 테스트 모드를 시작할 수 없습니다. 애드온을 다시 로드해 보세요 (/reload)",
        
        -- 설정창
        ["CONFIG_TITLE"] = "Low Health Alert 설정",
        ["HEALTH_THRESHOLD"] = "체력 임계값:",
        ["CURRENT_VALUE"] = "현재: %d%%",
        ["MACRO_LABEL"] = "매크로 명령어 (여러 줄 입력 가능):",
        ["ENABLE_ADDON"] = "애드온 활성화",
        ["USE_FLASH"] = "화면 깜빡임 경고 사용",
        ["FLASH_INTENSITY"] = "깜빡임 강도:",
        ["BUTTON_POSITION"] = "버튼 위치",
        ["X_COORD"] = "X:",
        ["Y_COORD"] = "Y:",
        ["CENTER"] = "중앙",
        ["BUTTON_ICON"] = "버튼 아이콘",
        ["ICON_PATH"] = "아이콘 경로:",
        ["TEST_BUTTON"] = "테스트",
        ["RESET_BUTTON"] = "기본값 복원",
        ["CLOSE_BUTTON"] = "닫기",
        ["SAVE_BUTTON"] = "저장",
        ["RESET_POSITION"] = "위치 초기화",
        ["POSITION_RESET_MSG"] = "Low Health Alert: 버튼 위치가 초기화되었습니다 (X=100, Y=0)",
        ["QUICK_SELECT"] = "빠른 선택:",
        ["DEFAULTS_RESTORED"] = "Low Health Alert: 기본값으로 복원되었습니다",
        ["SETTINGS_SAVED"] = "Low Health Alert: 설정이 저장되었습니다",
        ["SAVED_MACRO"] = "저장된 매크로",
        
        -- 상태 메시지
        ["STATUS_HEADER"] = "Low Health Alert 상태:",
        ["STATUS_ENABLED"] = "  활성화: %s",
        ["STATUS_THRESHOLD"] = "  체력 임계값: %d%%",
        ["STATUS_FLASH"] = "  깜빡임: %s",
        ["STATUS_MACRO"] = "  매크로: %s",
        ["STATUS_POSITION"] = "  버튼 위치: X=%d, Y=%d",
        ["CURRENT_MACRO"] = "Low Health Alert 현재 매크로:",
        ["NO_MACRO"] = "설정된 매크로가 없습니다",
        
        -- 명령어 도움말
        ["COMMANDS_HEADER"] = "Low Health Alert 명령어:",
        ["COMMAND_CONFIG"] = "  /lha - 설정창 열기",
        ["COMMAND_TEST"] = "  /lha test - 10초간 테스트",
        ["COMMAND_STATUS"] = "  /lha status - 현재 상태 확인",
        
        -- 기타
        ["YES"] = "예",
        ["NO"] = "아니오",
        ["NONE"] = "없음",

        -- 미니맵 버튼
        ["SHOW_MINIMAP_BUTTON"] = "미니맵 버튼 표시",
        ["STATUS_ENABLED"] = "상태: |cff00ff00활성화|r",
        ["STATUS_DISABLED"] = "상태: |cffff0000비활성화|r",
        ["ADDON_ENABLED"] = "|cff00ff00Low Health Alert: 활성화됨|r",
        ["ADDON_DISABLED"] = "|cffff0000Low Health Alert: 비활성화됨|r",
        ["LEFT_CLICK_CONFIG"] = "왼쪽 클릭: 설정창 열기",
        ["RIGHT_CLICK_TOGGLE"] = "오른쪽 클릭: 켜기/끄기 전환",
        ["DRAG_TO_MOVE"] = "드래그: 버튼 이동",
    }
end

-- 전역 변수로 노출 (addon 네임스페이스 사용)
addon.L = L
LowHealthAlert = addon