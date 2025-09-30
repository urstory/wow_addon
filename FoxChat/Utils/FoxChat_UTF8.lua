local addonName, addon = ...

-- UTF8 유틸리티 모듈
FoxChat = FoxChat or {}
FoxChat.Utils = FoxChat.Utils or {}
FoxChat.Utils.UTF8 = {}

local UTF8 = FoxChat.Utils.UTF8

-- UTF-8 문자열의 글자 수를 계산하는 함수 (WoW 내장 함수 활용)
function UTF8:GetLength(str)
    if not str then return 0 end
    -- WoW에 내장된 strlenutf8 함수 사용
    if type(_G.strlenutf8) == "function" then
        return strlenutf8(str)
    end
    -- 폴백: 순수 Lua 구현
    local len, i = 0, 1
    local bytes = #str
    while i <= bytes do
        local c = str:byte(i)
        local n
        if c < 0x80 then
            n = 1
        elseif c < 0xE0 then
            n = 2
        elseif c < 0xF0 then
            n = 3
        elseif c < 0xF5 then
            n = 4
        else
            n = 1
        end
        i = i + n
        len = len + 1
    end
    return len
end

-- UTF-8 문자열의 바이트 길이를 계산
function UTF8:GetByteLength(str)
    if not str then return 0 end

    local validBytes = 0
    local i = 1

    while i <= #str do
        local c = str:byte(i)
        if not c then break end

        local charLen
        if c < 0x80 then
            charLen = 1
        elseif c >= 0xF0 and c < 0xF5 then
            charLen = 4
        elseif c >= 0xE0 and c < 0xF0 then
            charLen = 3
        elseif c >= 0xC0 and c < 0xE0 then
            charLen = 2
        else
            -- 잘못된 UTF-8 시작 바이트
            i = i + 1
            validBytes = validBytes + 1
            goto continue
        end

        -- 전체 문자가 유효한지 확인
        if i + charLen - 1 <= #str then
            local valid = true
            for j = 1, charLen - 1 do
                local b = str:byte(i + j)
                if not b or b < 0x80 or b >= 0xC0 then
                    valid = false
                    break
                end
            end

            if valid then
                validBytes = validBytes + charLen
                i = i + charLen
            else
                validBytes = validBytes + 1
                i = i + 1
            end
        else
            -- 불완전한 문자
            break
        end

        ::continue::
    end

    return validBytes
end

-- UTF-8 문자열을 바이트 수 기준으로 안전하게 자르는 함수
function UTF8:TrimByBytes(str, byteLimit)
    if not str or str == "" then return "" end
    byteLimit = byteLimit or 255

    -- 이미 제한 내에 있으면 그대로 반환
    if #str <= byteLimit then
        return str
    end

    -- 유효한 UTF-8 경계를 찾아서 자르기
    local validPos = 0  -- 마지막으로 확인된 유효한 위치
    local i = 1

    while i <= #str and i <= byteLimit do
        local b = str:byte(i)
        if not b then
            break
        end

        local charLen = 1
        if b < 0x80 then
            -- ASCII 문자 (1바이트)
            charLen = 1
        elseif b >= 0xF0 then
            -- 4바이트 문자
            charLen = 4
        elseif b >= 0xE0 then
            -- 3바이트 문자 (한글 등)
            charLen = 3
        elseif b >= 0xC0 then
            -- 2바이트 문자
            charLen = 2
        else
            -- 잘못된 UTF-8 시작 바이트
            break
        end

        -- 전체 문자가 byteLimit 내에 들어가는지 확인
        if i + charLen - 1 <= byteLimit then
            -- 이 문자를 포함할 수 있음
            validPos = i + charLen - 1
            i = i + charLen
        else
            -- 이 문자를 포함할 수 없음
            break
        end
    end

    -- 유효한 위치까지 자르기
    if validPos > 0 then
        return str:sub(1, validPos)
    else
        -- 첫 문자도 들어갈 수 없는 경우 (매우 드물지만)
        return ""
    end
end

-- 메시지 검증 함수 (글자수와 바이트수 체크)
function UTF8:Validate(str)
    if not str then
        return { charLen = 0, byteLen = 0, okForChat = true }
    end

    local byteLen = self:GetByteLength(str)

    return {
        charLen = self:GetLength(str),
        byteLen = byteLen,
        okForChat = (byteLen <= 255)
    }
end

-- UTF-8 문자열을 글자 수 기준으로 자르는 함수
function UTF8:TrimByChars(str, charLimit)
    if not str or str == "" then return "" end

    local count = 0
    local i = 1
    local lastPos = 0

    while i <= #str and count < charLimit do
        local c = str:byte(i)
        if not c then break end

        local charLen
        if c < 0x80 then
            charLen = 1
        elseif c >= 0xF0 then
            charLen = 4
        elseif c >= 0xE0 then
            charLen = 3
        elseif c >= 0xC0 then
            charLen = 2
        else
            charLen = 1
        end

        if i + charLen - 1 <= #str then
            count = count + 1
            lastPos = i + charLen - 1
            i = i + charLen
        else
            break
        end
    end

    if lastPos > 0 then
        return str:sub(1, lastPos)
    else
        return ""
    end
end

-- UTF-8 문자열의 특정 위치의 문자 가져오기
function UTF8:GetChar(str, index)
    if not str or str == "" or index < 1 then return nil end

    local count = 0
    local i = 1

    while i <= #str do
        local c = str:byte(i)
        if not c then break end

        local charLen
        if c < 0x80 then
            charLen = 1
        elseif c >= 0xF0 then
            charLen = 4
        elseif c >= 0xE0 then
            charLen = 3
        elseif c >= 0xC0 then
            charLen = 2
        else
            charLen = 1
        end

        count = count + 1

        if count == index then
            if i + charLen - 1 <= #str then
                return str:sub(i, i + charLen - 1)
            else
                return nil
            end
        end

        i = i + charLen
    end

    return nil
end

-- 하위 호환성을 위한 전역 함수 (기존 코드와의 호환)
if not UTF8 then
    _G.UTF8 = {
        len = function(str) return FoxChat.Utils.UTF8:GetLength(str) end,
        trimByBytes = function(str, limit) return FoxChat.Utils.UTF8:TrimByBytes(str, limit) end,
        validate = function(str) return FoxChat.Utils.UTF8:Validate(str) end
    }
end