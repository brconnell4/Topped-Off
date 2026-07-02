local ADDON, ns = ...

local BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local ROW_H = 26
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function saveWindow()
	local f = ns.frame
	local point, _, _, x, y = f:GetPoint()
	local w = ns.DB().window
	w.point, w.x, w.y = point, x, y
	w.w, w.h = math.floor(f:GetWidth()), math.floor(f:GetHeight())
end

-- pull an item off the cursor (drag & drop) onto the list
local function addFromCursor()
	local kind, id, link = GetCursorInfo()
	if kind == "item" then
		ns.AddItem(link or id, tonumber(ns.addQty and ns.addQty:GetText()) or 1)
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
	if ns.header then ns.header:SetShown(#items > 0) end

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
			row.have:SetText(tostring(have))
			if have >= want then row.have:SetTextColor(0.4, 0.8, 0.4) else row.have:SetTextColor(0.9, 0.6, 0.3) end
			row.qty:SetText(tostring(e.qty or 0))
			row.enable:SetChecked(e.enabled)
			-- commit the value on Enter AND on losing focus (clicking away / closing / X),
			-- so you don't have to press Enter for it to save
			local function commitQty(self)
				e.qty = tonumber(self:GetText()) or e.qty or 0
			end
			row.qty:SetScript("OnEnterPressed", function(self)
				commitQty(self)
				self:ClearFocus()
				ns.RefreshList()
			end)
			row.qty:SetScript("OnEditFocusLost", commitQty)
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
-- movable window (works alongside an open vendor + bags)
----------------------------------------------------------------------
function ns.BuildWindow()
	if ns.frame then return end
	local db = ns.DB()

	local f = CreateFrame("Frame", "ToppedOffFrame", UIParent, "BackdropTemplate")
	ns.frame = f
	f:SetSize(db.window.w or 340, db.window.h or 400)
	f:SetPoint(db.window.point or "CENTER", UIParent, db.window.point or "CENTER", db.window.x or 0, db.window.y or 0)
	f:SetBackdrop(BACKDROP)
	f:SetBackdropColor(0, 0, 0, 0.92)
	f:SetFrameStrata("HIGH")
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(280, 240) elseif f.SetMinResize then f:SetMinResize(280, 240) end
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() saveWindow() end)
	f:SetScript("OnReceiveDrag", addFromCursor)
	f:SetScript("OnMouseUp", function() if GetCursorInfo() then addFromCursor() end end)

	-- black -> red -> black banner across the top
	local banner = CreateFrame("Frame", nil, f)
	banner:SetPoint("TOPLEFT", 5, -5)
	banner:SetPoint("TOPRIGHT", -5, -5)
	banner:SetHeight(18)
	local RED, BLK = { 0.66, 0.09, 0.09, 0.95 }, { 0.03, 0.01, 0.01, 0.95 }
	local function fade(tex, c1, c2)
		tex:SetColorTexture(1, 1, 1)
		if tex.SetGradient and CreateColor then
			tex:SetGradient("HORIZONTAL", CreateColor(unpack(c1)), CreateColor(unpack(c2)))
		elseif tex.SetGradientAlpha then
			tex:SetGradientAlpha("HORIZONTAL", c1[1], c1[2], c1[3], c1[4], c2[1], c2[2], c2[3], c2[4])
		else
			tex:SetColorTexture(0.4, 0.06, 0.06, 0.95)
		end
	end
	local lt = banner:CreateTexture(nil, "BORDER")
	lt:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
	lt:SetPoint("BOTTOMRIGHT", banner, "BOTTOM", 0, 0)
	fade(lt, BLK, RED)
	local rt = banner:CreateTexture(nil, "BORDER")
	rt:SetPoint("TOPLEFT", banner, "TOP", 0, 0)
	rt:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
	fade(rt, RED, BLK)
	local bLine = banner:CreateTexture(nil, "ARTWORK")
	bLine:SetColorTexture(0, 0, 0, 0.5)
	bLine:SetHeight(1)
	bLine:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
	bLine:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)

	local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("CENTER", banner, "CENTER", 0, 0)
	title:SetText("Topped Off")
	title:SetTextColor(1, 1, 1)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() f:Hide() db.window.shown = false end)

	-- auto-buy master toggle
	local auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	auto:SetSize(24, 24)
	auto:SetPoint("TOPLEFT", 10, -34)
	local autoLbl = auto:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	autoLbl:SetPoint("LEFT", auto, "RIGHT", 2, 0)
	autoLbl:SetText("Auto-buy at vendors")
	auto:SetChecked(db.autoBuy)
	auto:SetScript("OnClick", function(self) db.autoBuy = self:GetChecked() and true or false end)

	-- gold reserve floor
	local floorLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	floorLbl:SetPoint("TOPLEFT", 12, -62)
	floorLbl:SetText("Keep in reserve:")
	local floorBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	floorBox:SetSize(60, 18)
	floorBox:SetPoint("LEFT", floorLbl, "RIGHT", 10, 0)
	floorBox:SetAutoFocus(false)
	floorBox:SetNumeric(true)
	floorBox:SetText(tostring(db.goldFloor or 0))
	local function commitFloor(self) db.goldFloor = tonumber(self:GetText()) or 0 end
	floorBox:SetScript("OnEnterPressed", function(self) commitFloor(self) self:ClearFocus() end)
	floorBox:SetScript("OnEditFocusLost", commitFloor)
	floorBox:SetScript("OnEscapePressed", function(self) self:SetText(tostring(db.goldFloor or 0)) self:ClearFocus() end)
	local gLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	gLbl:SetPoint("LEFT", floorBox, "RIGHT", 3, 0)
	gLbl:SetText("|cffffd100g|r")

	local buyNow = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	buyNow:SetSize(90, 20)
	buyNow:SetPoint("TOPRIGHT", -8, -58)
	buyNow:SetText("Restock now")
	buyNow:SetScript("OnClick", function() ns.Restock(true) end)

	-- manual refresh of the "Own" counts (also updates live on bag changes)
	local refresh = CreateFrame("Button", nil, f)
	refresh:SetSize(18, 18)
	refresh:SetPoint("RIGHT", buyNow, "LEFT", -4, 0)
	refresh:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
	refresh:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
	local rh = refresh:GetHighlightTexture()
	if rh then rh:SetBlendMode("ADD") rh:SetAlpha(0.4) end
	refresh:SetScript("OnClick", function() ns.RefreshList() end)
	refresh:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:SetText("Refresh counts") GameTooltip:Show()
	end)
	refresh:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- add-item row
	local addLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	addLbl:SetPoint("TOPLEFT", 12, -90)
	addLbl:SetText("Add: type an item name, or drag an item from your bags")
	addLbl:SetTextColor(1, 0.82, 0)
	local addBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	addBox:SetSize(180, 20)
	addBox:SetPoint("TOPLEFT", 14, -104)
	addBox:SetAutoFocus(false)
	addBox:SetScript("OnReceiveDrag", addFromCursor)
	local addQty = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	addQty:SetSize(36, 20)
	addQty:SetPoint("LEFT", addBox, "RIGHT", 12, 0)
	addQty:SetAutoFocus(false)
	addQty:SetNumeric(true)
	addQty:SetJustifyH("CENTER")
	addQty:SetText("20")
	ns.addQty = addQty
	local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	addBtn:SetSize(44, 20)
	addBtn:SetPoint("LEFT", addQty, "RIGHT", 8, 0)
	addBtn:SetText("Add")
	local function doAdd()
		local text = addBox:GetText()
		if text and text ~= "" then
			ns.AddItem(text, tonumber(addQty:GetText()) or 1)
			addBox:SetText() addBox:ClearFocus()
		end
	end
	addBtn:SetScript("OnClick", doAdd)
	addBox:SetScript("OnEnterPressed", doAdd)

	-- column headers (align with the row layout below)
	local hdr = CreateFrame("Frame", nil, f)
	hdr:SetPoint("TOPLEFT", 10, -132)
	hdr:SetPoint("TOPRIGHT", -10, -132)
	hdr:SetHeight(14)
	ns.header = hdr
	local function hlabel(text, anchor, x)
		local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint(anchor, hdr, anchor, x, 0)
		fs:SetText(text)
		fs:SetTextColor(1, 0.82, 0)
		return fs
	end
	hlabel("Item", "LEFT", 28)
	hlabel("Own", "RIGHT", -102)
	hlabel("Buy", "RIGHT", -58)
	hlabel("On", "RIGHT", -25)
	local hLine = hdr:CreateTexture(nil, "ARTWORK")
	hLine:SetColorTexture(1, 1, 1, 0.15)
	hLine:SetHeight(1)
	hLine:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, -1)
	hLine:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, -1)

	-- item list
	local list = CreateFrame("Frame", nil, f)
	list:SetPoint("TOPLEFT", 10, -150)
	list:SetPoint("BOTTOMRIGHT", -10, 12)
	ns.listContent = list
	list:EnableMouseWheel(true)
	list:SetScript("OnReceiveDrag", addFromCursor)
	ns.listOffset = 0
	list:SetScript("OnMouseWheel", function(_, d)
		ns.listOffset = math.max(0, (ns.listOffset or 0) - d)
		ns.RefreshList()
	end)
	local empty = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	empty:SetPoint("TOP", 0, -6)
	empty:SetText("No items yet — add what you always want in your bags.")
	empty:SetTextColor(1, 0.82, 0)
	ns.emptyText = empty

	-- resize grip (bottom-right)
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", 0, 0)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() saveWindow() ns.RefreshList() end)

	-- resize grip (bottom-left, mirrored)
	local gripL = CreateFrame("Button", nil, f)
	gripL:SetSize(16, 16)
	gripL:SetPoint("BOTTOMLEFT", 0, 0)
	local gTex = gripL:CreateTexture(nil, "ARTWORK")
	gTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	gTex:SetTexCoord(1, 0, 0, 1)
	gTex:SetAllPoints()
	gripL:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	local gHi = gripL:GetHighlightTexture()
	if gHi then gHi:SetTexCoord(1, 0, 0, 1) end
	gripL:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMLEFT") end)
	gripL:SetScript("OnMouseUp", function() f:StopMovingOrSizing() saveWindow() ns.RefreshList() end)

	if not db.window.shown then f:Hide() end
	ns.RefreshList()
end

function ns.ShowWindow()
	if not ns.frame then ns.BuildWindow() end
	ns.frame:Show()
	ns.DB().window.shown = true
	ns.RefreshList()
end

function ns.ToggleWindow()
	if not ns.frame then ns.BuildWindow() end
	if ns.frame:IsShown() then
		ns.frame:Hide() ns.DB().window.shown = false
	else
		ns.ShowWindow()
	end
end

----------------------------------------------------------------------
-- ESC > Options > AddOns page: just a launcher for the window
----------------------------------------------------------------------
function ns.BuildOptionsPage()
	if ns.panel then return end
	local o = CreateFrame("Frame", "ToppedOffOptions")
	ns.panel = o

	local head = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	head:SetPoint("TOPLEFT", 16, -16)
	head:SetText("Topped Off")

	local desc = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", 16, -46)
	desc:SetWidth(520)
	desc:SetJustifyH("LEFT")
	desc:SetText("Your restock list opens in its own movable window so you can use it while a vendor is open "
		.. "(the game won't let a settings page and a vendor be open at the same time).\n\n"
		.. "Open the window, add the items and amounts you always want in your bags, then it tops them up at any "
		.. "vendor that sells them.  Slash:  /to  opens the window anytime.")

	local btn = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
	btn:SetSize(170, 26)
	btn:SetPoint("TOPLEFT", 16, -120)
	btn:SetText("Open Topped Off")
	btn:SetScript("OnClick", function()
		-- close the settings panel so it doesn't block the vendor
		if SettingsPanel and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
			HideUIPanel(InterfaceOptionsFrame)
		end
		ns.ShowWindow()
	end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(o, "Topped Off")
		Settings.RegisterAddOnCategory(cat)
		ns.settingsCategory = cat
	end
end
