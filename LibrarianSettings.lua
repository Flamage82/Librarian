LibrarianSettings = ZO_Object:Subclass()

local time_formats = {
	{ name = "12 hour", value = TIME_FORMAT_PRECISION_TWELVE_HOUR}, 
	{ name = "24 hour", value = TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR}
}

function LibrarianSettings:New( ... )
    local result = ZO_Object.New( self )
    result:Initialise( ... )
    return result
end

local function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

local function getValue(tbl, name)
	for _,p in pairs(tbl) do
		if p.name == name then return p.value end
	end
end

local function getName(tbl, value)
	for _,p in pairs(tbl) do
		if p.value == value then return p.name end
	end
end

function LibrarianSettings:Initialise(settings)
	self.settings = settings

	if self.settings.time_format == nil then
		self.settings.time_format = (GetCVar("Language.2") == "en") and TIME_FORMAT_PRECISION_TWELVE_HOUR or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR
	end

	if self.settings.showAllBooks == nil then
		self.settings.showAllBooks = true
	end

	local LAM = LibStub("LibAddonMenu-1.0")
	local optionsPanel = LAM:CreateControlPanel("LibrarianOptions", "Librarian")

	local time_formats_list = map(time_formats, function(item) return item.name end)
	
	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsTimeFormat", 
		"Time Format",
		"Select a format to display times in.", 
		time_formats_list,
		function() return getName(time_formats, self.settings.time_format) end,
		function(format) 
			self.settings.time_format = getValue(time_formats, format)
			Librarian:LayoutBooks()
		end)
end