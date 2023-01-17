local ADDON_NAME, Core = ...

--<
local UI = Core.UI
-->


local function onValueChanged (self, value)
	self.controller:SetScrollOffset(-value)
	
	if self.controller:AtBottom() then
		self.toBottom:Hide()
	elseif not self.toBottom:IsShown() then
		self.toBottom:Show()
	end
end


local function scrollToBottomOnClick (button)
	local self = button:GetParent()
	
	self.controller:ScrollToBottom()
	self:SetValue(0)
end


local function Update (self)
	self:SetMinMaxValues(-self.controller:GetMaxScrollRange(), 0)
	self:SetValue(-self.controller:GetScrollOffset())
end


local function SetController (self, new)
	self.controller = new
	self:update()
end


function Core.CreateSlider (parent)
	local f = CreateFrame("Slider", nil, parent)
	f.toBottom = CreateFrame("Button", nil, f)
	
	f:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
	f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 10)
	f:SetOrientation("VERTICAL")
	f:SetWidth(10)
	f:SetMinMaxValues(0, 1)
	f:SetValue(0)
	f:SetValueStep(1)
	f:SetObeyStepOnDrag(true)
	f.controller = parent
	f:SetHitRectInsets(-20, 0, 0, 0)
	
	f.knobTexture = f:CreateTexture(nil)
	f.knobTexture:SetSize(2, 18)
	f.knobTexture:SetColorTexture(.8, .8, .8)
	f:SetThumbTexture(f.knobTexture)
	f.knobTexture:SetPoint("TOPRIGHT", -3, 0)

	f.toBottom:SetPoint("BOTTOM", -20, -2)
	f.toBottom:SetSize(32, 32)
	f.toBottom:SetNormalTexture([[Interface\BUTTONS\UI-MicroStream-Yellow]])
	f.toBottom:GetNormalTexture():SetDesaturated(true)
	f.toBottom:Hide()
	f.toBottom:SetScript("OnClick", scrollToBottomOnClick)
	
	f.SetController = SetController	
	f.update = Update
	
	f:SetScript("OnValueChanged", onValueChanged)
	
	return f
end