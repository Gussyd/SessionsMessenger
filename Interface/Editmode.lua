local ADDON_NAME, Core = ...

local L = Core.L
local UI = Core.UI
local SM = Core.SM

local editFrame = CreateFrame("frame", nil, Core.UI, "BackdropTemplate")
editFrame:SetFrameStrata("DIALOG")
editFrame:EnableMouse(true)
editFrame:SetBackdrop({
	edgeFile=[[Interface\GLUES\COMMON\TextPanel-Border]],
	edgeSize=8,
})
editFrame:SetSize(200, 100)
editFrame.BG = editFrame:CreateTexture(nil, "BACKGROUND", nil)
editFrame.BG:SetAllPoints()
editFrame.BG:SetColorTexture(0,0,0,0.7)


local highlight = Core.UI:CreateTexture(nil, "OVERLAY", nil)
highlight:SetAtlas("editmode-actionbar-highlight-nineslice-center")
--highlight:SetAtlas("editmode-actionbar-selected-nineslice-center")
highlight:SetSize(1, 1)
highlight:Hide()

local selectedHighlight = Core.UI:CreateTexture(nil, "OVERLAY", nil)
selectedHighlight:SetAtlas("communities-chat-body-remove")
selectedHighlight:SetSize(1, 1)
selectedHighlight:Hide()

local header = CreateFrame("Button", nil, UI)
header:SetNormalTexture([[Interface\Worldmap\UI-QuestBlob-Inside-red]])
header:SetSize(200 + UI.main:GetWidth(), 16)
header:SetPoint("BOTTOMLEFT", UI, "TOPLEFT", 0, 20)
header:SetNormalFontObject("GameFontWhite")
header:SetText(L["Edit Mode: Click Here To Exit"])
header:SetScript("OnClick", function(this) editFrame:Exit() end)
header:Hide()



local function edit_OnEnter (self)
	if editFrame.selection == self then
		return
	end
	
	highlight:SetPoint("CENTER", self)
	highlight:SetSize(self:GetSize())	
	highlight:Show()
end

local function edit_OnMouseDown (self)
	selectedHighlight:ClearAllPoints()
	selectedHighlight:SetPoint("CENTER", self)
	selectedHighlight:SetSize(self:GetSize())
	selectedHighlight:Show()
	highlight:Hide()
	
	editFrame:Init()
	editFrame:ClearAllPoints()
	editFrame:SetPoint("LEFT", self, "RIGHT")
	local c = self.info.c
	editFrame.colourSelect:SetColorTexture(c.r, c.g, c.b, c.a)
	editFrame.subTitle:SetText(self.info.name)
	
	editFrame:Show()
	editFrame.selection = self
end

local function edit_OnLeave (self)
	highlight:ClearAllPoints()
	highlight:Hide()
end


local function pickerCallback(previousDump)
	local r,g,b,a
	
	if previousDump then
		r, g, b, a = unpack(previousDump)
	else
		r, g, b = ColorPickerFrame:GetColorRGB()
		a = OpacitySliderFrame:GetValue()
	end

	local info = editFrame.selection.info.c
	editFrame.selection.BG:SetColorTexture(r, g, b, a)
	-- SetGradient

	info.r, info.g, info.b, info.a = r, g, b, a
end

local function openColorPicker (fauxBtn)
	selectedHighlight:Hide()
	
	local c = editFrame.selection.info.c
	
	ColorPickerFrame.hasOpacity = true
	ColorPickerFrame.opacity = c.a
	ColorPickerFrame.previousValues = {c.r, c.g, c.b, c.a}
	ColorPickerFrame.func = pickerCallback
	ColorPickerFrame.opacityFunc = pickerCallback
	ColorPickerFrame.cancelFunc = pickerCallback
	ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end



local initiated = false
function editFrame:Init ()
	if initiated then return end
	self.title = self:CreateFontString()
	self.title:SetFontObject("QuestFont_Outline_Huge")
	self.title:SetPoint("TOP", 0, -5)
	self.title:SetText(L["Edit Appearance"])
	
	self.subTitle = self:CreateFontString()
	self.subTitle:SetFontObject("GameFontWhite")
	self.subTitle:SetPoint("TOP", 0, -25)
	
	self.colourSelect = self:CreateTexture(nil, "OVERLAY", nil)
	self.colourSelect:EnableMouse(true)
	self.colourSelect:SetSize(24, 24)
	self.colourSelect:SetPoint("TOP", -30, -50)
	self.colourSelect.border = self:CreateTexture(nil, "OVERLAY", nil)
	self.colourSelect.border:SetAtlas("collections-itemborder-collected")
	self.colourSelect.border:SetSize(24, 24)
	self.colourSelect.border:SetPoint("CENTER", self.colourSelect)
	
	self.colourSelect:SetScript("OnMouseDown", openColorPicker)
	
	self.exitBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.exitBtn:SetText(L["Exit Editmode"])
	self.exitBtn:SetPoint("BOTTOMRIGHT", -2, 2)
	self.exitBtn:SetWidth(100)
	self.exitBtn:SetScript("OnClick", function(this) self:Exit() end)
	
	initiated = true
end

function editFrame:Exit ()
	highlight:Hide()
	selectedHighlight:Hide()
	
	for i, frame in ipairs(UI.frames) do
		frame:SetScript("OnEnter", nil)
		frame:SetScript("OnLeave", nil)
		frame:SetScript("OnMouseDown", nil)
		local info = frame.info
		SESMSG_Profile["DisplayInfo"][info.name]["c"] = frame.info.c
	end
	
	self.selection = false
	self:Hide()
	
	if SM.selected then
		SM.selected.page:Show()
	end
	
	header:Hide()
end

function editFrame:Open (frame)
	editFrame:ClearAllPoints()
	editFrame:SetPoint("RIGHT", frame)
	editFrame:Show()
end

function editFrame.SetupScripts ()
	for i, frame in ipairs(UI.frames) do
		frame:SetScript("OnEnter", edit_OnEnter)
		frame:SetScript("OnLeave", edit_OnLeave)
		frame:SetScript("OnMouseDown", edit_OnMouseDown)
	end
	
	UI.leftFrame:Show()
	UI.main:Show()
	header:SetWidth(UI.main:GetWidth() + UI.leftFrame:GetWidth() + UI:GetWidth())
	header:Show()
	
	if SM.selected then
		SM.selected.page:Hide()
	end
end

Core.Editmode = editFrame