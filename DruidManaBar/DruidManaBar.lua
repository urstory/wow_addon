local addonName, addon = ...
local L = addon.L

-- 기본 설정값
local defaults = {
    enabled = true,
    barX = 0,
    barY = -200,
    barWidth = 200,
    barHeight = 20,
    showHealthBar = true,
    healthBarHeight = 15,
    flashHealthThreshold = 0.3,
    -- 표시 옵션
    visibilityMode = "forms", -- "always", "forms", "combat"
    showInBearForm = true,
    showInCatForm = true,
    showInAquaticForm = true,
    showInTravelForm = true,
    showInMoonkinForm = true,
    healthDisplayMode = "number", -- "number", "percent", "both"
    manaDisplayMode = "number", -- "number", "percent", "both"
    -- 변신 마나 비용 (레벨별로 업데이트됨)
    bearFormCost = 593,
    direBearFormCost = 593,
    catFormCost = 593,
    aquaticFormCost = 50,
    travelFormCost = 50,
    moonkinFormCost = 50,
    -- 바 색상
    manaBarColor = {r = 0, g = 0.5, b = 1},
    manaBarEmptyColor = {r = 0.3, g = 0.3, b = 0.3},
    healthBarColor = {r = 0.8, g = 0.1, b = 0.1},
    bearLineColor = {r = 1, g = 1, b = 0},
    catLineColor = {r = 0, g = 0.5, b = 1},
    -- 버프 모니터링
    showBuffMonitor = true,
    -- 타겟 디버프 표시
    showTargetDebuffs = true,
}

-- 변신 스펠 ID (정확한 ID 사용)
local SPELL_BEAR_FORM = 5487  -- 곰 변신 (또는 5488)
local SPELL_BEAR_FORM_2 = 5488  -- 곰 변신 다른 랭크
local SPELL_DIRE_BEAR_FORM = 9634  -- 광포한 곰 변신
local SPELL_CAT_FORM = 768  -- 표범 변신
local SPELL_AQUATIC_FORM = 1066  -- 바다표범 변신
local SPELL_TRAVEL_FORM = 783  -- 치타 변신 (Travel Form)
local SPELL_MOONKIN_FORM = 24858  -- Moonkin Form

-- 버프 스펠 ID
local SPELL_GIFT_OF_THE_WILD = 21849  -- 야생의 선물
local SPELL_MARK_OF_THE_WILD = 9884   -- 야생의 징표 (모든 랭크의 기본 ID)
local SPELL_OMEN_OF_CLARITY = 16864   -- 천명의 전조
local SPELL_THORNS = 9910              -- 가시 (모든 랭크의 기본 ID)

-- 버프 아이콘 텍스처
local BUFF_TEXTURES = {
    MARK_OF_THE_WILD = "Interface\\Icons\\Spell_Nature_Regeneration",
    OMEN_OF_CLARITY = "Interface\\Icons\\Spell_Nature_CrystalBall",
    THORNS = "Interface\\Icons\\Spell_Nature_Thorns",
}

-- 변신 스펠 ID 배열
local BEAR_FORM_SPELLS = {5487, 5488}  -- 곰 변신 (모든 랭크)
local DIRE_BEAR_FORM_SPELLS = {9634}  -- 광포한 곰 변신
local CAT_FORM_SPELLS = {768}  -- 표범 변신

-- 변신 폼 인덱스 (Classic)
local FORM_INDICES = {
    BEAR = 1,
    AQUATIC = 2,
    CAT = 3,
    TRAVEL = 4,
    MOONKIN = 5,
}

-- 변신 폼 아이콘 텍스처 (DruidBar Classic 참고)
local FORM_TEXTURES = {
    BEAR = "Interface\\Icons\\Ability_Racial_BearForm",
    DIRE_BEAR = "Interface\\Icons\\Ability_Racial_BearForm",
    CAT = "Interface\\Icons\\Ability_Druid_CatForm",
    AQUATIC = "Interface\\Icons\\Ability_Druid_AquaticForm",
    TRAVEL = "Interface\\Icons\\Ability_Druid_TravelForm",
    MOONKIN = "Interface\\Icons\\Spell_Nature_ForceOfNature",
}

-- 변신 마나 비용 테이블 (레벨별)
local shapeshiftCosts = {
    [SPELL_BEAR_FORM] = {
        [1] = 50,  -- Rank 1
    },
    [SPELL_DIRE_BEAR_FORM] = {
        [1] = 50,  -- Rank 1
    },
    [SPELL_CAT_FORM] = {
        [1] = 100, -- Rank 1
    },
    [SPELL_AQUATIC_FORM] = {
        [1] = 50, -- Rank 1
    },
    [SPELL_TRAVEL_FORM] = {
        [1] = 50, -- Rank 1
    },
    [SPELL_MOONKIN_FORM] = {
        [1] = 50, -- Rank 1
    },
}

local mainFrame = nil
local manaBar = nil
local healthBar = nil
local bearLine = nil
local catLine = nil
local buffIcons = {}  -- 버프 아이콘 프레임들
local targetDebuffIcons = {}  -- 타겟 디버프 아이콘들
local comboPoints = {}  -- 콤보 포인트(버블) 표시
local isFlashing = false
local lastMana = 0
local manaRegenRate = 0
local lastManaUpdate = 0
local fiveSRStartTime = 0
local inFiveSR = false

-- Forward declaration
local UpdateBars

-- 툴팁 프레임 생성 (재사용)
local scanTooltip = CreateFrame("GameTooltip", "DruidManaBarScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- 아이콘 텍스처로 폼 식별 (DruidBar Classic 방식)
local function GetFormByTexture(texture)
    if not texture then return nil end
    
    if string.find(texture, "BearForm") then
        return "bear"
    elseif string.find(texture, "CatForm") then
        return "cat"
    elseif string.find(texture, "AquaticForm") then
        return "aquatic"
    elseif string.find(texture, "TravelForm") then
        return "travel"
    elseif string.find(texture, "ForceOfNature") then
        return "moonkin"
    end
    return nil
end

-- 변신 바에서 마나 비용 가져오기 (향상된 패턴 매칭)
local function GetManaCostFromShapeshiftBar(spellId)
    -- print(string.format("GetManaCostFromShapeshiftBar 호출 - 스펠ID: %d", spellId))
    local numForms = GetNumShapeshiftForms()
    for i = 1, numForms do
        local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
        
        -- 변신 바 툴팁 확인
        scanTooltip:ClearLines()
        scanTooltip:SetShapeshift(i)
        
        -- 첫 번째 줄에서 스펠 이름 확인
        local name = DruidManaBarScanTooltipTextLeft1 and DruidManaBarScanTooltipTextLeft1:GetText()
        
        -- 모든 슬롯 디버그 출력
        -- print(string.format("  슬롯 %d: 이름=%s, 텍스처=%s", i, name or "nil", texture or "nil"))
        local isMatch = false
        
        -- 텍스처로 폼 타입 확인
        local formType = GetFormByTexture(texture)
        
        -- 디버그: 스펠 이름 출력
        if spellId == SPELL_CAT_FORM then
            -- print(string.format("슬롯 %d 스펠 이름: %s, 텍스처: %s, 폼타입: %s (표범 변신 체크 중)", 
            --     i, name or "nil", texture or "nil", formType or "nil"))
        end
        
        -- 스펠 ID별로 매칭 (텍스처 타입도 함께 확인)
        if spellId == SPELL_DIRE_BEAR_FORM and name and (string.find(name, "Dire Bear") or string.find(name, "광포한 곰")) then
            isMatch = true
        elseif (spellId == SPELL_BEAR_FORM or spellId == SPELL_BEAR_FORM_2) and name and (string.find(name, "Bear Form") or string.find(name, "곰 변신")) and not (string.find(name, "Dire") or string.find(name, "광포한")) then
            isMatch = true
        elseif spellId == SPELL_CAT_FORM and name then
            -- 표범 변신: 정확한 이름 매칭
            if name == "표범 변신" or name == "Cat Form" then
                isMatch = true
                -- print(string.format("  -> 표범 변신 매칭됨! (슬롯 %d, 이름: %s)", i, name))
            end
        elseif spellId == SPELL_AQUATIC_FORM and formType == "aquatic" then
            isMatch = true
        elseif spellId == SPELL_TRAVEL_FORM and formType == "travel" then
            isMatch = true
        end
        
        if isMatch then
            -- 표범 변신인 경우 특별 처리
            local isCatForm = (spellId == SPELL_CAT_FORM)
            
            -- 모든 가능한 마나 패턴들
            local patterns = {
                -- 영어 패턴
                "(%d+) Mana",
                "^(%d+) Mana",
                "Mana: (%d+)",
                "(%d+) mana",
                "Cost: (%d+) Mana",
                "Costs (%d+) Mana",
                "Mana (%d+)",
                "(%d+)Mana",
                "(%d+)%s*Mana",
                "Requires (%d+) Mana",
                "Uses (%d+) Mana",
                "%[Mana (%d+)%]",  -- [Mana 593] 형식
                
                -- 한국어 패턴
                "(%d+) 마나",
                "^(%d+) 마나",
                "마나: (%d+)",
                "비용: (%d+) 마나",
                "마나 (%d+)",
                "(%d+)마나",
                "(%d+)%s*마나",
                "(%d+) 의 마나",
                "(%d+)의 마나",
                "소모: (%d+) 마나",
                "소비: (%d+) 마나",
                "필요: (%d+) 마나",
                "사용: (%d+) 마나",
                "%[마나 (%d+)%]",  -- [마나 593] 형식
                "마나 (%d+)%]",     -- 마나 593] 형식 (대괄호 일부)
                "%[마나 (%d+)",     -- [마나 593 형식 (대괄호 일부)
                
                -- 특수 케이스
                "^(%d+)$",  -- 숫자만 있는 경우 (j > 1일 때만)
                "^%s*(%d+)%s*$"  -- 공백 포함 숫자만
            }
            
            -- 마나 비용 찾기
            local foundValues = {}
            
            for j = 1, scanTooltip:NumLines() do
                local textLeft = _G["DruidManaBarScanTooltipTextLeft"..j]
                local textRight = _G["DruidManaBarScanTooltipTextRight"..j]
                
                if textLeft then
                    local text = textLeft:GetText()
                    if text then
                        -- 모든 패턴 시도
                        for _, pattern in ipairs(patterns) do
                            local mana = string.match(text, pattern)
                            if mana then
                                local manaValue = tonumber(mana)
                                -- 합리적인 마나 값인지 확인
                                if manaValue and manaValue >= 10 and manaValue < 10000 then
                                    -- 특수 케이스: 숫자만 있는 패턴은 첫 번째 줄이 아닐 때만
                                    if pattern == "^(%d+)$" or pattern == "^%s*(%d+)%s*$" then
                                        if j > 1 then
                                            table.insert(foundValues, manaValue)
                                        end
                                    else
                                        table.insert(foundValues, manaValue)
                                    end
                                end
                            end
                        end
                    end
                end
                
                if textRight then
                    local text = textRight:GetText()
                    if text then
                        -- 오른쪽 텍스트에서도 패턴 확인
                        for _, pattern in ipairs(patterns) do
                            local mana = string.match(text, pattern)
                            if mana then
                                local manaValue = tonumber(mana)
                                -- 합리적인 마나 값인지 확인
                                if manaValue and manaValue >= 10 and manaValue < 10000 then
                                    table.insert(foundValues, manaValue)
                                end
                            end
                        end
                    end
                end
            end
            
            -- 찾은 값들 중에서 선택
            if #foundValues > 0 then
                -- 디버그 출력
                if isCatForm then
                    -- print("표범 변신 마나 값 감지:", table.concat(foundValues, ", "))
                end
                
                -- 가장 큰 값 반환 (모든 변신 폼에 동일하게 적용)
                table.sort(foundValues, function(a, b) return a > b end)
                if isCatForm then
                    -- print("표범 변신 마나 선택 (최대값):", foundValues[1])
                end
                -- print(string.format("  -> 스펠ID %d 마나 비용 반환: %d", spellId, foundValues[1]))
                return foundValues[1]
            end
            
            -- 최후의 수단: 큰 숫자 찾기 (400-9999 범위)
            -- 표범의 경우 215는 다른 값일 가능성이 있으므로 제외
            for j = 2, scanTooltip:NumLines() do  -- 첫 줄(스킬명) 제외
                local textLeft = _G["DruidManaBarScanTooltipTextLeft"..j]
                if textLeft then
                    local text = textLeft:GetText()
                    if text then
                        -- 400-9999 범위의 숫자 찾기 (215같은 낮은 값 제외)
                        for num in string.gmatch(text, "%d+") do
                            local value = tonumber(num)
                            if value and value >= 400 and value < 10000 then
                                -- 593 같은 특정 값 우선
                                if value == 593 or value == 592 or value == 594 or value == 595 then
                                    return value
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- 스펠 ID로 마나 비용 가져오기
local function GetManaCostBySpellID(spellId)
    -- 먼저 변신 바에서 시도
    local cost = GetManaCostFromShapeshiftBar(spellId)
    if cost then
        return cost
    end
    
    -- 스펠북에서 해당 ID 찾기
    for i = 1, MAX_SKILLLINE_TABS do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        if numSpells then
            for j = 1, numSpells do
                local spellIndex = offset + j
                local bookSpellName = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL)
                
                -- 이름으로도 매칭 시도
                local isMatch = false
                if spellId == SPELL_DIRE_BEAR_FORM and bookSpellName and (string.find(bookSpellName, "Dire Bear") or string.find(bookSpellName, "광포한 곰")) then
                    isMatch = true
                elseif spellId == SPELL_CAT_FORM and bookSpellName and (string.find(bookSpellName, "Cat Form") or string.find(bookSpellName, "표범")) then
                    isMatch = true
                end
                
                if isMatch then
                    -- 툴팁에서 마나 비용 추출
                    scanTooltip:ClearLines()
                    scanTooltip:SetSpellBookItem(spellIndex, BOOKTYPE_SPELL)
                    
                    for k = 1, scanTooltip:NumLines() do
                        local textLeft = _G["DruidManaBarScanTooltipTextLeft"..k]
                        local textRight = _G["DruidManaBarScanTooltipTextRight"..k]
                        
                        if textLeft then
                            local text = textLeft:GetText()
                            if text then
                                -- 동일한 패턴 세트 사용
                                local patterns = {
                                    "(%d+) Mana", "^(%d+) Mana", "Mana: (%d+)",
                                    "(%d+) mana", "Cost: (%d+) Mana", "Costs (%d+) Mana",
                                    "%[Mana (%d+)%]",
                                    "(%d+) 마나", "^(%d+) 마나", "마나: (%d+)",
                                    "비용: (%d+) 마나", "(%d+)마나", "(%d+)%s*마나",
                                    "소모: (%d+) 마나", "소비: (%d+) 마나",
                                    "%[마나 (%d+)%]", "마나 (%d+)%]", "%[마나 (%d+)"
                                }
                                for _, pattern in ipairs(patterns) do
                                    local mana = string.match(text, pattern)
                                    if mana then
                                        local manaValue = tonumber(mana)
                                        if manaValue and manaValue >= 10 and manaValue < 10000 then
                                            return manaValue
                                        end
                                    end
                                end
                            end
                        end
                        
                        if textRight then
                            local text = textRight:GetText()
                            if text then
                                local mana = string.match(text, "(%d+) Mana") or 
                                           string.match(text, "(%d+) 마나") or
                                           string.match(text, "^(%d+)$")  -- 숫자만
                                if mana then
                                    local manaValue = tonumber(mana)
                                    if manaValue and manaValue >= 10 and manaValue < 10000 then
                                        return manaValue
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Metamorphosis 룬 체크 (무료 변신)
local function HasMetamorphosisRune()
    -- Season of Discovery 룬 체크
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name and (string.find(name, "Metamorphosis") or spellId == 410061) then
            return true
        end
    end
    
    -- 룬 장비 체크 (장갑 슬롯)
    local gloves = GetInventoryItemLink("player", 10)
    if gloves and string.find(gloves, "Metamorphosis") then
        return true
    end
    
    return false
end

-- 스펠이 배워졌는지 확인
local function IsSpellKnownByName(spellName)
    for i = 1, MAX_SKILLLINE_TABS do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        if numSpells then
            for j = 1, numSpells do
                local spellIndex = offset + j
                local bookSpellName = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL)
                if bookSpellName and (
                    string.find(bookSpellName, spellName) or
                    bookSpellName == spellName
                ) then
                    return true
                end
            end
        end
    end
    return false
end

-- 버프 체크 함수
local function CheckBuffs()
    local missingBuffs = {}
    
    -- 야생의 선물/징표 체크
    local hasMarkOfTheWild = false
    local hasGiftOfTheWild = false
    
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name then
            if string.find(name, "Mark of the Wild") or string.find(name, "야생의 징표") then
                hasMarkOfTheWild = true
            elseif string.find(name, "Gift of the Wild") or string.find(name, "야생의 선물") then
                hasGiftOfTheWild = true
            end
        end
    end
    
    -- 야생의 선물 또는 야생의 징표 스킬을 배웠는지 확인
    local knowsMarkOfTheWild = IsSpellKnownByName("Mark of the Wild") or IsSpellKnownByName("야생의 징표")
    local knowsGiftOfTheWild = IsSpellKnownByName("Gift of the Wild") or IsSpellKnownByName("야생의 선물")
    
    -- 둘 중 하나라도 배웠는데 둘 다 없으면 야생의 징표 아이콘 표시
    if (knowsMarkOfTheWild or knowsGiftOfTheWild) and not hasMarkOfTheWild and not hasGiftOfTheWild then
        table.insert(missingBuffs, "MARK_OF_THE_WILD")
    end
    
    -- 천명의 전조 체크 (Omen of Clarity) - 단순화된 체크
    -- 먼저 스킬을 배웠는지 확인
    local knowsOmenOfClarity = false
    for i = 1, MAX_SKILLLINE_TABS do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        if numSpells then
            for j = 1, numSpells do
                local spellIndex = offset + j
                local bookSpellName = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL)
                -- 천명의 전조를 찾기 위해 부분 매칭 사용
                if bookSpellName then
                    local lowerName = string.lower(bookSpellName)
                    if string.find(lowerName, "omen") or string.find(lowerName, "clarity") or
                       string.find(bookSpellName, "천명") or string.find(bookSpellName, "전조") then
                        knowsOmenOfClarity = true
                        break
                    end
                end
            end
        end
        if knowsOmenOfClarity then break end
    end

    -- 스킬을 배웠다면 버프 체크
    if knowsOmenOfClarity then
        local hasOmenOfClarity = false
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if name then
                local lowerName = string.lower(name)
                -- 천명의 전조 버프 확인 (다양한 패턴 매칭)
                if string.find(lowerName, "omen") or string.find(lowerName, "clarity") or
                   string.find(name, "천명") or string.find(name, "전조") then
                    hasOmenOfClarity = true
                    break
                end
            end
        end
        if not hasOmenOfClarity then
            table.insert(missingBuffs, "OMEN_OF_CLARITY")
        end
    end
    
    -- 가시 체크
    if IsSpellKnownByName("Thorns") or IsSpellKnownByName("가시") then
        local hasThorns = false
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if name and (string.find(name, "Thorns") or string.find(name, "가시")) then
                hasThorns = true
                break
            end
        end
        if not hasThorns then
            table.insert(missingBuffs, "THORNS")
        end
    end
    
    return missingBuffs
end

-- 변신 스펠의 현재 마나 비용 가져오기 (수동 값 우선)
local function GetShapeshiftManaCost(formType)
    -- Metamorphosis 룬이 있으면 변신 비용 0
    if HasMetamorphosisRune() then
        return 0
    end
    
    -- 먼저 수동으로 설정된 값 확인 (우선순위 최상)
    local manualCost = 0
    if formType == "bear" then
        manualCost = DruidManaBarDB.bearFormCost or 0
    elseif formType == "direbear" then
        manualCost = DruidManaBarDB.direBearFormCost or 0
    elseif formType == "cat" then
        manualCost = DruidManaBarDB.catFormCost or 0
    end
    
    -- 수동 값이 있으면 그것을 사용
    if manualCost > 0 then
        return manualCost
    end
    
    -- 수동 값이 없으면 정확한 스펠 ID로 자동 감지
    local spellId = nil
    if formType == "bear" then
        -- 곰 변신은 5487 또는 5488일 수 있음
        local cost1 = GetManaCostBySpellID(SPELL_BEAR_FORM)
        local cost2 = GetManaCostBySpellID(SPELL_BEAR_FORM_2)
        if cost1 and cost1 > 0 then
            return cost1
        elseif cost2 and cost2 > 0 then
            return cost2
        end
    elseif formType == "direbear" then
        spellId = SPELL_DIRE_BEAR_FORM  -- 9634
    elseif formType == "cat" then
        spellId = SPELL_CAT_FORM  -- 768
    end
    
    if spellId then
        local manaCost = GetManaCostBySpellID(spellId)
        if manaCost and manaCost > 0 then
            return manaCost
        end
    end
    
    -- 자동 감지 실패하면 기본값 사용
    if formType == "bear" or formType == "direbear" then
        return defaults.bearFormCost
    elseif formType == "cat" then
        return defaults.catFormCost
    end
    
    return 0
end

-- 바 생성
local function CreateBars()
    if mainFrame then return end
    
    -- 메인 프레임
    mainFrame = CreateFrame("Frame", "DruidManaBarFrame", UIParent)
    local healthBarHeight = (DruidManaBarDB.showHealthBar ~= false) and (DruidManaBarDB.healthBarHeight or defaults.healthBarHeight) or 0
    local spacing = (DruidManaBarDB.showHealthBar ~= false) and 2 or 0
    mainFrame:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                      (DruidManaBarDB.barHeight or defaults.barHeight) + healthBarHeight + spacing)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 
                      DruidManaBarDB.barX or defaults.barX, 
                      DruidManaBarDB.barY or defaults.barY)
    
    -- 이동 가능 설정
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(false)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        DruidManaBarDB.barX = x
        DruidManaBarDB.barY = y
    end)
    
    -- 체력 바
    healthBar = CreateFrame("StatusBar", nil, mainFrame)
    healthBar:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                      DruidManaBarDB.healthBarHeight or defaults.healthBarHeight)
    healthBar:SetPoint("TOP", mainFrame, "TOP", 0, 0)
    healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local color = DruidManaBarDB.healthBarColor or defaults.healthBarColor
    healthBar:SetStatusBarColor(color.r, color.g, color.b)
    -- 초기값은 실제 값으로 설정
    local maxHealth = UnitHealthMax("player")
    healthBar:SetMinMaxValues(0, maxHealth > 0 and maxHealth or 100)
    
    -- 체력 바 배경
    healthBar.bg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBar.bg:SetAllPoints()
    healthBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    healthBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)
    
    -- 체력 바 테두리
    healthBar.border = CreateFrame("Frame", nil, healthBar, "BackdropTemplate")
    healthBar.border:SetPoint("TOPLEFT", -1, 1)
    healthBar.border:SetPoint("BOTTOMRIGHT", 1, -1)
    healthBar.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    healthBar.border:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- 마나 바
    manaBar = CreateFrame("StatusBar", nil, mainFrame)
    manaBar:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                    DruidManaBarDB.barHeight or defaults.barHeight)
    manaBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -2)
    manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- 초기값은 실제 값으로 설정
    local maxMana = UnitPowerMax("player", 0)  -- 0 = Mana
    manaBar:SetMinMaxValues(0, maxMana > 0 and maxMana or 100)
    
    -- 마나 바 배경
    manaBar.bg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBar.bg:SetAllPoints()
    manaBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    manaBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)
    
    -- 마나 바 테두리
    manaBar.border = CreateFrame("Frame", nil, manaBar, "BackdropTemplate")
    manaBar.border:SetPoint("TOPLEFT", -1, 1)
    manaBar.border:SetPoint("BOTTOMRIGHT", 1, -1)
    manaBar.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    manaBar.border:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- 곰 변신 마나 선
    bearLine = manaBar:CreateTexture(nil, "OVERLAY")
    bearLine:SetSize(2, DruidManaBarDB.barHeight or defaults.barHeight)
    bearLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local bearColor = DruidManaBarDB.bearLineColor or defaults.bearLineColor
    bearLine:SetVertexColor(bearColor.r, bearColor.g, bearColor.b)
    
    -- 표범 변신 마나 선
    catLine = manaBar:CreateTexture(nil, "OVERLAY")
    catLine:SetSize(2, DruidManaBarDB.barHeight or defaults.barHeight)
    catLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    local catColor = DruidManaBarDB.catLineColor or defaults.catLineColor
    catLine:SetVertexColor(catColor.r, catColor.g, catColor.b)
    
    -- 마나 텍스트
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manaBar.text:SetPoint("CENTER", manaBar, "CENTER", 0, 0)
    
    -- 마나 회복 텍스트 (마우스 오버시 표시)
    manaBar.regenText = manaBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manaBar.regenText:SetPoint("TOP", manaBar, "BOTTOM", 0, -2)
    manaBar.regenText:Hide()
    
    -- 체력 텍스트
    healthBar.text = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthBar.text:SetPoint("CENTER", healthBar, "CENTER", 0, 0)

    -- 초기 체력바 표시 설정
    if DruidManaBarDB.showHealthBar == false then
        healthBar:Hide()
    end

    -- 마우스 오버 이벤트 (추가 정보 표시) - manaBar가 생성된 후에 설정
    manaBar:SetScript("OnEnter", function()
        UpdateBars()
    end)
    manaBar:SetScript("OnLeave", function()
        if manaBar.regenText then
            manaBar.regenText:Hide()
        end
    end)
    
    -- 버프 아이콘 생성 (마나 바 아래에 3개)
    local iconSize = 24
    local iconSpacing = 2
    
    -- 야생의 징표 아이콘
    local markIcon = CreateFrame("Frame", nil, mainFrame)
    markIcon:SetSize(iconSize, iconSize)
    markIcon:SetPoint("TOP", manaBar, "BOTTOM", -(iconSize + iconSpacing), -5)
    markIcon.texture = markIcon:CreateTexture(nil, "ARTWORK")
    markIcon.texture:SetAllPoints()
    markIcon.texture:SetTexture(BUFF_TEXTURES.MARK_OF_THE_WILD)
    markIcon:Hide()
    buffIcons["MARK_OF_THE_WILD"] = markIcon
    
    -- 천명의 전조 아이콘
    local omenIcon = CreateFrame("Frame", nil, mainFrame)
    omenIcon:SetSize(iconSize, iconSize)
    omenIcon:SetPoint("TOP", manaBar, "BOTTOM", 0, -5)
    omenIcon.texture = omenIcon:CreateTexture(nil, "ARTWORK")
    omenIcon.texture:SetAllPoints()
    omenIcon.texture:SetTexture(BUFF_TEXTURES.OMEN_OF_CLARITY)
    omenIcon:Hide()
    buffIcons["OMEN_OF_CLARITY"] = omenIcon
    
    -- 가시 아이콘
    local thornsIcon = CreateFrame("Frame", nil, mainFrame)
    thornsIcon:SetSize(iconSize, iconSize)
    thornsIcon:SetPoint("TOP", manaBar, "BOTTOM", (iconSize + iconSpacing), -5)
    thornsIcon.texture = thornsIcon:CreateTexture(nil, "ARTWORK")
    thornsIcon.texture:SetAllPoints()
    thornsIcon.texture:SetTexture(BUFF_TEXTURES.THORNS)
    thornsIcon:Hide()
    buffIcons["THORNS"] = thornsIcon
    
    -- 아이콘 초기화
    for buffName, icon in pairs(buffIcons) do
        icon:SetAlpha(1)
    end
end

-- 버프 아이콘 업데이트
local function UpdateBuffIcons()
    if not DruidManaBarDB.showBuffMonitor then
        -- 버프 모니터링이 꺼져있으면 모든 아이콘 숨기기
        for _, icon in pairs(buffIcons) do
            icon:Hide()
            icon.isFlashing = false
        end
        return
    end
    
    local missingBuffs = CheckBuffs()
    
    -- 모든 아이콘 초기화
    for buffName, icon in pairs(buffIcons) do
        icon:Hide()
        icon:SetAlpha(1)
    end

    -- 누락된 버프 아이콘 표시 (깜빡임 없이)
    for _, buffName in ipairs(missingBuffs) do
        if buffIcons[buffName] then
            buffIcons[buffName]:Show()
            buffIcons[buffName]:SetAlpha(1)
        end
    end
end

-- 콤보 포인트(버블) 업데이트
local function UpdateComboPoints()
    if not DruidManaBarDB.showTargetDebuffs then
        for _, point in pairs(comboPoints) do
            point:Hide()
        end
        return
    end

    -- 표범 폼이 아니거나 타겟이 없으면 숨기기
    if GetShapeshiftForm() ~= FORM_INDICES.CAT or not UnitExists("target") then
        for _, point in pairs(comboPoints) do
            point:Hide()
        end
        return
    end

    -- 현재 콤보 포인트 가져오기
    local cp = GetComboPoints("player", "target") or 0

    -- 콤보 포인트가 0이면 모두 숨기기
    if cp == 0 then
        for _, point in pairs(comboPoints) do
            point:Hide()
        end
        return
    end

    -- 콤보 포인트 표시
    local pointSize = 32  -- 크기를 16에서 32로 2배 증가
    local pointSpacing = 8  -- 간격도 비례하여 증가
    local totalWidth = 5 * pointSize + 4 * pointSpacing
    local xOffset = -totalWidth / 2 + pointSize / 2

    for i = 1, 5 do
        if not comboPoints[i] then
            -- 콤보 포인트 생성
            local point = CreateFrame("Frame", nil, mainFrame)
            point:SetSize(pointSize, pointSize)

            -- 붉은 원 텍스처
            point.texture = point:CreateTexture(nil, "ARTWORK")
            point.texture:SetAllPoints()
            -- 레이드 타겟 아이콘 사용 (원형)
            point.texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Seal")
            point.texture:SetVertexColor(1, 0, 0, 1)  -- 붉은색

            -- 나중에 호환성을 위해 유지
            point.active = point.texture
            point.bg = point:CreateTexture(nil, "BACKGROUND")
            point.bg:Hide()

            comboPoints[i] = point
        end

        local point = comboPoints[i]
        point:SetPoint("BOTTOM", healthBar, "TOP", xOffset + (i-1) * (pointSize + pointSpacing), 5)

        if i <= cp then
            point.active:Show()
            point.bg:Hide()  -- 배경 숨기기
            point:Show()
        else
            point:Hide()  -- 비활성 포인트는 완전히 숨기기
        end
    end
end

-- 타겟 디버프 업데이트 (비활성화 - 콤보 포인트만 표시)
local function UpdateTargetDebuffs()
    -- 모든 디버프 아이콘 숨기기
    for _, icon in pairs(targetDebuffIcons) do
        icon:Hide()
    end
end

-- 체력 바 깜빡임
local function StartHealthFlash()
    if isFlashing then return end
    isFlashing = true

    local elapsed = 0
    healthBar:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local alpha = (math.sin(elapsed * 10) + 1) / 2
        self:SetAlpha(0.3 + alpha * 0.7)
    end)
end

local function StopHealthFlash()
    if not isFlashing then return end
    isFlashing = false
    
    healthBar:SetScript("OnUpdate", nil)
    healthBar:SetAlpha(1)
end

-- 마나 회복률 계산 (DruidBar Classic 방식)
local function CalculateManaRegen()
    -- 기본 회복: 지능/5 + 15
    local intellect = UnitStat("player", 4)  -- 4 = Intellect
    local baseRegen = (intellect / 5) + 15
    
    -- Innervate 버프 확인 (400% 회복)
    local hasInnervate = false
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name and (name == "Innervate" or string.find(name, "Innervate")) then
            hasInnervate = true
            break
        end
    end
    
    if hasInnervate then
        return baseRegen * 4
    end
    
    -- 5초 규칙 체크 (전투 중 마나 회복 30%)
    if inFiveSR and (GetTime() - fiveSRStartTime) < 5 then
        return baseRegen * 0.3
    else
        return baseRegen
    end
end

-- 바 업데이트
UpdateBars = function()
    if not mainFrame or not DruidManaBarDB.enabled then return end
    
    local currentMana = UnitPower("player", 0) -- 0 = Mana
    local maxMana = UnitPowerMax("player", 0)
    local currentHealth = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    local currentTime = GetTime()
    
    -- 마나 회복률 업데이트
    if lastManaUpdate > 0 then
        local timeDiff = currentTime - lastManaUpdate
        if timeDiff > 0 then
            local manaDiff = currentMana - lastMana
            if manaDiff > 0 then
                -- 실제 회복률 계산
                manaRegenRate = manaDiff / timeDiff
            end
        end
    end
    
    lastMana = currentMana
    lastManaUpdate = currentTime
    
    -- 체력 바 업데이트
    if healthBar then
        if DruidManaBarDB.showHealthBar ~= false then
            healthBar:Show()
            -- 최대값 업데이트
            healthBar:SetMinMaxValues(0, maxHealth > 0 and maxHealth or 100)
            healthBar:SetValue(currentHealth)

            local healthPercent = 0
            if maxHealth > 0 then
                healthPercent = currentHealth / maxHealth
            end

            -- 체력 표시 모드에 따른 텍스트 설정
            local displayMode = DruidManaBarDB.healthDisplayMode or defaults.healthDisplayMode
            if displayMode == "percent" then
                healthBar.text:SetText(string.format("%.0f%%", healthPercent * 100))
            elseif displayMode == "both" then
                healthBar.text:SetText(string.format("%d / %d (%.0f%%)", currentHealth, maxHealth, healthPercent * 100))
            else -- number
                healthBar.text:SetText(string.format("%d / %d", currentHealth, maxHealth))
            end

            -- 체력이 낮으면 깜빡임
            if maxHealth > 0 and healthPercent <= (DruidManaBarDB.flashHealthThreshold or defaults.flashHealthThreshold) then
                StartHealthFlash()
            else
                StopHealthFlash()
            end
        else
            healthBar:Hide()
            StopHealthFlash()
        end
    end
    
    -- 마나 바 업데이트
    if manaBar then
        -- 최대값 업데이트
        manaBar:SetMinMaxValues(0, maxMana > 0 and maxMana or 100)
        manaBar:SetValue(currentMana)

        local manaPercent = 0
        if maxMana > 0 then
            manaPercent = currentMana / maxMana
        end
        
        -- 마나 표시 모드에 따른 텍스트 설정
        local manaDisplayMode = DruidManaBarDB.manaDisplayMode or defaults.manaDisplayMode
        if manaDisplayMode == "percent" then
            manaBar.text:SetText(string.format("%.0f%%", manaPercent * 100))
        elseif manaDisplayMode == "both" then
            manaBar.text:SetText(string.format("%d / %d (%.0f%%)", currentMana, maxMana, manaPercent * 100))
        else -- number
            manaBar.text:SetText(string.format("%d / %d", currentMana, maxMana))
        end
        
        -- 마우스 오버시 마나 회복 정보 표시
        if manaBar:IsMouseOver() then
            local regenPerSec = CalculateManaRegen() / 5  -- 5초당 회복을 초당으로
            local timeToFull = maxMana > currentMana and ((maxMana - currentMana) / regenPerSec) or 0
            if timeToFull > 0 then
                manaBar.regenText:SetText(string.format("Regen: %.1f/s | Full in: %.1fs", regenPerSec, timeToFull))
                manaBar.regenText:Show()
            else
                manaBar.regenText:Hide()
            end
        else
            manaBar.regenText:Hide()
        end
        
        -- 변신 마나 비용 가져오기
        local bearCost = GetShapeshiftManaCost("bear")
        local catCost = GetShapeshiftManaCost("cat")
        local direBearCost = GetShapeshiftManaCost("direbear")
        
        -- 광포한 곰이 있으면 그 비용을 곰 비용으로 사용
        if direBearCost > 0 then
            bearCost = direBearCost
        end
        
        -- 디버그: 실제 비용 확인
        -- print(string.format("Bear Cost: %d, Cat Cost: %d", bearCost or 0, catCost or 0))
        
        -- Metamorphosis 룬 체크
        local hasMetamorphosis = HasMetamorphosisRune()
        if hasMetamorphosis then
            bearCost = 0
            catCost = 0
        end
        
        -- 마나 바 색상 설정
        local formIndex = GetShapeshiftForm()
        local canShapeshift = false
        
        -- 현재 폼에 따라 다른 비용 체크
        if formIndex == 0 then
            -- 인간 폼: 둘 중 최소값으로 체크
            canShapeshift = currentMana >= math.min(bearCost, catCost)
        elseif formIndex == FORM_INDICES.BEAR then
            -- 곰 폼: 표범 변신 비용만 체크
            canShapeshift = currentMana >= catCost
        elseif formIndex == FORM_INDICES.CAT then
            -- 표범 폼: 곰 변신 비용만 체크
            canShapeshift = currentMana >= bearCost
        else
            -- 다른 폼: 곰/표범 중 최소값
            canShapeshift = currentMana >= math.min(bearCost, catCost)
        end
        
        if canShapeshift then
            local color = DruidManaBarDB.manaBarColor or defaults.manaBarColor
            manaBar:SetStatusBarColor(color.r, color.g, color.b)
        else
            local color = DruidManaBarDB.manaBarEmptyColor or defaults.manaBarEmptyColor
            manaBar:SetStatusBarColor(color.r, color.g, color.b)
        end
        
        -- 변신 마나 선 위치 업데이트 (Metamorphosis가 없을 때만)
        if bearCost > 0 and not hasMetamorphosis and maxMana > 0 then
            local bearPercent = bearCost / maxMana
            bearLine:ClearAllPoints()
            bearLine:SetPoint("CENTER", manaBar, "LEFT", 
                            (DruidManaBarDB.barWidth or defaults.barWidth) * bearPercent, 0)
            bearLine:Show()
        else
            bearLine:Hide()
        end
        
        if catCost > 0 and not hasMetamorphosis and maxMana > 0 then
            local catPercent = catCost / maxMana
            catLine:ClearAllPoints()
            catLine:SetPoint("CENTER", manaBar, "LEFT", 
                           (DruidManaBarDB.barWidth or defaults.barWidth) * catPercent, 0)
            catLine:Show()
        else
            catLine:Hide()
        end
    end
    
    -- 버프 아이콘 업데이트
    UpdateBuffIcons()

    -- 초기 콤보 포인트 업데이트
    UpdateComboPoints()
end

-- 현재 변신 폼이 표시 설정에 포함되는지 확인
local function ShouldShowInCurrentForm()
    local formIndex = GetShapeshiftForm()
    
    if formIndex == 0 then
        return false -- 변신하지 않은 상태
    elseif formIndex == FORM_INDICES.BEAR then
        return DruidManaBarDB.showInBearForm ~= false
    elseif formIndex == FORM_INDICES.CAT then
        return DruidManaBarDB.showInCatForm ~= false
    elseif formIndex == FORM_INDICES.AQUATIC then
        return DruidManaBarDB.showInAquaticForm ~= false
    elseif formIndex == FORM_INDICES.TRAVEL then
        return DruidManaBarDB.showInTravelForm ~= false
    elseif formIndex == FORM_INDICES.MOONKIN then
        return DruidManaBarDB.showInMoonkinForm ~= false
    end
    
    return true
end

-- 가시성 업데이트
local function UpdateVisibility()
    if not mainFrame then return end
    
    local _, class = UnitClass("player")
    if class ~= "DRUID" or not DruidManaBarDB.enabled then
        mainFrame:Hide()
        return
    end
    
    local visMode = DruidManaBarDB.visibilityMode or defaults.visibilityMode
    local inCombat = UnitAffectingCombat("player")
    local hasForm = GetShapeshiftForm() > 0
    local shouldShow = false
    
    if visMode == "always" then
        shouldShow = true
    elseif visMode == "combat" then
        shouldShow = inCombat
    elseif visMode == "forms" then
        shouldShow = hasForm and ShouldShowInCurrentForm()
    end
    
    if shouldShow then
        mainFrame:Show()
        UpdateBars()
    else
        mainFrame:Hide()
    end
end

-- 이벤트 프레임
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_AURA")  -- 버프 변경 감지
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")  -- 타겟 변경 감지
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")  -- 콤보 포인트 업데이트

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 설정 로드
        DruidManaBarDB = DruidManaBarDB or {}
        for k, v in pairs(defaults) do
            if DruidManaBarDB[k] == nil then
                DruidManaBarDB[k] = v
            end
        end
        
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if class == "DRUID" then
            CreateBars()
            UpdateVisibility()
            
            -- 주기적 업데이트
            C_Timer.NewTicker(0.1, function()
                if mainFrame and mainFrame:IsVisible() then
                    UpdateBars()
                end
            end)
        end
        
    elseif event == "UNIT_POWER_UPDATE" and arg1 == "player" then
        UpdateBars()
        
    elseif event == "UNIT_HEALTH" and arg1 == "player" then
        UpdateBars()
        
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        UpdateVisibility()
        UpdateTargetDebuffs()  -- 변신 폼 변경시 디버프 표시 업데이트
        UpdateComboPoints()  -- 콤보 포인트 업데이트
        
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateVisibility()
        
    elseif event == "LEARNED_SPELL_IN_TAB" then
        -- 새 스펠을 배웠을 때 마나 비용 업데이트
        C_Timer.After(0.5, UpdateBars)
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        -- 5초 규칙 시작 (스펠 시전 시)
        fiveSRStartTime = GetTime()
        inFiveSR = true
        C_Timer.After(5, function()
            inFiveSR = false
        end)
        
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            -- 버프가 변경되었을 때 아이콘 업데이트
            UpdateBuffIcons()
        elseif arg1 == "target" then
            -- 타겟 디버프 업데이트
            UpdateTargetDebuffs()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- 타겟이 변경되었을 때 디버프 업데이트
        UpdateTargetDebuffs()
        UpdateComboPoints()
    elseif event == "UNIT_POWER_UPDATE" then
        local powerType = select(1, ...)
        if arg1 == "player" and powerType == "COMBO_POINTS" then
            UpdateComboPoints()
        end
    end
end)

-- 공개 함수들
function DruidManaBar:UpdateVisibility()
    UpdateVisibility()
end

function DruidManaBar:UpdateBars()
    UpdateBars()
end

function DruidManaBar:UpdatePosition()
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 
                          DruidManaBarDB.barX or defaults.barX, 
                          DruidManaBarDB.barY or defaults.barY)
    end
end

function DruidManaBar:UpdateSize()
    if mainFrame then
        local healthBarHeight = (DruidManaBarDB.showHealthBar ~= false) and (DruidManaBarDB.healthBarHeight or defaults.healthBarHeight) or 0
        local spacing = (DruidManaBarDB.showHealthBar ~= false) and 2 or 0

        mainFrame:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                         (DruidManaBarDB.barHeight or defaults.barHeight) + healthBarHeight + spacing)

        if healthBar then
            healthBar:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                             DruidManaBarDB.healthBarHeight or defaults.healthBarHeight)
        end

        if manaBar then
            manaBar:SetSize(DruidManaBarDB.barWidth or defaults.barWidth,
                           DruidManaBarDB.barHeight or defaults.barHeight)
        end

        UpdateBars()
    end
end

function DruidManaBar:TestMode()
    if not mainFrame then
        CreateBars()
    end
    
    mainFrame:EnableMouse(true)
    mainFrame:Show()
    UpdateBars()
    
    print(L["TEST_MODE_START"])
    
    C_Timer.After(10, function()
        mainFrame:EnableMouse(false)
        UpdateVisibility()
        print(L["TEST_MODE_END"])
    end)
end

-- 변신 버튼에서 스펠 ID 가져오기
local function GetShapeshiftSpellId(slot)
    -- Classic API: texture, active, castable 순서
    local texture, isActive, isCastable = GetShapeshiftFormInfo(slot)
    
    -- 툴팁에서 이름 가져오기
    scanTooltip:ClearLines()
    scanTooltip:SetShapeshift(slot)
    local name = DruidManaBarScanTooltipTextLeft1 and DruidManaBarScanTooltipTextLeft1:GetText()
    
    if name and type(name) == "string" then
        -- 변신 버튼의 툴팁에서 스펠 ID 추출
        scanTooltip:ClearLines()
        scanTooltip:SetShapeshift(slot)
        
        local spellName = scanTooltip:GetSpell()
        if spellName then
            -- 스펠북에서 해당 이름 찾기
            for i = 1, MAX_SKILLLINE_TABS do
                local _, _, offset, numSpells = GetSpellTabInfo(i)
                if numSpells then
                    for j = 1, numSpells do
                        local spellIndex = offset + j
                        local bookSpellName = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL)
                        if bookSpellName == spellName then
                            local link = GetSpellLink(spellIndex, BOOKTYPE_SPELL)
                            local spellId = link and tonumber(string.match(link, "spell:(%d+)"))
                            if spellId then
                                return spellId, spellName
                            end
                        end
                    end
                end
            end
        end
        return nil, name
    end
    return nil, nil
end

-- 스펠 ID 정보 표시 함수
function DruidManaBar:ShowSpellInfo(spellIdStr)
    local spellId = tonumber(spellIdStr)
    if not spellId then
        print("|cffff0000Invalid spell ID. Usage: /dmb spellinfo <ID>|r")
        return
    end
    
    print(string.format("|cff00ff00=== Spell Info for ID: %d ===|r", spellId))
    
    -- 스펠 정보 가져오기
    local name, rank = GetSpellInfo(spellId)
    local known = IsSpellKnown(spellId)
    
    print(string.format("  Name: %s", name or "Unknown"))
    print(string.format("  Rank: %s", rank or ""))
    print(string.format("  Known: %s", known and "|cff00ff00YES|r" or "|cffff0000NO|r"))
    
    -- 변신 바에서 찾기
    local foundInShapeshiftBar = false
    local numForms = GetNumShapeshiftForms()
    for i = 1, numForms do
        scanTooltip:ClearLines()
        scanTooltip:SetShapeshift(i)
        local formName = DruidManaBarScanTooltipTextLeft1 and DruidManaBarScanTooltipTextLeft1:GetText()
        
        if formName then
            local match = false
            if spellId == SPELL_DIRE_BEAR_FORM and (string.find(formName, "Dire Bear") or string.find(formName, "광포한 곰")) then
                match = true
            elseif spellId == SPELL_CAT_FORM and (string.find(formName, "Cat") or string.find(formName, "표범")) then
                match = true
            end
            
            if match then
                foundInShapeshiftBar = true
                print(string.format("  Shapeshift Bar: Slot %d - %s", i, formName))
            end
        end
    end
    
    -- 마나 비용 확인
    local manaCost = GetManaCostBySpellID(spellId)
    print(string.format("  Mana Cost (Auto): %s", manaCost or "?"))
    
    -- 수동 설정 값 확인
    local manualCost = nil
    if spellId == SPELL_BEAR_FORM or spellId == SPELL_BEAR_FORM_2 then
        manualCost = DruidManaBarDB.bearFormCost
    elseif spellId == SPELL_DIRE_BEAR_FORM then
        manualCost = DruidManaBarDB.direBearFormCost
    elseif spellId == SPELL_CAT_FORM then
        manualCost = DruidManaBarDB.catFormCost
    end
    
    if manualCost then
        print(string.format("  Mana Cost (Manual): %d", manualCost))
    end
    
    print("|cff00ff00=== End Info ===|r")
end

-- 드루이드 변신 스펠 ID 목록 표시
function DruidManaBar:ListFormIDs()
    print("|cff00ff00=== Druid Form Spell IDs ===|r")
    print("  곰 변신: 5487, 5488")
    print("  광포한 곰 변신: 9634")
    print("  표범 변신: 768")
    print("  바다표범 변신: 1066")
    print("  치타 변신: 783")
    print("  달빛야수 변신: 24858")
    print("|cff00ff00Use /dmb spellinfo <ID> to check specific spell|r")
end

-- 변신 바 디버그 함수 (향상된 버전)
function DruidManaBar:DebugShapeshiftBar()
    print("|cff00ff00=== Shapeshift Bar Debug ===|r")
    
    local numForms = GetNumShapeshiftForms()
    print(string.format("Number of forms: %d", numForms))
    
    for i = 1, numForms do
        local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
        local formName = GetFormByTexture(texture) or "Unknown"
        print(string.format("|cffffff00Slot %d: %s|r", i, formName))
        print(string.format("  Texture: %s", texture or "nil"))
        print(string.format("  Active: %s, Castable: %s", tostring(isActive), tostring(isCastable)))
        
        -- 툴팁 내용 전체 출력
        scanTooltip:ClearLines()
        scanTooltip:SetShapeshift(i)
        
        print("  |cff00ffffTooltip Analysis:|r")
        local foundMana = false
        for j = 1, scanTooltip:NumLines() do
            local textLeft = _G["DruidManaBarScanTooltipTextLeft"..j]
            local textRight = _G["DruidManaBarScanTooltipTextRight"..j]
            
            if textLeft then
                local leftText = textLeft:GetText()
                if leftText then
                    -- 숫자가 포함된 라인 강조
                    if string.find(leftText, "%d") then
                        print(string.format("    |cff00ff00[L%d]|r |cffffff00%s|r", j, leftText))
                        
                        -- 다양한 마나 패턴 테스트
                        local patterns = {
                            "(%d+) Mana",
                            "(%d+) 마나",
                            "Mana: (%d+)",
                            "마나: (%d+)",
                            "(%d+) mana",
                            "Cost: (%d+) Mana",
                            "비용: (%d+) 마나",
                            "마나 (%d+)",
                            "Mana (%d+)",
                            "(%d+)마나",
                            "(%d+)Mana",
                            "%[마나 (%d+)%]",  -- 한국 클라이언트 특수 형식
                            "%[Mana (%d+)%]"   -- 영어 클라이언트 특수 형식
                        }
                        
                        for _, pattern in ipairs(patterns) do
                            local mana = string.match(leftText, pattern)
                            if mana then
                                print(string.format("      |cff00ff00>>> FOUND MANA: %s (pattern: %s)|r", mana, pattern))
                                foundMana = true
                                break
                            end
                        end
                    else
                        print(string.format("    [L%d] %s", j, leftText))
                    end
                end
            end
            
            if textRight then
                local rightText = textRight:GetText()
                if rightText then
                    print(string.format("    |cff00ffff[R%d]|r %s", j, rightText))
                    
                    -- 오른쪽 텍스트에서도 마나 체크
                    if string.find(rightText, "%d") then
                        local mana = string.match(rightText, "^(%d+)$") or
                                   string.match(rightText, "(%d+) Mana") or
                                   string.match(rightText, "(%d+) 마나")
                        if mana then
                            print(string.format("      |cff00ff00>>> FOUND MANA (right): %s|r", mana))
                            foundMana = true
                        end
                    end
                end
            end
        end
        
        if not foundMana then
            print("    |cffff0000*** NO MANA COST FOUND IN TOOLTIP ***|r")
        end
        
        -- 자동 감지 테스트
        print("  |cffffff00Auto-detect Results:|r")
        local bearCost = GetManaCostFromShapeshiftBar(SPELL_BEAR_FORM) or GetManaCostFromShapeshiftBar(SPELL_BEAR_FORM_2)
        local direBearCost = GetManaCostFromShapeshiftBar(SPELL_DIRE_BEAR_FORM)
        local catCost = GetManaCostFromShapeshiftBar(SPELL_CAT_FORM)
        
        print(string.format("    Bear Form: %s", bearCost or "?"))
        print(string.format("    Dire Bear Form: %s", direBearCost or "?"))
        print(string.format("    Cat Form: %s", catCost or "?"))
        
        -- 실제 사용되는 값 표시
        print("  |cffffff00Actual Values Used (with manual override):|r")
        local actualBear = GetShapeshiftManaCost("bear")
        local actualDireBear = GetShapeshiftManaCost("direbear")
        local actualCat = GetShapeshiftManaCost("cat")
        print(string.format("    Bear: %d (manual: %d)", actualBear, DruidManaBarDB.bearFormCost or 0))
        print(string.format("    Dire Bear: %d (manual: %d)", actualDireBear, DruidManaBarDB.direBearFormCost or 0))
        print(string.format("    Cat: %d (manual: %d)", actualCat, DruidManaBarDB.catFormCost or 0))
    end
    
    print("|cff00ff00=== End Debug ===|r")
end

-- 변신 스펠 디버그 함수
function DruidManaBar:DebugShapeshifts()
    print("|cff00ff00=== DruidManaBar Shapeshift Debug ===|r")
    
    -- 현재 설정된 값 출력
    print("|cffffff00Current Settings:|r")
    print(string.format("  Bear Form Cost (Manual): %d", DruidManaBarDB.bearFormCost or 0))
    print(string.format("  Cat Form Cost (Manual): %d", DruidManaBarDB.catFormCost or 0))
    print(string.format("  Dire Bear Cost (Manual): %d", DruidManaBarDB.direBearFormCost or 0))
    
    print("|cff00ff00=== End Debug ===|r")
end

-- 툴팁 원시 텍스트 덤프 함수
function DruidManaBar:DebugTooltipRaw()
    print("|cff00ff00=== Raw Tooltip Dump ===|r")
    
    local numForms = GetNumShapeshiftForms()
    for i = 1, numForms do
        local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
        if texture then
            local formName = GetFormByTexture(texture) or "Unknown"
            print(string.format("|cffffff00Form %d: %s|r", i, formName))
            
            scanTooltip:ClearLines()
            scanTooltip:SetShapeshift(i)
            
            -- 원시 텍스트 덤프
            for j = 1, scanTooltip:NumLines() do
                local textLeft = _G["DruidManaBarScanTooltipTextLeft"..j]
                local textRight = _G["DruidManaBarScanTooltipTextRight"..j]
                
                if textLeft and textLeft:GetText() then
                    local text = textLeft:GetText()
                    -- 각 문자의 바이트 값도 출력
                    local bytes = ""
                    for k = 1, #text do
                        bytes = bytes .. string.format("%02X ", string.byte(text, k))
                    end
                    print(string.format("  L%d: [%s]", j, text))
                    print(string.format("      Bytes: %s", bytes))
                end
                
                if textRight and textRight:GetText() then
                    local text = textRight:GetText()
                    print(string.format("  R%d: [%s]", j, text))
                end
            end
        end
    end
    
    print("|cff00ff00=== End Raw Dump ===|r")
end

-- 테스트 모드 함수
function DruidManaBar:TestMode()
    if not mainFrame then
        CreateBars()
    end
    
    mainFrame:EnableMouse(true)
    mainFrame:Show()
    UpdateBars()
    
    print(L["TEST_MODE_START"])
    
    C_Timer.After(10, function()
        mainFrame:EnableMouse(false)
        UpdateVisibility()
        print(L["TEST_MODE_END"])
    end)
end

-- 슬래시 명령어
SLASH_DRUIDMANABAR1 = "/dmb"
SLASH_DRUIDMANABAR2 = "/druidmanabar"

SlashCmdList["DRUIDMANABAR"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = cmd:lower()
    
    if cmd == "test" then
        DruidManaBar:TestMode()
    elseif cmd == "debug" then
        DruidManaBar:DebugShapeshifts()
    elseif cmd == "debugbar" then
        DruidManaBar:DebugShapeshiftBar()
    elseif cmd == "debugtooltip" then
        DruidManaBar:DebugTooltipRaw()
    elseif cmd == "spellinfo" and arg then
        DruidManaBar:ShowSpellInfo(arg)
    elseif cmd == "formids" then
        DruidManaBar:ListFormIDs()
    elseif cmd == "checkbuff" then
        DruidManaBar:CheckBuffDebug()
    elseif cmd == "config" or cmd == "" then
        if DruidManaBar.ShowConfig then
            DruidManaBar:ShowConfig()
        end
    else
        print(L["COMMANDS_HEADER"])
        print(L["COMMAND_CONFIG"])
        print(L["COMMAND_TEST"])
        print(L["COMMAND_DEBUG"])
        print("|cff00ff00Additional Debug Commands:|r")
        print("  /dmb checkbuff - Debug buff checking system")
        print("  /dmb debugbar - Show detailed shapeshift bar tooltips")
        print("  /dmb debugtooltip - Show raw tooltip text dump")
        print("  /dmb spellinfo <ID> - Show spell information")
        print("  /dmb formids - List all druid form spell IDs")
        print("|cffffff00If auto-detection shows '?', run '/dmb debugbar' and report the output|r")
    end
end

-- 버프 체크 디버그 함수
function addon:CheckBuffDebug()
    print("|cff00ff00=== DruidManaBar 버프 체크 디버그 ===|r")

    -- 스펠북 검사
    print("|cffffff00[스펠북 검사]|r")
    local foundSpells = {}
    for i = 1, MAX_SKILLLINE_TABS do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        if numSpells then
            for j = 1, numSpells do
                local spellIndex = offset + j
                local bookSpellName = GetSpellBookItemName(spellIndex, BOOKTYPE_SPELL)
                if bookSpellName then
                    local lowerName = string.lower(bookSpellName)
                    -- 관련 스펠들 찾기
                    if string.find(lowerName, "omen") or string.find(lowerName, "clarity") or
                       string.find(bookSpellName, "천명") or string.find(bookSpellName, "전조") or
                       string.find(lowerName, "mark") or string.find(lowerName, "wild") or
                       string.find(lowerName, "gift") or string.find(lowerName, "thorns") or
                       string.find(bookSpellName, "야생") or string.find(bookSpellName, "가시") then
                        table.insert(foundSpells, bookSpellName)
                    end
                end
            end
        end
    end

    if #foundSpells > 0 then
        print("찾은 관련 스펠:")
        for _, spell in ipairs(foundSpells) do
            print("  - " .. spell)
        end
    else
        print("  관련 스펠을 찾을 수 없음")
    end

    -- 현재 버프 검사
    print("|cffffff00[현재 버프]|r")
    local buffs = {}
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name then
            table.insert(buffs, name)
        end
    end

    if #buffs > 0 then
        print("활성 버프:")
        for _, buff in ipairs(buffs) do
            print("  - " .. buff)
        end
    else
        print("  활성 버프 없음")
    end

    -- 누락된 버프 검사
    print("|cffffff00[누락된 버프 검사]|r")
    local missingBuffs = CheckBuffs()
    if #missingBuffs > 0 then
        print("누락된 버프:")
        for _, buff in ipairs(missingBuffs) do
            print("  - " .. buff)
        end
    else
        print("  모든 버프 활성화됨")
    end

    print("|cff00ff00=== 디버그 종료 ===|r")
end

-- 전역 변수로 노출
_G["DruidManaBar"] = DruidManaBar or {}
for k, v in pairs(addon) do
    _G["DruidManaBar"][k] = v
end

-- 함수들 노출
DruidManaBar.UpdateVisibility = UpdateVisibility
DruidManaBar.UpdateBars = UpdateBars
DruidManaBar.UpdatePosition = UpdatePosition
DruidManaBar.UpdateSize = UpdateSize
DruidManaBar.GetManaCostFromShapeshiftBar = GetManaCostFromShapeshiftBar
DruidManaBar.CheckBuffDebug = addon.CheckBuffDebug
DruidManaBar.UpdateTargetDebuffs = UpdateTargetDebuffs
