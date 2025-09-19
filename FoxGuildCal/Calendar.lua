-- FoxGuildCal Calendar UI
local addonName, addon = ...

-- 전역 날짜 변수
local currentYear, currentMonth, selectedDay
local dayButtons = {}
local eventFrames = {}

-- 날짜 변수 설정 함수 (외부에서 호출 가능)
function addon:SetDateVariables(year, month, day)
    currentYear = year
    currentMonth = month
    selectedDay = day
end

-- 현재 날짜 변수 반환
function addon:GetDateVariables()
    return currentYear, currentMonth, selectedDay
end

-- 메인 캘린더 프레임 생성
local function CreateCalendarFrame()
    local frame = CreateFrame("Frame", "FoxGuildCalFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()  -- 창 이동은 항상 가능
    end)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(50)

    -- ESC 키로 닫기 지원
    tinsert(UISpecialFrames, "FoxGuildCalFrame")
    
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)  -- 완전 불투명 검은 배경
    
    -- 제목
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("FoxGuildCal - 길드 캘린더")
    frame.title = title
    
    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()  -- 닫기는 항상 가능
    end)
    
    -- 월 네비게이션
    local prevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    prevButton:SetSize(30, 25)
    prevButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -50)
    prevButton:SetText("<")
    prevButton:SetScript("OnClick", function()
        currentMonth = currentMonth - 1
        if currentMonth < 1 then
            currentMonth = 12
            currentYear = currentYear - 1
        end
        -- 월이 바뀌면 선택된 날짜를 1일로 리셋
        selectedDay = 1
        addon:UpdateCalendar()
        addon:ShowDayEvents(currentYear, currentMonth, selectedDay)
    end)
    
    local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextButton:SetSize(30, 25)
    nextButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -300, -50)
    nextButton:SetText(">")
    nextButton:SetScript("OnClick", function()
        currentMonth = currentMonth + 1
        if currentMonth > 12 then
            currentMonth = 1
            currentYear = currentYear + 1
        end
        -- 월이 바뀌면 선택된 날짜를 1일로 리셋
        selectedDay = 1
        addon:UpdateCalendar()
        addon:ShowDayEvents(currentYear, currentMonth, selectedDay)
    end)
    
    local monthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    monthLabel:SetPoint("TOP", frame, "TOP", -150, -52)
    frame.monthLabel = monthLabel
    
    -- 요일 헤더 (일요일부터 시작)
    local weekDays = {"일", "월", "화", "수", "목", "금", "토"}
    for i, day in ipairs(weekDays) do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 30 + (i-1)*40, -85)  -- 30으로 조정하여 칸에 맞춤
        label:SetText(day)
        if i == 1 then -- 일요일
            label:SetTextColor(1, 0.2, 0.2)
        elseif i == 7 then -- 토요일
            label:SetTextColor(0.2, 0.2, 1)
        end
    end
    
    -- 날짜 버튼들
    for week = 0, 5 do
        for day = 1, 7 do
            local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
            button:SetSize(38, 30)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (day-1)*40, -110 - week*35)
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            button:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            button.text = text
            
            -- 공유 일정 표시 점 (녹색)
            local sharedDot = button:CreateTexture(nil, "OVERLAY")
            sharedDot:SetSize(6, 6)
            sharedDot:SetPoint("TOPRIGHT", -2, -2)
            sharedDot:SetTexture("Interface\\Buttons\\WHITE8X8")
            sharedDot:SetVertexColor(0, 1, 0)
            sharedDot:Hide()
            button.sharedDot = sharedDot

            -- 개인 일정 표시 점 (황금색)
            local personalDot = button:CreateTexture(nil, "OVERLAY")
            personalDot:SetSize(6, 6)
            personalDot:SetPoint("TOPRIGHT", -10, -2)  -- 공유 일정 점 왼쪽에 표시
            personalDot:SetTexture("Interface\\Buttons\\WHITE8X8")
            personalDot:SetVertexColor(1, 0.84, 0)
            personalDot:Hide()
            button.personalDot = personalDot

            -- 구버전 호환성을 위해 유지
            button.eventDot = sharedDot
            
            button:SetScript("OnClick", function(self)
                if self.day then
                    selectedDay = self.day
                    -- 현재 년도와 월도 업데이트 (혹시나 변경되었을 경우를 대비)
                    addon:UpdateCalendar()
                    addon:ShowDayEvents(currentYear, currentMonth, self.day)
                end
            end)
            
            button:SetScript("OnEnter", function(self)
                if self.day then
                    self:SetBackdropColor(0.2, 0.2, 0.3, 1)
                end
            end)
            
            button:SetScript("OnLeave", function(self)
                if self.day then
                    if selectedDay == self.day then
                        self:SetBackdropColor(0.3, 0.3, 0.5, 1)
                    else
                        self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                    end
                end
            end)
            
            table.insert(dayButtons, button)
        end
    end
    
    -- 우측 이벤트 목록 패널
    local eventPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    eventPanel:SetSize(280, 400)
    eventPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -50)
    eventPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    eventPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    eventPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local eventPanelTitle = eventPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eventPanelTitle:SetPoint("TOP", eventPanel, "TOP", 0, -10)
    eventPanelTitle:SetText("일정 목록")
    eventPanel.title = eventPanelTitle

    -- 이벤트 스크롤 프레임
    local scrollFrame = CreateFrame("ScrollFrame", nil, eventPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", eventPanel, "TOPLEFT", 5, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", eventPanel, "BOTTOMRIGHT", -25, 40)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(250, 600)
    scrollFrame:SetScrollChild(scrollChild)
    eventPanel.scrollChild = scrollChild

    -- 이벤트 추가 버튼
    local addButton = CreateFrame("Button", nil, eventPanel, "UIPanelButtonTemplate")
    addButton:SetSize(100, 25)
    addButton:SetPoint("BOTTOM", eventPanel, "BOTTOM", 0, 10)
    addButton:SetText("일정 추가")
    addButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            addon:Print("전투 중에는 일정을 추가할 수 없습니다.")
            return
        end
        addon:ShowAddEventDialog()
    end)

    -- 상세 정보 패널 (기본적으로 숨김)
    local detailPanel = CreateFrame("Frame", nil, eventPanel, "BackdropTemplate")
    detailPanel:SetAllPoints(eventPanel)
    detailPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    detailPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    detailPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    detailPanel:Hide()

    -- 뒤로가기 버튼
    local backButton = CreateFrame("Button", nil, detailPanel)
    backButton:SetSize(24, 24)
    backButton:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 5, -5)
    backButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    backButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    backButton:SetScript("OnClick", function()
        detailPanel:Hide()
        scrollFrame:Show()
        addButton:Show()
        eventPanelTitle:SetText(string.format("%d년 %d월 %d일", currentYear, currentMonth, selectedDay))
    end)

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOP", detailPanel, "TOP", 0, -10)
    detailTitle:SetText("일정 상세")
    detailPanel.title = detailTitle

    -- 상세 정보 컨테이너
    local detailContent = CreateFrame("Frame", nil, detailPanel)
    detailContent:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -35)
    detailContent:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -10, 10)
    detailPanel.content = detailContent

    eventPanel.detailPanel = detailPanel
    frame.eventPanel = eventPanel
    frame:Hide()
    
    return frame
end

-- 캘린더 업데이트
function addon:UpdateCalendar()
    local frame = addon.calendarFrame
    if not frame then return end

    -- 날짜 변수가 초기화되지 않았으면 초기화
    if not currentYear or not currentMonth then
        local today = C_DateAndTime.GetCurrentCalendarTime()
        currentYear = today.year
        currentMonth = today.month
        if not selectedDay then
            selectedDay = today.monthDay
        end
    end

    -- 월 레이블 업데이트
    frame.monthLabel:SetText(string.format("%d년 %s", currentYear, addon:GetMonthName(currentMonth)))
    
    -- 날짜 버튼 업데이트
    local firstDay = addon:GetFirstDayOfWeek(currentYear, currentMonth)
    local daysInMonth = addon:GetDaysInMonth(currentYear, currentMonth)
    local today = addon:GetCurrentDate()
    
    -- 모든 버튼 초기화
    for _, button in ipairs(dayButtons) do
        button:Hide()
        button.day = nil
        button.sharedDot:Hide()
        button.personalDot:Hide()
    end
    
    -- 날짜 설정
    for day = 1, daysInMonth do
        local buttonIndex = firstDay + day - 1
        local button = dayButtons[buttonIndex]
        if button then
            button:Show()
            button.day = day
            button.text:SetText(tostring(day))
            
            -- 오늘 날짜 표시
            if currentYear == today.year and currentMonth == today.month and day == today.day then
                button.text:SetTextColor(1, 1, 0) -- 노란색
            else
                button.text:SetTextColor(1, 1, 1)
            end
            
            -- 선택된 날짜 표시
            if selectedDay == day then
                button:SetBackdropColor(0.3, 0.3, 0.5, 1)
            else
                button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            end
            
            -- 이벤트 있는지 체크하고 각각의 점 표시
            local hasEvent, hasPersonal, hasShared = addon:HasEventsOnDay(currentYear, currentMonth, day)
            if hasShared then
                button.sharedDot:Show()
            end
            if hasPersonal then
                button.personalDot:Show()
            end
        end
    end
end

-- 특정 날짜에 이벤트가 있는지 체크 및 타입 반환
function addon:HasEventsOnDay(year, month, day)
    local dateStr = addon:FormatDate(year, month, day)
    local hasPersonal = false
    local hasShared = false

    -- 개인 일정 확인
    for _, event in pairs(addon.db.personalEvents or {}) do
        if not event.deleted and event.date == dateStr then
            hasPersonal = true
            break
        end
    end

    -- 공유 일정 확인
    local guildKey = addon:GetGuildKey()
    if guildKey then
        local events = addon.db.events[guildKey] or {}
        for _, event in pairs(events) do
            if not event.deleted and event.date == dateStr then
                hasShared = true
                break
            end
        end
    end

    return hasPersonal or hasShared, hasPersonal, hasShared
end

-- 선택한 날짜의 이벤트 표시
function addon:ShowDayEvents(year, month, day)
    local frame = addon.calendarFrame
    if not frame then return end

    local dateStr = addon:FormatDate(year, month, day)
    local scrollChild = frame.eventPanel.scrollChild

    -- 기존 이벤트 프레임 제거
    for _, eventFrame in ipairs(eventFrames) do
        eventFrame:Hide()
        eventFrame:SetParent(nil)
    end
    eventFrames = {}

    -- 날짜 표시
    frame.eventPanel.title:SetText(string.format("%d년 %d월 %d일", year, month, day))

    -- 모든 이벤트 수집
    local allEvents = {}

    -- 개인 일정 추가
    for _, event in pairs(addon.db.personalEvents or {}) do
        if not event.deleted and event.date == dateStr then
            table.insert(allEvents, event)
        end
    end

    -- 공유 일정 추가
    local guildKey = addon:GetGuildKey()
    if guildKey then
        for _, event in pairs(addon.db.events[guildKey] or {}) do
            if not event.deleted and event.date == dateStr then
                table.insert(allEvents, event)
            end
        end
    end

    -- 시간순 정렬
    table.sort(allEvents, function(a, b)
        local timeA = (a.hour or 0) * 60 + (a.minute or 0)
        local timeB = (b.hour or 0) * 60 + (b.minute or 0)
        return timeA < timeB
    end)

    -- 이벤트 목록 생성
    local yOffset = -5
    for _, event in ipairs(allEvents) do
            local eventFrame = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            eventFrame:SetSize(240, 60)
            eventFrame:SetPoint("TOP", scrollChild, "TOP", 0, yOffset)
            eventFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            eventFrame:SetBackdropColor(0.1, 0.1, 0.2, 0.9)
            eventFrame:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
            
            local timeText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            timeText:SetPoint("TOPLEFT", eventFrame, "TOPLEFT", 5, -5)
            timeText:SetText(string.format("%02d:%02d", event.hour or 0, event.minute or 0))
            timeText:SetTextColor(0.7, 0.7, 1)
            
            local titleText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleText:SetPoint("TOPLEFT", eventFrame, "TOPLEFT", 5, -20)
            -- 개인 일정은 다른 색상으로 표시
            local titleStr = event.title
            if event.isShared == false then
                titleStr = "|cffffaa00[개인] " .. event.title .. "|r"
            else
                titleStr = "|cff00ffff" .. event.title .. "|r"
            end
            titleText:SetText(titleStr)
            titleText:SetWidth(230)
            titleText:SetJustifyH("LEFT")
            
            local authorText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            authorText:SetPoint("BOTTOMLEFT", eventFrame, "BOTTOMLEFT", 5, 5)
            authorText:SetText("작성: " .. (event.author or "Unknown"))
            authorText:SetTextColor(0.6, 0.6, 0.6)
            
            -- 삭제 버튼 (작성자 또는 같은 닉네임)
            local playerName = UnitName("player")
            local canDelete = false

            -- 작성자 확인 (전체 이름 또는 닉네임만)
            if event.author then
                if event.author == addon:GetPlayerFullName() then
                    canDelete = true
                else
                    -- 닉네임만 비교 (서버명 제외)
                    local authorName = event.author:match("^([^-]+)")
                    if authorName == playerName then
                        canDelete = true
                    end
                end
            end

            if canDelete then
                local deleteButton = CreateFrame("Button", nil, eventFrame)
                deleteButton:SetSize(16, 16)
                deleteButton:SetPoint("TOPRIGHT", eventFrame, "TOPRIGHT", -5, -5)
                deleteButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
                deleteButton:SetScript("OnClick", function()
                    if InCombatLockdown() then
                        addon:Print("전투 중에는 일정을 삭제할 수 없습니다.")
                        return
                    end
                    addon:DeleteEvent(event.id)
                end)
            end
            
            eventFrame:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.2, 0.2, 0.3, 1)
            end)
            
            eventFrame:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.1, 0.1, 0.2, 0.9)
            end)
            
            -- 클릭 시 상세 정보를 별도 패널에 표시
            eventFrame:SetScript("OnClick", function(self)
                addon:ShowEventDetailPanel(event)
            end)
            
            table.insert(eventFrames, eventFrame)
            yOffset = yOffset - 65
    end

    scrollChild:SetHeight(math.abs(yOffset))
end

-- 이벤트 상세 정보를 별도 패널에 표시
function addon:ShowEventDetailPanel(event)
    local frame = addon.calendarFrame
    if not frame then return end

    -- 기존 상세 패널이 있으면 제거
    if frame.detailPanel then
        frame.detailPanel:Hide()
        frame.detailPanel:SetParent(nil)
        frame.detailPanel = nil
    end

    -- 새로운 상세 정보 패널 생성 (캘린더 프레임 우측에)
    local detailPanel = CreateFrame("Frame", "FoxGuildCalDetailPanel", frame, "BackdropTemplate")
    detailPanel:SetSize(300, 400)
    detailPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
    detailPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    detailPanel:SetBackdropColor(0, 0, 0, 1)
    detailPanel:SetFrameStrata("HIGH")
    detailPanel:SetFrameLevel(frame:GetFrameLevel() + 1)

    -- 제목
    local title = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", detailPanel, "TOP", 0, -20)
    title:SetText("일정 상세 정보")

    -- 닫기 버튼
    local closeButton = CreateFrame("Button", nil, detailPanel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        detailPanel:Hide()
        frame.detailPanel = nil
    end)

    local content = detailPanel

    -- 이벤트 제목
    local eventTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    eventTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 20, -50)
    eventTitle:SetText("|cff00ff00" .. event.title .. "|r")
    eventTitle:SetWidth(260)
    eventTitle:SetJustifyH("LEFT")

    -- 날짜와 시간
    local dateTime = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateTime:SetPoint("TOPLEFT", eventTitle, "BOTTOMLEFT", 0, -10)
    local timeStr = string.format("%s %02d:%02d", event.date, event.hour or 0, event.minute or 0)
    dateTime:SetText("|cffffffff날짜/시간:|r " .. timeStr)

    -- 작성자
    local author = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    author:SetPoint("TOPLEFT", dateTime, "BOTTOMLEFT", 0, -10)
    author:SetText("|cffffffff작성자:|r " .. (event.author or "Unknown"))

    -- 일정 유형
    local eventType = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eventType:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -10)
    local typeText = event.isShared == false and "|cffff8800[개인 일정]|r" or "|cff00ffff[공유 일정]|r"
    eventType:SetText("|cffffffff일정 유형:|r " .. typeText)

    -- 설명 레이블
    local descLabel = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", eventType, "BOTTOMLEFT", 0, -15)
    descLabel:SetText("|cffffffff설명:|r")

    -- 설명 내용 (스크롤 가능)
    local descBg = CreateFrame("Frame", nil, detailPanel, "BackdropTemplate")
    descBg:SetSize(260, 150)
    descBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    descBg:SetBackdropColor(0, 0, 0, 0.5)

    local descScroll = CreateFrame("ScrollFrame", nil, descBg, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", descBg, "TOPLEFT", 8, -8)
    descScroll:SetPoint("BOTTOMRIGHT", descBg, "BOTTOMRIGHT", -30, 8)

    local descContent = CreateFrame("Frame", nil, descScroll)
    descContent:SetSize(220, 1)

    local descText = descContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT", descContent, "TOPLEFT", 0, 0)
    descText:SetWidth(220)
    descText:SetText(event.description and event.description ~= "" and event.description or "(설명 없음)")
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")

    local textHeight = descText:GetStringHeight()
    descContent:SetHeight(textHeight + 10)

    descScroll:SetScrollChild(descContent)

    -- 버튼들
    if event.author == addon:GetPlayerFullName() then
        local editButton = CreateFrame("Button", nil, detailPanel, "UIPanelButtonTemplate")
        editButton:SetSize(80, 25)
        editButton:SetPoint("BOTTOMLEFT", detailPanel, "BOTTOMLEFT", 20, 20)
        editButton:SetText("수정")
        editButton:SetScript("OnClick", function()
            detailPanel:Hide()
            frame.detailPanel = nil
            addon:ShowEditEventDialog(event)
        end)

        local deleteButton = CreateFrame("Button", nil, detailPanel, "UIPanelButtonTemplate")
        deleteButton:SetSize(80, 25)
        deleteButton:SetPoint("LEFT", editButton, "RIGHT", 10, 0)
        deleteButton:SetText("삭제")
        deleteButton:SetScript("OnClick", function()
            StaticPopup_Show("FOXGUILDCAL_DELETE_CONFIRM", event.title, nil, event)
            detailPanel:Hide()
            frame.detailPanel = nil
        end)
    end

    frame.detailPanel = detailPanel
    detailPanel:Show()

    -- 현재 선택된 이벤트 저장
    frame.selectedEvent = event
end

-- 이벤트 상세 정보 팝업 (기존 함수는 호환성을 위해 유지)
function addon:ShowEventDetail(event)
    -- 새로운 상세 패널 방식으로 변경
    addon:ShowEventDetailPanel(event)
end

-- 삭제 확인 다이얼로그
StaticPopupDialogs["FOXGUILDCAL_DELETE_CONFIRM"] = {
    text = "일정 \"%s\"을(를) 삭제하시겠습니까?",
    button1 = "삭제",
    button2 = "취소",
    OnAccept = function(self, event)
        addon:DeleteEvent(event.id)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- 이벤트 수정 다이얼로그
function addon:ShowEditEventDialog(event)
    if not event then return end

    -- 전투 중 체크
    if InCombatLockdown() then
        addon:Print("전투 중에는 일정을 수정할 수 없습니다.")
        return
    end
    
    local dialog = CreateFrame("Frame", "FoxGuildCalEditEvent", UIParent, "BackdropTemplate")
    dialog:SetSize(350, 350)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(100)
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    dialog:SetBackdropColor(0, 0, 0, 1)  -- 완전 불투명 검은 배경
    
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("일정 수정")
    
    -- 제목 입력
    local titleLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -50)
    titleLabel:SetText("제목:")
    
    local titleEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    titleEdit:SetSize(300, 20)
    titleEdit:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -5)
    titleEdit:SetAutoFocus(true)
    titleEdit:SetText(event.title)
    
    -- Tab 키 처리
    titleEdit:SetScript("OnTabPressed", function(self)
        hourEdit:SetFocus()
    end)
    
    -- 시간 입력
    local timeLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", titleEdit, "BOTTOMLEFT", 0, -10)
    timeLabel:SetText("시간 (HH:MM):")
    
    local hourEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    hourEdit:SetSize(40, 20)
    hourEdit:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -5)
    hourEdit:SetAutoFocus(false)
    hourEdit:SetMaxLetters(2)
    hourEdit:SetNumeric(true)
    hourEdit:SetText(string.format("%02d", event.hour or 0))
    
    hourEdit:SetScript("OnTabPressed", function(self)
        minuteEdit:SetFocus()
    end)
    
    local colonLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colonLabel:SetPoint("LEFT", hourEdit, "RIGHT", 5, 0)
    colonLabel:SetText(":")
    
    local minuteEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    minuteEdit:SetSize(40, 20)
    minuteEdit:SetPoint("LEFT", colonLabel, "RIGHT", 5, 0)
    minuteEdit:SetAutoFocus(false)
    minuteEdit:SetMaxLetters(2)
    minuteEdit:SetNumeric(true)
    minuteEdit:SetText(string.format("%02d", event.minute or 0))
    
    minuteEdit:SetScript("OnTabPressed", function(self)
        descEdit:SetFocus()
    end)
    
    -- 일정 유형 체크박스
    local shareCheckbox = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    shareCheckbox:SetPoint("TOPLEFT", hourEdit, "BOTTOMLEFT", 0, -10)
    shareCheckbox.text = shareCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shareCheckbox.text:SetPoint("LEFT", shareCheckbox, "RIGHT", 5, 0)
    shareCheckbox.text:SetText("길드 공유 일정")
    shareCheckbox:SetChecked(true)  -- 기본값: 공유 일정

    -- 설명 입력 (멀티라인)
    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", shareCheckbox, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("설명 (선택):")
    
    local descBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    descBg:SetSize(300, 100)
    descBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    descBg:SetBackdropColor(0, 0, 0, 0.5)
    
    local descScroll = CreateFrame("ScrollFrame", nil, descBg, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", descBg, "TOPLEFT", 8, -8)
    descScroll:SetPoint("BOTTOMRIGHT", descBg, "BOTTOMRIGHT", -30, 8)
    
    local descEdit = CreateFrame("EditBox", nil, descScroll)
    descEdit:SetMultiLine(true)
    descEdit:SetMaxLetters(500)
    descEdit:SetSize(260, 200)
    descEdit:SetFont(GameFontNormal:GetFont())  -- 게임 기본 폰트 사용
    descEdit:SetAutoFocus(false)
    descEdit:SetTextInsets(5, 5, 5, 5)
    descEdit:SetText(event.description or "")
    
    descScroll:SetScrollChild(descEdit)
    
    descEdit:SetScript("OnEditFocusGained", function(self)
        descBg:SetBackdropBorderColor(1, 1, 0, 1)
    end)
    descEdit:SetScript("OnEditFocusLost", function(self)
        descBg:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    
    -- 버튼들
    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 25)
    saveButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 50, 20)
    saveButton:SetText("저장")
    saveButton:SetScript("OnClick", function()
        local eventTitle = titleEdit:GetText()
        if eventTitle == "" then
            addon:Print("제목을 입력하세요.")
            return
        end
        
        local hour = tonumber(hourEdit:GetText()) or 0
        local minute = tonumber(minuteEdit:GetText()) or 0
        
        -- 기존 이벤트 업데이트
        event.title = eventTitle
        event.hour = hour
        event.minute = minute
        event.description = descEdit:GetText()
        event.isShared = shareCheckbox:GetChecked()
        event.updatedAt = time()
        
        addon:UpdateEvent(event)
        dialog:Hide()
    end)
    
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -50, 20)
    cancelButton:SetText("취소")
    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    dialog:Show()
end

-- 이벤트 업데이트
function addon:UpdateEvent(event)
    if event.isShared then
        -- 공유 일정: 길드별로 저장
        local guildKey = addon:GetGuildKey()
        if not guildKey then
            addon:Print("길드에 가입되어 있지 않습니다.")
            return
        end
        addon.db.events[guildKey] = addon.db.events[guildKey] or {}
        addon.db.events[guildKey][event.id] = event
        addon:BroadcastEvent("UPDATE", event)
        addon:Print("공유 일정이 수정되었습니다: " .. event.title)
    else
        -- 개인 일정: 계정 레벨로 저장
        addon.db.personalEvents[event.id] = event
        addon:Print("개인 일정이 수정되었습니다: " .. event.title)
    end

    addon:UpdateCalendar()
    addon:ShowDayEvents(event.year, event.month, event.day)
end

-- 이벤트 추가 다이얼로그
function addon:ShowAddEventDialog()
    -- 전투 중 체크
    if InCombatLockdown() then
        addon:Print("전투 중에는 일정을 추가할 수 없습니다.")
        return
    end

    -- 날짜 변수 초기화 확인
    if not currentYear or not currentMonth or not selectedDay then
        local today = C_DateAndTime.GetCurrentCalendarTime()
        if not currentYear then currentYear = today.year end
        if not currentMonth then currentMonth = today.month end
        if not selectedDay then selectedDay = today.monthDay end
    end

    -- 디버그 정보
    -- addon:Print(string.format("선택된 날짜: %d년 %d월 %d일", currentYear, currentMonth, selectedDay))
    
    local dialog = CreateFrame("Frame", "FoxGuildCalAddEvent", UIParent, "BackdropTemplate")
    dialog:SetSize(350, 350)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(100)
    dialog:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    dialog:SetBackdropColor(0.05, 0.05, 0.05, 1)  -- 완전 불투명 어두운 회색 배경
    
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("일정 추가")
    
    -- 제목 입력
    local titleLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -50)
    titleLabel:SetText("제목:")
    
    local titleEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    titleEdit:SetSize(300, 20)
    titleEdit:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -5)
    titleEdit:SetAutoFocus(true)
    
    -- 시간 입력
    local timeLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", titleEdit, "BOTTOMLEFT", 0, -10)
    timeLabel:SetText("시간 (HH:MM):")
    
    local hourEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    hourEdit:SetSize(40, 20)
    hourEdit:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -5)
    hourEdit:SetAutoFocus(false)
    hourEdit:SetMaxLetters(2)
    hourEdit:SetNumeric(true)
    
    local colonLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colonLabel:SetPoint("LEFT", hourEdit, "RIGHT", 5, 0)
    colonLabel:SetText(":")
    
    local minuteEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    minuteEdit:SetSize(40, 20)
    minuteEdit:SetPoint("LEFT", colonLabel, "RIGHT", 5, 0)
    minuteEdit:SetAutoFocus(false)
    minuteEdit:SetMaxLetters(2)
    minuteEdit:SetNumeric(true)
    
    -- 일정 유형 체크박스
    local shareCheckbox = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    shareCheckbox:SetPoint("TOPLEFT", hourEdit, "BOTTOMLEFT", 0, -10)
    shareCheckbox.text = shareCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shareCheckbox.text:SetPoint("LEFT", shareCheckbox, "RIGHT", 5, 0)
    shareCheckbox.text:SetText("길드 공유 일정")
    shareCheckbox:SetChecked(true)  -- 기본값: 공유 일정

    -- 설명 입력 (멀티라인)
    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", shareCheckbox, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("설명 (선택):")
    
    -- 스크롤 프레임과 에디트박스를 위한 배경
    local descBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    descBg:SetSize(300, 100)
    descBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    descBg:SetBackdropColor(0, 0, 0, 0.5)
    
    local descScroll = CreateFrame("ScrollFrame", nil, descBg, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", descBg, "TOPLEFT", 8, -8)
    descScroll:SetPoint("BOTTOMRIGHT", descBg, "BOTTOMRIGHT", -30, 8)
    
    local descEdit = CreateFrame("EditBox", nil, descScroll)
    descEdit:SetMultiLine(true)
    descEdit:SetMaxLetters(500)
    descEdit:SetSize(260, 200)
    descEdit:SetFont(GameFontNormal:GetFont())  -- 게임 기본 폰트 사용
    descEdit:SetAutoFocus(false)
    descEdit:SetTextInsets(5, 5, 5, 5)
    
    descScroll:SetScrollChild(descEdit)

    -- Tab 키 네비게이션 설정
    titleEdit:SetScript("OnTabPressed", function(self)
        hourEdit:SetFocus()
    end)

    hourEdit:SetScript("OnTabPressed", function(self)
        minuteEdit:SetFocus()
    end)

    minuteEdit:SetScript("OnTabPressed", function(self)
        descEdit:SetFocus()
    end)

    descEdit:SetScript("OnTabPressed", function(self)
        titleEdit:SetFocus()
    end)

    -- 포커스 시 테두리 효과
    descEdit:SetScript("OnEditFocusGained", function(self)
        descBg:SetBackdropBorderColor(1, 1, 0, 1)
    end)
    descEdit:SetScript("OnEditFocusLost", function(self)
        descBg:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    
    -- 버튼들
    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 25)
    saveButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 50, 20)
    saveButton:SetText("저장")
    saveButton:SetScript("OnClick", function()
        local eventTitle = titleEdit:GetText()
        if eventTitle == "" then
            addon:Print("제목을 입력하세요.")
            return
        end
        
        local hour = tonumber(hourEdit:GetText()) or 0
        local minute = tonumber(minuteEdit:GetText()) or 0
        
        -- 날짜 값 마지막 검증
        local year = currentYear
        local month = currentMonth
        local day = selectedDay

        -- 각 값을 개별적으로 확인
        if not year or not month or not day then
            addon:Print(string.format("오류: 날짜 정보가 올바르지 않습니다. (year=%s, month=%s, day=%s)",
                tostring(year), tostring(month), tostring(day)))
            return
        end

        local event = {
            id = addon:GenerateEventId(),
            date = addon:FormatDate(year, month, day),
            year = year,
            month = month,
            day = day,
            hour = hour,
            minute = minute,
            title = eventTitle,
            description = descEdit:GetText(),
            author = addon:GetPlayerFullName(),
            isShared = shareCheckbox:GetChecked(),  -- 공유 여부
            createdAt = time(),
            updatedAt = time(),
        }

        -- 저장 전 최종 확인
        addon:Print(string.format("일정 저장: %d년 %d월 %d일 - %s",
            event.year, event.month, event.day, event.title))
        
        addon:AddEvent(event)
        dialog:Hide()
    end)
    
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -50, 20)
    cancelButton:SetText("취소")
    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
    titleEdit:SetFocus()
end

-- 이벤트 추가
function addon:AddEvent(event)
    -- 날짜 정보 검증
    if not event.year or not event.month or not event.day then
        addon:Print("오류: 날짜 정보가 올바르지 않습니다.")
        return
    end

    if event.isShared then
        -- 공유 일정: 길드별로 저장
        local guildKey = addon:GetGuildKey()
        if not guildKey then
            addon:Print("길드에 가입되어 있지 않습니다.")
            return
        end
        addon.db.events[guildKey] = addon.db.events[guildKey] or {}
        addon.db.events[guildKey][event.id] = event
        addon:BroadcastEvent("ADD", event)
        addon:Print("공유 일정이 추가되었습니다: " .. event.title)
    else
        -- 개인 일정: 계정 레벨로 저장
        addon.db.personalEvents[event.id] = event
        addon:Print("개인 일정이 추가되었습니다: " .. event.title)
    end

    addon:UpdateCalendar()
    addon:ShowDayEvents(event.year, event.month, event.day)
end

-- 이벤트 삭제
function addon:DeleteEvent(eventId)
    -- 전투 중 체크
    if InCombatLockdown() then
        addon:Print("전투 중에는 일정을 삭제할 수 없습니다.")
        return
    end

    local deleted = false
    local playerName = UnitName("player")

    -- 개인 일정 확인
    if addon.db.personalEvents[eventId] then
        local event = addon.db.personalEvents[eventId]
        event.deleted = true
        event.deletedAt = time()
        event.deletedBy = addon:GetPlayerFullName()
        addon:Print("개인 일정이 삭제되었습니다.")
        deleted = true
    end

    -- 공유 일정 확인 (개인 일정과 별개로 확인 - 버그로 인해 양쪽에 있을 수 있음)
    local guildKey = addon:GetGuildKey()
    if guildKey then
        local events = addon.db.events[guildKey]
        if events and events[eventId] then
            local event = events[eventId]

            -- 작성자 확인 (전체 이름 또는 닉네임 비교)
            local canDelete = false
            if event.author then
                if event.author == addon:GetPlayerFullName() then
                    canDelete = true
                else
                    -- 닉네임만 비교
                    local authorName = event.author:match("^([^-]+)")
                    if authorName == playerName then
                        canDelete = true
                    end
                end
            else
                -- author가 없으면 삭제 허용 (버그로 인한 경우)
                canDelete = true
            end

            if canDelete then
                event.deleted = true
                event.deletedAt = time()
                event.deletedBy = addon:GetPlayerFullName()
                addon:BroadcastEvent("DELETE", event)
                addon:Print("공유 일정이 삭제되었습니다.")
                deleted = true
            else
                addon:Print("이 일정을 삭제할 권한이 없습니다.")
            end
        end
    end

    if not deleted then
        addon:Print("삭제할 일정을 찾을 수 없습니다.")
    end

    addon:UpdateCalendar()
    addon:ShowDayEvents(currentYear, currentMonth, selectedDay)
end

-- 캘린더 열기/닫기
function addon:ToggleCalendar()
    if not addon.calendarFrame then
        addon.calendarFrame = CreateCalendarFrame()
    end

    if addon.calendarFrame:IsShown() then
        addon.calendarFrame:Hide()  -- 닫기는 항상 가능
    else
        -- 열기만 전투 중 제한
        if InCombatLockdown() then
            addon:Print("전투 중에는 캘린더를 열 수 없습니다.")
            return
        end
        -- 처음 열 때만 오늘 날짜로 초기화
        if not currentYear or not currentMonth or not selectedDay then
            local today = addon:GetCurrentDate()
            currentYear = today.year
            currentMonth = today.month
            selectedDay = today.day
        end

        addon:UpdateCalendar()
        addon:ShowDayEvents(currentYear, currentMonth, selectedDay)
        addon.calendarFrame:Show()
    end
end