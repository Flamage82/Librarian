LibrarianSettings = ZO_Object:Subclass()

local time_formats = {
	{ name = "12 hour", value = TIME_FORMAT_PRECISION_TWELVE_HOUR }, 
	{ name = "24 hour", value = TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR }
}

local alert_styles = {
	{ name = "None", value = 'None', chat = false, alert = false }, 
	{ name = "Chat only", value = 'Chat', chat = true, alert = false },
	{ name = "Alert only", value = 'Alert', chat = false, alert = true },
	{ name = "Both", value = 'Both', chat = true, alert = true },
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

local function getSettingByName(tbl, name)
	for _,p in pairs(tbl) do
		if p.name == name then return p end
	end
end

local function getSettingByValue(tbl, value)
	for _,p in pairs(tbl) do
		if p.value == value then return p end
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

	if self.settings.alert_style == nil then
		self.settings.alert_style = 'Both'
		self.settings.chatEnabled = true
		self.settings.alertEnabled = true
	end

	if self.settings.showUnreadIndicatorInReader == nil then
		self.settings.showUnreadIndicatorInReader = true
	end

	local LAM = LibStub("LibAddonMenu-1.0")
	local optionsPanel = LAM:CreateControlPanel("LibrarianOptions", "Librarian")

	local time_formats_list = map(time_formats, function(item) return item.name end)
	
	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsTimeFormat", 
		"Time Format",
		"Select a format to display times in.", 
		time_formats_list,
		function() return getSettingByValue(time_formats, self.settings.time_format).name end,
		function(format) 
			self.settings.time_format = getSettingByName(time_formats, format).value
			LIBRARIAN:CommitScrollList()
		end)

	local alert_styles_list = map(alert_styles, function(item) return item.name end)

	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsAlertSetting", 
		"Alert Settings",
		"Select a style of alert.", 
		alert_styles_list,
		function() return getSettingByValue(alert_styles, self.settings.alert_style).name end,
		function(format) 
			local setting = getSettingByName(alert_styles, format)
			self.settings.alert_style = setting.value
			self.settings.chatEnabled = setting.chat
			self.settings.alertEnabled = setting.alert
		end)

	LAM:AddCheckbox(optionsPanel, 
		"LibrarianOptionsUnreadIndicator",
		"Unread Indicator",
		"Show unread indicator in book reader", 
		function() return self.settings.showUnreadIndicatorInReader end, 
		function(value) self.settings.showUnreadIndicatorInReader = value end)
end