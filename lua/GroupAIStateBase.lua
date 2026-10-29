-- Every enemy and bot runs CopLogicBase._upd_attention_obj_detection over all registered attention objects. Two kinds of
-- them are checked for nothing:
-- * a dead enemy stays one until its corpse is disposed of (setting corpse_limit, up to 250). With 130 corpses lying around
--   every living unit walks ~160 objects per tick, ~70% of the frame time. Corpses only matter while the level is still
--   stealthy (guards find bodies), so once the alarm is up they are left out.
-- * objects the unit's team has no attention settings for at all (get_attention returns nothing for any reaction range):
--   an enemy checks every other enemy, which is a friend to it, just to throw it away again.
-- The vanilla sets (self._attention_objects[filter]) are never changed: the filtered copy (per filter and team) is rebuilt
-- when something was (un)registered or changed, and every second for units that died or changed teams since.

if not GroupAIStateBase then
	return
end

local REFRESH_T = 1

-- registered / changed / removed attention objects: the filtered copies are stale
if not GroupAIStateBase._blt_attention_version then
	GroupAIStateBase._blt_attention_version = true

	for _, name in ipairs({ "register_AI_attention_object", "on_AI_attention_changed", "unregister_AI_attention_object" }) do
		local original = GroupAIStateBase[name]

		if original then
			GroupAIStateBase[name] = function(self, ...)
				self._fr_attention_version = (self._fr_attention_version or 0) + 1

				return original(self, ...)
			end
		end
	end
end

local function is_corpse(attention_info)
	local unit = attention_info.unit

	if not alive(unit) then
		return false
	end

	local character_damage = unit:character_damage()

	return character_damage ~= nil and character_damage.dead ~= nil and character_damage:dead()
end

-- kept when reloaded, so the filter is never stacked on itself
local get_by_filter = GroupAIStateBase._fr_get_by_filter or GroupAIStateBase.get_AI_attention_objects_by_filter
GroupAIStateBase._fr_get_by_filter = get_by_filter

function GroupAIStateBase:get_AI_attention_objects_by_filter(filter, team, ...)
	local list = get_by_filter(self, filter, team, ...)

	if not FieldRepairs:IsEnabled("attention_corpses") then
		return list
	end

	local cache = self._fr_attention_cache

	if not cache then
		cache = {}
		self._fr_attention_cache = cache
	end

	local loud = not self:whisper_mode()
	local key = tostring(filter) .. "/" .. tostring(team and team.id)
	local t = TimerManager:game():time()
	local entry = cache[key]

	if entry and entry.list == list and entry.loud == loud and entry.version == self._fr_attention_version and t < entry.t then
		return entry.filtered
	end

	local filter_num = team and managers.navigation:convert_access_filter_to_number({ filter })
	local filtered = {}

	for u_key, attention_info in pairs(list) do
		if not (loud and is_corpse(attention_info)) and (not team or attention_info.handler:get_attention(filter_num, nil, nil, team)) then
			filtered[u_key] = attention_info
		end
	end

	cache[key] = { list = list, loud = loud, version = self._fr_attention_version, t = t + REFRESH_T, filtered = filtered }

	return filtered
end
