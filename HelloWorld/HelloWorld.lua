-- HelloWorld.lua
-- A simple Hello World addon for WoW TBC Classic

-- Initialize saved variables (will be loaded from SavedVariables file)
HelloWorldDB = HelloWorldDB or {}
HelloWorldDB.messages = HelloWorldDB.messages or {}

-- Create the main UI window
local mainFrame = CreateFrame("Frame", "HelloWorldFrame", UIParent)
mainFrame:SetWidth(300)
mainFrame:SetHeight(200)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide() -- Hidden by default

-- Create the background
local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(mainFrame)
bg:SetColorTexture(0, 0, 0, 0.8) -- Black with 80% opacity

-- Create a border
local border = mainFrame:CreateTexture(nil, "BORDER")
border:SetColorTexture(0.5, 0.5, 0.5, 1) -- Gray border
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)

-- Create the title bar background
local titleBg = mainFrame:CreateTexture(nil, "ARTWORK")
titleBg:SetHeight(30)
titleBg:SetPoint("TOPLEFT", 0, 0)
titleBg:SetPoint("TOPRIGHT", 0, 0)
titleBg:SetColorTexture(0.2, 0.2, 0.8, 1) -- Blue title bar

-- Create the title text
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -8)
title:SetText("Hello World Addon")

-- Create a scrollable message area
local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

-- Create the content frame for messages
local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetWidth(250)
contentFrame:SetHeight(1) -- Will be adjusted based on content
scrollFrame:SetScrollChild(contentFrame)

-- Create the message text in the content frame
local messageText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
messageText:SetPoint("TOPLEFT", 5, -5)
messageText:SetWidth(240)
messageText:SetJustifyH("LEFT")
messageText:SetText("No messages yet. Type /hw <message> to add one!")

-- Function to update the message display
local function UpdateMessageDisplay()
    if #HelloWorldDB.messages == 0 then
        messageText:SetText("No messages yet. Type /hw <message> to add one!")
        contentFrame:SetHeight(50)
    else
        local displayText = "Message History (" .. #HelloWorldDB.messages .. " total):\n\n"
        for i, msg in ipairs(HelloWorldDB.messages) do
            displayText = displayText .. i .. ". " .. msg .. "\n"
        end
        messageText:SetText(displayText)
        
        -- Adjust content height based on text
        local textHeight = messageText:GetStringHeight()
        contentFrame:SetHeight(math.max(textHeight + 20, 120))
    end
end

-- Create a clear button
local clearButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
clearButton:SetWidth(100)
clearButton:SetHeight(25)
clearButton:SetPoint("BOTTOM", 0, 10)
clearButton:SetText("Clear History")
clearButton:SetScript("OnClick", function()
    HelloWorldDB.messages = {}
    UpdateMessageDisplay()
    print("HelloWorld: Message history cleared!")
end)

-- Create a close button
local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)
closeButton:SetWidth(20)
closeButton:SetHeight(20)
closeButton:SetScript("OnClick", function()
    mainFrame:Hide()
end)

-- Create an event frame to listen for game events
local eventFrame = CreateFrame("Frame")

-- Function to print our hello world message on login
local function OnPlayerLogin()
    print("Hello World addon loaded! Type /hw to open the window.")
    print("HelloWorld: Loaded " .. #HelloWorldDB.messages .. " saved messages.")
    UpdateMessageDisplay()
end

-- Register for the PLAYER_LOGIN event
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Set up event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)

-- Function to toggle the window
local function ToggleWindow()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

-- Create slash commands with subcommand support
SLASH_HELLOWORLD1 = "/helloworld"
SLASH_HELLOWORLD2 = "/hw"
SlashCmdList["HELLOWORLD"] = function(msg)
    -- Parse the command and arguments
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()
    
    if command == "open" then
        mainFrame:Show()
        print("HelloWorld: Window opened.")
        
    elseif command == "close" then
        mainFrame:Hide()
        print("HelloWorld: Window closed.")
        
    elseif command == "write" then
        if rest and rest ~= "" then
            table.insert(HelloWorldDB.messages, rest)
            print("HelloWorld: Message saved! (Total: " .. #HelloWorldDB.messages .. ")")
            UpdateMessageDisplay()
        else
            print("HelloWorld: Usage - /hw write <message>")
        end
        
    elseif command == "clear" then
        HelloWorldDB.messages = {}
        UpdateMessageDisplay()
        print("HelloWorld: Message history cleared!")
        
    elseif command == "help" or command == "" then
        print("HelloWorld Commands:")
        print("  /hw open - Open the message window")
        print("  /hw close - Close the message window")
        print("  /hw write <message> - Save a message without toggling window")
        print("  /hw clear - Clear all saved messages")
        print("  /hw help - Show this help message")
        
    else
        -- If no recognized command, treat entire input as a message
        table.insert(HelloWorldDB.messages, msg)
        print("HelloWorld: Message saved! (Total: " .. #HelloWorldDB.messages .. ")")
        UpdateMessageDisplay()
        ToggleWindow()
    end
end
