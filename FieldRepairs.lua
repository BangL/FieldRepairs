-- Options of Field Repairs: every fix can be switched off. The fixes stay hooked and ask here when they run,
-- so a changed option applies at once (the callback queue of the mission scripts: from the next raid).
-- Hooked before core/lib/system/coresystem: some fixes run when BeardLib imports the editor, before lib/entry.

_G.FieldRepairs = _G.FieldRepairs or {}
local FieldRepairs = _G.FieldRepairs

FieldRepairs.config_path = SavePath .. "FieldRepairs.txt"
FieldRepairs.fixes = {
	"husk_customization",
	"mission_script_queue",
	"world_leak",
	"waypoint",
	"portal_units",
}
FieldRepairs.config = {}

function FieldRepairs:Load()
	local file = io.open(self.config_path, "r")
	if not file then
		return
	end

	local ok, data = blt.pcall(json.decode, file:read("*all"))
	file:close()
	if ok and type(data) == "table" then
		for _, id in ipairs(self.fixes) do
			if data[id] == false then
				self.config[id] = false
			end
		end
	end
end

function FieldRepairs:Save()
	local file = io.open(self.config_path, "w+")
	if file then
		file:write(json.encode(self.config))
		file:close()
	end
end

-- on unless switched off
function FieldRepairs:IsEnabled(id)
	return self.config[id] ~= false
end

function FieldRepairs:SetEnabled(id, value)
	if value then
		self.config[id] = nil
	else
		self.config[id] = false
	end
end

FieldRepairs:Load()

