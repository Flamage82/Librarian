LibrarianSettings = ZO_Object:Subclass()

local timeFormats = {
	{ name = "12 hour", value = TIME_FORMAT_PRECISION_TWELVE_HOUR }, 
	{ name = "24 hour", value = TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR }
}

local alertStyles = {
	{ name = "None", value = "None", chat = false, alert = false }, 
	{ name = "Chat only", value = "Chat", chat = true, alert = false },
	{ name = "Alert only", value = "Alert", chat = false, alert = true },
	{ name = "Both", value = "Both", chat = true, alert = true },
}

local reloadReminders = {
	{ name = "Never", value = 0 }, 
	{ name = "1 new book", value = 1 },
	{ name = "5 new books", value = 5 },
	{ name = "10 new books", value = 10 }
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

	if self.settings.timeFormat == nil then
		self.settings.timeFormat = (GetCVar("Language.2") == "en") and TIME_FORMAT_PRECISION_TWELVE_HOUR or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR
	end

	if self.settings.showAllBooks == nil then
		self.settings.showAllBooks = true
	end

	if self.settings.alertStyle == nil then
		self.settings.alertStyle = 'Both'
		self.settings.chatEnabled = true
		self.settings.alertEnabled = true
	end

	if self.settings.showUnreadIndicatorInReader == nil then
		self.settings.showUnreadIndicatorInReader = true
	end

	if self.settings.reloadReminderBookCount == nil then
		self.settings.reloadReminderBookCount = 5
	end

	local LAM = LibStub("LibAddonMenu-1.0")
	local optionsPanel = LAM:CreateControlPanel("LibrarianOptions", "Librarian")
	LAM:AddHeader(optionsPanel, "LibrarianOptionsHeader", nil)

	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsTimeFormat", 
		"Time Format",
		"Select a format to display times in.", 
		map(timeFormats, function(item) return item.name end),
		function() return getSettingByValue(timeFormats, self.settings.timeFormat).name end,
		function(name) 
			self.settings.timeFormat = getSettingByName(timeFormats, name).value
			LIBRARIAN:CommitScrollList()
		end)

	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsAlertSetting", 
		"Alert Settings",
		"Select a style of alert.", 
		map(alertStyles, function(item) return item.name end),
		function() return getSettingByValue(alertStyles, self.settings.alertStyle).name end,
		function(name) 
			local setting = getSettingByName(alertStyles, name)
			self.settings.alertStyle = setting.value
			self.settings.chatEnabled = setting.chat
			self.settings.alertEnabled = setting.alert
		end)

	LAM:AddCheckbox(optionsPanel, 
		"LibrarianOptionsUnreadIndicator",
		"Unread Indicator",
		"Show unread indicator in book reader.", 
		function() return self.settings.showUnreadIndicatorInReader end, 
		function(value) self.settings.showUnreadIndicatorInReader = value end)

	LAM:AddDropdown(optionsPanel, 
		"LibrarianOptionsReloadReminder", 
		"ReloadUI reminder after",
		"Reminder to /reloadui after this number of new books are discovered.", 
		map(reloadReminders, function(item) return item.name end),
		function() return getSettingByValue(reloadReminders, self.settings.reloadReminderBookCount).name end,
		function(name) 
			local setting = getSettingByName(reloadReminders, name)
			self.settings.reloadReminderBookCount = setting.value
		end)
end