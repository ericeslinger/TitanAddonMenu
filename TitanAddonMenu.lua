--[[ TitanAddonMenu

One Titan Panel button that gathers every addon's "open my config" entry point
into a single menu:

  1. LibDataBroker launchers   - the minimap-button convention (Bartender4, Masque, Plater, ...)
  2. Addon Compartment entries - addons that declare AddonCompartmentFunc in their TOC
  3. Slash commands            - a user-maintained list for addons that expose neither
                                 (Arc Auras, Shadowed Unit Frames, ...)

Click the button for the menu. Clicking a launcher entry sends its left-click;
hover it for a submenu with explicit Left click / Right click (Bartender4, for
example, unlocks bars on left and opens options on right). No bar tooltip: the
menu is the summary.

  /addonmenu                 show help
  /addonmenu list            list the slash entries
  /addonmenu add /cmd Label  add a slash entry
  /addonmenu remove /cmd     remove a slash entry
  /addonmenu reset           restore the default slash entries

Written as an LDB launcher so Titan wraps it with its own plugin frame; this is
the integration path the Titan developer docs recommend (see Titan/_ATitanDoc.lua
and the TitanUI example plugin).
--]]

local ADDON, NS = ...

local ldb = LibStub("LibDataBroker-1.1")

local TITLE = "Addons"
local SELF_NAME = ADDON -- our own LDB object name; excluded from the launcher list

local DEFAULT_SLASH = {
    { cmd = "/arcauras", label = "Arc Auras" },
    { cmd = "/suf",      label = "Shadowed Unit Frames" },
}

local frame = CreateFrame("Frame", ADDON .. "Frame", UIParent)

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3fc9f2" .. TITLE .. "|r: " .. tostring(msg))
end

local function Norm(s)
    return (tostring(s or ""):lower():gsub("[^%w]", ""))
end

local function SortByLabel(list)
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

-- The Titan frame that wraps an LDB object, if Titan has created one.
local function TitanFrameFor(name)
    if TitanUtils_ButtonName then
        local f = _G[TitanUtils_ButtonName(name)]
        if f then return f end
    end
    return frame
end

-- Run a slash command without going through the chat edit box when possible:
-- look it up in SlashCmdList and call the handler directly.
local function RunSlash(cmdline)
    local cmd, args = cmdline:match("^(%S+)%s*(.*)$")
    if not cmd then return end
    cmd = cmd:lower()
    for key, handler in pairs(SlashCmdList) do
        local i = 1
        while true do
            local s = _G["SLASH_" .. key .. i]
            if not s then break end
            if s:lower() == cmd then
                local ok, err = pcall(handler, args or "", DEFAULT_CHAT_FRAME.editBox)
                if not ok then Print(cmd .. " failed: " .. tostring(err)) end
                return true
            end
            i = i + 1
        end
    end
    -- Fallback: send it through chat like a typed command.
    local box = DEFAULT_CHAT_FRAME.editBox
    box:SetText(cmdline)
    ChatEdit_SendText(box, 0)
    return false
end

-- ---------------------------------------------------------------------------
-- sources
-- ---------------------------------------------------------------------------

-- 1. LDB launchers
local function CollectLaunchers()
    local out = {}
    for name, obj in ldb:DataObjectIterator() do
        if name ~= SELF_NAME and obj.type == "launcher" and type(obj.OnClick) == "function" then
            out[#out + 1] = {
                label = tostring(obj.label or name),
                key   = Norm(obj.label or name),
                run   = function(button)
                    local ok, err = pcall(obj.OnClick, TitanFrameFor(name), button or "LeftButton")
                    if not ok then Print(name .. " failed: " .. tostring(err)) end
                end,
            }
        end
    end
    return SortByLabel(out)
end

-- 2. Addon Compartment registrations (TOC: ## AddonCompartmentFunc: GlobalFuncName)
local function CollectCompartment(seen)
    local out = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if C_AddOns.IsAddOnLoaded(i) then
            local fn = C_AddOns.GetAddOnMetadata(i, "AddonCompartmentFunc")
            if fn and type(_G[fn]) == "function" then
                local label = (title or name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local key = Norm(name)
                -- skip addons already reachable through their LDB launcher
                local dup = false
                for k in pairs(seen) do
                    if k ~= "" and (key:find(k, 1, true) or k:find(key, 1, true)) then dup = true break end
                end
                if not dup then
                    out[#out + 1] = {
                        label = label,
                        run   = function(button)
                            local ok, err = pcall(_G[fn], name, button or "LeftButton")
                            if not ok then Print(name .. " failed: " .. tostring(err)) end
                        end,
                    }
                end
            end
        end
    end
    return SortByLabel(out)
end

-- 3. user slash list
local function CollectSlash()
    local out = {}
    for _, e in ipairs(TitanAddonMenuDB.slash) do
        out[#out + 1] = { label = e.label, cmd = e.cmd, run = function() RunSlash(e.cmd) end }
    end
    return SortByLabel(out)
end

local function Collect()
    local launchers = CollectLaunchers()
    local seen = {}
    for _, e in ipairs(launchers) do seen[e.key] = true end
    return launchers, CollectCompartment(seen), CollectSlash()
end

-- ---------------------------------------------------------------------------
-- menu + tooltip
-- ---------------------------------------------------------------------------

-- Each launcher entry runs its left-click when clicked and carries a submenu
-- with explicit "Left click" / "Right click" items, for addons whose launcher
-- does two different things (Bartender4: unlock bars / open options). Blizzard's
-- menu does not reliably report a right-click on an entry, hence the submenu.
local function AddSection(root, title, entries, extra, withButtons)
    if #entries == 0 then return end
    root:CreateDivider()
    root:CreateTitle(title, GRAY_FONT_COLOR)
    for _, e in ipairs(entries) do
        local label = extra and extra(e) or e.label
        local item = root:CreateButton(label, function() e.run("LeftButton") end)
        if withButtons and item and item.CreateButton then
            item:CreateButton("Left click", function() e.run("LeftButton") end)
            item:CreateButton("Right click", function() e.run("RightButton") end)
        end
    end
end

local function OpenMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TITLE)
        local launchers, compartment, slash = Collect()
        local ok, err = pcall(function()
            AddSection(root, "Launchers", launchers, nil, true)
            AddSection(root, "Addon Compartment", compartment, nil, true)
            AddSection(root, "Slash commands", slash, function(e)
                return e.label .. "  |cff808080" .. e.cmd .. "|r"
            end)
        end)
        if not ok then
            root:CreateDivider()
            root:CreateTitle("error: " .. tostring(err), RED_FONT_COLOR)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- slash command for managing the slash list
-- ---------------------------------------------------------------------------

local function ResetDefaults()
    TitanAddonMenuDB.slash = {}
    for _, e in ipairs(DEFAULT_SLASH) do
        TitanAddonMenuDB.slash[#TitanAddonMenuDB.slash + 1] = { cmd = e.cmd, label = e.label }
    end
end

local function Help()
    Print("usage:")
    Print("  /addonmenu list")
    Print("  /addonmenu add /command Label text")
    Print("  /addonmenu remove /command")
    Print("  /addonmenu reset")
end

SLASH_TITANADDONMENU1 = "/addonmenu"
SLASH_TITANADDONMENU2 = "/tam"
SlashCmdList.TITANADDONMENU = function(msg)
    local sub, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    if sub == "list" then
        for _, e in ipairs(TitanAddonMenuDB.slash) do Print(e.cmd .. "  " .. e.label) end
        if #TitanAddonMenuDB.slash == 0 then Print("(no slash entries)") end
    elseif sub == "add" then
        local cmd, label = rest:match("^(/%S+)%s*(.*)$")
        if not cmd then return Help() end
        if label == "" then label = cmd end
        for _, e in ipairs(TitanAddonMenuDB.slash) do
            if e.cmd:lower() == cmd:lower() then e.label = label Print("updated " .. cmd) return end
        end
        TitanAddonMenuDB.slash[#TitanAddonMenuDB.slash + 1] = { cmd = cmd, label = label }
        Print("added " .. cmd .. " as '" .. label .. "'")
    elseif sub == "remove" then
        local cmd = rest:match("^(/%S+)")
        if not cmd then return Help() end
        for i, e in ipairs(TitanAddonMenuDB.slash) do
            if e.cmd:lower() == cmd:lower() then
                table.remove(TitanAddonMenuDB.slash, i)
                Print("removed " .. cmd)
                return
            end
        end
        Print(cmd .. " not found")
    elseif sub == "reset" then
        ResetDefaults()
        Print("slash entries reset to defaults")
    else
        Help()
    end
end

-- ---------------------------------------------------------------------------
-- init
-- ---------------------------------------------------------------------------

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    TitanAddonMenuDB = TitanAddonMenuDB or {}
    if type(TitanAddonMenuDB.slash) ~= "table" then ResetDefaults() end

    ldb:NewDataObject(SELF_NAME, {
        type          = "launcher",
        icon          = "Interface\\Icons\\INV_Misc_Gear_01",
        label         = TITLE,
        text          = TITLE,
        OnClick       = function(owner, button)
            if button == "LeftButton" or button == "RightButton" then OpenMenu(owner) end
        end,
        -- Titan-specific metadata
        category      = "Interface",
        notes         = "Gathers every addon's config entry point into one menu.",
    })
end)
