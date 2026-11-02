-- CopActionWalk:update runs from CopMovement:_upd_actions. On a client the husk bots (HuskTeamAIMovement) can still update
-- their walk action after the host restarted the mission and the units were torn down: an extension is nil and the Lua
-- error reaches the engine update uncaught (C++ exception crash). Such an update is skipped here, any remaining error is
-- caught and logged instead of crashing.

if not CopActionWalk or CopActionWalk._blt_walk_update_fix then
	return
end
CopActionWalk._blt_walk_update_fix = true

local update = CopActionWalk.update

function CopActionWalk:update(t, ...)
	if not FieldRepairs:IsEnabled("walk_update") then
		return update(self, t, ...)
	end

	if not alive(self._unit) or not self._ext_base or not self._ext_anim then
		return
	end

	local ok, err = blt.pcall(update, self, t, ...)
	if not ok then
		log("[FieldRepairs] CopActionWalk:update skipped: " .. tostring(err))
	end
end
