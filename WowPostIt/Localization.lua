local addonName, addon = ...

-- 기본 영어 문자열
local L = {
    -- 메인 메시지
    ["ADDON_LOADED"] = "loaded. Type /postit to open notes.",
    ["NOTES"] = "Notes",
    ["NEW_NOTE"] = "New note...",
    ["SAMPLE_NOTE"] = "Welcome to WowPostIt!\n\nClick 'New' to create a new note.\nYour notes are automatically saved as you type.",
    
    -- 버튼
    ["NEW"] = "New",
    ["DELETE"] = "Delete",
    ["DELETE_ALL"] = "Delete All",
    ["SEND_CHAT"] = "Send",
    ["YES"] = "Yes",
    ["NO"] = "No",
    
    -- 메뉴
    ["HIDE_MINIMAP_BUTTON"] = "Hide Minimap Button",
    ["LEFT_CLICK_OPEN"] = "Left Click: Open Notes",
    ["RIGHT_CLICK_NEW"] = "Right Click: Create New Note",
    ["NEW_NOTE_CREATED"] = "New note created!",
    ["TOTAL_NOTES"] = "Total Notes: %d",
    ["SEND_TO_CHAT"] = "Send to Chat",
    ["SEND_SAY"] = "Say",
    ["SEND_GUILD"] = "Guild",
    ["SEND_PARTY"] = "Party",
    ["SEND_RAID"] = "Raid",
    
    -- 확인
    ["CONFIRM_DELETE"] = "Are you sure you want to delete this note?",
    ["CONFIRM_DELETE_ALL"] = "Are you sure you want to delete ALL notes? This cannot be undone!",
    
    -- 메시지
    ["NO_NOTE_SELECTED"] = "No note selected",
    ["NOTE_NOT_FOUND"] = "Note not found",
    ["NOT_IN_GUILD"] = "You are not in a guild",
    ["NOT_IN_PARTY"] = "You are not in a party",
    ["NOT_IN_RAID"] = "You are not in a raid",
    ["EMPTY_NOTE"] = "Note is empty",
    ["NOTE_SENT_TO"] = "Note sent to %s",
    ["CHANNEL_SAY"] = "Say",
    ["CHANNEL_GUILD"] = "Guild",
    ["CHANNEL_PARTY"] = "Party",
    ["CHANNEL_RAID"] = "Raid",
    
    -- 정보
    ["CREATED"] = "Created",
    ["MODIFIED"] = "Modified",

    -- 편집 잠금
    ["LOCK_EDIT"] = "Lock Edit",
    ["UNLOCK_EDIT"] = "Unlock Edit",
    ["LOCK_EDIT_DESC"] = "Click to disable editing",
    ["UNLOCK_EDIT_DESC"] = "Click to enable editing",
    ["EDIT_LOCKED"] = "Editing locked",
    ["EDIT_UNLOCKED"] = "Editing unlocked",
}

-- 한국어 번역
local locale = GetLocale()
if locale == "koKR" then
    L = {
        -- 메인 메시지
        ["ADDON_LOADED"] = "로드됨. /postit 명령어로 메모를 열 수 있습니다.",
        ["NOTES"] = "메모",
        ["NEW_NOTE"] = "새 메모...",
        ["SAMPLE_NOTE"] = "WowPostIt에 오신 것을 환영합니다!\n\n'새로 만들기'를 클릭하여 새 메모를 작성하세요.\n메모는 입력하는 즉시 자동 저장됩니다.",
        
        -- 버튼
        ["NEW"] = "새로 만들기",
        ["DELETE"] = "삭제",
        ["DELETE_ALL"] = "모두 삭제",
        ["SEND_CHAT"] = "전송",
        ["YES"] = "예",
        ["NO"] = "아니오",
        
        -- 메뉴
        ["HIDE_MINIMAP_BUTTON"] = "미니맵 버튼 숨기기",
        ["LEFT_CLICK_OPEN"] = "왼쪽 클릭: 메모 열기",
        ["RIGHT_CLICK_NEW"] = "오른쪽 클릭: 새 메모 생성",
        ["NEW_NOTE_CREATED"] = "새 메모가 생성되었습니다!",
        ["TOTAL_NOTES"] = "전체 메모: %d개",
        ["SEND_TO_CHAT"] = "채팅으로 전송",
        ["SEND_SAY"] = "일반 대화",
        ["SEND_GUILD"] = "길드",
        ["SEND_PARTY"] = "파티",
        ["SEND_RAID"] = "공격대",
        
        -- 확인
        ["CONFIRM_DELETE"] = "이 메모를 삭제하시겠습니까?",
        ["CONFIRM_DELETE_ALL"] = "모든 메모를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다!",
        
        -- 메시지
        ["NO_NOTE_SELECTED"] = "선택된 메모가 없습니다",
        ["NOTE_NOT_FOUND"] = "메모를 찾을 수 없습니다",
        ["NOT_IN_GUILD"] = "길드에 가입되어 있지 않습니다",
        ["NOT_IN_PARTY"] = "파티에 참가하고 있지 않습니다",
        ["NOT_IN_RAID"] = "공격대에 참가하고 있지 않습니다",
        ["EMPTY_NOTE"] = "메모가 비어 있습니다",
        ["NOTE_SENT_TO"] = "%s(으)로 메모를 전송했습니다",
        ["CHANNEL_SAY"] = "일반 대화",
        ["CHANNEL_GUILD"] = "길드",
        ["CHANNEL_PARTY"] = "파티",
        ["CHANNEL_RAID"] = "공격대",
        
        -- 정보
        ["CREATED"] = "생성일",
        ["MODIFIED"] = "수정일",

        -- 편집 잠금
        ["LOCK_EDIT"] = "편집 잠금",
        ["UNLOCK_EDIT"] = "편집 잠금 해제",
        ["LOCK_EDIT_DESC"] = "클릭하여 편집을 비활성화합니다",
        ["UNLOCK_EDIT_DESC"] = "클릭하여 편집을 활성화합니다",
        ["EDIT_LOCKED"] = "편집이 잠겼습니다",
        ["EDIT_UNLOCKED"] = "편집이 해제되었습니다",
    }
end

-- 전역 변수로 노출
addon.L = L
WowPostIt = addon