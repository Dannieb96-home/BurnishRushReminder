local LSM = LibStub("LibSharedMedia-3.0", true)

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
            if not alreadyAdded then
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

local function RGBToHex(r, g, b)
    return string.format("%02X%02X%02X", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function HexToRGB(hex)
    hex = hex:gsub("^#", "")
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)
    if not r or not g or not b then return nil end
    return r / 255, g / 255, b / 255
end

-- ============================================================
-- PANEL + SCROLL FRAME
-- ============================================================

local panel = CreateFrame("Frame")
panel.name = "Burning Rush Reminder"

local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)
scrollFrame:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(600)
content:SetHeight(930)
scrollFrame:SetScrollChild(content)

scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(max, current - delta * 30)))
end)

panel:SetScript("OnShow", function()
    if BurningRushReminder_SetPreview then BurningRushReminder_SetPreview(true) end
end)
panel:SetScript("OnHide", function()
    if BurningRushReminder_SetPreview then BurningRushReminder_SetPreview(false) end
end)

-- ============================================================
-- CONTENT WIDGETS
-- ============================================================

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Burning Rush Reminder")

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Warns you when Burning Rush is active in combat.")

local checkbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
checkbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
checkbox.Text:SetText("Enable Burning Rush Reminder")
checkbox:SetScript("OnClick", function(self)
    BurningRushReminderDB.enabled = self:GetChecked()
    if BurningRushReminder_UpdateReminder then BurningRushReminder_UpdateReminder() end
end)

local lockCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -8)
lockCheckbox.Text:SetText("Lock frame position (uncheck to adjust)")

local SLIDER_WIDTH = 300
local POS_RANGE = 1000
local MARKER_INTERVAL = 200

local centerHBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
local centerVBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
local resetPosBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
local xLabel, xSlider, xInput
local yLabel, ySlider, yInput
local updatingX = false
local updatingY = false

local function UpdatePositionButtons()
    local unlocked = not BurningRushReminderDB.locked
    local alpha = unlocked and 1 or 0.4
    centerHBtn:SetEnabled(unlocked)
    centerVBtn:SetEnabled(unlocked)
    resetPosBtn:SetEnabled(unlocked)
    centerHBtn:SetAlpha(alpha)
    centerVBtn:SetAlpha(alpha)
    resetPosBtn:SetAlpha(alpha)
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

resetPosBtn:SetPoint("LEFT", centerVBtn, "RIGHT", 6, 0)
resetPosBtn:SetSize(120, 28)
resetPosBtn:SetText("Reset Position")
resetPosBtn:SetScript("OnClick", function()
    BurningRushReminderDB.x = 0
    BurningRushReminderDB.y = 0
    BurningRushReminderFrame:ClearAllPoints()
    BurningRushReminderFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    updatingX = true
    xSlider:SetValue(0)
    updatingX = false
    xLabel:SetText("X Position: 0")
    xInput:SetText("0")
    updatingY = true
    ySlider:SetValue(0)
    updatingY = false
    yLabel:SetText("Y Position: 0")
    yInput:SetText("0")
end)

local function AddTicks(sl, width, range, interval)
    local container = CreateFrame("Frame", nil, sl)
    container:SetAllPoints(sl)
    for v = -range + interval, range - interval, interval do
        local frac = (v + range) / (2 * range)
        local tick = container:CreateTexture(nil, "ARTWORK")
        if v == 0 then
            tick:SetSize(2, 10)
            tick:SetColorTexture(1, 1, 1, 0.9)
        else
            tick:SetSize(1, 6)
            tick:SetColorTexture(1, 1, 1, 0.45)
        end
        tick:SetPoint("BOTTOM", container, "BOTTOMLEFT", frac * width, 4)
    end
end

-- X position
xLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
xLabel:SetPoint("TOPLEFT", centerHBtn, "BOTTOMLEFT", 0, -20)
xLabel:SetText("X Position: 0")

xSlider = CreateFrame("Slider", "BurningRushXSlider", content, "OptionsSliderTemplate")
xSlider:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -8)
xSlider:SetMinMaxValues(-POS_RANGE, POS_RANGE)
xSlider:SetValueStep(1)
xSlider:SetWidth(SLIDER_WIDTH)
xSlider.Low:SetText("-1000")
xSlider.High:SetText("1000")
xSlider.Text:SetText("")
AddTicks(xSlider, SLIDER_WIDTH, POS_RANGE, MARKER_INTERVAL)

xInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
xInput:SetSize(52, 20)
xInput:SetPoint("LEFT", xSlider, "RIGHT", 12, 0)
xInput:SetAutoFocus(false)
xInput:SetMaxLetters(5)
xInput:SetText("0")

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

-- Y position
yLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
yLabel:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -20)
yLabel:SetText("Y Position: 0")

ySlider = CreateFrame("Slider", "BurningRushYSlider", content, "OptionsSliderTemplate")
ySlider:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -8)
ySlider:SetMinMaxValues(-POS_RANGE, POS_RANGE)
ySlider:SetValueStep(1)
ySlider:SetWidth(SLIDER_WIDTH)
ySlider.Low:SetText("-1000")
ySlider.High:SetText("1000")
ySlider.Text:SetText("")
AddTicks(ySlider, SLIDER_WIDTH, POS_RANGE, MARKER_INTERVAL)

yInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
yInput:SetSize(52, 20)
yInput:SetPoint("LEFT", ySlider, "RIGHT", 12, 0)
yInput:SetAutoFocus(false)
yInput:SetMaxLetters(5)
yInput:SetText("0")

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

-- Drag poller
local dragPoller = CreateFrame("Frame", nil, UIParent)
dragPoller:Hide()
dragPoller:SetScript("OnUpdate", function()
    local f = BurningRushReminderFrame
    if not f then return end
    local screenCX = UIParent:GetWidth() / 2
    local screenCY = UIParent:GetHeight() / 2
    local frameCX, frameCY = f:GetCenter()
    if not frameCX then return end
    local x = math.floor(frameCX - screenCX)
    local y = math.floor(frameCY - screenCY)
    BurningRushReminderDB.x = x
    BurningRushReminderDB.y = y
    updatingX = true
    xSlider:SetValue(math.max(-POS_RANGE, math.min(POS_RANGE, x)))
    updatingX = false
    xLabel:SetText("X Position: " .. x)
    xInput:SetText(tostring(x))
    updatingY = true
    ySlider:SetValue(math.max(-POS_RANGE, math.min(POS_RANGE, y)))
    updatingY = false
    yLabel:SetText("Y Position: " .. y)
    yInput:SetText(tostring(y))
end)

BurningRushReminder_DragPollerShow = function() dragPoller:Show() end
BurningRushReminder_DragPollerHide = function() dragPoller:Hide() end

-- Font size
local fontSizeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontSizeLabel:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -20)
fontSizeLabel:SetText("Text Size: 20")

local slider = CreateFrame("Slider", "BurningRushFontSizeSlider", content, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -8)
slider:SetMinMaxValues(10, 100)
slider:SetValueStep(1)
slider:SetWidth(160)
slider.Low:SetText("10")
slider.High:SetText("100")
slider.Text:SetText("")

local sizeInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
sizeInput:SetSize(48, 20)
sizeInput:SetPoint("LEFT", slider, "RIGHT", 12, 0)
sizeInput:SetAutoFocus(false)
sizeInput:SetNumeric(true)
sizeInput:SetMaxLetters(3)
sizeInput:SetText("20")

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

-- ============================================================
-- FONT SELECTOR
-- ============================================================

local fontLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -24)
fontLabel:SetText("Font:")

local ROW_HEIGHT = 22
local VISIBLE_ROWS = 8
local LIST_WIDTH = 220

local dropdownBtn = CreateFrame("Frame", nil, content, "BackdropTemplate")
dropdownBtn:SetSize(LIST_WIDTH, ROW_HEIGHT + 10)
dropdownBtn:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -4)
dropdownBtn:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
dropdownBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
dropdownBtn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
dropdownBtn:EnableMouse(true)

local selectedText = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
selectedText:SetPoint("LEFT", dropdownBtn, "LEFT", 8, 0)
selectedText:SetPoint("RIGHT", dropdownBtn, "RIGHT", -20, 0)
selectedText:SetJustifyH("LEFT")

local arrow = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrow:SetPoint("RIGHT", dropdownBtn, "RIGHT", -6, 0)
arrow:SetText("v")

local listFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
listFrame:SetSize(LIST_WIDTH, ROW_HEIGHT * VISIBLE_ROWS + 10)
listFrame:SetFrameStrata("DIALOG")
listFrame:SetFrameLevel(100)
listFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
listFrame:SetBackdropColor(0.08, 0.08, 0.08, 1)
listFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
listFrame:Hide()

panel:HookScript("OnHide", function()
    listFrame:Hide()
end)

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

local function ScrollbarOnValueChanged(self, value)
    local newTop = math.floor(value + 0.5)
    if newTop ~= topIndex then
        topIndex = newTop
        RefreshRows()
    end
end

scrollBar:SetScript("OnValueChanged", ScrollbarOnValueChanged)

local function ScrollTo(index)
    local maxTop = math.max(1, #allFonts - VISIBLE_ROWS + 1)
    topIndex = math.max(1, math.min(maxTop, index))
    scrollBar:SetScript("OnValueChanged", nil)
    scrollBar:SetValue(topIndex)
    scrollBar:SetScript("OnValueChanged", ScrollbarOnValueChanged)
    RefreshRows()
end

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
    scrollBar:SetScript("OnValueChanged", nil)
    scrollBar:SetValue(topIndex)
    scrollBar:SetScript("OnValueChanged", ScrollbarOnValueChanged)
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

local clickCatcher = CreateFrame("Frame", nil, UIParent)
clickCatcher:SetAllPoints(UIParent)
clickCatcher:SetFrameStrata("DIALOG")
clickCatcher:SetFrameLevel(99)
clickCatcher:EnableMouse(true)
clickCatcher:Hide()
clickCatcher:SetScript("OnMouseDown", function()
    listFrame:Hide()
    clickCatcher:Hide()
end)

local originalOpenFontList = OpenFontList
OpenFontList = function()
    originalOpenFontList()
    clickCatcher:Show()
end

listFrame:HookScript("OnHide", function()
    clickCatcher:Hide()
end)

-- ============================================================
-- TEXT STYLE
-- ============================================================

local styleLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
styleLabel:SetPoint("TOPLEFT", dropdownBtn, "BOTTOMLEFT", 0, -24)
styleLabel:SetText("Text Style:")

local function MakeStyleButton(label, anchor)
    local btn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
    btn:SetSize(90, 24)
    if anchor then
        btn:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    else
        btn:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -8)
    end
    btn:SetText(label)
    local sel = btn:CreateTexture(nil, "OVERLAY")
    sel:SetTexture(btn:GetHighlightTexture():GetTexture())
    sel:SetAllPoints(btn)
    sel:SetVertexColor(0, 0, 0, 0.5)
    sel:Hide()
    btn.selectedTex = sel
    return btn
end

local styleNoneBtn    = MakeStyleButton("None",       nil)
local styleOutlineBtn = MakeStyleButton("Outline",    styleNoneBtn)
local styleThickBtn   = MakeStyleButton("Thick",      styleOutlineBtn)
local styleShadowBtn  = MakeStyleButton("Shadow",     styleThickBtn)

local function UpdateStyleButtons()
    local style = BurningRushReminderDB.textStyle or "outline"
    styleNoneBtn.selectedTex:SetShown(style == "none")
    styleOutlineBtn.selectedTex:SetShown(style == "outline")
    styleThickBtn.selectedTex:SetShown(style == "thickoutline")
    styleShadowBtn.selectedTex:SetShown(style == "shadow")
end

local function SetStyle(style)
    BurningRushReminderDB.textStyle = style
    UpdateStyleButtons()
    if BurningRushReminder_ApplyFont then BurningRushReminder_ApplyFont() end
end

styleNoneBtn:SetScript("OnClick",    function() SetStyle("none")         end)
styleOutlineBtn:SetScript("OnClick", function() SetStyle("outline")      end)
styleThickBtn:SetScript("OnClick",   function() SetStyle("thickoutline") end)
styleShadowBtn:SetScript("OnClick",  function() SetStyle("shadow")       end)

-- ============================================================
-- TEXT COLOUR
-- ============================================================

local colourLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
colourLabel:SetPoint("TOPLEFT", styleNoneBtn, "BOTTOMLEFT", 0, -24)
colourLabel:SetText("Text Colour:")

local swatch = CreateFrame("Frame", nil, content)
swatch:SetSize(26, 26)
swatch:SetPoint("LEFT", colourLabel, "RIGHT", 8, 0)

local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
swatchBorder:SetAllPoints(swatch)
swatchBorder:SetColorTexture(0.5, 0.5, 0.5, 1)

local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
swatchTex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
swatchTex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
swatchTex:SetColorTexture(1, 0.2, 0.2, 1)

local function ApplyColour(r, g, b)
    BurningRushReminderDB.colour = { r = r, g = g, b = b }
    swatchTex:SetColorTexture(r, g, b, 1)
    if BurningRushReminder_ApplyColour then BurningRushReminder_ApplyColour(r, g, b) end
end

local warlockBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
warlockBtn:SetSize(110, 24)
warlockBtn:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
warlockBtn:SetText("Warlock Purple")

local pickerBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
pickerBtn:SetSize(110, 24)
pickerBtn:SetPoint("LEFT", warlockBtn, "RIGHT", 6, 0)
pickerBtn:SetText("Colour Picker...")

local currentValueLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
currentValueLabel:SetPoint("TOPLEFT", colourLabel, "BOTTOMLEFT", 0, -14)
currentValueLabel:SetText("Current value: FF3333")

local hexLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
hexLabel:SetPoint("TOPLEFT", currentValueLabel, "BOTTOMLEFT", 0, -6)
hexLabel:SetText("#")

local hexInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
hexInput:SetSize(70, 20)
hexInput:SetPoint("LEFT", hexLabel, "RIGHT", 8, 0)
hexInput:SetAutoFocus(false)
hexInput:SetMaxLetters(6)

local RGB_SLIDER_WIDTH = 200
local rSlider, gSlider, bSlider
local rInp, gInp, bInp
local updatingRGB = false

local rLbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
rLbl:SetPoint("TOPLEFT", hexLabel, "BOTTOMLEFT", 0, -16)
rLbl:SetText("R: 255")
rLbl:SetTextColor(1, 0.4, 0.4)

rSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
rSlider:SetPoint("TOPLEFT", rLbl, "BOTTOMLEFT", 0, -4)
rSlider:SetMinMaxValues(0, 255)
rSlider:SetValueStep(1)
rSlider:SetWidth(RGB_SLIDER_WIDTH)
rSlider.Low:SetText("0")
rSlider.High:SetText("255")
rSlider.Text:SetText("")

rInp = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
rInp:SetSize(44, 20)
rInp:SetPoint("LEFT", rSlider, "RIGHT", 8, 0)
rInp:SetAutoFocus(false)
rInp:SetNumeric(true)
rInp:SetMaxLetters(3)

local gLbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
gLbl:SetPoint("TOPLEFT", rSlider, "BOTTOMLEFT", 0, -16)
gLbl:SetText("G: 51")
gLbl:SetTextColor(0.4, 1, 0.4)

gSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
gSlider:SetPoint("TOPLEFT", gLbl, "BOTTOMLEFT", 0, -4)
gSlider:SetMinMaxValues(0, 255)
gSlider:SetValueStep(1)
gSlider:SetWidth(RGB_SLIDER_WIDTH)
gSlider.Low:SetText("0")
gSlider.High:SetText("255")
gSlider.Text:SetText("")

gInp = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
gInp:SetSize(44, 20)
gInp:SetPoint("LEFT", gSlider, "RIGHT", 8, 0)
gInp:SetAutoFocus(false)
gInp:SetNumeric(true)
gInp:SetMaxLetters(3)

local bLbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
bLbl:SetPoint("TOPLEFT", gSlider, "BOTTOMLEFT", 0, -16)
bLbl:SetText("B: 51")
bLbl:SetTextColor(0.4, 0.4, 1)

bSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
bSlider:SetPoint("TOPLEFT", bLbl, "BOTTOMLEFT", 0, -4)
bSlider:SetMinMaxValues(0, 255)
bSlider:SetValueStep(1)
bSlider:SetWidth(RGB_SLIDER_WIDTH)
bSlider.Low:SetText("0")
bSlider.High:SetText("255")
bSlider.Text:SetText("")

bInp = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
bInp:SetSize(44, 20)
bInp:SetPoint("LEFT", bSlider, "RIGHT", 8, 0)
bInp:SetAutoFocus(false)
bInp:SetNumeric(true)
bInp:SetMaxLetters(3)

local function SyncColourControls(r, g, b)
    if not r then
        local db = BurningRushReminderDB.colour
        if not db then return end
        r, g, b = db.r, db.g, db.b
    end
    local ri = math.floor(r * 255)
    local gi = math.floor(g * 255)
    local bi = math.floor(b * 255)
    swatchTex:SetColorTexture(r, g, b, 1)
    currentValueLabel:SetText("Current value: " .. RGBToHex(r, g, b))
    hexInput:SetText(RGBToHex(r, g, b))
    rLbl:SetText("R: " .. ri)
    gLbl:SetText("G: " .. gi)
    bLbl:SetText("B: " .. bi)
    updatingRGB = true
    rSlider:SetValue(ri)
    gSlider:SetValue(gi)
    bSlider:SetValue(bi)
    updatingRGB = false
    rInp:SetText(tostring(ri))
    gInp:SetText(tostring(gi))
    bInp:SetText(tostring(bi))
end

BurningRushReminder_SyncColourControls = SyncColourControls

warlockBtn:SetScript("OnClick", function()
    local r, g, b = HexToRGB("8787ED")
    ApplyColour(r, g, b)
    SyncColourControls(r, g, b)
end)

pickerBtn:SetScript("OnClick", function()
    local db = BurningRushReminderDB.colour
    ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = false,
        r = db.r, g = db.g, b = db.b,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ApplyColour(r, g, b)
            SyncColourControls(r, g, b)
        end,
        cancelFunc = function(prev)
            ApplyColour(prev.r, prev.g, prev.b)
            SyncColourControls(prev.r, prev.g, prev.b)
        end,
    })
end)

hexInput:SetScript("OnEnterPressed", function(self)
    local r, g, b = HexToRGB(self:GetText())
    if r then
        ApplyColour(r, g, b)
        SyncColourControls(r, g, b)
    else
        local db = BurningRushReminderDB.colour
        self:SetText(RGBToHex(db.r, db.g, db.b))
    end
    self:ClearFocus()
end)
hexInput:SetScript("OnEscapePressed", function(self)
    local db = BurningRushReminderDB.colour
    self:SetText(RGBToHex(db.r, db.g, db.b))
    self:ClearFocus()
end)

local function OnRGBChanged()
    if updatingRGB then return end
    local r = rSlider:GetValue() / 255
    local g = gSlider:GetValue() / 255
    local b = bSlider:GetValue() / 255
    local ri = math.floor(rSlider:GetValue())
    local gi = math.floor(gSlider:GetValue())
    local bi = math.floor(bSlider:GetValue())
    ApplyColour(r, g, b)
    currentValueLabel:SetText("Current value: " .. RGBToHex(r, g, b))
    hexInput:SetText(RGBToHex(r, g, b))
    rLbl:SetText("R: " .. ri)
    gLbl:SetText("G: " .. gi)
    bLbl:SetText("B: " .. bi)
    rInp:SetText(tostring(ri))
    gInp:SetText(tostring(gi))
    bInp:SetText(tostring(bi))
end

rSlider:SetScript("OnValueChanged", OnRGBChanged)
gSlider:SetScript("OnValueChanged", OnRGBChanged)
bSlider:SetScript("OnValueChanged", OnRGBChanged)

local function MakeRGBInputHandler(sl)
    return function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(0, math.min(255, value))
            updatingRGB = true
            sl:SetValue(value)
            updatingRGB = false
            self:SetText(tostring(value))
            local r = rSlider:GetValue() / 255
            local g = gSlider:GetValue() / 255
            local b = bSlider:GetValue() / 255
            ApplyColour(r, g, b)
            hexInput:SetText(RGBToHex(r, g, b))
        else
            self:SetText(tostring(math.floor(sl:GetValue())))
        end
        self:ClearFocus()
    end
end

rInp:SetScript("OnEnterPressed", MakeRGBInputHandler(rSlider))
gInp:SetScript("OnEnterPressed", MakeRGBInputHandler(gSlider))
bInp:SetScript("OnEnterPressed", MakeRGBInputHandler(bSlider))
rInp:SetScript("OnEscapePressed", function(self) self:SetText(tostring(math.floor(rSlider:GetValue()))) self:ClearFocus() end)
gInp:SetScript("OnEscapePressed", function(self) self:SetText(tostring(math.floor(gSlider:GetValue()))) self:ClearFocus() end)
bInp:SetScript("OnEscapePressed", function(self) self:SetText(tostring(math.floor(bSlider:GetValue()))) self:ClearFocus() end)

-- ============================================================
-- EFFECT SECTION
-- ============================================================

local effectLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
effectLabel:SetPoint("TOPLEFT", bSlider, "BOTTOMLEFT", 0, -24)
effectLabel:SetText("Effect:")

local function MakeTriButton(parent, label, anchor)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(80, 24)
    if anchor then
        btn:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    else
        btn:SetPoint("TOPLEFT", effectLabel, "BOTTOMLEFT", 0, -8)
    end
    btn:SetText(label)
    local sel = btn:CreateTexture(nil, "OVERLAY")
    sel:SetTexture(btn:GetHighlightTexture():GetTexture())
    sel:SetAllPoints(btn)
    sel:SetVertexColor(0, 0, 0, 0.5)
    sel:Hide()
    btn.selectedTex = sel
    return btn
end

local effectNoneBtn  = MakeTriButton(content, "None",  nil)
local effectPulseBtn = MakeTriButton(content, "Pulse", effectNoneBtn)
local effectFlashBtn = MakeTriButton(content, "Flash", effectPulseBtn)

local speedLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
speedLabel:SetPoint("TOPLEFT", effectNoneBtn, "BOTTOMLEFT", 0, -16)
speedLabel:SetText("Speed: 1.5")

local speedSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
speedSlider:SetPoint("TOPLEFT", speedLabel, "BOTTOMLEFT", 0, -8)
speedSlider:SetMinMaxValues(0.1, 5.0)
speedSlider:SetValueStep(0.1)
speedSlider:SetWidth(200)
speedSlider.Low:SetText("0.1")
speedSlider.High:SetText("5.0")
speedSlider.Text:SetText("")

local speedInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
speedInput:SetSize(44, 20)
speedInput:SetPoint("LEFT", speedSlider, "RIGHT", 8, 0)
speedInput:SetAutoFocus(false)
speedInput:SetMaxLetters(4)
speedInput:SetText("1.5")

local updatingSpeed = false

speedSlider:SetScript("OnValueChanged", function(self, value)
    if updatingSpeed then return end
    value = math.floor(value * 10 + 0.5) / 10
    BurningRushReminderDB.effectSpeed = value
    speedLabel:SetText("Speed: " .. string.format("%.1f", value))
    speedInput:SetText(string.format("%.1f", value))
end)

speedInput:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.max(0.1, math.min(5.0, math.floor(value * 10 + 0.5) / 10))
        BurningRushReminderDB.effectSpeed = value
        updatingSpeed = true
        speedSlider:SetValue(value)
        updatingSpeed = false
        speedLabel:SetText("Speed: " .. string.format("%.1f", value))
        speedInput:SetText(string.format("%.1f", value))
    else
        speedInput:SetText(string.format("%.1f", BurningRushReminderDB.effectSpeed or 1.5))
    end
    self:ClearFocus()
end)
speedInput:SetScript("OnEscapePressed", function(self)
    speedInput:SetText(string.format("%.1f", BurningRushReminderDB.effectSpeed or 1.5))
    self:ClearFocus()
end)

-- ============================================================
-- FLASH COLOUR
-- ============================================================

local flashColourLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
flashColourLabel:SetPoint("TOPLEFT", speedSlider, "BOTTOMLEFT", 0, -24)
flashColourLabel:SetText("Flash Colour:")

local flashSwatch = CreateFrame("Frame", nil, content)
flashSwatch:SetSize(26, 26)
flashSwatch:SetPoint("LEFT", flashColourLabel, "RIGHT", 8, 0)

local flashSwatchBorder = flashSwatch:CreateTexture(nil, "BACKGROUND")
flashSwatchBorder:SetAllPoints(flashSwatch)
flashSwatchBorder:SetColorTexture(0.5, 0.5, 0.5, 1)

local flashSwatchTex = flashSwatch:CreateTexture(nil, "ARTWORK")
flashSwatchTex:SetPoint("TOPLEFT", flashSwatch, "TOPLEFT", 2, -2)
flashSwatchTex:SetPoint("BOTTOMRIGHT", flashSwatch, "BOTTOMRIGHT", -2, 2)
flashSwatchTex:SetColorTexture(1, 1, 0, 1)

local flashPickerBtn = CreateFrame("Button", nil, content, "GameMenuButtonTemplate")
flashPickerBtn:SetSize(110, 24)
flashPickerBtn:SetPoint("LEFT", flashSwatch, "RIGHT", 10, 0)
flashPickerBtn:SetText("Colour Picker...")

local flashHexLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
flashHexLabel:SetPoint("TOPLEFT", flashColourLabel, "BOTTOMLEFT", 0, -14)
flashHexLabel:SetText("Current value: FFFF00")

local flashHashLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
flashHashLabel:SetPoint("TOPLEFT", flashHexLabel, "BOTTOMLEFT", 0, -6)
flashHashLabel:SetText("#")

local flashHexInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
flashHexInput:SetSize(70, 20)
flashHexInput:SetPoint("LEFT", flashHashLabel, "RIGHT", 8, 0)
flashHexInput:SetAutoFocus(false)
flashHexInput:SetMaxLetters(6)

local function SyncFlashColour(r, g, b)
    if not r then
        local db = BurningRushReminderDB.flashColour
        if not db then return end
        r, g, b = db.r, db.g, db.b
    end
    flashSwatchTex:SetColorTexture(r, g, b, 1)
    flashHexLabel:SetText("Current value: " .. RGBToHex(r, g, b))
    flashHexInput:SetText(RGBToHex(r, g, b))
end

local function ApplyFlashColour(r, g, b)
    BurningRushReminderDB.flashColour = { r = r, g = g, b = b }
    SyncFlashColour(r, g, b)
end

flashHexInput:SetScript("OnEnterPressed", function(self)
    local r, g, b = HexToRGB(self:GetText())
    if r then
        ApplyFlashColour(r, g, b)
    else
        local db = BurningRushReminderDB.flashColour or { r = 1, g = 1, b = 0 }
        self:SetText(RGBToHex(db.r, db.g, db.b))
    end
    self:ClearFocus()
end)
flashHexInput:SetScript("OnEscapePressed", function(self)
    local db = BurningRushReminderDB.flashColour or { r = 1, g = 1, b = 0 }
    self:SetText(RGBToHex(db.r, db.g, db.b))
    self:ClearFocus()
end)

flashPickerBtn:SetScript("OnClick", function()
    local db = BurningRushReminderDB.flashColour or { r = 1, g = 1, b = 0 }
    ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = false,
        r = db.r, g = db.g, b = db.b,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ApplyFlashColour(r, g, b)
        end,
        cancelFunc = function(prev)
            ApplyFlashColour(prev.r, prev.g, prev.b)
        end,
    })
end)

local flashWidgets = { flashColourLabel, flashSwatch, flashPickerBtn, flashHexLabel, flashHashLabel, flashHexInput }

-- ============================================================
-- EFFECT BUTTON LOGIC
-- ============================================================

local function SetButtonSelected(btn, selected)
    btn.selectedTex:SetShown(selected)
end

local function UpdateEffectButtons()
    local effect = BurningRushReminderDB.effect or "none"
    local hasEffect = effect ~= "none"
    local isFlash = effect == "flash"

    SetButtonSelected(effectNoneBtn,  effect == "none")
    SetButtonSelected(effectPulseBtn, effect == "pulse")
    SetButtonSelected(effectFlashBtn, isFlash)

    local speedAlpha = hasEffect and 1 or 0.4
    speedLabel:SetAlpha(speedAlpha)
    speedSlider:SetEnabled(hasEffect) speedSlider:SetAlpha(speedAlpha)
    speedInput:SetEnabled(hasEffect)  speedInput:SetAlpha(speedAlpha)

    for _, w in ipairs(flashWidgets) do
        w:SetShown(isFlash)
    end
end

local function SetEffect(effect)
    BurningRushReminderDB.effect = effect
    UpdateEffectButtons()
    if BurningRushReminder_ApplyEffect then BurningRushReminder_ApplyEffect() end
end

effectNoneBtn:SetScript("OnClick",  function() SetEffect("none")  end)
effectPulseBtn:SetScript("OnClick", function() SetEffect("pulse") end)
effectFlashBtn:SetScript("OnClick", function() SetEffect("flash") end)

-- ============================================================
-- INIT
-- ============================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BurningRushReminder" then
        if not BurningRushReminderDB.colour then
            BurningRushReminderDB.colour = { r = 1, g = 0.2, b = 0.2 }
        end
        if not BurningRushReminderDB.effect then BurningRushReminderDB.effect = "none" end
        if not BurningRushReminderDB.effectSpeed or type(BurningRushReminderDB.effectSpeed) == "string" then
            BurningRushReminderDB.effectSpeed = 1.5
        end
        if not BurningRushReminderDB.flashColour then BurningRushReminderDB.flashColour = { r = 1, g = 1, b = 0 } end
        if not BurningRushReminderDB.textStyle then BurningRushReminderDB.textStyle = "outline" end

        checkbox:SetChecked(BurningRushReminderDB.enabled)
        lockCheckbox:SetChecked(BurningRushReminderDB.locked)

        local savedX = math.floor(BurningRushReminderDB.x)
        local savedY = math.floor(BurningRushReminderDB.y)
        local savedSize = BurningRushReminderDB.fontSize

        updatingX = true
        xSlider:SetValue(savedX)
        updatingX = false
        xLabel:SetText("X Position: " .. savedX)
        xInput:SetText(tostring(savedX))

        updatingY = true
        ySlider:SetValue(savedY)
        updatingY = false
        yLabel:SetText("Y Position: " .. savedY)
        yInput:SetText(tostring(savedY))

        updatingFromSlider = true
        slider:SetValue(savedSize)
        updatingFromSlider = false
        sizeInput:SetText(tostring(savedSize))
        fontSizeLabel:SetText("Text Size: " .. savedSize)

        local c = BurningRushReminderDB.colour
        SyncColourControls(c.r, c.g, c.b)
        SyncFlashColour()

        local displayName = BurningRushReminderDB.fontName or GetFontName(BurningRushReminderDB.font)
        selectedText:SetText(displayName)

        UpdatePositionButtons()
        UpdateEffectButtons()
        UpdateStyleButtons()

        local savedSpeed = BurningRushReminderDB.effectSpeed or 1.5
        updatingSpeed = true
        speedSlider:SetValue(savedSpeed)
        updatingSpeed = false
        speedLabel:SetText("Speed: " .. string.format("%.1f", savedSpeed))
        speedInput:SetText(string.format("%.1f", savedSpeed))

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

BurningRushReminderCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(BurningRushReminderCategory)
