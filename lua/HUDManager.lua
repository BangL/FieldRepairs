-- HUDManager:add_waypoint reads data.unit:position() when there is no position. A waypoint with neither a position nor
-- a living unit (a mission element whose unit is gone or not yet spawned) errors there. Such a waypoint is dropped.

if not HUDManager or HUDManager._blt_waypoint_fix then
	return
end
HUDManager._blt_waypoint_fix = true

local add_waypoint = HUDManager.add_waypoint

function HUDManager:add_waypoint(id, data, ...)
	if not FieldRepairs:IsEnabled("waypoint") then
		return add_waypoint(self, id, data, ...)
	end

	if type(data) ~= "table" or not (data.position or alive(data.unit)) then
		BLT:Log(LogLevel.WARN, "[Field Repairs] Waypoint " .. tostring(id) .. " has neither position nor unit, skipped")
		return
	end

	return add_waypoint(self, id, data, ...)
end
