BurningRushReminderDB = BurningRushReminderDB or {}

local frame = CreateFrame("Frame", "BurningRushReminderFrame", UIParent)
frame:SetSize(300, 60)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetMovable(true)

local function GetCentreRelative()
    local screenCX = UIParent:GetWidth() / 2
    local screenCY = UIParent:GetHeight() / 2
    local frameCX, frameCY = frame:GetCenter()
    if not frameCX then return 0, 0 end
    return frameCX - screenCX, frameCY - screenCY
end

frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    if BurningRushReminder_DragPollerShow then BurningRushReminder_DragPollerShow() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if BurningRushReminder_DragPollerHide then BurningRushReminder_DragPollerHide() end
    local x, y = GetCentreRelative()
    BurningRushReminderDB.x = x
    BurningRushReminderDB.y = y
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", x, y)
end)

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")
text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
text:SetText("BURNING RUSH ACTIVE!")

-- ============================================================
-- ANIMATION
-- ============================================================

local glowTimer = 0
local lastEffect = nil

local function Lerp(a, b, t) return a + (b - a) * t end

local animFrame = CreateFrame("Frame", nil, UIParent)
animFrame:Hide()
animFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = BurningRushReminderDB
    local effect = db.effect or "none"
    local speed = db.effectSpeed or 1.5
    local hz = speed
    glowTimer = glowTimer + elapsed
    local sine = (math.sin(glowTimer * hz * math.pi * 2) + 1) / 2

    if effect == "pulse" then
        text:SetAlpha(0.2 + sine * 0.8)
        local c = db.colour or { r = 1, g = 0.2, b = 0.2 }
        text:SetTextColor(c.r, c.g, c.b)
    elseif effect == "flash" then
        text:SetAlpha(1)
        local c  = db.colour      or { r = 1, g = 0.2, b = 0.2 }
        local fc = db.flashColour or { r = 1, g = 1,   b = 0    }
        text:SetTextColor(
            Lerp(c.r, fc.r, sine),
            Lerp(c.g, fc.g, sine),
            Lerp(c.b, fc.b, sine)
        )
    else
        text:SetAlpha(1)
        self:Hide()
    end
end)

local function ApplyEffect()
    local effect = BurningRushReminderDB.effect or "none"
    if effect ~= lastEffect then
        glowTimer = 0
        lastEffect = effect
    end
    text:SetAlpha(1)
    local c = BurningRushReminderDB.colour or { r = 1, g = 0.2, b = 0.2 }
    text:SetTextColor(c.r, c.g, c.b)
    if effect == "pulse" or effect == "flash" then
        animFrame:Show()
    else
        animFrame:Hide()
    end
end

function BurningRushReminder_ApplyEffect() ApplyEffect() end

local DEFAULT_FONT   = "Fonts\\FRIZQT__.TTF"
local DEFAULT_COLOUR = { r = 1, g = 0.2, b = 0.2 }

local function ApplyFont()
    local db = BurningRushReminderDB
    local font = (db and db.font) or DEFAULT_FONT
    local size = (db and db.fontSize) or 20
    local style = db.textStyle or "outline"
    font = font:gsub("/", "\\")

    local flags = ""
    if style == "outline" then
        flags = "OUTLINE"
    elseif style == "thickoutline" then
        flags = "THICKOUTLINE"
    end

    local success = text:SetFont(font, size, flags)
    if not success then
        text:SetFont(DEFAULT_FONT, size, flags)
    end

    if style == "shadow" then
        text:SetShadowOffset(2, -2)
        text:SetShadowColor(0, 0, 0, 1)
    else
        text:SetShadowOffset(0, 0)
        text:SetShadowColor(0, 0, 0, 0)
    end
end

local function ApplyColour(r, g, b)
    if not r then
        local c = BurningRushReminderDB.colour or DEFAULT_COLOUR
        r, g, b = c.r, c.g, c.b
    end
    local effect = BurningRushReminderDB.effect or "none"
    if effect == "none" then
        text:SetTextColor(r, g, b)
    end
end

local function ApplyLock()
    local locked = BurningRushReminderDB.locked
    if locked == nil then locked = true end
    if locked then
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetFrameStrata("MEDIUM")
    else
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetFrameStrata("TOOLTIP")
    end
end

frame:Hide()

local burningRushActive = false
local burningRushInstanceID = nil
local expectingAura = false
local previewActive = false

local function UpdateReminder()
    if previewActive then
        frame:Show()
        ApplyEffect()
        return
    end
    if BurningRushReminderDB.enabled and InCombatLockdown() and burningRushActive then
        frame:Show()
        ApplyEffect()
    else
        frame:Hide()
        animFrame:Hide()
        text:SetAlpha(1)
        local c = BurningRushReminderDB.colour or DEFAULT_COLOUR
        text:SetTextColor(c.r, c.g, c.b)
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
        local db = BurningRushReminderDB
        if db.enabled == nil then db.enabled = true end
        if db.x == nil then db.x = 0 end
        if db.y == nil then db.y = 200 end
        if db.fontSize == nil then db.fontSize = 20 end
        if db.locked == nil then db.locked = true end
        if db.font == nil then db.font = DEFAULT_FONT end
        if db.fontName == nil then db.fontName = "Default (Friz Quadrata)" end
        if db.colour == nil then db.colour = { r = DEFAULT_COLOUR.r, g = DEFAULT_COLOUR.g, b = DEFAULT_COLOUR.b } end
        if db.effect == nil then db.effect = "none" end
        if db.effectSpeed == nil or type(db.effectSpeed) == "string" then db.effectSpeed = 1.5 end
        if db.flashColour == nil then db.flashColour = { r = 1, g = 1, b = 0 } end
        if db.textStyle == nil then db.textStyle = "outline" end

        ApplyColour()
        ApplyLock()
        ApplyEffect()
        ApplyFont()
        C_Timer.After(0, ApplyFont)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)

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

    elseif event == "PLAYER_REGEN_DISABLED" then
        local i = 1
        while true do
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            if not aura then break end
            if aura.spellId == BURNING_RUSH_SPELL_ID then
                burningRushActive = true
                burningRushInstanceID = aura.auraInstanceID
                break
            end
            i = i + 1
        end
    end

    UpdateReminder()
end)

SLASH_BURNINGRUSH1 = "/brr"
SlashCmdList["BURNINGRUSH"] = function()
    if BurningRushReminderCategory then
        Settings.OpenToCategory(BurningRushReminderCategory:GetID())
    end
end
