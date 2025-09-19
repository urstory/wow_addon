# FoxGuildCal Update Log

## 2025-01-19 Update

### English

#### Event Detail Display Improvement
- **Changed from Popup to Side Panel**: Event details are now displayed in a separate side panel instead of a modal popup window
- **Better User Experience**: Users can now quickly browse through multiple events without closing and reopening popups
- **Persistent Event List**: The event list remains visible and accessible while viewing event details
- **Dynamic Content Update**: Clicking on different events immediately updates the detail panel with the selected event's information
- **Non-Intrusive Design**: The detail panel appears to the right of the calendar window and can be closed with the X button

#### Key Features
- Side panel appears to the right of the main calendar window
- Event list remains fully interactive while detail panel is open
- Seamless switching between different event details
- Clear visual separation between list and detail views
- Maintains all existing functionality (edit, delete, etc.)

---

### 한국어

#### 일정 상세 표시 개선
- **팝업에서 사이드 패널로 변경**: 일정 상세 정보가 모달 팝업 창 대신 별도의 사이드 패널에 표시됩니다
- **향상된 사용자 경험**: 이제 팝업을 닫고 다시 열 필요 없이 여러 일정을 빠르게 탐색할 수 있습니다
- **일정 목록 유지**: 일정 상세 정보를 보는 동안에도 일정 목록이 계속 표시되고 접근 가능합니다
- **동적 콘텐츠 업데이트**: 다른 일정을 클릭하면 선택한 일정의 정보로 상세 패널이 즉시 업데이트됩니다
- **비침입적 디자인**: 상세 패널이 캘린더 창 오른쪽에 나타나며 X 버튼으로 닫을 수 있습니다

#### 주요 기능
- 메인 캘린더 창 오른쪽에 사이드 패널 표시
- 상세 패널이 열려 있어도 일정 목록은 완전히 상호작용 가능
- 다른 일정 상세 정보 간 원활한 전환
- 목록과 상세 보기 간 명확한 시각적 구분
- 기존의 모든 기능 유지 (수정, 삭제 등)

---

## Technical Details

### Modified Files
- `Calendar.lua`: Main changes to event detail display logic

### Functions Changed
- `ShowDayEvents()`: Modified event click handler to use new panel system
- `ShowEventDetailPanel()`: New function to display event details in side panel
- `ShowEventDetail()`: Redirected to use new panel system for backward compatibility

### UI Structure
```
[Main Calendar Frame] --> [Event Detail Panel]
         |                        |
    [Event List]            [Close Button]
         |                        |
    [Add Event]             [Event Info]
                                  |
                            [Edit/Delete]
```