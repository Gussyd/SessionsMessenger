local ADDON_NAME, Core = ...

--<
local SM = Core.SM
local utils = Core.utils
-->

local PanelMixin, WindowMixin = {}, {height=10}
local indent = 10
local ySpacing = 5


function PanelMixin:Init ()
	Mixin(self, WindowMixin)
	self.Tabs = {}
	self.windows = {}
	self.parameters = {}
	self.okay = self.CommitChanges
	self.cancel = self.DiscardChanges
	
	if self.name then
		self:NewTitle(self.name)
		self:NewNavigation()
	end
end

function PanelMixin:NewNavigation ()
	self.navigation = CreateFrame("Frame", nil, self)
	self.navigation:SetSize(300, 20)
	self:Attach(self.navigation)
	self.navigation:SetPoint("RIGHT", self)
	
	local line = self:CreateLine(nil, "OVERLAY")
	line:SetTexture([[Interface\COMMON\UI-TooltipDivider]])
	line:SetStartPoint("BOTTOMLEFT", self.navigation, -7, -3)
	line:SetEndPoint("BOTTOMRIGHT", self.navigation, -3, -3)
	line:SetThickness(10)
end

function PanelMixin:NewWindow (name, frame)
	local f = frame or CreateFrame("Frame", nil, self)
	Mixin(f, WindowMixin)
	f.panel = self
	f.columnWidth = 210
	f:SetPoint("BOTTOMRIGHT")
	f:SetPoint("TOPLEFT", 10, -self.height)
	
	local id = #self.windows +1

	local b = CreateFrame("Button", nil, self.navigation, "TabButtonTemplate")
	b:SetPoint("BOTTOMLEFT", self.Tabs[id-1] or self.navigation, id > 1 and "BOTTOMRIGHT" or "BOTTOMLEFT")
	b:SetText(name)
	b:SetID(id)
	b:SetScript("OnClick", function(this)
		PanelTemplates_Tab_OnClick(this, self)
		for i=1, #self.windows do
			local window = self.windows[i]
			window:SetShown(i == this:GetID())
		end
	end)
	
	self.Tabs[id] = b
	self.windows[id] = f	
	PanelTemplates_TabResize(b, 0, nil, b:GetFontString():GetStringWidth() + 10)
	PanelTemplates_SetNumTabs(self, id)
	PanelTemplates_SetTab(self, 1)
	f:SetShown(id == 1)
	
	return f
end

function PanelMixin:CommitChanges ()
	for param, value in pairs(self.parameters) do
		Core.db[param] = value
	end
	
	SM:SetPreferences()
end

function PanelMixin:DiscardChanges ()
	for param, value in pairs(self.parameters) do
		self.parameters[param] = Core.db[param]
	end
end

-----

function WindowMixin:Attach (widget, column, yOffset)
	local predictedHeight = widget:GetHeight() + (yOffset or 0) + ySpacing
	if not column then
		widget:SetPoint("TOPLEFT", indent, -self.height)
		self.height = self.height + predictedHeight
	else
		widget:SetPoint("TOPLEFT", self.columnWidth * column + indent + 5, -self.columns[column])
		self.columns[column] = self.columns[column] + predictedHeight
	end
	
	if widget:GetObjectType() == "FontString" then
		widget:SetPoint("RIGHT", -indent, 0)
		widget:SetMaxLines(2)
	end
end

function WindowMixin:NewString (text, fObject)
	local fs = self:CreateFontString(nil, "OVERLAY", fObject or "GameFontWhite")
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	
	return fs
end

function WindowMixin:NewTitle (text)
	self:Attach(self:NewString(text, "GameFontNormalLarge"), nil, 20)
end

function WindowMixin:NewSection (title, y, desc)
	self.columns = self.columns or {}

	local fs = self:NewString(title, "GameFontNormalLarge")
	self:Attach(fs)
	
	if desc then
		self:Attach(self:NewString(desc, "SystemFont_Shadow_Small"), nil)
	end

	for i=0, 2 do
		self.columns[i] = self.height
	end
	
	self.height = self.height + y - (desc and 14 or 0)
	
	local border = CreateFrame("Frame", nil, self, "BackdropTemplate")
	border:SetBackdrop({edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]], edgeSize=8})
	border:SetPoint("TOPLEFT", fs, -10, 5)
	border:SetPoint("RIGHT", self, -indent, 0)
	border:SetHeight(y)
end

function WindowMixin:CreateDescription (column, text)
	self:Attach(self:NewString(text), column, not column and 20 or nil)
end

function WindowMixin:CreateCheckButton (column, param, description)
	local cb = CreateFrame("CheckButton", nil, self, "SessionsCheckButtonTemplate")
	cb:SetScript("OnClick", function(this) self.panel.parameters[param] = this:GetChecked() end)
	cb:SetScript("OnShow", function(this) this:SetChecked(Core.db[param]) end)
	cb.label:SetText(description)
	self:Attach(cb, column)
end

function WindowMixin:CreateSlider (column, param, MIN, MAX)
	local name = "SM_PanelSlider_".. param
	local slider = CreateFrame("Slider", name, self, "OptionsSliderTemplate")
	slider.value = self:NewString("(".. Core.db[param].. ")")
	slider.value:SetPoint("CENTER", slider, "CENTER", 0, -12)
	slider:SetMinMaxValues(MIN, MAX)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	_G[name.. "Low"]:SetText(MIN)
	_G[name.. "High"]:SetText(MAX)
	slider:SetScript("OnValueChanged", function(this, val)
		this.value:SetText(string.format("(%s)", val))
		self.panel.parameters[param] = val
	end)
	slider:SetScript("OnShow", function(this) this:SetValue(self.panel.parameters[param] or Core.db[param]) end)
	self:Attach(slider, column, 20)
end

function WindowMixin:CreateScrollingList (column)
	local scroller = CreateFrame("ScrollFrame", nil, self, "SessionsQuickListTemplate")
	scroller:SetScript("OnShow", function(this) 
		for i=1, #this.items do
			local item = this.items[i]
			item:UnlockHighlight()
			
			if item.label:GetText() == Core.db["TextFont"] then
				item:LockHighlight()
			end
		end
	end)
	
	scroller.items = {}
	self:Attach(scroller, column)
	return scroller
end

function WindowMixin:CreateEditBox (column, param, includeArrow)
	local box = CreateFrame("EditBox", nil, self, "InputBoxInstructionsTemplate")
	box:SetAutoFocus(false)
	box:SetSize(120, 30)
	box.Instructions:SetText(param.. "...")
	box.parameter = param
	
	if includeArrow then
		local tex = self:CreateTexture(nil, "OVERLAY")
		tex:SetTexture([[Interface\Tooltips\ReforgeGreenArrow]])
		tex:SetPoint("LEFT", box, "RIGHT", 30, 0)
	end

	self:Attach(box, column, 10)
	return box
end

function WindowMixin:CreateButton (column, text, func)
	local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	btn:SetText(text)
	btn:SetWidth(100)
	btn:SetScript("OnClick", func)
	self:Attach(btn, column)

	return btn
end

Core.PanelHelper = PanelMixin
