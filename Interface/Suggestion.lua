local ADDON_NAME, Core = ...

--<
local UI = Core.UI
local utils = Core.utils
-->


function Core.CreateSuggestionFrame ()
	if Core.suggestionFrame then
		return
	end

	local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
	f:SetFrameStrata("TOOLTIP")
	f:Hide()
	f.BG = f:CreateTexture(nil, "BACKGROUND")
	f.BG:SetAllPoints()
	f.BG:SetSize(f:GetSize())
	f.BG:SetColorTexture(.09, .11, .2, .9)

	f.title = f:CreateFontString(nil)
	f.title:SetPoint("TOP", -3, -2)
	f.title:SetFont([[Fonts\MORPHEUS.ttf]], 9, "OUTLINE")
	f.title:SetTextColor(1, 1, .4)
	f.title:SetText([[|TInterface\MINIMAP\TRACKING\None:16:16|t Suggestions]])

	f:SetBackdrop({edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]], edgeSize=6})
	f.names = {}
	f.btnCache = {}
	f.MAX_BUTTONS = 4
	f.BUTTON_HEIGHT = 12
	
	f.Attach = function(self, parent)
		self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 2)
		self:SetWidth(parent:GetWidth())
	end
	
	f.ClearList =  function(self)
		for i, btn in ipairs(self.names) do
			btn:ClearAllPoints()
			btn:Hide()
			
			self.names[i] = nil
			table.insert(self.btnCache, btn)
		end
	end
	
	f.Detach = function(self)
		self:ClearAllPoints()
		self:ClearList()
		self:Hide()
	end
	
	f.Update = function (self)
		if #self.names > 0 then
			self:SetHeight(#self.names * self.BUTTON_HEIGHT + 17)
			if not self:IsShown() then self:Show() end
		else
			self:Hide()
		end
	end
	
	f.Add = function(self, displayName, func)
		local b
		
		if #self.btnCache > 0 then
			b = table.remove(self.btnCache)
			
		else
			b = CreateFrame("Button", nil, self)
			b:SetHighlightTexture([[Interface\FriendsFrame\UI-FriendsFrame-HighlightBar-Blue]])
			b:SetNormalFontObject("SystemFont_Outline_Small")
			b:SetSize(self:GetWidth(), self.BUTTON_HEIGHT)
			b:SetText(displayName)
			b:SetScript("PostClick", function() self:Detach() end)
			local fS = b:GetFontString()
			fS:SetAllPoints()
		
		end

		b:SetScript("OnClick", func)
		b:SetPoint("BOTTOM", 0, (self.BUTTON_HEIGHT * #self.names)+4)
	
		b:SetText(displayName)
		b:Show()
		
		self.names[#self.names+1] = b
		self:Update()
	end
	
	f.HasSpace = function(self)
		return (#self.names < self.MAX_BUTTONS)
	end
	
	f:SetScript("OnShow", function(self) self:Update() end)
	Core.suggestionFrame = f
end