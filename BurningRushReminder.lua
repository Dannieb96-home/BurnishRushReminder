-- Default settings
BurningRushReminderDB = BurningRushReminderDB or {}
if BurningRushReminderDB.enabled == nil then BurningRushReminderDB.enabled = true end
if BurningRushReminderDB.x == nil then BurningRushReminderDB.x = 0 end
if BurningRushReminderDB.y == nil then BurningRushReminderDB.y = 200 end
if BurningRushReminderDB.fontSize == nil then BurningRushReminderDB.fontSize = 20 end
if BurningRushReminderDB.locked == nil then BurningRushReminderDB.locked = true end
if BurningRushReminderDB.font == nil then BurningRushReminderDB.font = "Fonts\\FRIZQT__.TTF" end
if BurningRushReminderDB.colour == nil then BurningRushReminderDB.colour = { r = 1, g = 0.2, b = 0.2 } end

-- Warning frame
local frame = CreateFrame("Frame", "BurningRushReminderFrame", UIParent)
frame:SetSize(300, 60)
frame:SetPoint("CENTER", UIParent, "CENTER", BurningRushReminderDB.x, BurningRushReminderDB.y)
frame:SetMovable(true)
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    BurningRushReminderDB.x = x
    BurningRushReminderDB.y = y
end)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER")
text:SetText("BURNING RUSH ACTIVE!")

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local function ApplyFont()
    local font = BurningRushReminderDB.font or DEFAULT_FONT
    local size = BurningRushReminderDB.fontSize or 20
    local success = text:SetFont(font, size, "OUTLINE")
    if not success then
        BurningRushReminderDB.font = DEFAULT_FONT
        text:SetFont(DEFAULT_FONT, size, "OUTLINE")
    end
end
ApplyFont()

local function ApplyColour(r, g, b)
    local c = BurningRushReminderDB.colour
    r = r or (c and c.r) or 1
    g = g or (c and c.g) or 0.2
    b = b or (c and c.b) or 0.2
    text:SetTextColor(r, g, b)
end
ApplyColour()

local function ApplyLock()
    if BurningRushReminderDB.locked then
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetFrameStrata("MEDIUM")
    else
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetFrameStrata("TOOLTIP")
    end
end
ApplyLock()

frame:Hide()

local burningRushActive = false
local burningRushInstanceID = nil
local expectingAura = false
local previewActive = false

local function UpdateReminder()
    if previewActive then
        frame:Show()
        return
    end
    if BurningRushReminderDB.enabled and InCombatLockdown() and burningRushActive then
        frame:Show()
    else
        frame:Hide()
    end
end

function BurningRushReminder_UpdateReminder() UpdateReminder() end
function BurningRushReminder_ApplyFont() ApplyFont() end
function BurningRushReminder_ApplyColour(r, g, b) ApplyColour(r, g, b) end
function BurningRushReminder_ApplyLock() ApplyLock() end
function BurningRushReminder_SetPreview(state)
    previewActive = state
    UpdateReminder()
end

local BURNING_RUSH_SPELL_ID = 111400

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellId)
    if event == "ADDON_LOADED" and unit == "BurningRushReminder" then
        ApplyFont()
        ApplyColour()
        ApplyLock()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", BurningRushReminderDB.x, BurningRushReminderDB.y)
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellId == BURNING_RUSH_SPELL_ID then
            expectingAura = true
        end

    elseif event == "UNIT_AURA" and unit == "player" then
        local updateInfo = castGUID
        if updateInfo then
            if expectingAura and updateInfo.addedAuras then
                local aura = updateInfo.addedAuras[1]
                if aura then
                    burningRushInstanceID = aura.auraInstanceID
                    burningRushActive = true
                    expectingAura = false
                end
            end
            if updateInfo.removedAuraInstanceIDs and burningRushInstanceID then
                for _, instanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
                    if instanceID == burningRushInstanceID then
                        burningRushActive = false
                        burningRushInstanceID = nil
                    end
                end
            end
        end

    elseif event == "PLAYER_DEAD" then
        burningRushActive = false
        burningRushInstanceID = nil
        expectingAura = false

    elseif event == "PLAYER_REGEN_ENABLED" then
        burningRushActive = false
        burningRushInstanceID = nil
        expectingAura = false
    end

    UpdateReminder()
end)

SLASH_BURNINGRUSH1 = "/brr"
SlashCmdList["BURNINGRUSH"] = function()
    if BurningRushReminderCategory then
        Settings.OpenToCategory(BurningRushReminderCategory:GetID())
    end
end
