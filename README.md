# Topped Off

A lightweight World of Warcraft addon for **TBC (Burning Crusade) Classic / Anniversary** that keeps your consumables and reagents **topped off** automatically. Set the items and amounts you always want in your bags once, and it buys the shortfall at any vendor that sells them — no more manually restocking runes, ammo, poisons, food, or water every time you pass a vendor.

## Features

- **Target counts** — "always keep 20 Rune of Teleportation in my bags." Have 7, walk up to the vendor, it buys 13.
- **Works with anything a vendor sells for gold** — reagents, ammo, poison mats, sharpening stones, vendor food & water, etc.
- **Auto-buy at vendors** — tops up automatically the moment you open any merchant that stocks your items. A **Restock now** button in the window does it on demand.
- **Gold reserve** — set a floor and it will never spend you below it.
- **Enable/disable per item** — pause one without deleting it.
- **Per-character** — your mage's list is separate from your rogue's, automatically.
- **Movable window** — opens with `/to` or an *Open Topped Off* button in **ESC → Options → AddOns → Topped Off**, and stays open while you shop, so you can add items you see at the vendor.

## Usage

- `/to` — open the restock window (or the *Open Topped Off* button in ESC → Options → AddOns)

**Adding items:** type the item's exact name in the *Add* box and set a target quantity, then **Add**. You can also **drag an item from your bags** into the window (bags only — not the vendor's list). Set your **gold reserve**, toggle **Auto-buy at vendors**, and you're done.

## What it won't buy

- **Conjured** food/water and anything not sold by a vendor (it can only buy what's on the shelf).
- Items bought with **honor / arena points / badges / tokens** — only gold-priced goods are auto-bought, so it never touches your currencies.

## Install

Copy the `ToppedOff` folder into your client's AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/ToppedOff/
```

Restart the client and enable **Topped Off** at the character-select screen.

## Files

| File | Purpose |
|------|---------|
| `Core.lua` | config, vendor buy logic, events, slash commands |
| `UI.lua` | the options page + item list |
| `ToppedOff.toc` | addon manifest (per-character SavedVariables) |

Built for Interface **20505** (TBC Anniversary).
