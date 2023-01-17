local ADDON_NAME, Core = ...

local UI = Core.UI

local elapsed = 0
local function onDrag (self, ms)
	elapsed = elapsed + ms
	if elapsed > 1 then
		elapsed = 0
		self:SetAnchor()
	end
end

local function stopMoving (self)
	self:SetAnchor()
	self:SetScript("OnUpdate", nil)
	self:StopMovingOrSizing()
	Core.utils.SaveFramePosition(self, "HubLayout")
end

local function startMoving (self)
	self:StartMoving()
	self:SetScript("OnUpdate", onDrag)
end

function Core.Hub_Init ()
	local self = CreateFrame("Button", nil, UIParent, "SessionsHubTemplate")
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", startMoving)
	self:SetScript("OnDragStop", stopMoving)
	self.notices = {}
	self.cache = {}
	self.tipTitle = "Sessions Messenger Hub"; self.tipBody = "Click to open Sessions"
	Core.utils.RegisterForTooltip(self)
	
	self:SetScript("OnClick", function() UI:Toggle() end)
	
	self.SetAnchor = function(self)
		local x = self:GetCenter()
		self.anchorRight = x < (GetScreenWidth() / 2) and true or false
		self:Refresh()
	end
	
	self.Refresh = function (self)
		for i=1, #self.notices do
			local f = self.notices[i]
			f:ClearAllPoints()

			if self.anchorRight then
				f:SetPoint("LEFT", self, "RIGHT", i==1 and 3 or (i-1) * (f:GetWidth() + 17), 2)
			else
				f:SetPoint("RIGHT", self, "LEFT", i==1 and -3 or -((i-1) * (f:GetWidth() + 17)), 2)
			end
		end
	end
	
	self.RemoveNotice = function (self, frame)
		frame:ClearAllPoints()
		frame:Hide()
		
		for i=1, #self.notices do
			if self.notices[i] == frame then
				self.cache[#self.cache+1] = table.remove(self.notices, i)
				break
			end
		end
		
		if #self.notices > 0 then
			self:Refresh()
		end
	end
	
	self.AddNotice = function (self, session, ctype)
		local frame
		if #self.cache > 0 then
			frame = table.remove(self.cache)
		else
			frame = CreateFrame("Frame", nil, self, "SessionsNoticeTemplate")
		end		
		self.notices[#self.notices+1] = frame
		
		local r,g,b = Core.utils.GetRGB(ctype)
		frame.BG:SetGradient("Horizontal", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
		frame.text:SetText(session.missedMessages)
		
		local name = session:GetName()
		if name:find("^|") then name = Core.utils.capitalize(session.name) end
		
		frame.title:SetText(string.sub(name, 1, 4))
		frame.icon:SetVertexColor(r,g,b)
		frame:SetShown(not UI:IsShown())
		self:Refresh()
		
		return frame
	end

	Core.hub = self

end