-- A bot that goes down hides its weapon: the downed animation calls CopInventory's hide_weapon callback, which ends in
-- PlayerInventory:hide_equipped_unit. The bot keeps shooting with a weapon nobody can see. The weapon stays visible for
-- bots (and their husks) except in stealth before the first alert (cool); equipping and unequipping still show and place it as before.

local function patch(class)
	if not class or class._blt_bot_weapon_fix then
		return
	end
	class._blt_bot_weapon_fix = true

	local hide_equipped_unit = class.hide_equipped_unit

	function class:hide_equipped_unit(...)
		if FieldRepairs:IsEnabled("bot_weapon") and not self._unit:movement():cool() then
			return
		end

		return hide_equipped_unit(self, ...)
	end
end

patch(TeamAIInventory)
patch(HuskTeamAIInventory)
