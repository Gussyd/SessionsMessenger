local ADDON_NAME, Core = ...

local function create_container (parent)
	local viewport = CreateFrame("ScrollFrame", nil, parent)
	viewport:SetPoint("BOTTOMLEFT", parent)
	viewport:SetPoint("BOTTOMRIGHT", parent)
	viewport:SetHeight(parent:GetHeight())
	
	local container = CreateFrame("Frame", nil, viewport)
	container:SetSize(viewport:GetSize())
	container:SetAllPoints()
	
	viewport.container = container
	return viewport
end