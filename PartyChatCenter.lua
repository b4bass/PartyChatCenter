-- PartyChatCenter.lua
-- Core addon declaration and static data (localization, defaults, commands)
local addonName, addon = ...

-- SavedVariables setup
_G["ChatEnhancerDB"] = _G["ChatEnhancerDB"] or {}

-- Default configuration, stored in addon table
addon.defaults = {
    point = "TOP",
    x = 0,
    y = -250,
    fontSize = 18,
    timeVisible = 4,
    fontOpacity = 1.0,
    useBackground = false,
    bgOpacity = 1,
    chatOrder = "TOP",
    showNames = true,
    showAllChat = true,
    filterQuestie = true,
    filterOwnMessages = false,
    colorMessages = false,
    locationMode = 3,
    alertKeywords = "Be careful\nMana\nPatrol",
    alertModeEnabled = false,
    alertSound = true,
    highlightKeyword = true,
}

-- Localization strings for UI and messages, stored in addon table
addon.L = {
    TITLE = "Chat Enhancer",
    OPTIONS = "Chat Enhancer Options",
    FONT_SIZE = "Font Size",
    DISPLAY_TIME = "Display Time",
    FONT_OPACITY = "Font Opacity",
    BG_OPACITY = "Background Opacity",
    REVERSE_CHAT = "Reverse Chat Order",
    SHOW_NAMES = "Show Names",
    SHOW_ALL_CHAT = "Show All Chat",
    FILTER_QUESTIE = "Filter Questie Messages",
    FILTER_OWN = "Filter Your Messages",
    COLOR_MESSAGES = "Color Messages",
    LOCATION_MODE = "Location Mode",
    LOCATION_DUNGEON = "Dungeon Only",
    LOCATION_WORLD = "World Only",
    LOCATION_BOTH = "Both",
    SECTION_DISPLAY = "Display Settings",
    SECTION_FILTERS = "Filter Settings",
    SECTION_BEHAVIOR = "Behavior Settings",
    SECTION_ALERT = "Alert Settings",
    RESET_ALL = "Reset All",
    ALERT_KEYWORDS = "Alert Keywords",
    ALERT_MODE_ENABLED = "Enable Alert Only Mode",
    ALERT_SOUND = "Alert Sound",
    HIGHLIGHT_KEYWORD = "Highlight Alert Keyword",
    POSITION_RESET = "Chat Enhancer: Position reset",
    FONT_SET = "Chat Enhancer: Font size set to %d",
    TIME_SET = "Chat Enhancer: Display time set to %d seconds",
    RESET_CONFIRM = "Chat Enhancer: All settings reset to defaults",
    TOOLTIP_fontsize = "Adjust the font size of chat messages (12-28).",
    TOOLTIP_displaytime = "Set how long messages remain visible in seconds (1-8s).",
    TOOLTIP_fontopacity = "Adjust the transparency of chat text (0.1-1.0).",
    TOOLTIP_bgopacity = "Adjust the transparency of the background when shown (0.1-1.0).",
    TOOLTIP_reversechat = "Reverse the order of chat messages (newest at bottom vs. top).",
    TOOLTIP_shownames = "Toggle displaying sender names before messages.",
    TOOLTIP_showallchat = "Show all chat types (say, yell) in addition to party/raid chat.",
    TOOLTIP_filterquestie = "Filter out messages containing 'Questie' to reduce clutter.",
    TOOLTIP_filterown = "Filter out your own messages from being displayed.",
    TOOLTIP_colormessages = "Color messages by type: Say (white), Party (blue), Yell (red), Raid (purple).",
    TOOLTIP_locationmode = "Choose where the addon operates: Dungeon, World, or Both.",
    TOOLTIP_alertkeywords = "Enter newline-separated keywords or phrases to trigger alerts (e.g., 'Be careful\nMana\nPatrol').",
    TOOLTIP_alertmodeenabled = "Enable alert-only mode to show messages only with keywords.",
    TOOLTIP_alertsound = "Toggle a ding sound when a keyword is detected in alert-only mode.",
    TOOLTIP_highlightkeyword = "Highlight alert keywords in red.",
}

-- Slash command handler
SLASH_CHATENHANCER1 = "/ce"
SlashCmdList["CHATENHANCER"] = function(msg)
    msg = msg:lower()
    if msg == "reset" then
        addon.frame:ClearAllPoints()
        addon.frame:SetPoint(addon.defaults.point, addon.defaults.x, addon.defaults.y)
        addon.cfg.point = addon.defaults.point
        addon.cfg.x = addon.defaults.x
        addon.cfg.y = addon.defaults.y
        print(addon.L.POSITION_RESET)
    elseif msg:match("^font%s+(%d+)$") then
        local size = tonumber(msg:match("^font%s+(%d+)$"))
        if size and size >= 12 and size <= 28 then
            addon.cfg.fontSize = size
            addon.frame:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
            print(string.format(addon.L.FONT_SET, size))
        end
    elseif msg:match("^time%s+(%d+)$") then
        local time = tonumber(msg:match("^time%s+(%d+)$"))
        if time and time >= 1 and time <= 6 then
            addon.cfg.timeVisible = time
            addon.frame:SetTimeVisible(time)
            print(string.format(addon.L.TIME_SET, time))
        end
    elseif msg == "test" then
        addon.frame:AddMessage(addon.cfg.showNames and 
            ("|cff" .. string.format("%02x%02x%02x", 255, 128, 0) .. "Test Player|r: This is a test message") or 
            "This is a test message")
    else
        addon.ShowOptions()
    end
end