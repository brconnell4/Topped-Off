local ADDON, ns = ...

-- per-character config (SavedVariablesPerCharacter in the .toc keeps mage != rogue)
local defaults = {
	autoBuy = true,
	goldFloor = 0, -- gold to keep in reserve; never spend below this
	items = {},    -- { { id = <itemID>, name = "...", qty = <target in bags>, enabled = true, icon = <texID> }, ... }
	window = { point = "CENTER", x = 0, y = 0, shown = false },
}

local function applyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			applyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ns.DB() return ToppedOffDB end

-- add an item from a typed name or a shift-clicked/dragged item link
function ns.AddItem(input, qty)
	if type(input) == "string" then input = input:gsub("^%s+", ""):gsub("%s+$", "") end
	if not input or input == "" then return false, "empty" end
	local id = tonumber(input) or tonumber(tostring(input):match("item:(%d+)"))
	local bracket = tostring(input):match("%[(.-)%]")
	-- resolve id/name/icon; GetItemInfoInstant is synchronous and takes id, name, or link
	local iid, _, _, _, icon = GetItemInfoInstant(id or input)
	if iid then id = iid end
	local resolved = GetItemInfo(id or input) -- may be nil if not cached; that's ok
	local name = resolved or bracket or (type(input) == "string" and input) or ("item:" .. tostring(id))
	table.insert(ns.DB().items, {
		id = id, name = name, qty = tonumber(qty) or 1, enabled = true, icon = icon,
	})
	if ns.RefreshList then ns.RefreshList() end
	return true
end

function ns.RemoveItem(index)
	table.remove(ns.DB().items, index)
	if ns.RefreshList then ns.RefreshList() end
end

-- find an enabled list entry that matches a merchant item (by id first, then name)
local function matchEntry(mid, mname)
	local lname = mname and mname:lower()
	for _, e in ipairs(ns.DB().items) do
		if e.enabled then
			if e.id and mid and e.id == mid then return e end
			if e.name and lname and e.name:lower() == lname then return e end
		end
	end
end

-- top up everything the current vendor sells that's on the list
function ns.Restock(manual)
	local db = ns.DB()
	if not manual and not db.autoBuy then return end
	if not (MerchantFrame and MerchantFrame:IsShown()) then return end
	local floor = (tonumber(db.goldFloor) or 0) * 10000 -- copper
	local bought, blocked = {}, false
	local total = GetMerchantNumItems() or 0
	for i = 1, total do
		local name, _, price, stack, _, purchasable, _, extendedCost = GetMerchantItemInfo(i)
		-- only gold-priced, purchasable items (skip honor/token/badge stuff)
		if name and price and price > 0 and not extendedCost and purchasable ~= false then
			local link = GetMerchantItemLink(i)
			local mid = link and tonumber(link:match("item:(%d+)"))
			local e = matchEntry(mid, name)
			if e then
				local have = GetItemCount(mid or name) or 0
				local want = tonumber(e.qty) or 0
				local deficit = want - have
				if deficit > 0 then
					local per = (stack and stack > 0) and (price / stack) or price
					-- respect the gold reserve floor
					local affordable = (per > 0) and math.floor((GetMoney() - floor) / per) or deficit
					if affordable < 0 then affordable = 0 end
					local buyN = math.min(deficit, affordable)
					if buyN <= 0 then
						blocked = true
					else
						local maxStack = select(8, GetItemInfo(mid or name)) or (stack > 1 and stack) or 20
						if not maxStack or maxStack < 1 then maxStack = 20 end
						local remaining, guard = buyN, 0
						while remaining > 0 and guard < 60 do
							guard = guard + 1
							local chunk = math.min(remaining, maxStack)
							BuyMerchantItem(i, chunk)
							remaining = remaining - chunk
						end
						bought[#bought + 1] = (e.name or name) .. " x" .. buyN
					end
				end
			end
		end
	end
	if #bought > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Topped Off:|r bought " .. table.concat(bought, ", "))
	end
	if blocked then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Topped Off:|r held off on some buys (gold reserve).")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		ToppedOffDB = ToppedOffDB or {}
		applyDefaults(ToppedOffDB, defaults)
	elseif event == "PLAYER_LOGIN" then
		if ns.BuildWindow then ns.BuildWindow() end
		if ns.BuildOptionsPage then ns.BuildOptionsPage() end
	elseif event == "MERCHANT_SHOW" then
		-- small delay so the merchant's item list is fully populated
		C_Timer.After(0.2, function() ns.Restock(false) end)
	end
end)

SLASH_TOPPEDOFF1 = "/toppedoff"
SLASH_TOPPEDOFF2 = "/to"
SlashCmdList.TOPPEDOFF = function(msg)
	msg = (msg or ""):lower():gsub("%s+", "")
	if msg == "buy" then
		ns.Restock(true)
	elseif ns.ToggleWindow then
		ns.ToggleWindow()
	end
end
