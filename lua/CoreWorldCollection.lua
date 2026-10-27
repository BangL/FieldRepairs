-- The game keeps parts of a mission world alive after the world was destroyed: every raid that is started and left
-- (the lua state is not reloaded in between) leaves 10 to 20 MB behind in the lua heap. Three things hold the world:
--  * The nav links of the mission elements. NavigationManager:unregister_anim_nav_link removes the link from the engine,
--    but the engine keeps the user data table {element = element} of it in the registry, which holds the whole mission
--    script.
--  * MissionManager._runned_unit_sequences_callbacks and the _use_unit_callbacks of the main world definition. They
--    are only emptied when the whole simulation stops, callbacks of the elements of a destroyed world stay in them.
-- This lets go of what belongs to the world that is destroyed and nothing else.

if not CoreWorldCollection or CoreWorldCollection._blt_world_leak_fix then
	return
end
CoreWorldCollection._blt_world_leak_fix = true

local destroy_world = CoreWorldCollection.destroy_world

-- The elements of a world that is about to be destroyed, and the nav links they still hold
local function collect_elements(collection, world_id)
	local elements = {}
	local mission = collection._missions and collection._missions[world_id]
	if not mission then
		return elements
	end

	for _, script in pairs(mission._scripts or {}) do
		for _, element in pairs(script._elements or {}) do
			elements[element] = true
			if element.nav_link and element:nav_link() then
				-- what ElementNavLink:destroy would do, but the world does not call it
				blt.pcall(managers.navigation.unregister_anim_nav_link, managers.navigation, element)
			end
		end
	end

	return elements
end

-- Callbacks made with callback(object, ...) have the object as their first upvalue
local function belongs_to(callback, elements)
	if type(callback) ~= "function" then
		return false
	end

	local _, owner = debug.getupvalue(callback, 1)
	return owner ~= nil and elements[owner] == true
end

local function purge_list(list, elements)
	for i = #list, 1, -1 do
		if belongs_to(list[i], elements) then
			table.remove(list, i)
		end
	end
end

local function release_elements(elements)
	-- user data of removed nav links in the registry
	for key, value in pairs(debug.getregistry()) do
		if type(key) == "number" and type(value) == "table" then
			-- raw, other tables of the registry have metatables of their own
			local element = rawget(value, "element")
			if element ~= nil and elements[element] then
				rawset(value, "element", nil)
			end
		end
	end

	local runned = managers.mission and managers.mission._runned_unit_sequences_callbacks
	if runned then
		for unit_id, by_sequence in pairs(runned) do
			for sequence, list in pairs(by_sequence) do
				purge_list(list, elements)
				if not next(list) then
					by_sequence[sequence] = nil
				end
			end
			if not next(by_sequence) then
				runned[unit_id] = nil
			end
		end
	end

	local on_load = managers.worlddefinition and managers.worlddefinition._use_unit_callbacks
	if on_load then
		for unit_id, list in pairs(on_load) do
			purge_list(list, elements)
			if not next(list) then
				on_load[unit_id] = nil
			end
		end
	end
end

function CoreWorldCollection:destroy_world(world_id, ...)
	local ok, elements = blt.pcall(collect_elements, self, world_id)

	local result = destroy_world(self, world_id, ...)

	if ok and next(elements) then
		local released, err = blt.pcall(release_elements, elements)
		if not released then
			BLT:Log(LogLevel.WARN, "[Field Repairs] Could not release the elements of world " .. tostring(world_id) .. ": " .. tostring(err))
		end
	elseif not ok then
		BLT:Log(LogLevel.WARN, "[Field Repairs] Could not collect the elements of world " .. tostring(world_id) .. ": " .. tostring(elements))
	end

	return result
end
