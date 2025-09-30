local addonName, addon = ...

-- 공통 UI 컴포넌트 모듈
FoxChat = FoxChat or {}
FoxChat.UI = FoxChat.UI or {}
FoxChat.UI.Components = {}

local Components = FoxChat.UI.Components
local L = addon.L

-- CreateTextArea: 스크롤 가능한 텍스트 입력 영역
function Components:CreateTextArea(parent, width, height, maxLetters)
    -- 배경 프레임
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    -- ScrollFrame 생성
    local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    -- EditBox 생성
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(scrollFrame:GetWidth() - 5)
    editBox:SetHeight(2000)  -- 충분히 큰 고정 높이
    editBox:SetMaxLetters(maxLetters or 0)
    editBox:SetTextInsets(5, 5, 5, 25)  -- 하단 여백

    -- 줄 간격 조정
    editBox:SetSpacing(0)

    -- ScrollChild로 설정
    scrollFrame:SetScrollChild(editBox)

    -- ESC 키로 포커스 해제
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- 커서 위치 변경 시 자동 스크롤
    editBox.isScrolling = false
    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if self.isScrolling then return end  -- 재귀 방지

        local scrollOffset = scrollFrame:GetVerticalScroll()
        local scrollHeight = scrollFrame:GetHeight()
        local cursorTop = -y
        local cursorBottom = -y + h

        -- 커서가 화면 밖으로 나가는 것을 방지
        local maxScroll = self:GetHeight() - scrollHeight
        if maxScroll < 0 then maxScroll = 0 end

        -- 스크롤 업데이트가 필요한 경우만 처리
        if cursorTop < scrollOffset then
            self.isScrolling = true
            scrollFrame:SetVerticalScroll(math.max(0, cursorTop - 5))
            C_Timer.After(0.01, function() self.isScrolling = false end)
        elseif cursorBottom > (scrollOffset + scrollHeight - 40) then
            self.isScrolling = true
            local newScroll = cursorBottom - scrollHeight + 40
            scrollFrame:SetVerticalScroll(math.min(maxScroll, math.max(0, newScroll)))
            C_Timer.After(0.01, function() self.isScrolling = false end)
        end
    end)

    -- 배경 클릭 시 EditBox로 포커스
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            editBox:SetFocus()
        end
    end)

    -- 마우스 휠 스크롤
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollStep = 20

        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - scrollStep))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + scrollStep))
        end
    end)

    -- EditBox 크기 조정
    C_Timer.After(0.1, function()
        local w = scrollFrame:GetWidth()
        if w and w > 0 then
            editBox:SetWidth(w - 5)
        end
    end)

    bg.editBox = editBox
    bg.scrollFrame = scrollFrame

    return bg, editBox, scrollFrame
end

-- CreateSeparator: 구분선 생성
function Components:CreateSeparator(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    return line
end

-- CreateButton: 기본 버튼 생성
function Components:CreateButton(parent, text, width, height)
    width = width or 100
    height = height or 25

    local button = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")

    return button
end

-- CreateCheckbox: 체크박스 생성
function Components:CreateCheckbox(parent, label)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)

    if label then
        checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        checkbox.text:SetText(label)
    end

    return checkbox
end

-- CreateSlider: 슬라이더 생성
function Components:CreateSlider(parent, label, min, max, step)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(200)
    slider:SetHeight(16)
    slider:SetMinMaxValues(min or 0, max or 100)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)

    -- 라벨 설정
    if label then
        slider.Text:SetText(label)
    end

    -- 값 표시
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider:SetScript("OnValueChanged", function(self, value)
        self.valueText:SetText(string.format("%.1f", value))
    end)

    return slider
end

-- CreateEditBox: 단일행 입력 박스 생성
function Components:CreateEditBox(parent, width, height)
    width = width or 200
    height = height or 25

    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(width, height)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)

    local editBox = CreateFrame("EditBox", nil, bg)
    editBox:SetPoint("TOPLEFT", 5, -5)
    editBox:SetPoint("BOTTOMRIGHT", -5, 5)
    editBox:SetMultiLine(false)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextInsets(3, 3, 3, 3)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    bg.editBox = editBox
    return bg, editBox
end

-- CreateDropdown: 드롭다운 메뉴 생성
function Components:CreateDropdown(parent, label, width, items, callback)
    width = width or 150

    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)

    -- 라벨
    if label then
        dropdown.label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dropdown.label:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 2)
        dropdown.label:SetText(label)
    end

    -- 초기화 함수
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text or item
            info.value = item.value or item
            info.func = function(self)
                UIDropDownMenu_SetText(dropdown, self.value)
                if callback then
                    callback(self.value)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return dropdown
end

-- CreateColorPicker: 색상 선택 버튼 생성
function Components:CreateColorPicker(parent, r, g, b, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)

    -- 색상 표시
    button.texture = button:CreateTexture(nil, "BACKGROUND")
    button.texture:SetAllPoints()
    button.texture:SetColorTexture(r or 1, g or 1, b or 1, 1)

    -- 테두리
    button.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.border:SetPoint("TOPLEFT", -2, 2)
    button.border:SetPoint("BOTTOMRIGHT", 2, -2)
    button.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    button.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- 클릭 이벤트
    button:SetScript("OnClick", function(self)
        local r, g, b = self.texture:GetVertexColor()

        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.texture:SetColorTexture(r, g, b, 1)
            if callback then
                callback(r, g, b)
            end
        end

        ColorPickerFrame.cancelFunc = function()
            self.texture:SetColorTexture(r, g, b, 1)
        end

        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end)

    return button
end

-- CreateLabel: 라벨 텍스트 생성
function Components:CreateLabel(parent, text, fontSize)
    fontSize = fontSize or "GameFontNormal"

    local label = parent:CreateFontString(nil, "OVERLAY", fontSize)
    label:SetText(text or "")

    return label
end

-- CreateRadioButton: 라디오 버튼 생성
function Components:CreateRadioButton(parent, text)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20, 20)
    button:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
    button:SetPushedTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetPushedTexture():SetTexCoord(0.5, 0.75, 0, 1)
    button:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetHighlightTexture():SetTexCoord(0, 0.25, 0, 1)
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)

    if text then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", button, "RIGHT", 3, 0)
        label:SetText(text)
        button.text = label
    end

    return button
end

-- CreateBackground: 배경 프레임 생성 (EditBox 등을 위한)
function Components:CreateBackground(parent)
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)
    bg:SetBackdropBorderColor(0.4, 0.4, 0.4)

    return bg
end

-- CreatePanel: 패널 프레임 생성
function Components:CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    panel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

    return panel
end

-- CreateScrollFrame: 스크롤 프레임 생성
function Components:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 30, height)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end