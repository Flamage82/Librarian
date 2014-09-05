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

  if self.settings.enableCharacterSpin == nil then
    self.settings.enableCharacterSpin = true
  end
  
  local panelData = {
    type = "panel",
    name = "Librarian",
    displayName = "Librarian Book Manager",
    author = "Flamage",
    version = "1.2.6",
    slashCommand = "/librarianOptions"
  }

  local optionsTable = {
    [1] = {
      type = "dropdown",
      name = "Time Format",
      tooltip = "Select a format to display times in.",
      choices = map(timeFormats, function(item) return item.name end),
      getFunc = function() return getSettingByValue(timeFormats, self.settings.timeFormat).name end,
      setFunc = function(name) 
        self.settings.timeFormat = getSettingByName(timeFormats, name).value
        LIBRARIAN:CommitScrollList()
      end
    },
    [2] = {
      type = "dropdown",
      name = "Alert Settings",
      tooltip = "Select a style of alert.",
      choices = map(alertStyles, function(item) return item.name end),
      getFunc = function() return getSettingByValue(alertStyles, self.settings.alertStyle).name end,
      setFunc = function(name) 
        local setting = getSettingByName(alertStyles, name)
        self.settings.alertStyle = setting.value
        self.settings.chatEnabled = setting.chat
        self.settings.alertEnabled = setting.alert
      end
    },
    [3] = {
      type = "dropdown",
      name = "ReloadUI reminder after",
      tooltip = "Reminder to /reloadui after this number of new books are discovered.",
      choices = map(reloadReminders, function(item) return item.name end),
      getFunc = function() return getSettingByValue(reloadReminders, self.settings.reloadReminderBookCount).name end,
      setFunc = function(name) 
        local setting = getSettingByName(reloadReminders, name)
        self.settings.reloadReminderBookCount = setting.value
      end
    },
    [4] = {
      type = "checkbox",
      name = "Unread Indicator",
      tooltip = "Show an unread indicator in book reader.",
      getFunc = function() return self.settings.showUnreadIndicatorInReader end,
      setFunc = function(value) self.settings.showUnreadIndicatorInReader = value end
    },
    [5] = {
      type = "checkbox",
      name = "Character Spin",
      tooltip = "Allow the character to spin and face the camera when Librarian is open.",
      getFunc = function() return self.settings.enableCharacterSpin end,
      setFunc = function(value) 
        self.settings.enableCharacterSpin = value 
        SLASH_COMMANDS["/reloadui"]()
      end,
      warning = "UI will be reloaded automatically."
    },
    [6] = {
      type = "button",
      name = "Import from Lore Library",
      tooltip = "Import any missing books from the Lore Library.  Works with all books once Eidetic Memory is unlocked.",
      func = function() LIBRARIAN:ImportFromLoreLibrary() end
    }
  }

  if Librarian_SavedVariables["Default"][""] ~= nil then
    optionsTable[6] = {
      type = "button",
      name = "Import from before patch",
      tooltip = "Migrate data from before Patch 1.3, where account name was broken.",
      func = function() LIBRARIAN:ImportFromEmptyAccount() end
    }
  end
  
  local LAM = LibStub("LibAddonMenu-2.0")
  LAM:RegisterAddonPanel("LibrarianOptions", panelData)
  LAM:RegisterOptionControls("LibrarianOptions", optionsTable)
end