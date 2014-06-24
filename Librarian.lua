Librarian = ZO_SortFilterList:Subclass()
Librarian.defaults = {}

ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_LIBRARIAN", "Toggle Librarian")
ZO_CreateStringId("SI_BINDING_NAME_RELOAD_UI", "Reload UI")
ZO_CreateStringId("SI_WINDOW_TITLE_LIBRARIAN", "Librarian")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_UNREAD", "Unread")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_FOUND", "Found")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_TITLE", "Title")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_WORD_COUNT", "Words")
ZO_CreateStringId("SI_LIBRARIAN_MARK_UNREAD", "Mark as Unread")
ZO_CreateStringId("SI_LIBRARIAN_MARK_READ", "Mark as Read")
ZO_CreateStringId("SI_LIBRARIAN_CREDIT", "Librarian 1.0.18 by Flamage")
ZO_CreateStringId("SI_LIBRARIAN_BOOK_COUNT", "%d Books")
ZO_CreateStringId("SI_LIBRARIAN_UNREAD_COUNT", "%s (%d Unread)")
ZO_CreateStringId("SI_LIBRARIAN_SHOW_ALL_BOOKS", "Show books for all characters")
ZO_CreateStringId("SI_LIBRARIAN_NEW_BOOK_FOUND", "Book added to librarian")
ZO_CreateStringId("SI_LIBRARIAN_NEW_BOOK_FOUND_WITH_TITLE", "Book added to librarian: %s")
ZO_CreateStringId("SI_LIBRARIAN_FULLTEXT_SEARCH", "Full-text Search:")
ZO_CreateStringId("SI_LIBRARIAN_SEARCH_HINT", "Enter text to search for.")
ZO_CreateStringId("SI_LIBRARIAN_RELOAD_REMINDER", "ReloadUI suggested to update Librarian database.")

local SORT_ARROW_UP = "EsoUI/Art/Miscellaneous/list_sortUp.dds"
local SORT_ARROW_DOWN = "EsoUI/Art/Miscellaneous/list_sortDown.dds"
local LIBRARIAN_DATA = 1
local LIBRARIAN_SEARCH = 1

local ENTRY_SORT_KEYS =
{
    ["title"] = { },
    ["unread"] = { tiebreaker = "timeStamp" },
    ["timeStamp"] = { tiebreaker = "title" },
    ["wordCount"] = { tiebreaker = "title" }
}

function Librarian:New()
	local librarian = ZO_SortFilterList.New(self, LibrarianFrame)
	librarian:Initialise()
	return librarian
end

function Librarian:Initialise()
 	self.masterList = {}
 	self.newBookCount = 0
    self.sortHeaderGroup:SelectHeaderByKey("timeStamp")

 	ZO_ScrollList_AddDataType(self.list, LIBRARIAN_DATA, "LibrarianBookRow", 30, function(control, data) self:SetupBookRow(control, data) end)
 	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

	self.localSavedVars = ZO_SavedVars:New("Librarian_SavedVariables", 1, nil, self.defaults, nil)
	self.globalSavedVars = ZO_SavedVars:NewAccountWide("Librarian_SavedVariables", 1, nil, self.defaults, nil)

	if not self.globalSavedVars.settings then self.globalSavedVars.settings = {} end
	self.settings = self.globalSavedVars.settings

	if not self.globalSavedVars.books then self.globalSavedVars.books = {} end
	self.books = self.globalSavedVars.books

	if not self.localSavedVars.characterBooks then self.localSavedVars.characterBooks = {} end
	self.characterBooks = self.localSavedVars.characterBooks

	self.searchBox = GetControl(LibrarianFrame, "SearchBox")
    self.searchBox:SetHandler("OnTextChanged", function() self:OnSearchTextChanged() end)
    self.search = ZO_StringSearch:New()
    self.search:AddProcessor(LIBRARIAN_SEARCH, function(stringSearch, data, searchTerm, cache) return self:ProcessBookEntry(stringSearch, data, searchTerm, cache) end)

	self.sortFunction = function(listEntry1, listEntry2) return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, ENTRY_SORT_KEYS, self.currentSortOrder) end

	self:UpdateSavedVariables()	

	local settings = LibrarianSettings:New(self.settings)

	local function OnShowAllBooksClicked(checkButton, isChecked)
        self.settings.showAllBooks = isChecked
        self:RefreshFilters()
    end

    local function GetShowAllBooks()
		return self.settings.showAllBooks
    end

	local showAllBooks = LibrarianFrameShowAllBooks
	ZO_CheckButton_SetToggleFunction(showAllBooks, OnShowAllBooksClicked)
    ZO_CheckButton_SetCheckState(showAllBooks, GetShowAllBooks())

    --self:ImportFromLoreLibrary()
	self:RefreshData()
	self:InitializeKeybindStripDescriptors()
	self:InitializeScene()
	self:AddLoreReaderUnreadToggle()
end

function Librarian:AddLoreReaderUnreadToggle()
	if LORE_READER.keybindStripDescriptor then
		local toggleKeybind =
		{
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = function() 
            	local book = self:FindBook(LORE_READER.titleText)
            	if not book or book.unread then 
            		if self.settings.showUnreadIndicatorInReader then 
            			self.unreadIndicator:SetHidden(false) 
            		else 
            			self.unreadIndicator:SetHidden(true) 
            		end
            		return GetString(SI_LIBRARIAN_MARK_READ)
            	else 
            		self.unreadIndicator:SetHidden(true)
            		return GetString(SI_LIBRARIAN_MARK_UNREAD)
            	end
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
            	local book = self:FindBook(LORE_READER.titleText)
            	if not book then return end
                book.unread = not book.unread
                KEYBIND_STRIP:UpdateKeybindButtonGroup(LORE_READER.keybindStripDescriptor)
                self:RefreshData()
            end
        }
        table.insert(LORE_READER.keybindStripDescriptor, toggleKeybind)
    end

    self.unreadIndicator = WINDOW_MANAGER:CreateControl("LibrarianUnreadIndicator", ZO_LoreReaderBookContainer, CT_TEXTURE)
    self.unreadIndicator:SetAnchor(TOPLEFT, ZO_LoreReaderBookContainerFirstPage, TOPLEFT, -32, 3)
    self.unreadIndicator:SetDimensions(32, 32)
    self.unreadIndicator:SetHidden(true)
    self.unreadIndicator:SetTexture([[EsoUI/Art/Inventory/newitem_icon.dds]])
end

function Librarian:UpdateSavedVariables()
	-- Version 1.0.4 - Settings moved to global variables.
	if self.localSavedVars.setting_time_format then
		self.globalSavedVars.settings.time_format = self.localSavedVars.setting_time_format
		self.localSavedVars.setting_time_format = nil
	end

	-- Version 1.0.4 - Book data moved to global variables
	if self.localSavedVars.books then
		for _,book in ipairs(self.localSavedVars.books) do
			local timeStamp = book.timeStamp
			local unread = book.unread
			self:AddBook(book)
			local characterBook = self:FindCharacterBook(book.title)
			if characterBook then characterBook.timeStamp = timeStamp end
			local globalBook = self:FindBook(book.title)
			if globalBook then
				globalBook.timeStamp = timeStamp
				globalBook.unread = unread
			end
		end
		self.localSavedVars.books = nil
		self:RefreshData()
	end

	-- Version 1.0.16 - Fixed a couple of settings names.
	if self.globalSavedVars.settings.alert_style then
		self.globalSavedVars.settings.alertStyle = self.globalSavedVars.settings.alert_style
		self.globalSavedVars.settings.alert_style = nil
	end

	if self.globalSavedVars.settings.time_format then
		self.globalSavedVars.settings.timeFormat = self.globalSavedVars.settings.time_format
		self.globalSavedVars.settings.time_format = nil
	end
end

function Librarian:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = GetString(SI_LORE_LIBRARY_READ),
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function() 
            	return self.mouseOverRow 
            end,
            callback = function()
                self:ReadBook(self.mouseOverRow.data.title)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = function() 
            	if not self.mouseOverRow then return nil end
            	local book = self:FindBook(self.mouseOverRow.data.title)
            	if book.unread then 
            		return GetString(SI_LIBRARIAN_MARK_READ)
            	else 
            		return GetString(SI_LIBRARIAN_MARK_UNREAD)
            	end
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() 
            	return self.mouseOverRow 
            end,
            callback = function()
            	local book = self:FindBook(self.mouseOverRow.data.title)
                book.unread = not book.unread
                self:RefreshData()
            end,
        }
    }
end

function Librarian:InitializeScene()
	if not LIBRARIAN_SCENE then
		LIBRARIAN_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_WINDOW_TITLE_LIBRARIAN)
		LIBRARIAN_SCENE = ZO_Scene:New("librarian", SCENE_MANAGER)
		LIBRARIAN_SCENE:AddFragmentGroup(FRAGMENT_GROUP.UI_WINDOW)
		LIBRARIAN_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
		LIBRARIAN_SCENE:AddFragment(ZO_FadeSceneFragment:New(LibrarianFrame))
		LIBRARIAN_SCENE:AddFragment(RIGHT_BG_FRAGMENT)
		LIBRARIAN_SCENE:AddFragment(TITLE_FRAGMENT)
		LIBRARIAN_SCENE:AddFragment(LIBRARIAN_TITLE_FRAGMENT)
		LIBRARIAN_SCENE:AddFragment(EXPERIENCE_BAR_FRAGMENT)
		LIBRARIAN_SCENE:AddFragment(CODEX_WINDOW_SOUNDS)

		LIBRARIAN_SCENE:RegisterCallback("StateChange", 
			function(oldState, newState)
				if(newState == SCENE_SHOWING) then        
                    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
                elseif(newState == SCENE_HIDDEN) then      
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
                end
            end)
	end
end

function Librarian:ImportFromLoreLibrary()
	local hasImportedBooks = false
	local chatEnabled = self.settings.chatEnabled
	local alertEnabled = self.settings.alertEnabled
	self.settings.chatEnabled = true
	self.settings.alertEnabled = false

	for categoryIndex = 1, GetNumLoreCategories() do
		local categoryName, numCollections = GetLoreCategoryInfo(categoryIndex)
		for collectionIndex = 1, numCollections do
            local collectionName, description, numKnownBooks, totalBooks, hidden = GetLoreCollectionInfo(categoryIndex, collectionIndex)
            if not hidden then
            	for bookIndex = 1, totalBooks do
            		local title, icon, known = GetLoreBookInfo(categoryIndex, collectionIndex, bookIndex)
            		if string.sub(book.title, -1) == "]" then
						book.title = book.title .. " "
					end
            		if known then
            			if not self:FindCharacterBook(title) then
            				local body, medium, showTitle = ReadLoreBook(categoryIndex, collectionIndex, bookIndex)
            				local book = {title = title, body = body, medium = medium, showTitle = showTitle}
            				self:AddBook(book)
            			end
            		end
            	end
            end
        end
	end

	self.settings.chatEnabled = chatEnabled
	self.settings.alertEnabled = alertEnabled
end

function Librarian:BuildMasterList()
    for i, book in ipairs(self.books) do
		local data = {}
		for k,v in pairs(book) do
    		data[k] = v
  		end
  		data.type = LIBRARIAN_SEARCH
  		local characterBook = self:FindCharacterBook(book.title)
  		if characterBook then
			data.seenByCurrentCharacter = true
			data.timeStamp = characterBook.timeStamp
		else
			data.seenByCurrentCharacter = false
			data.timeStamp = book.timeStamp
		end
  		self.masterList[i] = data
    end
end

function Librarian:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    local bookCount = 0
    local unreadCount = 0
    local searchTerm = self.searchBox:GetText()
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        if self.settings.showAllBooks or data.seenByCurrentCharacter then
        	if(searchTerm == "" or self.search:IsMatch(searchTerm, data)) then
            	table.insert(scrollData, ZO_ScrollList_CreateDataEntry(LIBRARIAN_DATA, data))
            	bookCount = bookCount + 1
            	if data.unread then unreadCount = unreadCount + 1 end
            end
        end
    end    

    local message = string.format(GetString(SI_LIBRARIAN_BOOK_COUNT), bookCount)
    if unreadCount > 0 then message = string.format(GetString(SI_LIBRARIAN_UNREAD_COUNT), message, unreadCount) end
	LibrarianFrameBookCount:SetText(message)
end

function Librarian:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    table.sort(scrollData, self.sortFunction)
end

function Librarian:SetupBookRow(control, data)
	control.data = data
	control.unread = GetControl(control, "Unread")
	control.found = GetControl(control, "Found")
	control.title = GetControl(control, "Title")
	control.wordCount = GetControl(control, "WordCount")
	
	control.unread.nonRecolorable = true
	if data.unread then control.unread:SetAlpha(1) else control.unread:SetAlpha(0) end

	control.found.normalColor = ZO_NORMAL_TEXT
	control.found:SetText(self:FormatClockTime(data.timeStamp))

	control.title.normalColor = ZO_NORMAL_TEXT
	control.title:SetText(data.title)

	control.wordCount.normalColor = ZO_NORMAL_TEXT
	control.wordCount:SetText(data.wordCount)

	ZO_SortFilterList.SetupRow(self, control, data)
end

function Librarian:ProcessBookEntry(stringSearch, data, searchTerm, cache)
    local lowerSearchTerm = searchTerm:lower()

    if(zo_plainstrfind(data.title:lower(), lowerSearchTerm)) then
        return true
    end

    if(zo_plainstrfind(data.body:lower(), lowerSearchTerm)) then
        return true
    end

    return false
end

function Librarian:FindCharacterBook(title)
	if not self.characterBooks then return nil end
	for _,book in pairs(self.characterBooks) do
		if book.title == title then return book end
	end
end

function Librarian:FindBook(title)
	for _,book in pairs(self.books) do
		if book.title == title then return book end
	end
end

function Librarian:AddBook(book)
	if string.sub(book.title, -1) == "]" then
		book.title = book.title .. " "
	end

	if not self:FindCharacterBook(book.title) then
		if string.sub(book.body, -1) == "]" then
			book.body = book.body .. " "
		end

		if not self:FindBook(book.title) then
			book.timeStamp = GetTimeStamp()
			book.unread = true
			local wordCount = 0
			for w in book.body:gmatch("%S+") do wordCount = wordCount + 1 end
			book.wordCount = wordCount
			table.insert(self.books, book)
		end

		local characterBook = { title = book.title, timeStamp = GetTimeStamp() }
		table.insert(self.characterBooks, characterBook)
		
		self:RefreshData()
		if self.settings.alertEnabled then
			ZO_CenterScreenAnnounce_GetAnnounceObject():AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_LARGE_TEXT, SOUNDS.BOOK_ACQUIRED, GetString(SI_LIBRARIAN_NEW_BOOK_FOUND))
		end
		if self.settings.chatEnabled then
			d(string.format(GetString(SI_LIBRARIAN_NEW_BOOK_FOUND_WITH_TITLE), book.title))
		end

		self.newBookCount = self.newBookCount + 1
		if self.settings.reloadReminderBookCount and self.settings.reloadReminderBookCount > 0 and self.settings.reloadReminderBookCount <= self.newBookCount then
			d(GetString(SI_LIBRARIAN_RELOAD_REMINDER))
		end
	end
end

function Librarian:Toggle()
	if LibrarianFrame:IsControlHidden() then
		SCENE_MANAGER:Show("librarian")
	else
		SCENE_MANAGER:Hide("librarian")
	end	
end    

function Librarian:ReadBook(title)
	local book = self:FindBook(title)
	LORE_READER:SetupBook(book.title, book.body, book.medium, book.showTitle)
	LORE_READER.returnScene = "librarian" 
    SCENE_MANAGER:Show("loreReaderInteraction")
    PlaySound(LORE_READER.OpenSound)
end

function Librarian:FormatClockTime(time)
    local midnightSeconds = GetSecondsSinceMidnight()
    local utcSeconds = GetTimeStamp() % 86400
    local offset = midnightSeconds - utcSeconds
    if offset < -43200 then
    	offset = offset + 86400
    end

    local dateString = GetDateStringFromTimestamp(time)
    local timeString = ZO_FormatTime((time + offset) % 86400, TIME_FORMAT_STYLE_CLOCK_TIME, self.settings.timeFormat)
	return string.format("%s %s", dateString, timeString)
end

function Librarian:OnSearchTextChanged()
    ZO_EditDefaultText_OnTextChanged(self.searchBox)
    self:RefreshFilters()
end

local function SlashCommand(args)
	Librarian:Toggle()
end

local function OnAddonLoaded(event, addon)
	if addon == "Librarian" then
		LIBRARIAN = Librarian:New()
	end
end

local function OnShowBook(eventCode, title, body, medium, showTitle)
	local book = { title = title, body = body, medium = medium, showTitle = showTitle }
	LIBRARIAN:AddBook(book)
end

function LibrarianRow_OnMouseEnter(control)
    LIBRARIAN:Row_OnMouseEnter(control)
end

function LibrarianRow_OnMouseExit(control)
    LIBRARIAN:Row_OnMouseExit(control)
end

function LibrarianRow_OnMouseUp(control, button, upInside)
    LIBRARIAN:ReadBook(control.data.title)
end

SLASH_COMMANDS["/librarian"] = SlashCommand

EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_ADD_ON_LOADED, OnAddonLoaded) 
EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_SHOW_BOOK, OnShowBook)