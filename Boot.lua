local ADDON_NAME, Core = ...

--<
local format, gsub, upper, match = string.format, string.gsub, string.upper, string.match
-->


Core.VERSION = "2.0.1"
Core.TAB_HEIGHT = 40
Core.TAB_SPACING = 2
Core.TAB_TOTALHEIGHT =  Core.TAB_HEIGHT + Core.TAB_SPACING
Core.LINE_HEIGHT = 14
Core.colours = {}
Core.utils = {}
Core.myInfo = {}
Core.SM = {}
Core.L = setmetatable({}, {
	__index = function(self, key)
		return key
	end
})

--
BINDING_HEADER_SESSIONSMSGR = "Sessions Messenger"
BINDING_NAME_SMToggle = "Show/Hide UI Toggle"
BINDING_NAME_SMTalkToUnit = "Talk To Target (or mouseover)"
BINDING_NAME_SMChatOverride = "Focus SM's Editbox"

StaticPopupDialogs["SESSIONS_COPYTEXT"] = {
	text = "Ctrl-C to copy the text/link",
	button1 = DONE,
	hasEditBox = true,
	maxLetters = false,
	maxBytes = false,
	editBoxWidth = 260,
	enterClicksFirstButton = true,
	hideOnEscape = true,
	whileDead = true,
	OnShow = function(self, text) self.editBox:SetText(text); self.editBox:SetFocus() end,
	OnHide = function(self) self.data = nil end,
	EditBoxOnTextChanged = function(self, text) self:SetText(text); self:HighlightText() end,
	EditBoxOnEscapePressed = HideParentPanel,
	EditBoxOnEnterPressed = HideParentPanel,
}

--
function Core.utils.capitalize (str)
	return str:lower():gsub("^%l", upper)
end


function Core.utils.any (key, ...)
	local isAny = false
	
	for i=1, select("#", ...) do
		if key == select(i, ...) then
			isAny = true
			break
		end
	end
	
	return isAny
end


function Core.utils.GetColouredPlayerLink (name, englishClass, rpalias)
	local classColour = RAID_CLASS_COLORS[englishClass]
	return classColour:WrapTextInColorCode(GetPlayerLink(name, rpalias or Ambiguate(name, "none")))
end


function Core.utils.GetRGB (ctype)
	local info = ChatTypeInfo[ctype]
	return info.r, info.g, info.b
end


local function showGameTooltip (frame)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, frame.tipTitle)
	if frame.tipBody then
		GameTooltip:AddLine(frame.tipBody)
	end
	GameTooltip:Show()
end


function Core.utils.RegisterForTooltip (frame)
	frame:SetScript("OnEnter", showGameTooltip)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end


function Core.utils.GetEpochFromString (dt)
	local y, m, d = string.match(dt, "(%d+)-(%d+)-(%d+)")
	return time({year=y, month=m, day=d})
end


function Core.utils.getFullName (name, realm)
	if name:match("-") then return name end	
	return format("%s-%s", name, (realm ~= "" and realm) or Core.myRealmName)
end


function Core.utils.SMPrint (msg)
	if Core.SM.selected then
		Core.SM.selected.page:AddMessage(format("%s(SM) %s|r", RGBToColorCode(0.45, 0.8, 0.7), msg))
	else
		print( format("%s(SM) %s|r", RGBToColorCode(0.45, 0.8, 0.7), msg) )
	end
end


function Core.utils.AddOrRemoveEvents (frame, rm, ...)
	for i=1, select("#", ...) do
		if rm then
			frame:UnregisterEvent(select(i, ...))
		else
			frame:RegisterEvent(select(i, ...))
		end
	end
end


function Core.utils.SaveFramePosition (frame, layout)
	local layout = Core.db[layout]
	
	local point, parent, rel, x, y = frame:GetPoint()
	layout.point = point
	layout.rel = rel
	layout.x = x
	layout.y = y
	
	Core.db.Docked = Core.UI.dockMode
end


function Core.utils.ParseURL (text)
	if text:match("[^<]https?://") then
		text = gsub(text, "https?://[%w%p]+", "|H%1|h|cFF3366BB<%1>|r|h")
	else
		text = gsub(text, "[%w%-%.]+%.[%w%-]+%/[%w%p]+", "|Hhttp://%1|h|cFF3366BB<http://%1>|r|h")
	end
	
	return text
end


function Core.utils.AddError (err)
	if not Core.debugging then Core.debugging = {} end
	Core.debugging[#Core.debugging+1] = err
end


function Core.utils.ScanForGUID (name, fullName)
	local guid --= Core.History:GetInfo(upper(fullName))
	
	if guid then
		return guid
	end
	
	local friendInfo = C_FriendList.GetFriendInfo(name)
	if friendInfo then
		return friendInfo.guid
	end
	
	if IsInGuild() then
		local _, numMemOnline = GetNumGuildMembers()

		for i=1, numMemOnline do
			local memName,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_, memGUID = GetGuildRosterInfo(i)
			if memName == fullName then
				return memGUID
			end
		end
	end
	
	return false
end


function Core.utils.CreateDefaultBaseFrame (globalName)
	local f = CreateFrame("Frame", globalName or nil, UIParent, "BackdropTemplate")
	f:SetDontSavePosition(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetHitRectInsets(0, 0, -15, 0)
	f.BG = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.BG:SetPoint("BOTTOMRIGHT", -2, 2)
	f.BG:SetPoint("TOPLEFT", 2, 0)
	
	f.header = CreateFrame("Frame", nil, f)
	f.header:SetHeight(13)
	f.header:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 1, 0)
	f.header:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -1, 0)
	f.header.BG = f.header:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.header.BG:SetAllPoints()
	f.header.BG:SetColorTexture(0,0,0)
	f.header.closeBtn = CreateFrame("Button", nil, f.header)
	f.header.closeBtn:SetSize(16, 16)
	f.header.closeBtn:SetPoint("TOPRIGHT", 1, 2)
	f.header.closeBtn:SetNormalTexture([[Interface\FriendsFrame\ClearBroadcastIcon]])
	
	f:Hide()
	return f
end

Core.UI = CreateFrame("Frame", ADDON_NAME.."_MainFrame", UIParent, "BackdropTemplate")
--Core.UI = Core.utils.CreateDefaultBaseFrame(ADDON_NAME.. "_MainFrame")

Core.colours.black = CreateColor(0, 0, 0, 1)
Core.colours.white = CreateColor(1, 1, 1, 1)
Core.colours.grey = CreateColor(0.5, 0.5, 0.5, 0.7)
Core.colours.greyText = CreateColor(0.7, 0.7, 0.7)


local Bulletin = CreateFrame("Frame")
--[[
function Bulletin:Init ()
	self:SetClampedToScreen(true)
	
	self.BG = self:CreateTexture(nil)
	self.BG:SetColorTexture(0, 0, 0)
	self.BG:SetPoint("TOPLEFT", 6, -5)
	self.BG:SetPoint("BOTTOMRIGHT", -6, 5)
	self:SetBackdrop({edgeFile="Interface/Tooltips/CHATBUBBLE-BACKDROP", edgeSize=24})
	
	self.title = self:CreateFontString(nil)
	self.title:SetFont("Fonts/FRIZQT__.ttf", 16, "OUTLINE")
	self.title:SetPoint("TOPLEFT", 10, 15)
	
	self.msg = self:CreateFontString(nil)
	self.msg:SetFont("Fonts/ARIALN.ttf", 14)
	self.msg:SetPoint("TOPLEFT", 10, -4)
	self.msg:SetPoint("BOTTOMRIGHT", -3, 5)
	self.msg:SetJustifyH("LEFT")
	
	self.tail = self:CreateTexture(nil)
	self.tail:SetTexture("Interface/Tooltips/CHATBUBBLE-TAIL")
	self.tail:SetSize(32, 32)
	
	self.fadeOut = self:CreateAnimationGroup()
	self.alphaAnim = self.fadeOut:CreateAnimation("Alpha")
	self.alphaAnim:SetStartDelay(2)
	self.alphaAnim:SetDuration(2)
	self.alphaAnim:SetFromAlpha(1)
	self.alphaAnim:SetToAlpha(0)
	self.fadeOut:SetScript("OnFinished", function(...) self:Hide() end)
end
--]]



Core.utils.AddOrRemoveEvents(Bulletin, false, "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "FRIENDLIST_UPDATE", "PLAYER_LEAVING_WORLD")


local function checkIngameFriends ()
	local numFriends = C_FriendList.GetNumOnlineFriends()

	if numFriends >= 1 then
		local friends = {[1] = "In-game friends online:"}
		
		for i=1, numFriends do
			f = C_FriendList.GetFriendInfoByIndex(i)
			englishClass = select(2, GetPlayerInfoByGUID(f.guid))
			
			friends[#friends+1] = "[".. Core.utils.GetColouredPlayerLink(f.name, englishClass).. "]"
		end
		
		Core.utils.SMPrint(table.concat(friends, " "))
	end
end



local ranOnce = false
Bulletin:SetScript("OnEvent", function (self, e, ...)
	if e == "PLAYER_ENTERING_WORLD" then
		Core.UpdatePlayerInfo()
		--C_FriendList.ShowFriends()

		if ranOnce then
			return
		end
		
		Core.G_EditBox = DEFAULT_CHAT_FRAME.editBox
		C_ChatInfo.RegisterAddonMessagePrefix("SessionsMSGR")
		
		Core.RPAddOn = (IsAddOnLoaded("TotalRP3") and "TRP3")	
			or (IsAddOnLoaded("XRP") and "XRP")
			or (IsAddOnLoaded("MyRolePlay") and "MRP")
			or false

		Core.LSM = LibStub("LibSharedMedia-3.0")
		Core.Sessions:UpdateChatFont()
		Core.LoadPreferences()
		
		ranOnce = true
		
	elseif e == "ADDON_LOADED" then
		local a = ...
		if a == ADDON_NAME then	
			if type(SESMSG_History) ~= "table" then
				SESMSG_History = {}
			end
			
			if SESMSG_Profile == nil then
				SESMSG_Profile = Core.defaultConfig
			
			else
				for k, v in pairs(Core.defaultConfig) do
					if SESMSG_Profile[k] == nil then
						SESMSG_Profile[k] = v
					end
				end
				if SESMSG_Profile["Version"] ~= Core.VERSION then
					for k, v in pairs(SESMSG_Profile) do
						if Core.defaultConfig[k] == nil then
							SESMSG_Profile[k] = nil
						end
					end
					
					if SESMSG_Profile["HistoryExpiry"] < 30 and SESMSG_Profile["HistoryExpiry"] ~= 0 then
						SESMSG_Profile["HistoryExpiry"] = 14
					end
					
					SESMSG_Profile["Version"] = Core.VERSION
				end
			end
			
			Core.ChatFont = CreateFont("SessionsMessengerChatFont")
			Core.ChatFont:CopyFontObject("GameFontNormal")
			
			--Core.Hub_Init()
			Core.FloatingOptions_Init()
			Core.db = SESMSG_Profile
			
			--Core.LoadPreferences()
			
			SlashCmdList["SESSIONS_TOGGLEUI"] = function(msg)
				UI:Toggle()
			end
				SLASH_SESSIONS_TOGGLEUI1 = "/sessions"
				SLASH_SESSIONS_TOGGLEUI2 = "/sm"
				
			
			SlashCmdList["SESSIONS_CHECKVER"] = function(msg)
				Core.utils.SMPrint("Current version: ".. Core.VERSION)
			end			
				SLASH_SESSIONS_CHECKVER1 = "/smversion"

			self:UnregisterEvent("ADDON_LOADED")
		end
	
	elseif e == "PLAYER_LEAVING_WORLD" then
		if Core.db.LastHistoryCleanUp ~= date("%Y-%m-%d") then
			Core.History:CleanUp()
		end

	elseif e == "FRIENDLIST_UPDATE" then
		--checkIngameFriends()
		self:UnregisterEvent("FRIENDLIST_UPDATE")
	end
end)

