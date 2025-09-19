local addonName, addon = ...

-- 기본 영어 문자열
local L = {
    -- 메인 메시지
    ["ADDON_LOADED"] = "FoxChat loaded. Type /fc or /foxchat to open settings.",
    ["SETTINGS_SAVED"] = "FoxChat: Settings saved",
    ["DEFAULTS_RESTORED"] = "FoxChat: Settings restored to defaults",
    
    -- 설정창
    ["CONFIG_TITLE"] = "FoxChat Settings",
    ["KEYWORDS_LABEL"] = "Filter Keywords:",
    ["KEYWORDS_HELP"] = "Enter words to highlight (comma separated)",
    ["IGNORE_KEYWORDS_LABEL"] = "Ignore Keywords:",
    ["IGNORE_KEYWORDS_HELP"] = "Messages with these words won't be filtered",
    ["ENABLED"] = "Enable FoxChat",
    ["PLAY_SOUND"] = "Play sound alert",
    ["CHANNELS_AND_COLORS"] = "Channel Monitoring & Colors:",
    ["CHANNEL_GROUP_GUILD"] = "Guild",
    ["CHANNEL_GROUP_PUBLIC"] = "Public",
    ["CHANNEL_GROUP_PARTY_RAID"] = "Party/Raid",
    ["CHANNEL_GROUP_LFG"] = "LFG",
    ["CHANNEL_SAY"] = "Say",
    ["CHANNEL_YELL"] = "Yell",
    ["CHANNEL_PARTY"] = "Party",
    ["CHANNEL_GUILD"] = "Guild",
    ["CHANNEL_RAID"] = "Raid",
    ["CHANNEL_INSTANCE"] = "Instance",
    ["CHANNEL_WHISPER"] = "Whisper",
    ["CHANNEL_GENERAL"] = "General",
    ["CHANNEL_TRADE"] = "Trade",
    ["CHANNEL_LFG"] = "LookingForGroup",
    ["TEST_BUTTON"] = "Test",
    ["SAVE_BUTTON"] = "Save",
    ["CLOSE_BUTTON"] = "Close",
    ["RESET_BUTTON"] = "Reset to Defaults",
    ["TEST_MESSAGE"] = "This is a test message with your keywords!",
    ["SOUND_VOLUME"] = "Sound Volume:",
    ["HIGHLIGHT_STYLE"] = "Highlight Style:",
    ["STYLE_BOLD"] = "Bold",
    ["STYLE_COLOR"] = "Color Only",
    ["STYLE_BOTH"] = "Bold + Color",
    
    -- 말머리/말꼬리
    ["PREFIX_LABEL"] = "Message Prefix:",
    ["SUFFIX_LABEL"] = "Message Suffix:",
    ["PREFIX_SUFFIX_HELP"] = "Automatically adds text before and after your messages",
    ["PREFIX_SUFFIX_CHANNELS"] = "Apply to Channels:",
    
    -- 섹션 헤더
    ["SECTION_CHAT_FILTER"] = "Chat Filtering Settings",
    ["SECTION_PREFIX_SUFFIX"] = "Prefix/Suffix Settings",
    
    -- 명령어
    ["COMMANDS_HEADER"] = "FoxChat Commands:",
    ["COMMAND_CONFIG"] = "  /fc - Open settings",
    ["COMMAND_TOGGLE"] = "  /fc toggle - Enable/disable addon",
    ["COMMAND_ADD"] = "  /fc add <keyword> - Add a keyword",
    ["COMMAND_REMOVE"] = "  /fc remove <keyword> - Remove a keyword",
    ["COMMAND_LIST"] = "  /fc list - Show current keywords",
    
    -- 상태
    ["STATUS_ENABLED"] = "FoxChat: Enabled",
    ["STATUS_DISABLED"] = "FoxChat: Disabled",
    ["KEYWORD_ADDED"] = "FoxChat: Added keyword '%s'",
    ["KEYWORD_REMOVED"] = "FoxChat: Removed keyword '%s'",
    ["KEYWORD_NOT_FOUND"] = "FoxChat: Keyword '%s' not found",
    ["CURRENT_KEYWORDS"] = "Current keywords: %s",
    ["NO_KEYWORDS"] = "No keywords configured",
    
    -- 미니맵 버튼
    ["LEFT_CLICK_TOGGLE"] = "Left Click: Toggle On/Off",
    ["LEFT_CLICK_TOGGLE_FILTER"] = "Left Click: Toggle Filter",
    ["RIGHT_CLICK_CONFIG"] = "Right Click: Open Settings",
    ["ENABLED"] = "Enabled",
    ["DISABLED"] = "Disabled",
    ["FILTER_ENABLED"] = "Chat filtering enabled",
    ["FILTER_DISABLED"] = "Chat filtering disabled",
    ["FILTER_STATUS_ENABLED"] = "Filter: ON",
    ["FILTER_STATUS_DISABLED"] = "Filter: OFF",
    ["FILTER_ENABLE"] = "Enable Chat Filtering",
    ["PREFIX_SUFFIX_ENABLE"] = "Enable Prefix/Suffix",
    ["RESET_KEYWORDS"] = "Reset Keywords",
    ["KEYWORDS_RESET"] = "Keywords have been reset",
    ["SHOW_MINIMAP_BUTTON"] = "Show Minimap Button",
    
    -- 기본값
    ["DEFAULT_KEYWORDS"] = "LFG,WTS,WTB",
}

-- 한국어 번역
local locale = GetLocale()
if locale == "koKR" then
    L = {
        -- 메인 메시지
        ["ADDON_LOADED"] = "FoxChat 로드됨. /fc 또는 /foxchat로 설정창을 열 수 있습니다.",
        ["SETTINGS_SAVED"] = "FoxChat: 설정이 저장되었습니다",
        ["DEFAULTS_RESTORED"] = "FoxChat: 기본값으로 복원되었습니다",
        
        -- 설정창
        ["CONFIG_TITLE"] = "FoxChat 설정",
        ["KEYWORDS_LABEL"] = "필터링 문구:",
        ["KEYWORDS_HELP"] = "강조할 단어를 입력 (쉼표로 구분)",
        ["IGNORE_KEYWORDS_LABEL"] = "무시할 문구:",
        ["IGNORE_KEYWORDS_HELP"] = "이 단어가 포함된 메시지는 필터링 안함",
        ["ENABLED"] = "FoxChat 활성화",
        ["PLAY_SOUND"] = "소리 알림 재생",
        ["CHANNELS_AND_COLORS"] = "채널 모니터링 및 색상:",
        ["CHANNEL_GROUP_GUILD"] = "길드",
        ["CHANNEL_GROUP_PUBLIC"] = "공개",
        ["CHANNEL_GROUP_PARTY_RAID"] = "파티/공격대",
        ["CHANNEL_GROUP_LFG"] = "파티찾기",
        ["CHANNEL_SAY"] = "일반 대화",
        ["CHANNEL_YELL"] = "외치기",
        ["CHANNEL_PARTY"] = "파티",
        ["CHANNEL_GUILD"] = "길드",
        ["CHANNEL_RAID"] = "공격대",
        ["CHANNEL_INSTANCE"] = "인스턴스",
        ["CHANNEL_WHISPER"] = "귓속말",
        ["CHANNEL_GENERAL"] = "공개",
        ["CHANNEL_TRADE"] = "거래",
        ["CHANNEL_LFG"] = "파티찾기",
        ["TEST_BUTTON"] = "테스트",
        ["SAVE_BUTTON"] = "저장",
        ["CLOSE_BUTTON"] = "닫기",
        ["RESET_BUTTON"] = "기본값 복원",
        ["TEST_MESSAGE"] = "키워드가 포함된 테스트 메시지입니다!",
        ["SOUND_VOLUME"] = "소리 크기:",
        ["HIGHLIGHT_STYLE"] = "강조 스타일:",
        ["STYLE_BOLD"] = "굵게",
        ["STYLE_COLOR"] = "색상만",
        ["STYLE_BOTH"] = "굵게 + 색상",
        
        -- 말머리/말꼬리
        ["PREFIX_LABEL"] = "말머리:",
        ["SUFFIX_LABEL"] = "말꼬리:",
        ["PREFIX_SUFFIX_HELP"] = "내 메시지 앞뒤에 자동으로 텍스트를 추가합니다",
        ["PREFIX_SUFFIX_CHANNELS"] = "적용할 채널:",
        
        -- 섹션 헤더
        ["SECTION_CHAT_FILTER"] = "채팅 필터링 설정",
        ["SECTION_PREFIX_SUFFIX"] = "말머리/말꼬리 설정",
        
        -- 명령어
        ["COMMANDS_HEADER"] = "FoxChat 명령어:",
        ["COMMAND_CONFIG"] = "  /fc - 설정창 열기",
        ["COMMAND_TOGGLE"] = "  /fc toggle - 애드온 켜기/끄기",
        ["COMMAND_ADD"] = "  /fc add <키워드> - 키워드 추가",
        ["COMMAND_REMOVE"] = "  /fc remove <키워드> - 키워드 제거",
        ["COMMAND_LIST"] = "  /fc list - 현재 키워드 목록",
        
        -- 상태
        ["STATUS_ENABLED"] = "FoxChat: 활성화됨",
        ["STATUS_DISABLED"] = "FoxChat: 비활성화됨",
        ["KEYWORD_ADDED"] = "FoxChat: '%s' 키워드가 추가되었습니다",
        ["KEYWORD_REMOVED"] = "FoxChat: '%s' 키워드가 제거되었습니다",
        ["KEYWORD_NOT_FOUND"] = "FoxChat: '%s' 키워드를 찾을 수 없습니다",
        ["CURRENT_KEYWORDS"] = "현재 키워드: %s",
        ["NO_KEYWORDS"] = "설정된 키워드가 없습니다",
        
        -- 미니맵 버튼
        ["LEFT_CLICK_TOGGLE"] = "왼쪽 클릭: 켜기/끄기",
        ["LEFT_CLICK_TOGGLE_FILTER"] = "왼쪽 클릭: 필터 켜기/끄기",
        ["RIGHT_CLICK_CONFIG"] = "오른쪽 클릭: 설정창 열기",
        ["ENABLED"] = "활성화",
        ["DISABLED"] = "비활성화",
        ["FILTER_ENABLED"] = "채팅 필터링 활성화됨",
        ["FILTER_DISABLED"] = "채팅 필터링 비활성화됨",
        ["FILTER_STATUS_ENABLED"] = "필터: 켜짐",
        ["FILTER_STATUS_DISABLED"] = "필터: 꺼짐",
        ["FILTER_ENABLE"] = "채팅 필터링 사용",
        ["PREFIX_SUFFIX_ENABLE"] = "말머리/말꼬리 사용",
        ["RESET_KEYWORDS"] = "키워드 초기화",
        ["KEYWORDS_RESET"] = "키워드가 초기화되었습니다",
        ["SHOW_MINIMAP_BUTTON"] = "미니맵 버튼 표시",
        
        -- 기본값
        ["DEFAULT_KEYWORDS"] = "줄파락,구해요,팝니다",
    }
end

-- 전역 변수로 노출
addon.L = L
FoxChat = addon