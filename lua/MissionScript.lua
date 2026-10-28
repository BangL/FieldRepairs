core:import("CoreMissionManager")

-- CallbackHandler (the base of MissionScript) keeps its callbacks in one ascending array
-- and pays table.remove(t, 1) plus a table.insert(t, i, cb) for every callback it runs.
-- In this LuaJIT build table.remove is a Lua builtin that costs ~1 us per moved element
-- (and every other Lua operation is just as slow), so a script with ~170 polling triggers
-- (Odin's Fall: area/lookat triggers every 0.1-0.2 s) spends 20-70 ms per tick just
-- shuffling that array.
-- Same semantics, different structure: callbacks that are due at the same time share a
-- bucket, and only the (few) distinct due times are kept in a sorted array, soonest at
-- the end. Both the array and the buckets live in self._sorted, so clear() resets them.

-- the instances are created from the core class, not from the global lib subclass
local MissionScript = CoreMissionManager.MissionScript
local insert = table.insert
local original_insert_sorted = MissionScript.__insert_sorted
local original_update = MissionScript.update

local function insert_sorted(sorted, cb)
	local key = cb.next
	local buckets = sorted.buckets

	if not buckets then
		buckets = {}
		sorted.buckets = buckets
	end

	local bucket = buckets[key]

	if bucket then
		bucket[#bucket + 1] = cb

		return
	end

	buckets[key] = { cb }

	-- descending, so the soonest due time is at the end and popping it is free
	local lo, hi = 1, #sorted + 1

	while lo < hi do
		local mid = math.floor((lo + hi) * 0.5)

		if sorted[mid] > key then
			lo = mid + 1
		else
			hi = mid
		end
	end

	insert(sorted, lo, key)
end

-- The queue is either the vanilla array or the buckets, never both: the mode is chosen when the first
-- callback is queued (clear() starts a new queue), so the option applies from the next raid.
function MissionScript:__insert_sorted(cb)
	local sorted = self._sorted

	if sorted.buckets_mode == nil then
		sorted.buckets_mode = FieldRepairs:IsEnabled("mission_script_queue")
	end

	if sorted.buckets_mode then
		insert_sorted(sorted, cb)
	else
		original_insert_sorted(self, cb)
	end
end

function MissionScript:update(t, dt)
	if not self._sorted.buckets_mode then
		return original_update(self, t, dt)
	end

	self._t = self._t + dt

	while true do
		local sorted = self._sorted
		local n = #sorted
		local key = sorted[n]

		if not key or key > self._t then
			break
		end

		sorted[n] = nil

		local buckets = sorted.buckets
		local bucket = buckets[key]

		buckets[key] = nil

		-- newest first: the original queue put a new callback in front of older ones
		-- with the same due time
		for i = #bucket, 1, -1 do
			local cb = bucket[i]

			-- remove() only clears cb.next, the entry stays queued until it is due
			if cb.next ~= nil then
				cb.f(cb, self._t)

				if cb.times >= 0 then
					cb.times = cb.times - 1

					if cb.times <= 0 then
						cb.next = nil
					end
				end

				if cb.next then
					cb.next = cb.next + cb.interval

					insert_sorted(self._sorted, cb)
				end
			end
		end
	end

	for _, updator in pairs(self._updators) do
		updator(t, dt)
	end
end
