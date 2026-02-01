# WoW Classic Addon Development Guide

A comprehensive guide to patterns, best practices, and API usage for World of Warcraft Classic addon development.

---

## Table of Contents
1. [Addon Structure](#addon-structure)
2. [Logic Patterns](#logic-patterns)
3. [UI Design Patterns](#ui-design-patterns)
4. [Event System](#event-system)
5. [Data Persistence](#data-persistence)
6. [API Documentation Resources](#api-documentation-resources)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)

---

## Addon Structure

### Basic File Organization
```
AddonName/
├── AddonName.toc       # Manifest file (required)
├── AddonName.lua       # Main logic file
├── UI.lua             # UI-specific code (optional)
├── Config.lua         # Configuration/settings (optional)
└── libs/              # Embedded libraries (optional)
```

### TOC File Pattern
```lua
## Interface: 20504                    # TBC Classic version
## Title: My Addon
## Notes: Brief description
## Author: YourName
## Version: 1.0.0
## SavedVariables: AddonNameDB         # Account-wide data
## SavedVariablesPerCharacter: AddonNameCharDB  # Per-character data

# Load order matters!
Core.lua
Config.lua
UI.lua
```

**Key Points:**
- Files load in the order listed in the TOC
- Interface version must match your WoW version
- Use `##` for metadata, `#` for comments

---

## Logic Patterns

### 1. Namespace Pattern (Prevent Global Pollution)

**❌ Bad - Global pollution:**
```lua
function MyFunction()
    -- Pollutes global namespace
end
```

**✅ Good - Namespaced:**
```lua
-- Create addon namespace
MyAddon = MyAddon or {}
local addon = MyAddon

function addon:MyFunction()
    -- Scoped to addon
end

-- Or use local tables
local MyAddon = {}
function MyAddon:Init()
    -- Private to this file
end
```

### 2. Initialization Pattern

**Standard initialization sequence:**
```lua
local addonName, addon = ...  -- Passed by WoW

-- Initialize saved variables
addon.db = nil

-- Create event frame
local eventFrame = CreateFrame("Frame")

-- Initialization function
local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then return end
    
    -- Initialize database
    AddonDB = AddonDB or {}
    addon.db = AddonDB
    
    -- Set defaults
    addon.db.version = addon.db.version or "1.0"
    addon.db.settings = addon.db.settings or {}
    
    -- Unregister ADDON_LOADED to prevent re-init
    eventFrame:UnregisterEvent("ADDON_LOADED")
end

-- Register events
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        addon:OnPlayerLogin()
    end
end)
```

**Why this pattern:**
- `ADDON_LOADED` fires when TOC/lua files load (early)
- `PLAYER_LOGIN` fires when character fully enters world
- Unregistering after init improves performance

### 3. Module Pattern

**For larger addons, separate concerns:**
```lua
-- Core.lua
MyAddon = {}
local addon = MyAddon

addon.modules = {}

function addon:RegisterModule(name, module)
    self.modules[name] = module
    module.addon = self
end

-- UI.lua
local addon = MyAddon
local UIModule = {}

function UIModule:Init()
    -- Create UI
end

addon:RegisterModule("UI", UIModule)
```

### 4. Configuration Pattern

**Provide sensible defaults:**
```lua
local defaults = {
    version = "1.0",
    settings = {
        showMinimapButton = true,
        soundEnabled = true,
        scale = 1.0,
    },
    position = {
        point = "CENTER",
        x = 0,
        y = 0,
    },
}

-- Deep copy defaults
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- On init
AddonDB = AddonDB or {}
CopyDefaults(defaults, AddonDB)
```

---

## UI Design Patterns

### 1. Frame Hierarchy

**Understanding frame layers:**
```
UIParent (root)
└── Your Main Frame
    ├── Background Texture (BACKGROUND layer)
    ├── Border Texture (BORDER layer)
    ├── Content Frame (ARTWORK layer)
    │   ├── Title FontString (OVERLAY layer)
    │   └── Content FontString (OVERLAY layer)
    └── Buttons (OVERLAY layer)
```

**Layer order (bottom to top):**
1. BACKGROUND
2. BORDER
3. ARTWORK
4. OVERLAY
5. HIGHLIGHT

### 2. Reusable Frame Template

**Create a base window class:**
```lua
local function CreateBaseWindow(name, parent, width, height)
    local frame = CreateFrame("Frame", name, parent or UIParent)
    frame:SetWidth(width or 300)
    frame:SetHeight(height or 200)
    frame:SetPoint("CENTER")
    
    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    frame.bg = bg
    
    -- Border
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0.5, 0.5, 0.5, 1)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    frame.border = border
    
    -- Title bar
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetHeight(25)
    titleBg:SetPoint("TOPLEFT")
    titleBg:SetPoint("TOPRIGHT")
    titleBg:SetColorTexture(0.2, 0.2, 0.6, 1)
    frame.titleBg = titleBg
    
    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -5)
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.closeButton = closeBtn
    
    frame:Hide()
    return frame
end

-- Usage:
local myWindow = CreateBaseWindow("MyAddonWindow", UIParent, 400, 300)
myWindow.title:SetText("My Addon")
```

### 3. Dynamic Content Pattern

**For lists/scrollable content:**
```lua
-- Create scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

-- Create content frame
local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth())
scrollFrame:SetScrollChild(content)

-- Reusable item pool
local itemFrames = {}

local function GetOrCreateItem(index)
    if not itemFrames[index] then
        local item = CreateFrame("Frame", nil, content)
        item:SetHeight(20)
        item:SetWidth(content:GetWidth())
        
        item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.text:SetPoint("LEFT", 5, 0)
        
        itemFrames[index] = item
    end
    return itemFrames[index]
end

-- Update display
local function UpdateList(data)
    local yOffset = 0
    
    for i, entry in ipairs(data) do
        local item = GetOrCreateItem(i)
        item:SetPoint("TOPLEFT", 0, -yOffset)
        item.text:SetText(entry)
        item:Show()
        yOffset = yOffset + 20
    end
    
    -- Hide unused items
    for i = #data + 1, #itemFrames do
        itemFrames[i]:Hide()
    end
    
    content:SetHeight(math.max(yOffset, scrollFrame:GetHeight()))
end
```

### 4. Position Saving Pattern

**Save and restore window positions:**
```lua
-- Save position
local function SavePosition(frame, savedVar)
    local point, _, relativePoint, x, y = frame:GetPoint()
    savedVar.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

-- Restore position
local function RestorePosition(frame, savedVar)
    if savedVar.position then
        local pos = savedVar.position
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

-- Hook on drag stop
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self, MyAddonDB)
end)
```

---

## Event System

### 1. Event Registration Pattern

**Register only needed events:**
```lua
local eventHandlers = {}

-- Define handlers
eventHandlers.PLAYER_LOGIN = function(...)
    -- Handle login
end

eventHandlers.PLAYER_LOGOUT = function(...)
    -- Handle logout
end

eventHandlers.UNIT_HEALTH = function(unit)
    if unit == "player" then
        -- Handle player health change
    end
end

-- Generic event dispatcher
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
        handler(...)
    end
end)

-- Register all events with handlers
for event in pairs(eventHandlers) do
    eventFrame:RegisterEvent(event)
end
```

### 2. Common Events Reference

**Initialization Events:**
- `ADDON_LOADED` - When addon files load (use addonName parameter!)
- `PLAYER_LOGIN` - Character fully loaded, UI ready
- `PLAYER_ENTERING_WORLD` - Fires on login, reload, zone change

**Gameplay Events:**
- `PLAYER_TARGET_CHANGED` - Target changed
- `UNIT_HEALTH` - Unit health changed
- `UNIT_POWER_UPDATE` - Mana/energy/rage changed
- `COMBAT_LOG_EVENT_UNFILTERED` - Combat log entry
- `PLAYER_REGEN_DISABLED` - Entered combat
- `PLAYER_REGEN_ENABLED` - Left combat

**UI Events:**
- `VARIABLES_LOADED` - SavedVariables loaded
- `PLAYER_LOGOUT` - About to log out (save data now!)
- `BAG_UPDATE` - Inventory changed

### 3. Update Loop Pattern

**For continuous monitoring (use sparingly!):**
```lua
local timeSinceLastUpdate = 0
local updateInterval = 0.1  -- Update every 0.1 seconds

frame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    
    if timeSinceLastUpdate >= updateInterval then
        -- Do your update work here
        
        timeSinceLastUpdate = 0
    end
end)

-- Remember to stop when not needed:
-- frame:SetScript("OnUpdate", nil)
```

---

## Data Persistence

### 1. SavedVariables Best Practices

**Structure your database:**
```lua
-- Good database structure
AddonDB = {
    version = "1.0",
    global = {
        -- Account-wide settings
        firstRun = true,
        announcements = {},
    },
    profiles = {
        ["CharName-RealmName"] = {
            -- Per-character data
            settings = {},
            data = {},
        },
    },
}
```

### 2. Migration Pattern

**Handle version upgrades:**
```lua
local DB_VERSION = 2

local function MigrateDatabase()
    if not AddonDB.version or AddonDB.version < DB_VERSION then
        local oldVersion = AddonDB.version or 0
        
        -- V1 to V2 migration
        if oldVersion < 2 then
            -- Rename old fields, restructure data, etc.
            if AddonDB.oldField then
                AddonDB.newField = AddonDB.oldField
                AddonDB.oldField = nil
            end
        end
        
        AddonDB.version = DB_VERSION
        print("AddonDB upgraded to version " .. DB_VERSION)
    end
end

-- Call on ADDON_LOADED
```

### 3. Character Key Pattern

**Unique per-character identification:**
```lua
local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

-- Usage:
local charKey = GetCharacterKey()
AddonDB.profiles[charKey] = AddonDB.profiles[charKey] or {}
```

---

## API Documentation Resources

### 1. Primary Resources

**WoWWiki (Classic/TBC):**
- https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API
- Best for TBC Classic API reference
- Shows which APIs existed in which patch

**Wowpedia:**
- https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- More modern, but still has classic info
- Good for general API understanding

**WoWHead Guides:**
- https://www.wowhead.com/guides/wow-addons
- Tutorial-focused content
- Good for learning patterns

### 2. Efficient API Lookup Strategy

**When you need to know:**

**"How do I do X?"** → Search pattern:
1. Search: "wow api [what you want to do]"
2. Example: "wow api get player health"
3. Look for Widget API, Lua API, or Event API pages

**"What does this function do?"** → Direct lookup:
1. Search: "wow api [FunctionName]"
2. Example: "wow api CreateFrame"
3. Check return values and parameters

**"What events exist for Y?"** → Event search:
1. Search: "wow events [system]"
2. Example: "wow events inventory"
3. Check event arguments

**"How do others solve Z?"** → GitHub search:
1. Search GitHub: "[feature] language:lua"
2. Example: "auction house scanner language:lua"
3. Read real addon code

### 3. In-Game API Discovery

**Use Lua to explore:**
```lua
-- List all global functions starting with "Unit"
for k, v in pairs(_G) do
    if type(v) == "function" and k:match("^Unit") then
        print(k)
    end
end

-- Check if a function exists
if UnitHealth then
    print("UnitHealth exists!")
end

-- Get function info (limited)
local health = UnitHealth("player")
print("Player health:", health)

-- Inspect frame methods
local frame = CreateFrame("Frame")
for k, v in pairs(getmetatable(frame).__index) do
    if type(v) == "function" then
        print("Frame method:", k)
    end
end
```

### 4. Documentation Reading Pattern

**When reading API docs:**

1. **Function Signature** - What parameters does it take?
   ```lua
   UnitHealth("unitId") → current, max
   ```

2. **Return Values** - What does it give back?
   - nil = doesn't exist or invalid
   - Multiple returns = capture them all

3. **Unit IDs** - Know the common ones:
   - "player", "target", "pet", "party1-4", "raid1-40"
   - "mouseover", "focus" (TBC+)

4. **API Availability** - Check if it exists in TBC
   - Look for "Added in patch X.X.X"
   - Test in-game with: `/run print(FunctionName)`

### 5. Testing API Calls In-Game

**Use /run for quick tests:**
```lua
-- Test a function exists
/run print(UnitName("player"))

-- Test an event fires
/run local f=CreateFrame("Frame") f:RegisterEvent("PLAYER_REGEN_DISABLED") f:SetScript("OnEvent",function() print("Combat!") end)

-- Inspect a value
/run print(GetMoney())

-- Test UI creation
/run local f=CreateFrame("Frame",nil,UIParent) f:SetSize(100,100) f:SetPoint("CENTER") f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background"}) f:Show()
```

---

## Best Practices

### 1. Performance

**❌ Avoid:**
- OnUpdate for everything (CPU intensive)
- Creating frames repeatedly
- String concatenation in loops
- Polling when events exist

**✅ Do:**
- Use events whenever possible
- Reuse frames (object pooling)
- Use table.concat for string building
- Cache repeated lookups

**Example - Frame pooling:**
```lua
local buttonPool = {}
local activeButtons = 0

local function GetButton()
    activeButtons = activeButtons + 1
    if not buttonPool[activeButtons] then
        buttonPool[activeButtons] = CreateFrame("Button", nil, parent)
        -- Setup button
    end
    return buttonPool[activeButtons]
end

local function ReleaseButtons()
    for i = 1, activeButtons do
        buttonPool[i]:Hide()
    end
    activeButtons = 0
end
```

### 2. Code Organization

**Separate concerns:**
```lua
-- Core.lua - Addon initialization and core logic
-- UI.lua - All UI creation
-- Config.lua - Configuration and defaults
-- Utils.lua - Helper functions
-- Events.lua - Event handlers
```

### 3. Error Handling

**Graceful degradation:**
```lua
local function SafeFunction()
    local success, result = pcall(function()
        -- Risky operation
        return DoSomethingRisky()
    end)
    
    if success then
        return result
    else
        print("AddonName: Error -", result)
        return nil
    end
end
```

### 4. User Feedback

**Always inform the user:**
```lua
-- Prefix addon messages
local function Print(msg)
    print("|cFF00FF00[MyAddon]|r " .. msg)
end

-- Use colors for context
local function PrintError(msg)
    print("|cFFFF0000[MyAddon]|r " .. msg)
end

-- Provide helpful errors
if not input then
    PrintError("Usage: /myaddon <command> <args>")
    return
end
```

### 5. Secure Code (Taint Avoidance)

**Avoid tainting Blizzard UI:**
```lua
-- ❌ Bad - Can taint Blizzard frames
WorldFrame:HookScript("OnUpdate", MyFunction)

-- ✅ Good - Use your own frames
local myFrame = CreateFrame("Frame")
myFrame:SetScript("OnUpdate", MyFunction)

-- ✅ Good - Secure hooks when needed
hooksecurefunc("FunctionName", function(...)
    -- Your code
end)
```

---

## Common Pitfalls

### 1. ADDON_LOADED vs PLAYER_LOGIN

**Problem:**
```lua
-- ❌ Wrong - Fires for ALL addons!
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function()
    -- This runs 50+ times for all addons!
    InitializeAddon()
end)
```

**Solution:**
```lua
-- ✅ Correct - Check addon name
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyAddonName" then
        InitializeAddon()
    end
end)
```

### 2. Frame Creation in Loops

**Problem:**
```lua
-- ❌ Bad - Creates 100 frames every time!
for i = 1, 100 do
    local frame = CreateFrame("Frame")
    -- ...
end
```

**Solution:**
```lua
-- ✅ Good - Reuse frames
local frames = {}
for i = 1, 100 do
    frames[i] = frames[i] or CreateFrame("Frame")
    -- Update existing frame
end
```

### 3. Not Cleaning Up

**Problem:**
```lua
-- ❌ Bad - Events keep firing!
local tempFrame = CreateFrame("Frame")
tempFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
tempFrame:SetScript("OnEvent", MyHandler)
-- Frame is garbage collected but events still fire!
```

**Solution:**
```lua
-- ✅ Good - Unregister when done
tempFrame:UnregisterAllEvents()
tempFrame:SetScript("OnEvent", nil)
```

### 4. String Concatenation in Loops

**Problem:**
```lua
-- ❌ Bad - Creates many temporary strings
local str = ""
for i = 1, 1000 do
    str = str .. i .. ", "  -- Very slow!
end
```

**Solution:**
```lua
-- ✅ Good - Use table.concat
local parts = {}
for i = 1, 1000 do
    parts[i] = i
end
local str = table.concat(parts, ", ")
```

### 5. Hardcoded Strings

**Problem:**
```lua
-- ❌ Bad - Not localizable
print("Hello, player!")
```

**Solution:**
```lua
-- ✅ Good - Use localization table
local L = {
    ["GREETING"] = "Hello, player!",
}

-- Create locale file for other languages
-- Locales/enUS.lua, Locales/deDE.lua, etc.

print(L["GREETING"])
```

---

## Quick Reference Checklist

**Starting a new addon:**
- [ ] Create TOC file with correct Interface version
- [ ] Use namespace pattern (local addon = {})
- [ ] Handle ADDON_LOADED with name check
- [ ] Initialize SavedVariables with defaults
- [ ] Register only needed events
- [ ] Create reusable UI templates
- [ ] Test in-game frequently
- [ ] Check for errors with /console scriptErrors 1

**Before release:**
- [ ] No global pollution (check with /print(_G.MyVar))
- [ ] All frames cleaned up properly
- [ ] SavedVariables version migration
- [ ] Helpful error messages
- [ ] Performance tested (OnUpdate usage minimal)
- [ ] Works with other addons (no taint)
- [ ] Tested on multiple characters

---

## Conclusion

WoW addon development follows established patterns that prioritize:
1. **Clean code** - Namespaced, modular, readable
2. **Performance** - Event-driven, efficient, cached
3. **Persistence** - Proper SavedVariables usage
4. **User experience** - Feedback, error handling, intuitive UI
