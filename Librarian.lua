Librarian = {}
Librarian.defaults = {books = {}}

ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_LIBRARIAN", "Toggle Librarian")
ZO_CreateStringId("SI_BINDING_NAME_RELOAD_UI", "Reload UI")
ZO_CreateStringId("SI_WINDOW_TITLE_LIBRARIAN", "Librarian")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_UNREAD", "Unread")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_FOUND", "Found")
ZO_CreateStringId("SI_LIBRARIAN_SORT_TYPE_TITLE", "Title")
ZO_CreateStringId("SI_LIBRARIAN_MARK_UNREAD", "Mark as Unread")
ZO_CreateStringId("SI_LIBRARIAN_MARK_READ", "Mark as Read")

local previousBook
local scrollChild
local sortField = "Found"
local sortAscending = true

function Librarian:Initialise()
 	scrollChild = LibrarianFrameScrollContainer:GetNamedChild("ScrollChild")
	self.savedVars = ZO_SavedVars:New("Librarian_SavedVariables", 1, nil, self.defaults, nil)

	self:LayoutBooks()

	self:InitializeKeybindStripDescriptors()
	self:InitializeScene()
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
	local i = #self.savedVars.books
	self:LayoutBook(i, book)
	d("New book added!")
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
	if book.unread then bookControl.unread:SetAlpha(1) else bookControl.unread:SetAlpha(0) end
	local date = GetDateStringFromTimestamp(book.timeStamp)
	local time = ZO_FormatTime(book.timeStamp, TIME_FORMAT_STYLE_CLOCK_TIME, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
	bookControl.found:SetText(string.format("%s %s", date, time))
	bookControl.title:SetText(book.title)
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

	if sortField == "Unread" then
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.unread and not b.unread end)
		else 
			table.sort(self.savedVars.books, function(a, b) return not a.unread and b.unread end)
		end
	elseif sortField == "Found" then
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.timeStamp < b.timeStamp end)
		else
			table.sort(self.savedVars.books, function(a, b) return a.timeStamp > b.timeStamp end)
		end
	elseif sortField == "Title" then
		if sortAscending then
			table.sort(self.savedVars.books, function(a, b) return a.title < b.title end)
		else
			table.sort(self.savedVars.books, function(a, b) return a.title > b.title end)
		end
	end

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

local function SlashCommand(args)
	Librarian:Toggle()
end

local function OnAddonLoaded(event, addon)
	if addon == "Librarian" then
		Librarian:Initialise()
	end
end

local function OnShowBook(eventCode, title, body, medium, showTitle)
	Librarian:StoreBook(title, body, medium, showTitle)
end

SLASH_COMMANDS["/l"] = SlashCommand 
SLASH_COMMANDS["/lib"] = SlashCommand
SLASH_COMMANDS["/librarian"] = SlashCommand

EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_ADD_ON_LOADED, OnAddonLoaded) 
EVENT_MANAGER:RegisterForEvent("Librarian", EVENT_SHOW_BOOK, OnShowBook)