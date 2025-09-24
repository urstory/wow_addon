local addonName, addon = ...
local L = addon.L or {}

-- 메모 창
local noteWindow = nil
local noteList = nil
local noteEditBox = nil
local currentNoteId = nil
local listButtons = {}

-- 메모 창 생성
function addon:ShowNoteWindow()
    if noteWindow and noteWindow:IsShown() then
        noteWindow:Hide()
        return
    end
    
    if not noteWindow then
        -- 메인 프레임 생성
        noteWindow = CreateFrame("Frame", "WowPostItWindow", UIParent, "BasicFrameTemplateWithInset")
        noteWindow:SetSize(WowPostItDB.windowSize and WowPostItDB.windowSize.width or 600,
                          WowPostItDB.windowSize and WowPostItDB.windowSize.height or 400)
        noteWindow:SetPoint(WowPostItDB.windowPosition.point or "CENTER", WowPostItDB.windowPosition.x or 0, WowPostItDB.windowPosition.y or 0)
        noteWindow:SetMovable(true)
        noteWindow:SetResizable(true)
        noteWindow:SetClampedToScreen(true)
        noteWindow:EnableMouse(true)
        -- SetMinResize/SetMaxResize는 Classic에서 지원하지 않으므로 직접 제한 구현
        noteWindow.minWidth = 400
        noteWindow.minHeight = 300
        noteWindow.maxWidth = 1200
        noteWindow.maxHeight = 800
        noteWindow:RegisterForDrag("LeftButton")
        noteWindow:SetScript("OnDragStart", noteWindow.StartMoving)
        noteWindow:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint()
            WowPostItDB.windowPosition = {point = point, x = x, y = y}
        end)
        noteWindow:SetScript("OnSizeChanged", function(self, width, height)
            -- 크기 제한 적용
            local newWidth = math.max(self.minWidth or 400, math.min(self.maxWidth or 1200, width))
            local newHeight = math.max(self.minHeight or 300, math.min(self.maxHeight or 800, height))

            -- 제한된 크기로 다시 설정 (필요한 경우)
            if newWidth ~= width or newHeight ~= height then
                self:SetSize(newWidth, newHeight)
                return
            end

            WowPostItDB.windowSize = {width = newWidth, height = newHeight}
            -- 내부 요소들 크기 조정
            addon:UpdateWindowLayout()
        end)
        
        -- 타이틀
        noteWindow.title = noteWindow:CreateFontString(nil, "OVERLAY")
        noteWindow.title:SetFontObject("GameFontHighlight")
        noteWindow.title:SetPoint("CENTER", noteWindow.TitleBg, "CENTER", 0, 0)
        noteWindow.title:SetText("WowPostIt - " .. L["NOTES"])
        
        -- 좌측 노트 목록 프레임
        local listFrame = CreateFrame("Frame", nil, noteWindow, "InsetFrameTemplate")
        listFrame:SetPoint("TOPLEFT", noteWindow, "TOPLEFT", 10, -30)
        listFrame:SetSize(180, 340)
        
        -- 스크롤 프레임
        local scrollFrame = CreateFrame("ScrollFrame", "WowPostItListScroll", listFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -5)
        scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 5)
        
        -- 목록 컨테이너
        noteList = CreateFrame("Frame", nil, scrollFrame)
        noteList:SetSize(150, 1)
        scrollFrame:SetScrollChild(noteList)
        
        -- New 버튼
        local newButton = CreateFrame("Button", nil, noteWindow, "GameMenuButtonTemplate")
        newButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 15, 10)
        newButton:SetSize(80, 25)
        newButton:SetText(L["NEW"])
        newButton:SetScript("OnClick", function()
            local newNote = addon.CreateNote(L["NEW_NOTE"])
            currentNoteId = newNote.id
            noteEditBox:SetText(newNote.content)
            noteEditBox:SetFocus()
            self:UpdateNoteList()
        end)
        
        -- Delete 버튼
        local deleteButton = CreateFrame("Button", nil, noteWindow, "GameMenuButtonTemplate")
        deleteButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 100, 10)
        deleteButton:SetSize(80, 25)
        deleteButton:SetText(L["DELETE"])
        deleteButton:SetScript("OnClick", function()
            if currentNoteId then
                StaticPopupDialogs["WOWPOSTIT_DELETE_CONFIRM"] = {
                    text = L["CONFIRM_DELETE"],
                    button1 = L["YES"],
                    button2 = L["NO"],
                    OnAccept = function()
                        addon.DeleteNote(currentNoteId)
                        currentNoteId = nil
                        noteEditBox:SetText("")
                        self:UpdateNoteList()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("WOWPOSTIT_DELETE_CONFIRM")
            end
        end)
        
        -- Delete All 버튼
        local deleteAllButton = CreateFrame("Button", nil, noteWindow, "GameMenuButtonTemplate")
        deleteAllButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 185, 10)
        deleteAllButton:SetSize(80, 25)
        deleteAllButton:SetText(L["DELETE_ALL"])
        deleteAllButton:SetScript("OnClick", function()
            StaticPopupDialogs["WOWPOSTIT_DELETE_ALL_CONFIRM"] = {
                text = L["CONFIRM_DELETE_ALL"],
                button1 = L["YES"],
                button2 = L["NO"],
                OnAccept = function()
                    WowPostItDB.notes = {}
                    currentNoteId = nil
                    noteEditBox:SetText("")
                    if noteEditBox.bg then
                        noteEditBox.bg:SetVertexColor(0.9, 0.9, 0.5, 0.5)
                    end
                    self:UpdateNoteList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("WOWPOSTIT_DELETE_ALL_CONFIRM")
        end)
        
        -- 채팅 채널 드롭다운
        local chatDropdown = CreateFrame("Frame", "WowPostItChatDropdown", noteWindow, "UIDropDownMenuTemplate")
        chatDropdown:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -185, 7)
        UIDropDownMenu_SetWidth(chatDropdown, 100)
        UIDropDownMenu_SetText(chatDropdown, L["SEND_SAY"])
        
        -- 선택된 채팅 채널 저장
        noteWindow.selectedChatType = "SAY"
        
        -- 드롭다운 초기화 함수
        local function ChatDropdown_Initialize(self, level)
            local info = UIDropDownMenu_CreateInfo()
            
            -- Say
            info.text = L["SEND_SAY"]
            info.value = "SAY"
            info.func = function()
                noteWindow.selectedChatType = "SAY"
                UIDropDownMenu_SetText(chatDropdown, L["SEND_SAY"])
            end
            UIDropDownMenu_AddButton(info)
            
            -- Guild
            info.text = L["SEND_GUILD"]
            info.value = "GUILD"
            info.func = function()
                noteWindow.selectedChatType = "GUILD"
                UIDropDownMenu_SetText(chatDropdown, L["SEND_GUILD"])
            end
            UIDropDownMenu_AddButton(info)
            
            -- Party
            info.text = L["SEND_PARTY"]
            info.value = "PARTY"
            info.func = function()
                noteWindow.selectedChatType = "PARTY"
                UIDropDownMenu_SetText(chatDropdown, L["SEND_PARTY"])
            end
            UIDropDownMenu_AddButton(info)
            
            -- Raid
            info.text = L["SEND_RAID"]
            info.value = "RAID"
            info.func = function()
                noteWindow.selectedChatType = "RAID"
                UIDropDownMenu_SetText(chatDropdown, L["SEND_RAID"])
            end
            UIDropDownMenu_AddButton(info)
        end
        
        UIDropDownMenu_Initialize(chatDropdown, ChatDropdown_Initialize)
        
        -- 채팅 보내기 버튼
        local sendButton = CreateFrame("Button", nil, noteWindow, "GameMenuButtonTemplate")
        sendButton:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -100, 10)
        sendButton:SetSize(80, 25)
        sendButton:SetText(L["SEND_CHAT"])
        sendButton:SetScript("OnClick", function(self)
            if not currentNoteId then 
                print("|cFFFFFF00WowPostIt:|r " .. L["NO_NOTE_SELECTED"])
                return 
            end
            
            -- 선택된 채널로 전송
            local chatType = noteWindow.selectedChatType or "SAY"
            addon:SendNoteToChat(chatType)
        end)
        
        -- 우측 편집 영역
        local editFrame = CreateFrame("Frame", nil, noteWindow, "InsetFrameTemplate")
        editFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 5, 0)
        editFrame:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -10, 40)

        -- 잠금/해제 버튼 (우측 상단 - 스크롤바 왼쪽)
        local lockButton = CreateFrame("CheckButton", nil, editFrame)  -- CheckButton으로 변경
        lockButton:SetSize(16, 16)  -- 체크박스 크기와 동일하게
        lockButton:SetPoint("TOPRIGHT", editFrame, "TOPRIGHT", -30, -8)  -- 스크롤바를 피해 왼쪽으로 이동
        lockButton:SetFrameLevel(editFrame:GetFrameLevel() + 5)  -- 더 높은 레벨로 설정

        -- 잠금 상태 변수
        noteWindow.isLocked = false

        -- 커스텀 열쇠 아이콘
        local lockIcon = lockButton:CreateTexture(nil, "ARTWORK")
        lockIcon:SetAllPoints()
        -- 초기 상태: 열린 자물쇠 (편집 가능)
        lockIcon:SetTexture("Interface\\AddOns\\WowPostIt\\k1.png")
        lockButton.icon = lockIcon

        -- 하이라이트 효과
        lockButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        -- 버튼 툴팁
        lockButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if noteWindow.isLocked then
                GameTooltip:SetText(L["UNLOCK_EDIT"] or "편집 잠금 해제", 1, 1, 1)
                GameTooltip:AddLine(L["UNLOCK_EDIT_DESC"] or "클릭하여 편집을 활성화합니다", 0.8, 0.8, 0.8)
            else
                GameTooltip:SetText(L["LOCK_EDIT"] or "편집 잠금", 1, 1, 1)
                GameTooltip:AddLine(L["LOCK_EDIT_DESC"] or "클릭하여 편집을 비활성화합니다", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)

        lockButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        -- 버튼 클릭 이벤트
        lockButton:SetScript("OnClick", function(self)
            noteWindow.isLocked = not noteWindow.isLocked

            if noteWindow.isLocked then
                -- 잠긴 상태
                self.icon:SetTexture("Interface\\AddOns\\WowPostIt\\k2.png")  -- 닫힌 자물쇠 아이콘
                noteEditBox:EnableMouse(false)
                noteEditBox:EnableKeyboard(false)
                -- noteEditBox:SetTextColor(0.5, 0.5, 0.5)  -- 텍스트 색상 변경 제거
                noteEditBox:ClearFocus()
                print("|cFFFFFF00WowPostIt:|r " .. (L["EDIT_LOCKED"] or "편집이 잠겼습니다"))
            else
                -- 해제 상태
                self.icon:SetTexture("Interface\\AddOns\\WowPostIt\\k1.png")  -- 열린 자물쇠 아이콘
                noteEditBox:EnableMouse(true)
                noteEditBox:EnableKeyboard(true)
                -- noteEditBox:SetTextColor(1, 1, 1)  -- 텍스트 색상 변경 제거
                print("|cFFFFFF00WowPostIt:|r " .. (L["EDIT_UNLOCKED"] or "편집이 해제되었습니다"))
            end
        end)

        noteWindow.lockButton = lockButton
        
        -- 스크롤 가능한 편집 박스
        local editScrollFrame = CreateFrame("ScrollFrame", "WowPostItEditScroll", editFrame, "UIPanelScrollFrameTemplate")
        editScrollFrame:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 5, -5)
        editScrollFrame:SetPoint("BOTTOMRIGHT", editFrame, "BOTTOMRIGHT", -25, 5)
        
        -- 편집 박스
        noteEditBox = CreateFrame("EditBox", nil, editScrollFrame)
        noteEditBox:SetMultiLine(true)
        noteEditBox:SetMaxLetters(5000)
        noteEditBox:SetSize(370, 320)
        noteEditBox:SetAutoFocus(false)
        noteEditBox:SetFontObject("ChatFontNormal")
        noteEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        
        -- 포스트잇 배경
        local editBg = editScrollFrame:CreateTexture(nil, "BACKGROUND")
        editBg:SetAllPoints(editScrollFrame)
        editBg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        editBg:SetVertexColor(1.0, 1.0, 0.6, 0.3)  -- 기본 노란색
        noteEditBox.bg = editBg
        
        -- 텍스트 변경 시 자동 저장
        noteEditBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and currentNoteId then
                addon.SaveNote(currentNoteId, self:GetText())
                addon:UpdateNoteList()
            end
        end)
        
        editScrollFrame:SetScrollChild(noteEditBox)
        
        -- 저장 상태 표시
        local statusText = noteWindow:CreateFontString(nil, "OVERLAY")
        statusText:SetFontObject("GameFontNormalSmall")
        statusText:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 15, 40)
        statusText:SetTextColor(0.5, 0.5, 0.5)
        noteWindow.statusText = statusText
        
        -- 크기 조절 그립 (우측 하단)
        local resizeGrip = CreateFrame("Button", nil, noteWindow)
        resizeGrip:SetSize(16, 16)
        resizeGrip:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -2, 2)
        resizeGrip:SetNormalTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up")
        resizeGrip:SetHighlightTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight")
        resizeGrip:SetPushedTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down")
        resizeGrip:EnableMouse(true)
        resizeGrip:RegisterForDrag("LeftButton")
        resizeGrip:SetScript("OnDragStart", function(self)
            noteWindow:StartSizing("BOTTOMRIGHT")
        end)
        resizeGrip:SetScript("OnDragStop", function(self)
            noteWindow:StopMovingOrSizing()
        end)
        resizeGrip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(L["RESIZE_WINDOW"] or "Resize Window", 1, 1, 1)
            GameTooltip:AddLine(L["RESIZE_HINT"] or "Click and drag to resize", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        resizeGrip:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        noteWindow.resizeGrip = resizeGrip

        -- 닫기 버튼 이벤트
        noteWindow.CloseButton:SetScript("OnClick", function()
            noteWindow:Hide()
        end)

        -- 프레임 참조 저장
        noteWindow.listFrame = listFrame
        noteWindow.editFrame = editFrame
        noteWindow.editScrollFrame = editScrollFrame
        noteWindow.scrollFrame = scrollFrame
        noteWindow.newButton = newButton
        noteWindow.deleteButton = deleteButton
        noteWindow.deleteAllButton = deleteAllButton
        noteWindow.chatDropdown = chatDropdown
        noteWindow.sendButton = sendButton
    end
    
    -- 노트 목록 업데이트
    self:UpdateNoteList()
    
    -- 첫 번째 노트 선택
    local notes = addon.GetNotes()
    if #notes > 0 then
        currentNoteId = WowPostItDB.selectedNoteId or notes[1].id
        for _, note in ipairs(notes) do
            if note.id == currentNoteId then
                noteEditBox:SetText(note.content)
                -- 편집 영역 배경색 설정 (부드럽게)
                if noteEditBox.bg and note.color then
                    noteEditBox.bg:SetVertexColor(
                        note.color[1] * 0.85,
                        note.color[2] * 0.85,
                        note.color[3] * 0.85,
                        0.5
                    )
                end
                break
            end
        end
    end
    
    noteWindow:Show()
end

-- 윈도우 레이아웃 업데이트
function addon:UpdateWindowLayout()
    if not noteWindow then return end

    local width = noteWindow:GetWidth()
    local height = noteWindow:GetHeight()

    -- 좌측 노트 목록 프레임 크기 조정
    if noteWindow.listFrame then
        noteWindow.listFrame:SetHeight(height - 70)
    end

    -- 스크롤 프레임 크기 조정
    if noteWindow.scrollFrame then
        noteWindow.scrollFrame:SetPoint("TOPLEFT", noteWindow.listFrame, "TOPLEFT", 5, -5)
        noteWindow.scrollFrame:SetPoint("BOTTOMRIGHT", noteWindow.listFrame, "BOTTOMRIGHT", -25, 5)
    end

    -- 우측 편집 영역 크기 조정
    if noteWindow.editFrame then
        noteWindow.editFrame:SetPoint("TOPLEFT", noteWindow.listFrame, "TOPRIGHT", 5, 0)
        noteWindow.editFrame:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -10, 40)
    end

    -- 편집 스크롤 프레임 크기 조정
    if noteWindow.editScrollFrame then
        noteWindow.editScrollFrame:SetPoint("TOPLEFT", noteWindow.editFrame, "TOPLEFT", 5, -5)
        noteWindow.editScrollFrame:SetPoint("BOTTOMRIGHT", noteWindow.editFrame, "BOTTOMRIGHT", -25, 5)
    end

    -- 편집 박스 크기 조정
    if noteEditBox then
        local editWidth = width - 230  -- 좌측 패널(180) + 여백들
        local editHeight = height - 80
        noteEditBox:SetSize(editWidth, editHeight)
    end

    -- 버튼들 위치 재조정
    if noteWindow.newButton then
        noteWindow.newButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 15, 10)
    end
    if noteWindow.deleteButton then
        noteWindow.deleteButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 100, 10)
    end
    if noteWindow.deleteAllButton then
        noteWindow.deleteAllButton:SetPoint("BOTTOMLEFT", noteWindow, "BOTTOMLEFT", 185, 10)
    end
    if noteWindow.chatDropdown then
        noteWindow.chatDropdown:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -185, 7)
    end
    if noteWindow.sendButton then
        noteWindow.sendButton:SetPoint("BOTTOMRIGHT", noteWindow, "BOTTOMRIGHT", -100, 10)
    end
end

-- 노트 목록 업데이트
function addon:UpdateNoteList()
    if not noteList then return end
    
    -- 기존 버튼 제거
    for _, button in ipairs(listButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    listButtons = {}
    
    local notes = addon.GetNotes()
    local yOffset = -5
    
    for i, note in ipairs(notes) do
        -- 노트 버튼 생성
        local button = CreateFrame("Button", nil, noteList)
        button:SetSize(145, 30)
        button:SetPoint("TOPLEFT", noteList, "TOPLEFT", 0, yOffset)
        
        -- 버튼 배경 (포스트잇 색상)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        
        -- 노트의 색상 적용 (없으면 기본 노란색) - 더 부드럽게
        local noteColor = note.color or {0.9, 0.9, 0.5}
        if note.id == currentNoteId then
            -- 선택된 노트는 더 진하게
            bg:SetVertexColor(noteColor[1] * 0.75, noteColor[2] * 0.75, noteColor[3] * 0.75, 1.0)
        else
            -- 일반 노트 (더 부드럽게)
            bg:SetVertexColor(noteColor[1] * 0.85, noteColor[2] * 0.85, noteColor[3] * 0.85, 1.0)
        end
        bg:Show()
        button.bg = bg
        button.noteColor = noteColor
        
        -- 노트 제목 (첫 줄 또는 처음 10자)
        local title = button:CreateFontString(nil, "OVERLAY")
        title:SetFontObject("GameFontNormalSmall")
        title:SetPoint("LEFT", button, "LEFT", 5, 0)
        title:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        title:SetJustifyH("LEFT")
        title:SetTextColor(0, 0, 0, 1)  -- 검정색 텍스트
        
        -- UTF-8 안전한 문자열 자르기 함수
        local function utf8sub(str, startChar, numChars)
            local currentIndex = 1
            local charCount = 0
            local startIndex = 1
            local endIndex = str:len()
            
            while currentIndex <= str:len() do
                if charCount == startChar - 1 then
                    startIndex = currentIndex
                end
                
                local char = string.byte(str, currentIndex)
                local charLen = 1
                
                if char > 0 and char <= 127 then
                    charLen = 1
                elseif char >= 194 and char <= 223 then
                    charLen = 2
                elseif char >= 224 and char <= 239 then
                    charLen = 3
                elseif char >= 240 and char <= 244 then
                    charLen = 4
                end
                
                currentIndex = currentIndex + charLen
                charCount = charCount + 1
                
                if charCount == startChar + numChars - 1 then
                    endIndex = currentIndex - 1
                    break
                end
            end
            
            return str:sub(startIndex, endIndex)
        end
        
        -- 첫 줄 추출 (UTF-8 안전하게 10자 제한)
        local firstLine = note.content:match("^([^\n]+)") or note.content
        local utf8len = 0
        local i = 1
        while i <= #firstLine do
            local char = string.byte(firstLine, i)
            if char > 0 and char <= 127 then
                i = i + 1
            elseif char >= 194 and char <= 223 then
                i = i + 2
            elseif char >= 224 and char <= 239 then
                i = i + 3
            elseif char >= 240 and char <= 244 then
                i = i + 4
            else
                i = i + 1
            end
            utf8len = utf8len + 1
        end
        
        if utf8len > 10 then
            firstLine = utf8sub(firstLine, 1, 10) .. "..."
        end
        title:SetText(firstLine)
        
        -- 마우스 오버 효과
        button:SetScript("OnEnter", function(self)
            if note.id ~= currentNoteId then
                -- 마우스 오버 시 약간 밝게
                self.bg:SetVertexColor(
                    math.min(self.noteColor[1] * 0.95, 1.0),
                    math.min(self.noteColor[2] * 0.95, 1.0),
                    math.min(self.noteColor[3] * 0.95, 1.0),
                    1.0
                )
            end
            
            -- 툴팁 표시
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(firstLine, 1, 1, 1)
            GameTooltip:AddLine(L["CREATED"] .. ": " .. note.created, 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L["MODIFIED"] .. ": " .. note.modified, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        button:SetScript("OnLeave", function(self)
            if note.id ~= currentNoteId then
                -- 원래 색상으로 복원 (부드럽게)
                self.bg:SetVertexColor(
                    self.noteColor[1] * 0.85,
                    self.noteColor[2] * 0.85,
                    self.noteColor[3] * 0.85,
                    1.0
                )
            end
            GameTooltip:Hide()
        end)
        
        -- 클릭 이벤트
        button:SetScript("OnClick", function(self)
            -- 모든 버튼 원래 색상으로 (부드럽게)
            for _, btn in ipairs(listButtons) do
                btn.bg:SetVertexColor(
                    btn.noteColor[1] * 0.85,
                    btn.noteColor[2] * 0.85,
                    btn.noteColor[3] * 0.85,
                    1.0
                )
            end

            -- 현재 버튼 진하게
            self.bg:SetVertexColor(
                self.noteColor[1] * 0.75,
                self.noteColor[2] * 0.75,
                self.noteColor[3] * 0.75,
                1.0
            )

            -- 편집 영역 배경색 변경 (부드럽게)
            if noteEditBox.bg then
                noteEditBox.bg:SetVertexColor(
                    self.noteColor[1] * 0.85,
                    self.noteColor[2] * 0.85,
                    self.noteColor[3] * 0.85,
                    0.5
                )
            end

            -- 노트 내용 로드
            currentNoteId = note.id
            WowPostItDB.selectedNoteId = currentNoteId
            noteEditBox:SetText(note.content)

            -- 잠금 상태 해제
            if noteWindow.isLocked then
                noteWindow.isLocked = false
                noteWindow.lockButton.icon:SetTexture("Interface\\AddOns\\WowPostIt\\k1.png")  -- 열린 자물쇠 아이콘
                noteEditBox:EnableMouse(true)
                noteEditBox:EnableKeyboard(true)
                -- noteEditBox:SetTextColor(1, 1, 1)  -- 텍스트 색상 변경 제거
            end

            noteEditBox:SetFocus()
        end)
        
        table.insert(listButtons, button)
        yOffset = yOffset - 32
    end
    
    -- 목록 높이 조정
    noteList:SetHeight(math.abs(yOffset) + 40)
    
    -- 상태 업데이트
    if noteWindow and noteWindow.statusText then
        noteWindow.statusText:SetText(string.format(L["TOTAL_NOTES"], #notes))
    end
end