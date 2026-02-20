local LSM = LibStub("LibSharedMedia-3.0", true)

-- Temporary font string used to validate font paths
local validationString = UIParent:CreateFontString(nil, "ARTWORK")

local function IsValidFont(path)
    return validationString:SetFont(path, 12, "") == true
end

local function GetFonts()
    local fonts = {
        { name = "Default (Friz Quadrata)", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
        { name = "Morpheus (Quest)",        path = "Fonts\\MORPHEUS.TTF" },
        { name = "Skurri (Combat)",         path = "Fonts\\SKURRI.TTF" },
    }
    if LSM then
        for name, path in pairs(LSM:HashTable("font")) do
            local alreadyAdded = false
            for _, f in ipairs(fonts) do
                if f.path == path then alreadyAdded = true break end
            end
            if not alreadyAdded and IsValidFont(path) then
                table.insert(fonts, { name = name, path = path })
            end
        end
        table.sort(fonts, function(a, b) return a.name < b.name end)
    end
    return fonts
end

local function GetFontName(path)
    if BurningRushReminderDB and BurningRushReminderDB.fontName then
        if BurningRushReminderDB.font == path then
            return BurningRushReminderDB.fontName
        end
    end
    for _, f in ipairs(GetFonts()) do
        if f.path == path then return f.name end
    end
    return "Default (Friz Quadrata)"
end

local panel = CreateFrame("Frame")
panel.name = "Burning Rush Reminder"

panel:SetScript("OnShow", function()
    if BurningRushReminder_SetPreview then BurningRushReminder_SetPreview(true) end
end)
panel:SetScript("OnHide", function()
    if BurningRushReminder_SetPreview then BurningRushReminder_SetPreview(false) end
end)

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Burning Rush Reminder")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Warns you when Burning Rush is active in combat.")

-- Enable checkbox
local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
checkbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
checkbox.Text:SetText("Enable Burning Rush Reminder")
checkbox:SetScript("OnClick", function(self)
    BurningRushReminderDB.enabled = self:GetChecked()
    if BurningRushReminder_UpdateReminder then BurningRushReminder_UpdateReminder() end
end)

-- Lock checkbox
local lockCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -8)
lockCheckbox.Text:SetText("Lock frame position (uncheck to drag)")

local SLIDER_WIDTH = 300
local POS_RANGE = 1000
local MARKER_INTERVAL = 200

-- Helper: build a slider with tick marks and a typeable input box
-- Returns slider, inputBox, containerBottom (frame to anchor next element below)
local function MakePositionSlider(parent, anchorFrame, labelText, onChanged)
    -- Label
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -20)
    label:SetText(labelText .. ": 0")

    -- Slider
    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    sl:SetMinMaxValues(-POS_RANGE, POS_RANGE)
    sl:SetValueStep(1)
    sl:SetWidth(SLIDER_WIDTH)
    sl.Low:SetText("-1000")
    sl.High:SetText("1000")
    sl.Text:SetText("")

    -- Tick marks container parented to slider
    local tickContainer = CreateFrame("Frame", nil, sl)
    tickContainer:SetAllPoints(sl)

    -- One tick per MARKER_INTERVAL, skip -1000 and 1000 (already shown as Low/High)
    for v = -POS_RANGE + MARKER_INTERVAL, POS_RANGE - MARKER_INTERVAL, MARKER_INTERVAL do
        local frac = (v - (-POS_RANGE)) / (2 * POS_RANGE)  -- 0..1
        local tick = tickContainer:CreateTexture(nil, "ARTWORK")
        if v == 0 then
            -- centre marker: taller and brighter
            tick:SetSize(2, 10)
            tick:SetColorTexture(1, 1, 1, 0.9)
        else
            tick:SetSize(1, 6)
            tick:SetColorTexture(1, 1, 1, 0.45)
        end
        tick:SetPoint("BOTTOM", tickContainer, "BOTTOMLEFT", frac * SLIDER_WIDTH, 4)
    end

    -- Input box
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(52, 20)
    input:SetPoint("LEFT", sl, "RIGHT", 12, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(5)

    -- Allow negative sign + digits
    input:SetScript("OnChar", function(self, char)
        local text = self:GetText()
        if not char:match("[%-%d]") then
            self:SetText(text:gsub(char, ""))
        end
        -- only allow minus as first char
        if char == "-" and self:GetCursorPosition() ~= 1 then
            self:SetText(text:gsub("%-", ""))
        end
    end)

    local updating = false

    sl:SetScript("OnValueChanged", function(self, value)
        if updating then return end
        value = math.floor(value)
        label:SetText(labelText .. ": " .. value)
        input:SetText(tostring(value))
        onChanged(value)
    end)

    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(-POS_RANGE, math.min(POS_RANGE, value))
            updating = true
            sl:SetValue(value)
            updating = false
            label:SetText(labelText .. ": " .. value)
            input:SetText(tostring(value))
            onChanged(value)
        else
            input:SetText(tostring(math.floor(sl:GetValue())))
        end
        self:ClearFocus()
    end)

    input:SetScript("OnEscapePressed", function(self)
        input:SetText(tostring(math.floor(sl:GetValue())))
        self:ClearFocus()
    end)

    -- Return references needed by caller
    return label, sl, input, updating
end

-- Declare all position controls early so UpdatePositionButtons can reference them
local centerHBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
local centerVBtn = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")

local xLabel, xSlider, xInput
local yLabel, ySlider, yInput
local updatingX = false
local updatingY = false

local function UpdatePositionButtons()
    local unlocked = not BurningRushReminderDB.locked
    local alpha = unlocked and 1 or 0.4
    centerHBtn:SetEnabled(unlocked)
    centerVBtn:SetEnabled(unlocked)
    centerHBtn:SetAlpha(alpha)
    centerVBtn:SetAlpha(alpha)
    if xSlider then
        xSlider:SetEnabled(unlocked)
        xSlider:SetAlpha(alpha)
        xInput:SetEnabled(unlocked)
        xInput:SetAlpha(alpha)
    end
    if ySlider then
        ySlider:SetEnabled(unlocked)
        ySlider:SetAlpha(alpha)
        yInput:SetEnabled(unlocked)
        yInput:SetAlpha(alpha)
    end
end

lockCheckbox:SetScript("OnClick", function(self)
    BurningRushReminderDB.locked = self:GetChecked()
    if BurningRushReminder_ApplyLock then BurningRushReminder_ApplyLock() end
    UpdatePositionButtons()
end)

-- Center horizontal button
centerHBtn:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 2, -8)
centerHBtn:SetSize(140, 28)
centerHBtn:SetText("Center Horizontal")
centerHBtn:SetScript("OnClick", function()
    local screenCY = UIParent:GetHeight() / 2
    local _, frameCY = BurningRushReminderFrame:GetCenter()
    local currentY = frameCY - screenCY
    BurningRushReminderDB.x = 0
    BurningRushReminderDB.y = currentY
    BurningRushReminderFrame:ClearAllPoints()
    BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", 0, currentY)
    updatingX = true
    xSlider:SetValue(0)
    updatingX = false
    xLabel:SetText("X Position: 0")
    xInput:SetText("0")
end)

-- Center vertical button
centerVBtn:SetPoint("LEFT", centerHBtn, "RIGHT", 6, 0)
centerVBtn:SetSize(140, 28)
centerVBtn:SetText("Center Vertical")
centerVBtn:SetScript("OnClick", function()
    local screenCX = UIParent:GetWidth() / 2
    local frameCX, _ = BurningRushReminderFrame:GetCenter()
    local currentX = frameCX - screenCX
    BurningRushReminderDB.x = currentX
    BurningRushReminderDB.y = 0
    BurningRushReminderFrame:ClearAllPoints()
    BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", currentX, 0)
    updatingY = true
    ySlider:SetValue(0)
    updatingY = false
    yLabel:SetText("Y Position: 0")
    yInput:SetText("0")
end)

-- X position slider
xLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
xLabel:SetPoint("TOPLEFT", centerHBtn, "BOTTOMLEFT", 0, -20)
xLabel:SetText("X Position: 0")

xSlider = CreateFrame("Slider", "BurningRushXSlider", panel, "OptionsSliderTemplate")
xSlider:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -8)
xSlider:SetMinMaxValues(-POS_RANGE, POS_RANGE)
xSlider:SetValueStep(1)
xSlider:SetWidth(SLIDER_WIDTH)
xSlider.Low:SetText("-1000")
xSlider.High:SetText("1000")
xSlider.Text:SetText("")

xInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
xInput:SetSize(52, 20)
xInput:SetPoint("LEFT", xSlider, "RIGHT", 12, 0)
xInput:SetAutoFocus(false)
xInput:SetMaxLetters(5)

-- Tick marks for X slider
local xTickContainer = CreateFrame("Frame", nil, xSlider)
xTickContainer:SetAllPoints(xSlider)
for v = -POS_RANGE + MARKER_INTERVAL, POS_RANGE - MARKER_INTERVAL, MARKER_INTERVAL do
    local frac = (v + POS_RANGE) / (2 * POS_RANGE)
    local tick = xTickContainer:CreateTexture(nil, "ARTWORK")
    if v == 0 then
        tick:SetSize(2, 10)
        tick:SetColorTexture(1, 1, 1, 0.9)
    else
        tick:SetSize(1, 6)
        tick:SetColorTexture(1, 1, 1, 0.45)
    end
    tick:SetPoint("BOTTOM", xTickContainer, "BOTTOMLEFT", frac * SLIDER_WIDTH, 4)
end

xSlider:SetScript("OnValueChanged", function(self, value)
    if updatingX then return end
    value = math.floor(value)
    xLabel:SetText("X Position: " .. value)
    xInput:SetText(tostring(value))
    BurningRushReminderDB.x = value
    BurningRushReminderFrame:ClearAllPoints()
    BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", value, BurningRushReminderDB.y)
end)

xInput:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.max(-POS_RANGE, math.min(POS_RANGE, value))
        updatingX = true
        xSlider:SetValue(value)
        updatingX = false
        xLabel:SetText("X Position: " .. value)
        xInput:SetText(tostring(value))
        BurningRushReminderDB.x = value
        BurningRushReminderFrame:ClearAllPoints()
        BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", value, BurningRushReminderDB.y)
    else
        xInput:SetText(tostring(math.floor(xSlider:GetValue())))
    end
    self:ClearFocus()
end)

xInput:SetScript("OnEscapePressed", function(self)
    xInput:SetText(tostring(math.floor(xSlider:GetValue())))
    self:ClearFocus()
end)

-- Y position slider
yLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
yLabel:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -20)
yLabel:SetText("Y Position: 0")

ySlider = CreateFrame("Slider", "BurningRushYSlider", panel, "OptionsSliderTemplate")
ySlider:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -8)
ySlider:SetMinMaxValues(-POS_RANGE, POS_RANGE)
ySlider:SetValueStep(1)
ySlider:SetWidth(SLIDER_WIDTH)
ySlider.Low:SetText("-1000")
ySlider.High:SetText("1000")
ySlider.Text:SetText("")

yInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
yInput:SetSize(52, 20)
yInput:SetPoint("LEFT", ySlider, "RIGHT", 12, 0)
yInput:SetAutoFocus(false)
yInput:SetMaxLetters(5)

-- Tick marks for Y slider
local yTickContainer = CreateFrame("Frame", nil, ySlider)
yTickContainer:SetAllPoints(ySlider)
for v = -POS_RANGE + MARKER_INTERVAL, POS_RANGE - MARKER_INTERVAL, MARKER_INTERVAL do
    local frac = (v + POS_RANGE) / (2 * POS_RANGE)
    local tick = yTickContainer:CreateTexture(nil, "ARTWORK")
    if v == 0 then
        tick:SetSize(2, 10)
        tick:SetColorTexture(1, 1, 1, 0.9)
    else
        tick:SetSize(1, 6)
        tick:SetColorTexture(1, 1, 1, 0.45)
    end
    tick:SetPoint("BOTTOM", yTickContainer, "BOTTOMLEFT", frac * SLIDER_WIDTH, 4)
end

ySlider:SetScript("OnValueChanged", function(self, value)
    if updatingY then return end
    value = math.floor(value)
    yLabel:SetText("Y Position: " .. value)
    yInput:SetText(tostring(value))
    BurningRushReminderDB.y = value
    BurningRushReminderFrame:ClearAllPoints()
    BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", BurningRushReminderDB.x, value)
end)

yInput:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.max(-POS_RANGE, math.min(POS_RANGE, value))
        updatingY = true
        ySlider:SetValue(value)
        updatingY = false
        yLabel:SetText("Y Position: " .. value)
        yInput:SetText(tostring(value))
        BurningRushReminderDB.y = value
        BurningRushReminderFrame:ClearAllPoints()
        BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", BurningRushReminderDB.x, value)
    else
        yInput:SetText(tostring(math.floor(ySlider:GetValue())))
    end
    self:ClearFocus()
end)

yInput:SetScript("OnEscapePressed", function(self)
    yInput:SetText(tostring(math.floor(ySlider:GetValue())))
    self:ClearFocus()
end)

-- Font size label
local fontSizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontSizeLabel:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -20)
fontSizeLabel:SetText("Text Size:")

-- Font size slider
local slider = CreateFrame("Slider", "BurningRushFontSizeSlider", panel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -8)
slider:SetMinMaxValues(10, 100)
slider:SetValueStep(1)
slider:SetWidth(160)
slider.Low:SetText("10")
slider.High:SetText("100")
slider.Text:SetText("")

-- Font size text input
local sizeInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
sizeInput:SetSize(48, 20)
sizeInput:SetPoint("LEFT", slider, "RIGHT", 12, 0)
sizeInput:SetAutoFocus(false)
sizeInput:SetNumeric(true)
sizeInput:SetMaxLetters(3)

local updatingFromSlider = false

slider:SetScript("OnValueChanged", function(self, value)
    if updatingFromSlider then return end
    value = math.floor(value)
    BurningRushReminderDB.fontSize = value
    fontSizeLabel:SetText("Text Size: " .. value)
    sizeInput:SetText(tostring(value))
    if BurningRushReminder_ApplyFont then BurningRushReminder_ApplyFont() end
end)

sizeInput:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.max(10, math.min(100, value))
        BurningRushReminderDB.fontSize = value
        updatingFromSlider = true
        slider:SetValue(value)
        updatingFromSlider = false
        sizeInput:SetText(tostring(value))
        fontSizeLabel:SetText("Text Size: " .. value)
        if BurningRushReminder_ApplyFont then BurningRushReminder_ApplyFont() end
    end
    self:ClearFocus()
end)

sizeInput:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(BurningRushReminderDB.fontSize))
    self:ClearFocus()
end)

-- Font selector label
local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -24)
fontLabel:SetText("Font:")

local ROW_HEIGHT = 22
local VISIBLE_ROWS = 8
local LIST_WIDTH = 220

-- Dropdown selector frame
local dropdownBtn = CreateFrame("Frame", nil, panel, "BackdropTemplate")
dropdownBtn:SetSize(LIST_WIDTH, ROW_HEIGHT + 10)
dropdownBtn:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -4)
dropdownBtn:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
dropdownBtn:EnableMouse(true)

local selectedText = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
selectedText:SetPoint("LEFT", dropdownBtn, "LEFT", 8, 0)
selectedText:SetPoint("RIGHT", dropdownBtn, "RIGHT", -20, 0)
selectedText:SetJustifyH("LEFT")

local arrow = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrow:SetPoint("RIGHT", dropdownBtn, "RIGHT", -6, 0)
arrow:SetText("v")

-- List frame parented to UIParent
local listFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
listFrame:SetSize(LIST_WIDTH, ROW_HEIGHT * VISIBLE_ROWS + 10)
listFrame:SetFrameStrata("DIALOG")
listFrame:SetFrameLevel(100)
listFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
listFrame:Hide()

panel:HookScript("OnHide", function()
    listFrame:Hide()
end)

-- Virtual list state
local allFonts = {}
local topIndex = 1

local rows = {}
for i = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, listFrame)
    row:SetSize(LIST_WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -8 - (i - 1) * ROW_HEIGHT)

    local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rowText:SetPoint("LEFT", row, "LEFT", 4, 0)
    rowText:SetJustifyH("LEFT")
    row.rowText = rowText

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints()
    selected:SetColorTexture(1, 0.82, 0, 0.15)
    selected:Hide()
    row.selectedBg = selected

    rows[i] = row
end

local scrollBar = CreateFrame("Slider", nil, listFrame)
scrollBar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -4, -6)
scrollBar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 6)
scrollBar:SetWidth(8)
scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
scrollBar:SetOrientation("VERTICAL")
scrollBar:SetMinMaxValues(1, 1)
scrollBar:SetValue(1)

local function RefreshRows()
    for i = 1, VISIBLE_ROWS do
        local fontIndex = topIndex + i - 1
        local row = rows[i]
        if fontIndex <= #allFonts then
            local font = allFonts[fontIndex]
            row.rowText:SetText(font.name)
            if font.path == BurningRushReminderDB.font then
                row.rowText:SetTextColor(1, 0.82, 0, 1)
                row.selectedBg:Show()
            else
                row.rowText:SetTextColor(1, 1, 1, 1)
                row.selectedBg:Hide()
            end
            local fontPath = font.path
            local fontName = font.name
            row:SetScript("OnClick", function()
                BurningRushReminderDB.font = fontPath
                BurningRushReminderDB.fontName = fontName
                selectedText:SetText(fontName)
                listFrame:Hide()
                if BurningRushReminder_ApplyFont then BurningRushReminder_ApplyFont() end
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function ScrollTo(index)
    local maxTop = math.max(1, #allFonts - VISIBLE_ROWS + 1)
    topIndex = math.max(1, math.min(maxTop, index))
    scrollBar:SetValue(topIndex)
    RefreshRows()
end

scrollBar:SetScript("OnValueChanged", function(self, value)
    local newTop = math.floor(value + 0.5)
    if newTop ~= topIndex then
        topIndex = newTop
        RefreshRows()
    end
end)

listFrame:EnableMouseWheel(true)
listFrame:SetScript("OnMouseWheel", function(self, delta)
    ScrollTo(topIndex - delta * 3)
end)

local function OpenFontList()
    allFonts = GetFonts()
    topIndex = 1

    for i, f in ipairs(allFonts) do
        if f.path == BurningRushReminderDB.font then
            topIndex = math.max(1, i - math.floor(VISIBLE_ROWS / 2))
            break
        end
    end

    local maxTop = math.max(1, #allFonts - VISIBLE_ROWS + 1)
    scrollBar:SetMinMaxValues(1, maxTop)
    scrollBar:SetValue(topIndex)
    RefreshRows()

    listFrame:ClearAllPoints()
    listFrame:SetPoint("TOPLEFT", dropdownBtn, "BOTTOMLEFT", 0, -2)
    listFrame:Show()
end

dropdownBtn:SetScript("OnMouseDown", function()
    if listFrame:IsShown() then
        listFrame:Hide()
    else
        OpenFontList()
    end
end)

-- Initialise values once saved vars are available
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BurningRushReminder" then
        checkbox:SetChecked(BurningRushReminderDB.enabled)
        lockCheckbox:SetChecked(BurningRushReminderDB.locked)

        updatingX = true
        xSlider:SetValue(BurningRushReminderDB.x)
        updatingX = false
        xLabel:SetText("X Position: " .. math.floor(BurningRushReminderDB.x))
        xInput:SetText(tostring(math.floor(BurningRushReminderDB.x)))

        updatingY = true
        ySlider:SetValue(BurningRushReminderDB.y)
        updatingY = false
        yLabel:SetText("Y Position: " .. math.floor(BurningRushReminderDB.y))
        yInput:SetText(tostring(math.floor(BurningRushReminderDB.y)))

        updatingFromSlider = true
        slider:SetValue(BurningRushReminderDB.fontSize)
        updatingFromSlider = false
        sizeInput:SetText(tostring(BurningRushReminderDB.fontSize))
        fontSizeLabel:SetText("Text Size: " .. BurningRushReminderDB.fontSize)

        local displayName = BurningRushReminderDB.fontName or GetFontName(BurningRushReminderDB.font)
        selectedText:SetText(displayName)

        UpdatePositionButtons()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

BurningRushReminderCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(BurningRushReminderCategory)