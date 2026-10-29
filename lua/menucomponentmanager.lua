-- options menu

FieldRepairsMenu = FieldRepairsMenu or class(BLTMenu)

function FieldRepairsMenu:Init(root)
	self._something_changed = false

	self:Title({
		text = "fieldrepairs_title",
	})
	self:Label({
		text = nil,
		localize = false,
		h = 8,
	})

	self:AutoBindNamedControlsBegin()

	self:SubTitle({ text = "fieldrepairs_restart_note", localize = true, y_offset = 16 })

	for _, id in ipairs(FieldRepairs.fixes) do
		local key = "fieldrepairs_" .. id
		self:Toggle({
			name = key,
			text = managers.localization:text(key),
			localize = false,
			localized = false,
			desc = managers.localization:text(key .. "_desc"),
			localize_desc = false,
			localized_desc = false,
			value = FieldRepairs:IsEnabled(id),
			callback = callback(self, self, "OnOptionChanged", id),
			auto_select_on_hover = true,
		})
	end

	self:AutoBindNamedControlsEnd()
end

function FieldRepairsMenu:OnOptionChanged(id, value)
	FieldRepairs:SetEnabled(id, (type(value) == "table") and value.value or value)
	self._something_changed = true
end

function FieldRepairsMenu:Close()
	if self._something_changed then
		FieldRepairs:Save()
	end
end

Hooks:Add("MenuComponentManagerInitialize", "FieldRepairs_MenuComponentManagerInitialize", function(self)
	RaidMenuHelper:CreateMenu({
		name = "fieldrepairs_options",
		name_id = "fieldrepairs_title",
		inject_list = "blt_options",
		icon = "waypoint_special_tools",
		class = FieldRepairsMenu,
	})
end)
