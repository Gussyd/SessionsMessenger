local ADDON_NAME, Core = ...

--<
local table = table
local match, gsub, format = string.match, string.gsub, string.format
local utils = Core.utils
local UI = Core.UI
local L = Core.L
-->

local dates = {}
local orderedDates = {}
local buttonCache = {}
local isDrawn = false


local History = {}

function History:Init ()
	self.log = SESMSG_History
	--self.frame = CreateFrame("Frame")
end

function History:TargetHasEntries (target)
	if self.log[target] == nil then
		return false
	else
		return true
	end
end

function History:GetTargetGUID (target)
	if self:TargetHasEntries(target) then
		return "Player-".. self.log[target].INFO.ID
	end
end

function History:Open ()
	self.frame:Show()
end

--local history = utils.CreateDefaultBaseFrame()
local history =  CreateFrame("Frame", nil, UI.leftFrame)


function history:OnSessionInit (session)
	if self:HasHistorySlot(session.name) then
		local latest, dateString = self:GetMostRecentDate(session.name)
		
		if latest then
			session.page:AddMessage("~~~ Start of history: ".. date("%a, %B %d", utils.GetEpochFromString(dateString)))
			
			for i=#latest-5, #latest do
				if latest[i] ~= nil then
					local inbound = latest[i].IN
					
					local body = format("%s%s|r %s%s: %s",
						RGBToColorCode(.7, .7, .7), latest[i].TS,
						(inbound == true and session:GetName()) or (inbound == false and "Me") or inbound,
						inbound and " said" or "",
						latest[i].MSG
					)
					
					local r, g, b = session:GetRGB()
					
					session.page:AddMessage(body, r*0.75, g*0.75, b*0.75)
				end
			end
			
			session.page:AddMessage("~~~ End of history.")
		end
	end
end


function history:CleanUp ()
	local today = date("%Y-%m-%d")
	local expiry = tonumber(Core.db.HistoryExpiry)*24*60*60
	
	for name, struct in pairs(SESMSG_History) do

		if (name ~= nil) and (struct.HISTORY ~= nil) then	
			for dt, messages in pairs(struct.HISTORY) do
			
				if dt ~= nil then
					local newDate = date("%Y-%m-%d", utils.GetEpochFromString(dt) + expiry)
					
					if newDate <= today then
						struct.HISTORY[dt] = nil
					end
				end
				
			end
		end

	end
	
	Core.db.LastHistoryCleanUp = today
end


function history:NewEntry (...)	
	local name, id = ...
	
	if not self:HasHistorySlot(name) then
		SESMSG_History[name] = {
			["INFO"] = {
				["ID"] = id:gsub("Player%-", ""),
				["MEM"] = false
			},
			["HISTORY"] = {}
		}
	end
end


function history:HasHistorySlot (name)
	if SESMSG_History[name] == nil then
		return false
	else
		return true
	end
end


function history:GetInfo (name)
	if SESMSG_History[name] ~= nil then
		return "Player-".. SESMSG_History[name].INFO.ID	
	else
		return false
	end
end


function history:Fetch (name)
	local slot = SESMSG_History[name]
	dates = wipe(dates)
	self.Open()
	self.display:Clear()
	self.searchBox:ClearFocus()
	self.searchBox:SetText("")
	self.infoString:SetText("")
	self.header.title:SetText("")
	self.dropDownBtn:Disable()
	self.Tabs[1]:Click()
	
	if slot == nil or not slot.INFO.MEM then
		self.display:AddMessage("Nothing found for ".. name)
		return
		
	elseif next(slot["HISTORY"]) == nil and slot.INFO.MEM ~= nil then
		self.display:AddMessage("No recent history found for ".. name)
		self.display:AddMessage("    First message recorded on ".. slot.INFO.MEM.DT)
		self.display:AddMessage("    ".. slot.INFO.MEM.MSG)
		return
	end
	
	for i, dt in ipairs(self:GetOrderedDates(name)) do
		local info = {
			text=format("%s (%s)", date("%A", utils.GetEpochFromString(dt)), dt),
			value=dt,
			func=function(this) self:Preload(name, this.value, true) end,
			checked=function(this) return this.value == self.selectedDate end,
		}
		
		table.insert(dates, info)
	end
	
	if #dates > 0 then
		self.dropDownBtn:Enable()
	end	
	
	self:Preload(name, orderedDates[1], true)
end


function history:Preload (name, dt, run)
	self.display:Clear()
	
	self.selectedDate = dt
	self.selectedName = name
	
	if PanelTemplates_GetSelectedTab(self) ~= 1 then
		self.Tabs[1]:Click()
	end
	
	self:ClearSubstitutions()
	
	if run then
		self:Load()
	end
end


function history:Load ()
	if not self.selectedDate or not self.selectedName then
		return
	end

	local timestamp, author, r, g, b
	local text = ""
	
	local slot = SESMSG_History[self.selectedName].HISTORY[self.selectedDate]
	local displayName = utils.capitalize( Ambiguate(self.selectedName, "short") )
	
	for M, TBL in ipairs(slot) do
		if type(TBL.IN) == "boolean" then
			author = TBL.IN and displayName.. ": " or "Me: "
			r, g, b = 1, 1, 1
		else
			author = TBL.IN.. ": "
			r, g, b = .8, .8, .8
		end

		local pending = TBL.MSG
		
		if #self.substitutions > 0 then
			for i, r in ipairs(self.substitutions) do
				pending = gsub(pending, r.From, r.To)
				author = gsub(author, r.From, r.To)
			end
		end
		
		text = text.. pending
		
		if self.parameters.mergePosts and slot[M+1] ~= nil and slot[M+1]["IN"] == TBL.IN and slot[M+1]["TS"] == TBL.TS then
			--continue
		else
			timestamp = format("%s ", TBL.TS)
			
			self.display:AddMessage(
				((self.parameters.includeTS or self.parameters.includeTS == nil) and timestamp or "")..
				author.. text, 
				r, g, b
			)
			
			text = ""
		end
	end
	
	self.header.title:SetText(format("::|cFFffb90f %s|r :: |cFF6495ed%s|r", utils.capitalize(self.selectedName), self.selectedDate))
	self.infoString:SetText(format("(%s) results found", #dates))
	self.display.slider:update()
	
end


function history:GetOrderedDates (target)
	local slot = SESMSG_History[target]["HISTORY"]
	orderedDates = wipe(orderedDates)
	
	for dt, struct in pairs(slot) do
		table.insert(orderedDates, dt)
	end
	
	if #orderedDates > 0 then
		table.sort(orderedDates, function(a, b) return a > b end)
		return orderedDates
	end
end


function history:GetMostRecentDate (name)
	local ordered = self:GetOrderedDates(name)
	
	if ordered then
		local latest = orderedDates[1]
		return SESMSG_History[name]["HISTORY"][latest], latest
	else
		return false
	end
end


function history:ClearSubstitutions ()
	for i, btn in ipairs(self.substitutions) do
		btn.From = nil
		btn.To = nil
		btn:ClearAllPoints()
		btn:Hide()
		
		self.substitutions[i] = nil
		table.insert(buttonCache, btn)
	end
end


local function populateSuggestionList (editbox)
	local text = editbox:GetText():upper()
	Core.suggestionFrame:ClearList()
	
	if text == "" then 
		return Core.suggestionFrame:Hide() 
	end

	Core.suggestionFrame:Show()
	
	for k, v in pairs(SESMSG_History) do
		if Core.suggestionFrame:HasSpace() and (k:match("^"..text) ~= nil or v.INFO.ID:match("^"..text))  then
			Core.suggestionFrame:Add(utils.capitalize(k), function() history:Fetch(k) end)
		end
	end
end


local function edit_GenerateText ()
	history.display:Clear()
	history:Load()
	
	local pendingText = ""
	
	for lineIndex = 1, history.display:GetNumMessages() do
		msg = history.display:GetMessageInfo(lineIndex)
		pendingText =  format("%s%s\n", pendingText, msg)
	end
	
	StaticPopup_Show("SESSIONS_COPYTEXT", nil, nil, pendingText)
end


local function edit_RemoveSubstitution (button)
	for i, btn in ipairs(history.substitutions) do
		if btn == button then
			table.insert(buttonCache, table.remove(history.substitutions, i))
			btn.From = nil
			btn.To = nil
			btn:Hide()
			btn:ClearAllPoints()

			for ii=1, #history.substitutions do
				local B = history.substitutions[ii]
				B:SetPoint("TOPLEFT", history.subAnchor, "BOTTOMLEFT", 0, -5 - ((ii-1) * button:GetHeight()))
			end
			
			break
		end
	end
	
	if #history.substitutions < 4 and not history.addButton:IsEnabled() then
		history.addButton:Enable()
	end
end


local function edit_AddSubstitution (addButton)
	if not history.From or history.From == "" or not history.To or history.To == "" or history.From == history.To then
		return
	end

	for i=1, #history.substitutions do
		local btn = history.substitutions[i]
		if btn.From == history.From then
			return 
		end
	end
	
	local button
	if #buttonCache > 0 then
		button = table.remove(buttonCache)
	else
		button = CreateFrame("Button", nil, history.subAnchor, "UIPanelButtonTemplate")
		button:SetSize(60, 20)
		button:SetText("Remove")
		button.label = button:CreateFontString(nil, "OVERLAY", "NumberFont_Shadow_Med")
		button.label:SetPoint("LEFT", button, "RIGHT", 5, 0)
		button.label:SetJustifyH("LEFT")
		button:SetScript("OnClick", edit_RemoveSubstitution)
	end
	
	button:SetPoint("TOPLEFT", history.subAnchor, "BOTTOMLEFT", 0, -5-(#history.substitutions * button:GetHeight()))
	button.label:SetText(string.format("Replacing '%s' with '%s'", history.From, history.To))
	button.From = history.From
	button.To = history.To
	button:Show()
	table.insert(history.substitutions, button)
	
	if #history.substitutions == 4 then
		addButton:Disable()
	end
end


local function drawUI ()
	local self = history
	self:SetAllPoints()
	
	local titleBG = self:CreateTexture(nil, "OVERLAY", nil)
	titleBG:SetSize(UI.leftFrame:GetWidth(), 16)
	titleBG:SetPoint("TOP", 0, -2)
	titleBG:SetColorTexture(Core.colours.black:GetRGBA())
	
	local title = self:CreateFontString()
	title:SetFontObject("GameFontWhite")
	title:SetPoint("CENTER", titleBG)
	title:SetText(L["History"])
	
	local searchBar = CreateFrame("EditBox", nil, self, "SearchBoxTemplate")
	searchBar:SetPoint("TOP", 0, -30)
	searchBar:SetSize(132, 24)
	searchBar.Instructions:SetText("Search player...")
	searchBar:SetAutoFocus(false)
	
	self.searchBar = searchBar
	
	local scroller = CreateFrame("ScrollFrame", nil, UI.leftFrame)
	scroller:SetSize(24, 180)
	scroller:SetPoint("BOTTOM")

	local container = CreateFrame("Frame", nil, scroller)
	container:SetSize(scroller:GetSize())
	container:SetAllPoints()

	scroller:SetScrollChild(container)
	
end


local function initHistoryPanel ()
	Core.CreateSuggestionFrame()
	history.substitutions = {}
	
	history:SetSize(650, 600)
	history:SetPoint("CENTER")
	history:SetFrameStrata("HIGH")
	history:SetScript("OnDragStart", history.StartMoving)
	history:SetScript("OnDragStop", history.StopMovingOrSizing)
	history.BG:SetColorTexture(0, 0, 0, 0.9)
	history:SetBackdrop({edgeFile=[[Interface\FriendsFrame\UI-Toast-Border]], edgeSize=8})

	history.header.staticTitle = history.header:CreateFontString(nil, "OVERLAY")
	history.header.staticTitle:SetPoint("LEFT", 5, 0)
	history.header.staticTitle:SetFont([[Fonts\MORPHEUS.ttf]], 20, "OUTLINE")
	history.header.staticTitle:SetText("History Viewer")
	history.header.title = history.header:CreateFontString(nil, "OVERLAY")
	history.header.title:SetPoint("LEFT", history.header.staticTitle, "RIGHT", -5, 0)
	history.header.title:SetFont([[Fonts\MORPHEUS.ttf]], 17, "OUTLINE")
	history.header.closeBtn:SetScript("OnClick", function() history:CloseAll() end)

	Mixin(history, Core.PanelHelper)
	history:Init()
	
	local searchBox = history:CreateEditBox(nil, "Search...")
	searchBox:SetScript("OnEnterPressed", function(this) self:Fetch(this:GetText()) ; this:SetText("") end)
	searchBox:HookScript("OnTextChanged", populateSuggestionList)
	searchBox:HookScript("OnEditFocusGained", function(this) Core.suggestionFrame:Attach(this) ; if history.lastSearched then Core.suggestionFrame:Add(utils.capitalize(history.lastSearched), function() history:Fetch(history.lastSearched) end) end end)
	searchBox:SetScript("OnEditFocusLost", function() if Core.suggestionFrame:IsMouseOver() then return end Core.suggestionFrame:Detach() end)
	history.searchBox = searchBox
	
	local dropDownBtn = CreateFrame("Button", nil, history)
	dropDownBtn:SetSize(32, 32)
	dropDownBtn:SetNormalTexture([[Interface\CHATFRAME\UI-ChatIcon-ScrollDown-Up]])
	dropDownBtn:SetPushedTexture([[Interface\CHATFRAME\UI-ChatIcon-ScrollDown-Down]])
	dropDownBtn:SetDisabledTexture([[Interface\CHATFRAME\UI-ChatIcon-ScrollDown-Disabled]])
	dropDownBtn:SetHighlightTexture([[Interface\BUTTONS\UI-Common-MouseHilight]])
	dropDownBtn:Disable()
	dropDownBtn:SetPoint("RIGHT", history.searchBox, "RIGHT", 40, 0)
	dropDownBtn:SetScript("OnClick", function(this) EasyMenu(dates, Core.UI.floatingMenu, "cursor", 0, 0, "MENU") end)
	history.dropDownBtn = dropDownBtn
	
	history.infoString = history:CreateFontString(nil, "OVERLAY")
	history.infoString:SetPoint("LEFT", dropDownBtn, "RIGHT", 5, 0)
	history.infoString:SetFontObject("NumberFont_Shadow_Med")
	
	history:NewNavigation()
	history.display = Core.CreatePage(history)
	history.display:ClearAllPoints()
	history.display.slider = Core.CreateSlider(history.display)
	
	history:NewWindow("File", history.display)
	local editWindow = history:NewWindow("Format & Copy")
	editWindow:CreateDescription(nil, "Use this section to copy the selected session's history. Note: modifying this text does not alter the original history.")
	editWindow:NewSection("1. Formatting", 55)
	editWindow:CreateCheckButton(0, "includeTS", "Show timestamps")
	editWindow:CreateCheckButton(1, "mergePosts", "Merge multi-posts")
	
	editWindow:NewSection("2. Substitutions", 200, "Replace all occurences of a word or string of letters into another")
	editWindow:CreateDescription(0, "Original string")
	local eb1 = editWindow:CreateEditBox(0, "From", true)
	local func = function(this) history[this.parameter] = this:GetText() end
	eb1:SetScript("OnEditFocusLost", func)
	eb1:SetScript("OnEnterPressed", func)
	history.subAnchor = eb1
	editWindow:CreateDescription(1, "Target string")
	local eb2 = editWindow:CreateEditBox(1, "To", true)
	eb2:SetScript("OnEditFocusLost", func)
	eb2:SetScript("OnEnterPressed", func)
	editWindow.columns[2] = editWindow.columns[2] + 21
	history.addButton = editWindow:CreateButton(2, "Add", edit_AddSubstitution)
	
	editWindow:NewSection("3. Copy History", 55)
	editWindow:CreateButton(1, "Generate!", edit_GenerateText)

	isDrawn = true
end


function history.Open ()
	local debug = true
	if debug then return utils.SMPrint("History module disabled temporarily") end
	if not isDrawn then
		initHistoryPanel()
	end

	history:Show()
end


function history:CloseAll ()
	self.display:Clear()
	self.display:RefreshLayout()
	self:ClearSubstitutions()
	
	self.lastSearched = self.selectedName
	self.selectedDate = nil
	self.selectedName = nil
	
	self:Hide()
end


Core.History = history
