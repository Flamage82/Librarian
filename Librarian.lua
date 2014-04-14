Librarian = {}
Librarian.defaults = {books = {}}

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

local SORT_ARROW_UP = "EsoUI/Art/Miscellaneous/list_sortUp.dds"
local SORT_ARROW_DOWN = "EsoUI/Art/Miscellaneous/list_sortDown.dds"

local previousBook
local scrollChild
local sortField = "Found"
local sortAscending = false

local time_formats = {
	{ name = "12 hour", value = TIME_FORMAT_PRECISION_TWELVE_HOUR}, 
	{ name = "24 hour", value = TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR}
}

function Librarian:Initialise()
 	scrollChild = LibrarianFrameScrollContainer:GetNamedChild("ScrollChild")
 	scrollChild:SetAnchor(TOPRIGHT, nil, TOPRIGHT, -5, 0)
	self.savedVars = ZO_SavedVars:New("Librarian_SavedVariables", 1, nil, self.defaults, nil)

	if self.savedVars.setting_time_format == nil then
		self.savedVars.setting_time_format = (GetCVar("Language.2") == "en") and TIME_FORMAT_PRECISION_TWELVE_HOUR or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR
	end

	self:InitialiseSettings()

	self:SortBooks()

	self:InitializeKeybindStripDescriptors()
	self:InitializeScene()
end

function Librarian:InitialiseSettings()
	local LAM = LibStub("LibAddonMenu-1.0")
	local optionsPanel = LAM:CreateControlPanel("LibrarianOptions", "Librarian")

	local time_formats_list = map(time_formats, function(item) return item.name end)
	d(self.savedVars.setting_time_format)
	
	LAM:AddDropdown(optionsPanel, "LibrarianOptionsTimeFormat", "Time Format",
					"Select a format to display times in.", time_formats_list,
					function() return getName(time_formats, self.savedVars.setting_time_format) end,
					function(format) 
						self.savedVars.setting_time_format = getValue(time_formats, format)
						self:LayoutBooks()
					end)
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
            	if self.savedVars.books[self.mouseOverRow.id].unread then 
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
            	local book = self.savedVars.books[self.mouseOverRow.id]
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

function Librarian:StoreBook(title, body, medium, showTitle)
	if not self:FindBook(title) then
		self:AddBook(title, body, medium, showTitle)
	end
end

function Librarian:FindBook(title)
	for i, book in ipairs(self.savedVars.books) do
		if book.title == title then return book end
	end
end

function Librarian:AddBook(title, body, medium, showTitle)
	local book = {title = title, body = body, medium = medium, showTitle = showTitle, timeStamp = GetTimeStamp(), unread = true}
	table.insert(self.savedVars.books, book)
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
    for i, book in ipairs(self.savedVars.books) do
		self:LayoutBook(i, book)
    end

    local bookCount = table.getn(self.savedVars.books)
    LibrarianFrameBookCount:SetText(string.format(GetString(SI_LIBRARIAN_BOOK_COUNT), bookCount))
end

function Librarian:LayoutBook(i, book)
	local bookControl = GetControl("LibrarianBook"..i)
	if not bookControl then
		bookControl = CreateControlFromVirtual("LibrarianBook", scrollChild, "LibrarianBook", i)
		bookControl.id = i
	end
	
	bookControl.unread = bookControl:GetNamedChild("Unread")
	bookControl.found = bookControl:GetNamedChild("Found")
	bookControl.title = bookControl:GetNamedChild("Title")
	bookControl.wordCount = bookControl:GetNamedChild("WordCount")

	if book.unread then bookControl.unread:SetAlpha(1) else bookControl.unread:SetAlpha(0) end
	bookControl.found:SetText(self:FormatClockTime(book.timeStamp))
	bookControl.title:SetText(book.title)
	if not book.wordCount then
		local wordCount = 0
		for w in book.body:gmatch("%S+") do wordCount = wordCount + 1 end
		book.wordCount = wordCount
	end
	bookControl.wordCount:SetText(book.wordCount)

	if not previousBook then
    	bookControl:SetAnchor(TOPLEFT, scrollChild, TOPLEFT)
    else
    	bookControl:SetAnchor(TOPLEFT, previousBook, BOTTOMLEFT)
    end
    previousBook = bookControl
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

	if sortField == "Unread" then
		control = LibrarianFrameSortByUnread
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.unread and not b.unread end)
		else 
			table.sort(self.savedVars.books, function(a, b) return not a.unread and b.unread end)
		end
	elseif sortField == "Found" then
		control = LibrarianFrameSortByTime
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.timeStamp < b.timeStamp end)
		else
			table.sort(self.savedVars.books, function(a, b) return a.timeStamp > b.timeStamp end)
		end
	elseif sortField == "Title" then
		control = LibrarianFrameSortByTitle
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.title < b.title end)
		else
			table.sort(self.savedVars.books, function(a, b) return a.title > b.title end)
		end
	elseif sortField == "WordCount" then
		control = LibrarianFrameSortByWordCount
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.wordCount < b.wordCount end)
		else
			table.sort(self.savedVars.books, function(a, b) return a.wordCount > b.wordCount end)
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
	local book = self.savedVars.books[id]
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
    local timeString = ZO_FormatTime((time + offset) % 86400, TIME_FORMAT_STYLE_CLOCK_TIME, self.savedVars.setting_time_format)
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

function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

function getValue(tbl, name)
	for _,p in pairs(tbl) do
		if p.name == name then return p.value end
	end
end

function getName(tbl, value)
	for _,p in pairs(tbl) do
		if p.value == value then return p.name end
	end
end

local function OnShowBook(eventCode, title, body, medium, showTitle)
	Librarian:StoreBook(title, body, medium, showTitle)
end

SLASH_COMMANDS["/librarian"] = SlashCommand

EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_ADD_ON_LOADED, OnAddonLoaded) 
EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_SHOW_BOOK, OnShowBook)