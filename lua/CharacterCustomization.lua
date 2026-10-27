-- Vanilla replacement of CharacterCustomization:_part_loaded_callback with
-- alive checks. The dyn_resource callback can fire synchronously while a husk
-- is being spawned (drop-in); if the husk is destroyed meanwhile (joiner
-- aborts), the native get/rotation calls on dead objects crash the engine.
function CharacterCustomization:_part_loaded_callback(params)
    self._loading_units[params.name] = nil

    if params.current_version < (managers.character_customization:get_current_version_to_attach() or 0) then
        return false
    end

    if not self._unit or not alive(self._unit) then
        return
    end

    local attached_unit = safe_spawn_unit(Idstring(params.name), self._unit:position())

    if not attached_unit or not alive(attached_unit) then
        log("[Field Repairs] CharacterCustomization: could not spawn " .. tostring(params.name))
        return
    end

    if params.loading_entire_outfit then
        attached_unit:set_visible(false)
    end

    local old_unit = self._attached_units[params.slot]

    if old_unit and alive(old_unit) then
        old_unit:set_slot(0)
    end

    self._attached_units[params.slot] = nil

    self._unit:link(Idstring("Hips"), attached_unit, attached_unit:orientation_object():name())

    self._attached_units[params.slot] = attached_unit

    for _, bone_name in ipairs(CharacterCustomization.BONES) do
        if not alive(self._unit) or not alive(attached_unit) then
            log("[Field Repairs] CharacterCustomization: unit died while attaching " .. tostring(params.name))
            return
        end

        local ids_bone = Idstring(bone_name)
        local skin_object = attached_unit:get_object(ids_bone)
        local char_object = self._unit:get_object(ids_bone)

        if skin_object and char_object then
            skin_object:link(char_object)
            skin_object:set_position(char_object:position())
            skin_object:set_rotation(char_object:rotation())
        end
    end

    local head_unit = self._attached_units[CharacterCustomizationTweakData.PART_TYPE_HEAD]
    local upper_unit = self._attached_units[CharacterCustomizationTweakData.PART_TYPE_UPPER]
    local lower_unit = self._attached_units[CharacterCustomizationTweakData.PART_TYPE_LOWER]

    if alive(head_unit) and alive(upper_unit) and alive(lower_unit) and params.loading_entire_outfit then
        head_unit:set_visible(self._visible)
        upper_unit:set_visible(self._visible)
        lower_unit:set_visible(self._visible)

        if self._unit:contour() then
            self._unit:contour():update_materials()
        end
    end
end
