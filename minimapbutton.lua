-------------------------------------------------------------------------------
-- Cross RP by Tammya-MoonGuard (2018)
--
-- The minimap button and menu.
-------------------------------------------------------------------------------
local _, Me  = ...
local L      = Me.Locale
local LDB    = LibStub( "LibDataBroker-1.1" )
local DBIcon = LibStub( "LibDBIcon-1.0"     )
local MinimapMenu = {}
Me.MinimapMenu = MinimapMenu
-------------------------------------------------------------------------------
-- The communities frame is very unstable when it comes to taint issues, so
--  we don't use the Blizzard internal drop down menu stuff; instead we use
--  MSA-DropDownMenu as an easy replacement. As far as I know, it's just
--  Blizzard's code copied and renamed. We're doing it this way in the hopes
--  that Blizzard will unfuck their menus so we can use them directly.

local UIDropDownMenu_CreateInfo   = MS_CRPA_DropDownMenu_CreateInfo
local UIDropDownMenu_AddButton    = MS_CRPA_DropDownMenu_AddButton
local UIDropDownMenu_AddSeparator = function( level )
	MS_CRPA_DropDownMenu_AddSeparator( MS_CRPA_DropDownMenu_CreateInfo(), level )
end
local UIDropDownMenu_Initialize  = MS_CRPA_DropDownMenu_Initialize
local UIDropDownMenu_JustifyText = MS_CRPA_DropDownMenu_JustifyText
local ToggleDropDownMenu         = MS_CRPA_ToggleDropDownMenu

local DROPDOWNMENU_TEMPLATE      = "UIDropDownMenuTemplate"
local function GetOpenMenu()
	return MS_CRPA_DROPDOWNMENU_OPEN_MENU
	--return UIDROPDOWNMENU_OPEN_MENU
end
-------------------------------------------------------------------------------
-- The frame that the GameTooltip belongs to, if we're using it.
local m_tooltip_frame = nil
-------------------------------------------------------------------------------
-- What spot in the tooltip does the "Traffic: " line appear. This only shows
--  when the user is connected.
local m_traffic_lines_index = nil

-------------------------------------------------------------------------------
-- Called during setup, it initializes our LDB object and registers it, as well
--  as passes it to LibDBIcon so we can have a minimap button.
function Me.SetupMinimapButton()

	Me.ldb = LDB:NewDataObject( "CrossRP", {
		-- "data source" for addons to get a feed from and display our button.
		--  Titan Panel and other similar addons will also see this so they 
		--  can have our minimap button too.
		type    = "data source";
		
		-- The text that's displayed for addons like Titan Panel; this isn't
		--  used for the minimap button (LibDBIcon).
		text    = L.CROSS_RP;
		
		-- The label for this text, shown next to the text like a title. This
		--  will be mostly static, and the above will change according to the 
		--  connection state.
		label   = L.CROSS_RP;
		
		-- The icon that's paired with the text, or the icon for the minimap
		--  button.
		icon    = "Interface\\Icons\\INV_Jewelcrafting_ArgusGemCut_Red_MiscIcons";
		
		-- Mouse event handlers. These are used both for the minimap button
		--  and the relay indicator when connected.
		OnClick = Me.OnMinimapButtonClick;
		OnEnter = Me.OnMinimapButtonEnter;
		OnLeave = Me.OnMinimapButtonLeave;
		
		-- The color of the icon.
		iconR   = 1.0;
		iconG   = 1.0;
		iconB   = 1.0;
	})
	-- Second argument is a saved variables section. It uses that to read and
	--  save settings like if the minimap button is hidden, and handles all of
	--  that under the hood.
	DBIcon:Register( "CrossRP", Me.ldb, Me.db.global.minimapbutton )
	
	Me.SetupMinimapButton = nil
end

-------------------------------------------------------------------------------
-- Called when the minimap button or anything hooked to act the same way is
--  clicked.
function Me.OnMinimapButtonClick( frame, button )
	if button == "LeftButton" or button == "RightButton" then
		GameTooltip:Hide()
		Me.OpenMinimapMenu( frame )
	end
end

-------------------------------------------------------------------------------
local function FormatTimePeriod( t )
	local seconds = math.floor( t ) % 60
	local minutes = math.floor( t / 60 ) % 60
	local hours = math.floor( t / (60*60) )
	if hours > 0 then
		return string.format( "%d:%02d:%02d", hours, minutes, seconds )
	else
		return string.format( "%d:%02d", minutes, seconds )
	end
end

-------------------------------------------------------------------------------
function Me.FormatIdleTime()
	return FormatTimePeriod( GetTime() - Me.relay_active_time )
end

-------------------------------------------------------------------------------
function Me.FormatUptime()
	return FormatTimePeriod( GetTime() - Me.connect_time )
end

-------------------------------------------------------------------------------
function Me.RefreshMinimapTooltip()
	GameTooltip:ClearLines()
	-- Name, version.
	GameTooltip:AddDoubleLine( L.CROSS_RP, Me.version, 1,1,1, 1,1,1 )
	if Me.DEBUG_MODE then
		GameTooltip:AddLine( "|cFFFFFF00Debug Mode", 1,1,1 )
	end
	
	if Me.active then
		GameTooltip:AddLine( L.CROSSRP_ACTIVE, 0,1,0 )
	else
		GameTooltip:AddLine( L.CROSSRP_INACTIVE, 0.5, 0.5 ,0.5 )
	end
	
	local linked = Me.RPChat.enabled and Me.RPChat.password
--	if Me.RPChat.enabled and Me.RPChat.password then
--		GameTooltip:AddLine( " " )
--		GameTooltip:AddLine( "Group Linked", 0, 1, 0 )
--	end
	
	GameTooltip:AddLine( " " )
	GameTooltip:AddLine( L.NETWORK_STATUS, 1,1,1 )
	local status = Me.Proto.GetNetworkStatus()
	if #status == 0 then
		GameTooltip:AddLine( L.NO_CONNECTIONS, 0.5, 0.5 ,0.5 )
	else
		for k,v in pairs( status ) do
			local cr, cg, cb = 0.7, 0.7, 0.7
			local name = Me.Proto.GetBandName(v.band)
			local quota = v.quota
			if v.active then
				cr, cg, cb = 1, 1, 1
			end
			if v.direct then
				cr, cg, cb = 0.11, 0.95, 1
			end
			if v.quota == 0 then
				cr, cg, cb = 1, 0, 0
				quota = "N/A"
			end
			if v.secure then
				name = name .. " [L]"
			end
			
			GameTooltip:AddDoubleLine( name, quota, cr,cg,cb, 1,1,1 )
		end
	end
	
	GameTooltip:AddLine( " " )
	GameTooltip:AddLine( L.MINIMAP_TOOLTIP_CLICK_OPEN_MENU, 1,1,1 )
	
	GameTooltip:Show()
	return true
end

-------------------------------------------------------------------------------
local function UpdateTooltipTicker()
	if GameTooltip:GetOwner() ~= m_tooltip_frame
	                                        or (not GameTooltip:IsShown()) then
		return
	end
	Me.RefreshMinimapTooltip()
	Me.Timer_Start( "minimap_tooltip", "push", 1.0, UpdateTooltipTicker )
end

-------------------------------------------------------------------------------
function Me.OnMinimapButtonEnter( frame )
	GameTooltip:SetOwner( frame, "ANCHOR_NONE" )
	GameTooltip:SetPoint( "TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0 )
	m_tooltip_frame = frame
	Me.RefreshMinimapTooltip()
	Me.Timer_Start( "minimap_tooltip", "push", 1.0, UpdateTooltipTicker )
end

-------------------------------------------------------------------------------
-- Handler for when mouse leaves the interactive area.
function Me.OnMinimapButtonLeave( frame )
	GameTooltip:Hide()
end

-------------------------------------------------------------------------------
-- Handler for the channel buttons.
local function ToggleChannel( self, arg1, arg2, checked )
	Me.ListenToChannel( arg1, checked )
end

-------------------------------------------------------------------------------
-- Returns the color code of one of our RP channels; `index` may be 1-9 or "W".
local function GetChannelColorCode( index )
	index = tostring(index)
	local color = Me.db.global["color_rp"..index:lower()]
	return string.format( "|cff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end

-------------------------------------------------------------------------------
-- Handler for the Relay button.
local function ToggleRelayClicked( self, arg1, arg2, checked )
	-- Toggle relay and update our caption. The checkbox is already updated
	--  by the menu side.
	Me.EnableRelay( checked )
	local caption = L.RELAY
	if Me.relay_on then
		caption = "|cFF03FF11" .. caption
	end
	self:SetText( caption )
end

local function PrintNetworkLink( self, link )
	Me.PrintLinkToChat( link )
end

-------------------------------------------------------------------------------
function MinimapMenu.RPChatOptions( level )
	local info
	
	if Me.RPChat.IsController() then
		UIDropDownMenu_AddSeparator( level )
		if Me.RPChat.enabled then
			info = UIDropDownMenu_CreateInfo()
			info.text       = "Unlink Group"
			info.notCheckable = true
			info.func       = function( self, arg1, arg2, checked )
				
			end
			UIDropDownMenu_AddButton( info, level )
		else
			info = UIDropDownMenu_CreateInfo()
			info.text       = "Link Group"
			info.notCheckable = true
			info.func       = function( self, arg1, arg2, checked )
				
			end
			UIDropDownMenu_AddButton( info, level )
		end
	end
end

-------------------------------------------------------------------------------
-- Initializer for the minimap button menu.
local function InitializeMenu( self, level, menuList )
	local info
	if level == 1 then

		info = UIDropDownMenu_CreateInfo()
		info.text    = L.CROSS_RP
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L.TRANSLATE_EMOTES
		info.checked          = Me.translate_emotes_option
		info.isNotRadio       = true
		info.func             = function( self, arg1, arg2, checked )
			Me.translate_emotes_option = checked
		end
		info.tooltipTitle     = L.TRANSLATE_EMOTES
		info.tooltipText      = L.TRANSLATE_EMOTES_TIP
		info.tooltipOnButton  = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		MinimapMenu.RPChatOptions()
			
		-- Settings button.
		UIDropDownMenu_AddSeparator( level )
		info = UIDropDownMenu_CreateInfo()
		info.text         = L.SETTINGS
		info.notCheckable = true
		info.func         = Me.OpenOptions
		info.tooltipTitle     = info.text
		info.tooltipText      = L.SETTINGS_TIP
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
	end
end

-------------------------------------------------------------------------------
-- Open the minimap menu under this parent frame. The parent frame must be a
--  named frame.
function Me.OpenMinimapMenu( parent )
	
	if not Me.minimap_menu then
		Me.minimap_menu = CreateFrame( "Button", "CrossRPMinimapMenu", 
		                                 UIParent, DROPDOWNMENU_TEMPLATE )
	end
	
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if GetOpenMenu() == Me.minimap_menu and Me.minimap_menu_parent == parent then
	
		-- The menu is already open at the same parent, so we close it.
		ToggleDropDownMenu( 1, nil, Me.minimap_menu )
		return
	end
	
	Me.minimap_menu_parent = parent
	
	UIDropDownMenu_Initialize( Me.minimap_menu, InitializeMenu, "MENU" )
	UIDropDownMenu_JustifyText( Me.minimap_menu, "LEFT" )
	
	ToggleDropDownMenu( 1, nil, Me.minimap_menu, parent:GetName(), 
	                                             offset_x or 0, offset_y or 0 )
end
