# DruidManaBar Changelog

## Version 1.1 - Features from DruidBar Classic

### New Features
1. **Icon-based Form Detection**
   - Added GetFormByTexture() function to detect forms by icon texture
   - More reliable form detection in Classic API

2. **Mana Regeneration Tracking**
   - Calculates base mana regen: Intellect/5 + 15
   - Shows regen rate and time to full when hovering over mana bar
   - Tracks 5-second rule (30% regen in combat after casting)

3. **Innervate Buff Detection**
   - Detects Innervate buff for 400% mana regeneration
   - Automatically adjusts regen calculations

4. **Metamorphosis Rune Support**
   - Checks for Metamorphosis rune (Season of Discovery)
   - Shows free shapeshifting when rune is active
   - Hides mana cost lines when metamorphosis is active

5. **Enhanced Mouse Interaction**
   - Mouse hover shows mana regeneration details
   - Displays time until mana is full
   - Shows current regen rate per second

### UI Improvements
1. **Fixed Config Layout**
   - Increased config window height to 800px
   - Repositioned buttons to prevent covering manual mana inputs
   - Centered buttons at bottom of config window

### Technical Improvements
- Better form detection using multiple methods
- More accurate mana cost detection
- Improved event handling for spell casts
- Added support for rune-based abilities

## Version 1.0 - Initial Release
- Basic mana and health bars for druids
- Shapeshift mana cost indicators
- Configurable display modes
- Manual mana cost override options