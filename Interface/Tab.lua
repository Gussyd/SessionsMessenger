local ADDON_NAME, Core = ...

--<
local format = string.format
local utils = Core.utils
local UI = Core.UI
-->

local frameCache = {}
Core.orderedTabs = {}


Core.clientTextures = {
	["App"] =  [[Interface\CHATFRAME\UI-ChatIcon-Battlenet]],
	["D3"] =   [[Interface\CHATFRAME\UI-ChatIcon-D3]],
	["Hero"] = [[Interface\CHATFRAME\UI-ChatIcon-HotS]],
	["S1"] =   [[Interface\CHATFRAME\UI-ChatIcon-SC]],
	["S2"] =   [[Interface\CHATFRAME\UI-ChatIcon-SC2]],
	["WoW"] =  [[Interface\CHATFRAME\UI-ChatIcon-WoW]],
	["WTCG"] = [[Interface\CHATFRAME\UI-ChatIcon-WTCG]],
	["Pro"] =  [[Interface\CHATFRAME\UI-ChatIcon-Overwatch]],
	["VIPR"] = [[Interface\CHATFRAME\UI-ChatIcon-CallOfDutyBlackOps4]],
	["W3"] =   [[Interface\CHATFRAME\UI-ChatIcon-Warcraft3Reforged]],
	["ODIN"] = [[Interface\CHATFRAME\UI-ChatIcon-CallOfDutyMWicon]],
	["LAZR"] = [[Interface\CHATFRAME\UI-ChatIcon-CallOfDutyMW2icon]],
}


Core.clientStrings = {
	["App"] =  "In App",
	["D3"] =   "Playing D3",
	["Hero"] = "Playing HotS",
	["S1"] =   "Playing SC1",
	["S2"] =   "Playing SC2",
	["WTCG"] = "In Hearthstone",
	["Pro"] =  "Playing OW",
	["VIPR"] = "Playing CoD:BO4",
	["W3"] =   "Playing W3:R",
	["ODIN"] = "Playing CoD:MW",
	["LAZR"] = "Playing CoD:MW2",
}

-- Reverse lookup table for localised class names
local locClassNames = {}
for eng, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	locClassNames[loc] = eng
end
for eng, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
	locClassNames[loc] = eng
end


function Core.AppendTab (f)
	if #Core.orderedTabs == 0 then
		f:SetPoint("TOP")
	else 
		f:SetPoint("TOP", 0, -(#Core.orderedTabs * Core.TAB_TOTALHEIGHT))
	end
	
	if not f:IsShown() then f:Show() end
end


function Core.Tab_ReanchorAll ()
	if #Core.orderedTabs >= 1 then
		for i, t in ipairs(Core.orderedTabs) do
			t:ClearAllPoints()
			
			if i == 1 then
				t:SetPoint("TOP")
				
			else
				t:SetPoint("TOP", 0, -(i-1) * Core.TAB_TOTALHEIGHT)
			end
			
			t.tabIndex = i
		end
	end
	
	UI.RefreshTabContainer()
end


function Core.CloseTab (f)
	for i, tab in ipairs(Core.orderedTabs) do
		if tab == f then
			table.remove(Core.orderedTabs, i)
			break
		end
	end
	
	f:ClearAllPoints()
	f:Hide()
	f.tabIndex = 0
	
	if f.portrait:GetVertexColor() ~= 1 then
		f.portrait:SetTexCoord(0, 1, 0, 1)
		f.portrait:SetVertexColor(1, 1, 1)
	end
	if f.portrait:GetSize() ~= 48 then
		f.portrait:SetSize(48, 48)
	end
	
	table.insert(frameCache, f)	
	Core.Tab_ReanchorAll()
end


function Core.BNetDisplayUpdate (tab, info)
	tab.portrait:SetTexture(Core.clientTextures[info.clientProgram] or Core.clientTextures["App"])
	
	local status
	
	if info.characterName then
		local colour = RAID_CLASS_COLORS[locClassNames[info.className]]
		status = string.format("%s (%s)", colour and colour:WrapTextInColorCode(info.characterName) or info.characterName, info.characterLevel)
	else
		status = Core.clientStrings[info.clientProgram] or (info.isOnline and "|cFFff794dAway|r" or "|cFFb3b3b3Offline|r")
	end
	
	tab.infoString:SetText(status)
end


local function acquireTabFrame ()
	if #frameCache > 0 then
		return table.remove(frameCache)
	end

	local frame = CreateFrame("Frame", nil, UI.tabContainer, "SessionsTabTemplate")
	frame:SetBackdrop({
		edgeFile=[[Interface\Tooltips\UI-Tooltip-Border]],
		edgeSize=8,
	})
	frame:SetHitRectInsets(1, 1, 1, 1)
	SetPortraitToTexture(frame.notification.BG, [[Interface\BUTTONS\RedGrad64]])
	frame.notification.BG:SetVertexColor(1,0,0)

	return frame
end


function Core.Tab_ApplyTemplate (frame, template, info, session)
	if template == "WHISPER" then
		local gender = (info[5] == 2 and "-male") or (info[5] == 3 and "-female")
		local engClass, engRace = info[2], string.lower(info[4])
		local atlas = "raceicon128-".. engRace.. gender
		--local _texture = format([[Interface\CHARACTERFRAME\TemporaryPortrait-%s-%s]], gender, info[4])
		local c = ChatTypeInfo["WHISPER"]
		--frame.BG:SetGradient("Horizontal", CreateColor(0,0,0,0), CreateColor(c.r, c.g, c.b, 0.3))
		frame.portrait:SetAtlas(atlas)
		--SetPortraitToTexture(frame.portrait, CreateAtlasMarkup(atlas))
		frame.sessionName:SetText(info[6])
		session.classColour = CreateColor(GetClassColor(engClass))
		frame.sessionName:SetTextColor(session.classColour:GetRGB())
		frame.infoString:SetText(info[1])
		
		
	elseif template == "BN_WHISPER" then
		frame.sessionName:SetTextColor(.6, .6, .8)
		frame.portrait:SetSize(32, 32)
		frame.sessionName:SetText(info.accountName)
		
		Core.BNetDisplayUpdate(frame, info.gameAccountInfo)
		
		
	elseif template == "PARTY" then
		frame.portrait:SetTexture([[Interface\COMMON\icon-]].. UnitFactionGroup("player"))
		frame.sessionName:SetText(session.title)
		local c = ChatTypeInfo["PARTY"]
		frame.sessionName:SetTextColor(c.r, c.g, c.b)
		frame.infoString:SetText("")
		
		
	elseif template == "GUILD" then
		SetLargeGuildTabardTextures("player", frame.portrait)
		frame.sessionName:SetText(session.title)
		local c = ChatTypeInfo["GUILD"]
		frame.sessionName:SetTextColor(c.r, c.g, c.b)
		local gn = GetGuildInfo("player")

		if #gn >= 12 then
			gn = gn:sub(1, 12).. "..."
		end
		
		frame.infoString:SetText(format("<%s>", gn))
		

	elseif template == "TEMP" then
		local img
		if session.name == "_console" then
			img = [[Interface\DialogFrame\UI-Dialog-Icon-AlertOther]]
		else
			img = [[Interface\Garrison\Portraits\FollowerPortrait_NoPortrait]]
		end
		
		frame.portrait:SetTexture(img)
		frame.sessionName:SetText(Ambiguate(session.title, "short"))
		frame.sessionName:SetTextColor(Core.colours.white:GetRGBA())
		frame.infoString:SetText("...")
		
	elseif template == "CONSOLE" then
		frame.portrait:SetTexture([[Interface\DialogFrame\UI-Dialog-Icon-AlertOther]])
		frame.sessionName:SetText(session.name)
		frame.infoString:SetText("</>")
	end
end


function Core.CreateTab (session, info)
	local frame = acquireTabFrame()

	Core.AppendTab(frame)
	frame.BG:SetGradient("Horizontal",CreateColor(0.2, 0.2, 0.38, 1),  CreateColor(0, 0, 0, 0.8))
	frame.portrait:SetBlendMode("ADD")
	frame.portrait:SetSize(64, 64)
	
	local template = ((session.needsInfo or info == nil or session.name == "_console") and "TEMP")  or session.chatType
	Core.Tab_ApplyTemplate(frame, template, info, session)
	
	Core.orderedTabs[#Core.orderedTabs+1] = frame
	frame.tabIndex = #Core.orderedTabs
	
	UI.RefreshTabContainer()

	return frame
end


