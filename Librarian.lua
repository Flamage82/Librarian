Librarian = ZO_Object:Subclass()
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
ZO_CreateStringId("SI_LIBRARIAN_CREDIT", "by Flamage")
ZO_CreateStringId("SI_LIBRARIAN_BOOK_COUNT", "%d Books")
ZO_CreateStringId("SI_LIBRARIAN_SHOW_ALL_BOOKS", "Show books for all characters")

local SORT_ARROW_UP = "EsoUI/Art/Miscellaneous/list_sortUp.dds"
local SORT_ARROW_DOWN = "EsoUI/Art/Miscellaneous/list_sortDown.dds"

local previousBook
local scrollChild
local sortField = "Found"
local sortAscending = false

function Librarian:Initialise()
 	scrollChild = LibrarianFrameScrollContainer:GetNamedChild("ScrollChild")
 	scrollChild:SetAnchor(TOPRIGHT, nil, TOPRIGHT, -5, 0)
	self.localSavedVars = ZO_SavedVars:New("Librarian_SavedVariables", 1, nil, self.defaults, nil)
	self.globalSavedVars = ZO_SavedVars:NewAccountWide("Librarian_SavedVariables", 1, nil, self.defaults, nil)

	if not self.globalSavedVars.settings then self.globalSavedVars.settings = {} end
	self.settings = self.globalSavedVars.settings

	if not self.globalSavedVars.books then self.globalSavedVars.books = {} end
	self.books = self.globalSavedVars.books

	if not self.localSavedVars.characterBooks then self.localSavedVars.characterBooks = {} end
	self.characterBooks = self.localSavedVars.characterBooks

	self:UpdateSavedVariables()	

	local settings = LibrarianSettings:New(self.settings)

	local function OnShowAllBooksClicked(checkButton, isChecked)
        self.settings.showAllBooks = isChecked
        self:LayoutBooks()
    end

    local function GetShowAllBooks()
		return self.settings.showAllBooks
    end

	local showAllBooks = LibrarianFrameShowAllBooks
	ZO_CheckButton_SetToggleFunction(showAllBooks, OnShowAllBooksClicked)
    ZO_CheckButton_SetCheckState(showAllBooks, GetShowAllBooks())

	self:SortBooks()

	self:InitializeKeybindStripDescriptors()
	self:InitializeScene()
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
			self:OpenBook(book)
			local characterBook = self:FindCharacterBook(book.title)
			if characterBook then characterBook.timeStamp = timeStamp end
			local globalBook = self:FindBook(book.title)
			if globalBook then
				globalBook.timeStamp = timeStamp
				globalBook.unread = unread
			end
		end
		self.localSavedVars.books = nil
		self:SortBooks()
	end
end

function Librarian:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = GetString(SI_LORE_LIBRARY_READ),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                self:ReadBook(self.mouseOverRow.id)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = function() 
            	if not self.mouseOverRow then return nil end
            	if self.books[self.mouseOverRow.id].unread then 
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
            	local book = self.books[self.mouseOverRow.id]
                book.unread = not book.unread
                if book.unread then self.mouseOverRow.unread:SetAlpha(1) else self.mouseOverRow.unread:SetAlpha(0) end
                KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
                KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
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
	end
end

function Librarian:OpenBook(book)
	if not self:FindCharacterBook(book.title) then
		self:AddBook(book)
	end
end

function Librarian:FindCharacterBook(title)
	for _,book in ipairs(self.characterBooks) do
		if book.title == title then return book end
	end
end

function Librarian:FindBook(title)
	for _,book in ipairs(self.books) do
		if book.title == title then return book end
	end
end

function Librarian:AddBook(book)
	local characterBook = {title = book.title, timeStamp = GetTimeStamp()}
	table.insert(self.characterBooks, characterBook)

	local function IsBookInGlobalData(book)
		for _,i in ipairs(self.books) do
			if i.title == book.title then return true end
		end
		return false
	end

	if not IsBookInGlobalData(book) then
		book.timeStamp = GetTimeStamp()
		book.unread = true
		table.insert(self.books, book)
	end
	
	self:SortBooks()
	d("Book added to Librarian.")
	--ZO_CenterScreenAnnounce_GetAnnounceObject():AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_LARGE_TEXT, SOUNDS.SKILL_LINE_LEVELED_UP, "Test")
end

function Librarian:Toggle()
	if LibrarianFrame:IsControlHidden() then
		SCENE_MANAGER:Show("librarian")
	else
		SCENE_MANAGER:Hide("librarian")
	end	
end    

function Librarian:LayoutBooks()
    ZO_Scroll_ResetToTop(LibrarianFrameScrollContainer)
    previousBook = nil

    for i, book in ipairs(self.sortedBooks) do
		self:LayoutBook(i, book)
    end

    local bookCount = 0
    if self.settings.showAllBooks then
    	bookCount = table.getn(self.books)
    else
    	for _,book in pairs(self.sortedBooks) do
    		if book.seenByCurrentCharacter then bookCount = bookCount + 1 end
    	end
    end
    LibrarianFrameBookCount:SetText(string.format(GetString(SI_LIBRARIAN_BOOK_COUNT), bookCount))
end

function Librarian:LayoutBook(i, book)
	local bookControl = GetControl("LibrarianBook"..i)
	if not bookControl then
		bookControl = CreateControlFromVirtual("LibrarianBook", scrollChild, "LibrarianBook", i)
		bookControl.id = i
		bookControl.unread = bookControl:GetNamedChild("Unread")
		bookControl.found = bookControl:GetNamedChild("Found")
		bookControl.title = bookControl:GetNamedChild("Title")
		bookControl.wordCount = bookControl:GetNamedChild("WordCount")
	end
	
	if self.settings.showAllBooks or book.seenByCurrentCharacter then
		bookControl:SetHidden(false)
		if book.unread then bookControl.unread:SetAlpha(1) else bookControl.unread:SetAlpha(0) end
		bookControl.found:SetText(self:FormatClockTime(book.timeStamp))
		bookControl.title:SetText(book.title)
		bookControl.wordCount:SetText(book.wordCount)

		if not previousBook then
	    	bookControl:SetAnchor(TOPLEFT, scrollChild, TOPLEFT)
	    else
	    	bookControl:SetAnchor(TOPLEFT, previousBook, BOTTOMLEFT)
	    end
	    previousBook = bookControl
	else
		bookControl:SetHidden(true)
	end
end

function Librarian:InitialiseSortHeader(control, name, tag)
	control.tag = tag
	local nameControl = GetControl(control, "Name")
    nameControl:SetFont("ZoFontHeader")
    nameControl:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    nameControl:SetText(GetString(name))
    nameControl:SetHorizontalAlignment(alignment or TEXT_ALIGN_LEFT)
    control.initialDirection = initialDirection or ZO_SORT_ORDER_DOWN
    control.usesArrow = true
end

function Librarian:SortBy(control)
	local field = control.tag
	if field == sortField then
		sortAscending = not sortAscending
	else
		sortField = field
		sortAscending = true
	end

	self:SortBooks()
end

function Librarian:SortBooks()
	local control

	self.sortedBooks = {}
	for _,book in pairs(self.books) do
		local characterBook = self:FindCharacterBook(book.title)
		if not book.wordCount then
			local wordCount = 0
			for w in book.body:gmatch("%S+") do wordCount = wordCount + 1 end
			book.wordCount = wordCount
		end
		local sortedBook = {title = book.title, unread = book.unread, wordCount = book.wordCount}
		if characterBook then
			sortedBook.seenByCurrentCharacter = true
			sortedBook.timeStamp = characterBook.timeStamp
		else
			sortedBook.seenByCurrentCharacter = false
			sortedBook.timeStamp = book.timeStamp
		end
		table.insert(self.sortedBooks, sortedBook)
	end

	if sortField == "Unread" then
		control = LibrarianFrameSortByUnread
		if sortAscending then
			table.sort(self.sortedBooks, function(a, b) return a.unread and not b.unread end)
		else 
			table.sort(self.sortedBooks, function(a, b) return not a.unread and b.unread end)
		end
	elseif sortField == "Found" then
		control = LibrarianFrameSortByTime
		if sortAscending then
			table.sort(self.sortedBooks, function(a, b) return a.timeStamp < b.timeStamp end)
		else
			table.sort(self.sortedBooks, function(a, b) return a.timeStamp > b.timeStamp end)
		end
	elseif sortField == "Title" then
		control = LibrarianFrameSortByTitle
		if sortAscending then
			table.sort(self.sortedBooks, function(a, b) return a.title < b.title end)
		else
			table.sort(self.sortedBooks, function(a, b) return a.title > b.title end)
		end
	elseif sortField == "WordCount" then
		control = LibrarianFrameSortByWordCount
		if sortAscending then
			table.sort(self.sortedBooks, function(a, b) return a.wordCount < b.wordCount end)
		else
			table.sort(self.sortedBooks, function(a, b) return a.wordCount > b.wordCount end)
		end
	end

	LibrarianFrameSortByUnread:GetNamedChild("Arrow"):SetHidden(true)
	LibrarianFrameSortByTime:GetNamedChild("Arrow"):SetHidden(true)
	LibrarianFrameSortByTitle:GetNamedChild("Arrow"):SetHidden(true)

	local arrow = control:GetNamedChild("Arrow")
	if sortAscending then
		arrow:SetTexture(SORT_ARROW_DOWN)
	else 
		arrow:SetTexture(SORT_ARROW_UP)
	end
	arrow:SetHidden(false)

	self:LayoutBooks()
end

function Librarian:ReadBook(id)
	local sortedBook = self.sortedBooks[id]
	local book = self:FindBook(sortedBook.title)
	LORE_READER:SetupBook(book.title, book.body, book.medium, book.showTitle)
	LORE_READER.returnScene = "librarian" 
    SCENE_MANAGER:Show("loreReaderInteraction")
    PlaySound(LORE_READER.OpenSound)
end

function Librarian:OnMouseEnter(buttonPart)
	self.mouseOverRow = buttonPart
	local highlight = buttonPart:GetNamedChild("Highlight")
	if highlight then
		if not highlight.animation then
	        highlight.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", highlight)
	    end
    	highlight.animation:PlayForward()
    end

    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
end

function Librarian:OnMouseExit(buttonPart)
	self.mouseOverRow = nil
	local highlight = buttonPart:GetNamedChild("Highlight")
	if highlight and highlight.animation then
        highlight.animation:PlayBackward()
    end

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
end

function Librarian:FormatClockTime(time)
    local midnightSeconds = GetSecondsSinceMidnight()
    local utcSeconds = GetTimeStamp() % 86400
    local offset = midnightSeconds - utcSeconds
    if offset < -43200 then
    	offset = offset + 86400
    end

    local dateString = GetDateStringFromTimestamp(time)
    local timeString = ZO_FormatTime((time + offset) % 86400, TIME_FORMAT_STYLE_CLOCK_TIME, self.settings.time_format)
	return string.format("%s %s", dateString, timeString)
end

local function SlashCommand(args)
	Librarian:Toggle()
end

local function OnAddonLoaded(event, addon)
	if addon == "Librarian" then
		Librarian:Initialise()
	end
end

local function OnShowBook(eventCode, title, body, medium, showTitle)
	local book = {title = title, body = body, medium = medium, showTitle = showTitle}
	Librarian:OpenBook(book)
end

SLASH_COMMANDS["/librarian"] = SlashCommand

EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_ADD_ON_LOADED, OnAddonLoaded) 
EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_SHOW_BOOK, OnShowBook)