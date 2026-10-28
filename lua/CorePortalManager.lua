-- PortalUnitGroup:remove_unit_id only clears the id. The unit stays in self._units, so units that were removed or
-- destroyed stay referenced (and keep being iterated by the portal update) until the group itself is gone.

-- the globals of the game are not visible in the module
local FieldRepairs = _G.FieldRepairs

core:module("CorePortalManager")

if not PortalUnitGroup or PortalUnitGroup._blt_remove_unit_fix then
	return
end
PortalUnitGroup._blt_remove_unit_fix = true

local remove_unit_id = PortalUnitGroup.remove_unit_id

function PortalUnitGroup:remove_unit_id(unit, ...)
	remove_unit_id(self, unit, ...)

	if not FieldRepairs:IsEnabled("portal_units") then
		return
	end

	local units = self._units
	for i = #units, 1, -1 do
		if units[i] == unit then
			table.remove(units, i)
		end
	end
end
