local ADDON, ns = ...

local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local ROW_H = 26
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- pull an item off the cursor (drag & drop) onto the list
local function addFromCursor()
	local kind, id, link = GetCursorInfo()
	if kind == "item" then
		local qty = tonumber(ns.addQty and ns.addQty:GetText()) or 1
		ns.AddItem(link or id, qty)
		ClearCursor()
	end
end

----------------------------------------------------------------------
-- item rows
----------------------------------------------------------------------
local function getRow(i)
	ns.rows = ns.rows or {}
	local row = ns.rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, ns.listContent)
	row:SetHeight(ROW_H)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", 2, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
	row.remove:SetSize(22, 22)
	row.remove:SetPoint("RIGHT", 0, 0)

	row.enable = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.enable:SetSize(22, 22)
	row.enable:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)

	row.qty = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	row.qty:SetSize(40, 18)
	row.qty:SetPoint("RIGHT", row.enable, "LEFT", -8, 0)
	row.qty:SetAutoFocus(false)
	row.qty:SetNumeric(true)
	row.qty:SetJustifyH("CENTER")

	row.have = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.have:SetPoint("RIGHT", row.qty, "LEFT", -8, 0)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row.have, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	ns.rows[i] = row
	return row
end

function ns.RefreshList()
	if not ns.listContent then return end
	local items = ns.DB().items
	local visible = math.max(1, math.floor(ns.listContent:GetHeight() / ROW_H))
	local maxOffset = math.max(0, #items - visible)
	ns.listOffset = math.min(ns.listOffset or 0, maxOffset)

	ns.emptyText:SetShown(#items == 0)

	for i = 1, visible do
		local idx = i + (ns.listOffset or 0)
		local e = items[idx]
		local row = getRow(i)
		if e then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", ns.listContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
			row:SetPoint("TOPRIGHT", ns.listContent, "TOPRIGHT", 0, -(i - 1) * ROW_H)
			if not e.icon then e.icon = select(5, GetItemInfoInstant(e.id or e.name)) end
			row.icon:SetTexture(e.icon or QUESTION)
			row.name:SetText(e.name or "?")
			local have = GetItemCount(e.id or e.name) or 0
			local want = tonumber(e.qty) or 0
			row.have:SetText("have " .. have)
			if have >= want then row.have:SetTextColor(0.4, 0.8, 0.4) else row.have:SetTextColor(0.9, 0.6, 0.3) end
			row.qty:SetText(tostring(e.qty or 0))
			row.enable:SetChecked(e.enabled)
			row.qty:SetScript("OnEnterPressed", function(self)
				e.qty = tonumber(self:GetText()) or 0
				self:ClearFocus()
				ns.RefreshList()
			end)
			row.enable:SetScript("OnClick", function(self) e.enabled = self:GetChecked() and true or false end)
			row.remove:SetScript("OnClick", function() ns.RemoveItem(idx) end)
			row:Show()
		else
			row:Hide()
		end
	end
	for i = visible + 1, #ns.rows do ns.rows[i]:Hide() end
end

----------------------------------------------------------------------
-- options page (lives in ESC > Options > AddOns)
----------------------------------------------------------------------
function ns.BuildOptions()
	if ns.panel then return end
	local db = ns.DB()

	local o = CreateFrame("Frame", "ToppedOffOptions", nil, "BackdropTemplate")
	ns.panel = o
	o:Hide()

	local head = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	head:SetPoint("TOPLEFT", 16, -16)
	head:SetText("Topped Off")

	local desc = o:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	desc:SetPoint("TOPLEFT", 16, -40)
	desc:SetText("Set the items and amounts you always want in your bags; it tops them up at any vendor that sells them.")

	-- auto-buy master toggle
	local auto = CreateFrame("CheckButton", nil, o, "UICheckButtonTemplate")
	auto:SetSize(24, 24)
	auto:SetPoint("TOPLEFT", 14, -60)
	local autoLbl = auto:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	autoLbl:SetPoint("LEFT", auto, "RIGHT", 2, 0)
	autoLbl:SetText("Auto-buy at vendors  |cff808080(or type /to buy at a vendor)|r")
	auto:SetChecked(db.autoBuy)
	auto:SetScript("OnClick", function(self) db.autoBuy = self:GetChecked() and true or false end)

	-- gold reserve floor
	local floorLbl = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	floorLbl:SetPoint("TOPLEFT", 16, -90)
	floorLbl:SetText("Keep in reserve:")
	local floorBox = CreateFrame("EditBox", nil, o, "InputBoxTemplate")
	floorBox:SetSize(70, 18)
	floorBox:SetPoint("LEFT", floorLbl, "RIGHT", 10, 0)
	floorBox:SetAutoFocus(false)
	floorBox:SetNumeric(true)
	floorBox:SetText(tostring(db.goldFloor or 0))
	floorBox:SetScript("OnEnterPressed", function(self) db.goldFloor = tonumber(self:GetText()) or 0 self:ClearFocus() end)
	floorBox:SetScript("OnEscapePressed", function(self) self:SetText(tostring(db.goldFloor or 0)) self:ClearFocus() end)
	local gLbl = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	gLbl:SetPoint("LEFT", floorBox, "RIGHT", 4, 0)
	gLbl:SetText("|cffffd100gold|r")

	-- add-item row
	local addLbl = o:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	addLbl:SetPoint("TOPLEFT", 16, -120)
	addLbl:SetText("Add: type an item name (exact), or shift-click / drag an item")
	local addBox = CreateFrame("EditBox", nil, o, "InputBoxTemplate")
	addBox:SetSize(240, 20)
	addBox:SetPoint("TOPLEFT", 18, -134)
	addBox:SetAutoFocus(false)
	addBox:SetScript("OnReceiveDrag", addFromCursor)
	local addQty = CreateFrame("EditBox", nil, o, "InputBoxTemplate")
	addQty:SetSize(40, 20)
	addQty:SetPoint("LEFT", addBox, "RIGHT", 14, 0)
	addQty:SetAutoFocus(false)
	addQty:SetNumeric(true)
	addQty:SetJustifyH("CENTER")
	addQty:SetText("20")
	ns.addQty = addQty
	local addBtn = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
	addBtn:SetSize(48, 20)
	addBtn:SetPoint("LEFT", addQty, "RIGHT", 10, 0)
	addBtn:SetText("Add")
	local function doAdd()
		local text = addBox:GetText()
		if text and text ~= "" then
			ns.AddItem(text, tonumber(addQty:GetText()) or 1)
			addBox:SetText("") addBox:ClearFocus()
		end
	end
	addBtn:SetScript("OnClick", doAdd)
	addBox:SetScript("OnEnterPressed", doAdd)

	-- item list (own mouse-wheel scroll)
	local list = CreateFrame("Frame", nil, o)
	list:SetPoint("TOPLEFT", 16, -168)
	list:SetPoint("BOTTOMRIGHT", -16, 16)
	ns.listContent = list
	list:EnableMouseWheel(true)
	list:SetScript("OnReceiveDrag", addFromCursor)
	ns.listOffset = 0
	list:SetScript("OnMouseWheel", function(_, d)
		ns.listOffset = math.max(0, (ns.listOffset or 0) - d)
		ns.RefreshList()
	end)
	local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	empty:SetPoint("TOPLEFT", 2, -4)
	empty:SetText("No items yet — add what you always want in your bags above.")
	ns.emptyText = empty

	o:SetScript("OnShow", function() ns.RefreshList() end)

	-- register into ESC > Options > AddOns, or fall back to a standalone dialog
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(o, "Topped Off")
		Settings.RegisterAddOnCategory(cat)
		ns.settingsCategory = cat
	else
		o:SetParent(UIParent)
		o:SetSize(420, 460)
		o:SetPoint("CENTER")
		o:SetFrameStrata("DIALOG")
		o:SetBackdrop(BACKDROP)
		o:SetBackdropColor(0, 0, 0, 0.95)
		o:EnableMouse(true)
		o:SetMovable(true)
		o:RegisterForDrag("LeftButton")
		o:SetScript("OnDragStart", o.StartMoving)
		o:SetScript("OnDragStop", o.StopMovingOrSizing)
		local closeO = CreateFrame("Button", nil, o, "UIPanelCloseButton")
		closeO:SetPoint("TOPRIGHT", 2, 2)
	end

	ns.RefreshList()
end

function ns.OpenConfig()
	if not ns.panel then ns.BuildOptions() end
	if ns.settingsCategory and Settings and Settings.OpenToCategory then
		local cat = ns.settingsCategory
		Settings.OpenToCategory((cat.GetID and cat:GetID()) or cat.ID or cat)
	elseif ns.panel then
		ns.panel:SetShown(not ns.panel:IsShown())
	end
end
