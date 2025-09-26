
- wow classic 에드온을 만듭니다.
- 설정창은 다른 어떤 내용보다 가장 맨위(레이어상)에 보여져야 합니다.
- 에드온은 미니맵에 설정 버튼이 붙어 있어야 합니다. DruidManaBar/ FoxChat/ FoxGuildCal/ 에서 이 부분은 잘 구현되어 있습니다.

ㅡ Readme에는 다음과 같은 개발자 정보를 넣어주세요.
    개발자 : 우르사 (20주년 하드코어 클래식 서버 , Fox and Wolf 길드)

## Textarea 정의와 개발 계획

### 요구사항
1. **스크롤바**: 모든 textarea에는 스크롤바가 필수로 있어야 함
2. **커서 동작**:
   - 빈 텍스트 상태: 아무 곳이나 클릭 시 첫 번째 줄 첫 번째 칸에 커서
   - 문자열 있는 위치 클릭: 해당 위치에 커서
   - 문자열 없는 위치 클릭: 문자열 마지막에 커서
3. **줄 제한 제거**: 스크롤바가 있으므로 줄 수 제한 불필요

### 구현 계획

#### 1단계: 기본 구조
- ScrollFrame (UIPanelScrollFrameTemplate 사용)
- EditBox를 ScrollChild로 설정
- 배경 Frame은 클릭 이벤트 처리용

#### 2단계: 커서 동작 구현
```lua
-- EditBox 클릭 이벤트
EditBox:SetScript("OnMouseUp", function(self, button)
    -- 기본 클릭 동작 유지 (문자열 있는 곳 클릭 시)
end)

-- 배경 클릭 이벤트
Background:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        local editBox = self.editBox
        editBox:SetFocus()

        local text = editBox:GetText()
        if not text or text == "" then
            -- 빈 텍스트: 처음 위치
            editBox:SetCursorPosition(0)
        else
            -- 텍스트 있음: 끝 위치
            editBox:SetCursorPosition(string.len(text))
        end
    end
end)
```

#### 3단계: 스크롤 동작 최적화
- EditBox 높이를 동적으로 조정
- 스크롤바 자동 표시/숨김
- 커서 위치에 따른 자동 스크롤

#### 4단계: 재사용 가능한 함수로 만들기
```lua
function CreateTextArea(parent, width, height, maxLetters)
    -- ScrollFrame 생성
    -- EditBox 생성 및 설정
    -- 이벤트 핸들러 등록
    -- return scrollFrame, editBox
end
```

### 적용 대상
1. 광고 메시지 입력창
2. 선입 메시지 입력창
3. 자동 인사말 입력창 (내가 참가)
4. 자동 인사말 입력창 (다른 사람 참가)


