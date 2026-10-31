-- TurretWeapon:on_puppet_damaged uses damage_info.attacker_unit without checking it (movement(), send_to_peers_synched).
-- Explosions of a FlamerTank take the attacker from the stored peer unit, which can be destroyed by then (peer downed or
-- respawned). A method call on a destroyed unit is an engine access violation, not a Lua error. Such damage is skipped here.

local function patch(class)
	if not class or class._blt_turret_attacker_fix then
		return
	end
	class._blt_turret_attacker_fix = true

	local on_puppet_damaged = class.on_puppet_damaged

	function class:on_puppet_damaged(data, damage_info, ...)
		if FieldRepairs:IsEnabled("turret_attacker") and not alive(damage_info and damage_info.attacker_unit) then
			return
		end

		return on_puppet_damaged(self, data, damage_info, ...)
	end
end

patch(TurretWeapon)
