-- Characters are built from customization units (upper, head, lower, ...). The contour (outline) of a character calls
-- OcclusionManager:remove_occlusion with the main unit only, and that only sets set_skip_occlusion on the "model" objects.
-- Two things stay subject to occlusion culling: the "lod" objects (the LOD groups of every unit) and the attached customization
-- units. While the character is occluded (behind a wall near the player) the engine culls the lower part: the outline loses
-- its legs. Skip (and restore) occlusion on the lod objects of the unit and of its attached customization units too.

if not _OcclusionManager or _OcclusionManager._blt_contour_occlusion_fix then
	return
end
_OcclusionManager._blt_contour_occlusion_fix = true

local ids_lod = Idstring("lod")

local function set_skip_unit(self, unit, skip)
	if not alive(unit) then
		return
	end

	for _, obj in pairs(unit:get_objects_by_type(self._model_ids)) do
		obj:set_skip_occlusion(skip)
	end
	for _, obj in pairs(unit:get_objects_by_type(ids_lod)) do
		obj:set_skip_occlusion(skip)
	end
end

function _OcclusionManager:set_skip_attached(unit, skip)
	if not alive(unit) or not unit.customization then
		return
	end

	set_skip_unit(self, unit, skip)

	local customization = unit:customization()
	if not customization or not customization:has_attached_units() then
		return
	end

	for _, attached in pairs(customization:attached_units()) do
		set_skip_unit(self, attached, skip)
	end
end

local remove_occlusion = _OcclusionManager.remove_occlusion

function _OcclusionManager:remove_occlusion(unit, ...)
	remove_occlusion(self, unit, ...)

	if FieldRepairs:IsEnabled("contour_occlusion") then
		self:set_skip_attached(unit, true)
	end
end

local add_occlusion = _OcclusionManager.add_occlusion

function _OcclusionManager:add_occlusion(unit, ...)
	add_occlusion(self, unit, ...)

	-- restored whatever the option says now: it may have been switched off while the skip was set
	self:set_skip_attached(unit, false)
end
