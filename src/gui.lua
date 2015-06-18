--- A GUI system for ComputerCraft.
--	@module CCGui

-- Includes
local class = loadfile('class')()

if not surface then
	os.loadAPI('surface')
end

--- Searches for an attached monitor or uses the terminal by default.
local function getDefaultMonitor()
	local mon = peripheral.find('monitor', function(name, obj) return obj.isColor() end)
	
	-- Check if we found a monitor
	if mon then
		return mon
	end
	
	-- We didn't find one, check if we can use the terminal
	if term.isColor() then
		return term.current()
	else
		error('No advanced monitor or advanced computer found', 2)
	end
end

local function nop()
end

local function drawBox(mon, x1, y1, x2, y2, color)
	mon.setBackgroundColor(color)
	for y=y1,y2 do
		mon.setCursorPos(x1,y)
		for x=x1,x2 do
			mon.write(" ")
		end
	end
end

--- Refreshes the display, redrawing widgets as needed.
function refresh()
	os.queueEvent('redraw_needed')
end

local deferredFuncs = {}

function setTimeout(func, seconds)
	local id = os.startTimer(seconds)
	deferredFuncs[id] = func
end

-- Returns true if this event was handled
local function checkDeferredFuncs(timerId)
	if deferredFuncs[timerId] then
		deferredFuncs[timerId]()
		deferredFuncs[timerId] = nil
		return true
	else
		return false
	end
end

------------------------------------------------------------
--- The root of the GUI system that handles events.
--	@type Gui
Gui = class()

function Gui:__init(monitor)
	self._monitor = monitor or getDefaultMonitor()
	self.root = nil
end

--- Sets the root Widget for the GUI system.
function Gui:setRoot(widget)
	self.root = widget
	if widget then
		local width, height = self._monitor.getSize()
		widget.dirty = true
		widget.x = 1
		widget.y = 1
		widget.width = width
		widget.height = height
	end
end

--- Starts the event loop of the GUI system.
function Gui:run()
	refresh()
	
	self.quit = false
	while not self.quit do
		self:_handleEvent(os.pullEvent())
	end
end

function Gui:_handleEvent(event, ...)
	local args = {...}
	
	if event == 'char' then
		self:_char(args[1])
	elseif event == 'key' then
		self:_key(args[1])
	elseif event == 'mouse_click' then
		self:_click(args[1], args[2], args[3])
	elseif event == 'monitor_touch' then
		self:_click(1, args[2], args[3])
	elseif event == 'redraw_needed' then
		self:_draw()
	elseif event == 'timer' then
		if not checkDeferredFuncs(args[1]) then
			-- This one is for us
		end
	end
end

function Gui:_char(char)
	if self.root then
		self.root:onChar(char)
	end
end

function Gui:_key(keyCode)
	if self.root then
		self.root:onKey(keyCode)
	end
end

function Gui:_click(button, x, y)
	if self.root then
		self.root:onClick(button, x, y)
	end
end

function Gui:_draw()
	self._monitor.clear()
	if self.root then
		self.root:draw()
		self.root.surf:render(self._monitor, 1, 1)
	else
		error('No root element provided to Gui class.', 3)
	end
end

------------------------------------------------------------
--- The base graphical element that all others inherit from.
--	@type Widget
Widget = class()

Widget.win = nil

Widget._dirty = true

--- Called to handle a keyboard character being pressed.
--	@function onChar
--	@tparam string char The character that was pressed.
Widget.onChar = nop

--- Called to handle a keyboard button being pressed.
--	@function onKey
--	@tparam number keycode The code of the key pressed, see keys API.
Widget.onKey = nop

--- Called to handle the mouse being clicked or the monitor being touched.
--	@function onClick
--	@tparam number button The button pressed, left click and monitor touch are 1, right click is 2.
--	@tparam number x The x coordinate of the location pressed.
--	@tparam number y The y coordinate of the location pressed.
Widget.onClick = nop

--- This should be implemented to draw the widget.
--	@function onDraw
Widget.onDraw = nop

--- Draws the widget to the screen.
--	This should only be called by the @{Gui} class.
function Widget:draw()
	-- Check if a surface exists
	if not self.surf then
		self:_createSurf()
	end
	
	-- Check if the surface needs to be redrawn
	if self:isDirty() then
		-- The content of the window has changed, we need a re-draw
		self:onDraw()
		self._dirty = false
	end
end

--- Checks if the widget needs redrawing.
--	@treturn boolean True if the widget needs to be redrawn, false if not.
function Widget:isDirty()
	return self._dirty
end

--- Sets a flag that this widget needs to be redrawn
function Widget:setDirty()
	self._dirty = true
end

function Widget:_createSurf()
	-- Check if the widget has been initialized
	if not self.width and not self.height and not self.x and not self.y then
		error('Widget must be initalized before creating surface', 2)
	end
	self.surf = surface.create(self.width, self.height)
end

------------------------------------------------------------
--- A base class for widgets that contain other widgets.
--	@type Container
Container = class(Widget)

function Container:__init()
	self._children = {}
end

function Container:isDirty()
	-- Check if this container is dirty
	if Widget.isDirty(self) then
		return true
	end
	
	-- Check each of the children
	for k, child in pairs(self._children) do
		if child:isDirty() then
			return true
		end
	end
	
	return false
end

function Container:onChar(char)
	for k, child in pairs(self._children) do
		child:onChar(char)
	end
end

function Container:onKey(keyCode)
	for k, child in pairs(self._children) do
		child:onKey(keyCode)
	end
end

function Container:onClick(button, x, y)
	for k, child in pairs(self._children) do
		-- Check if the position is inside the child
		local x1, y1 = child.x, child.y
		local x2, y2 = child.surf.width, child.surf.height
		x2 = x1 + x2 - 1
		y2 = y1 + y2 - 1
		if (x >= x1) and (x <= x2) and (y >= y1) and (y <= y2) then
			child:onClick(button, x - x1 + 1, y - y1 + 1)
		end
	end
end

------------------------------------------------------------
--- A container that stacks widgets.
--	@type Stack
Stack = class(Container)

function Stack:__init(direction, spacing)
	Container.__init(self)
	self._direction = direction or 'vertical'
	self._spacing = spacing or 1
end

--- Adds a widget to this stack.
--	@param widget The widget to add to the stack.
function Stack:addWidget(widget)
	table.insert(self._children, widget)
	self:_layout()
	self:setDirty()
end

--- Clears all widgets from this stack.
function Stack:clearWidgets()
	self._children = {}
	self:setDirty()
end

function Stack:_layout()
	-- Check if a surface exists
	if not self.surf then
		self:_createSurf()
	end
	
	local width, height = self.surf.width, self.surf.height
	local numChildren = #self._children
	
	-- Calculate how much space is left for each widgets
    local layoutDirectionSize
    if self._direction == 'vertical' then
        layoutDirectionSize = height
    elseif self._direction == 'horizontal' then
        layoutDirectionSize = width
    else
        error('Invalid Stack direction: ' .. self_direction, 2)
    end
    local widgetSize = math.floor((layoutDirectionSize - (self._spacing*numChildren))/numChildren)+1
	
	-- Position each child leaving a space between them
	local pos = 1
	for i, child in ipairs(self._children) do
		if self._direction == 'vertical' then
			child.x = 1
			child.y = pos
			child.width = width
			child.height = widgetSize
		elseif self._direction =='horizontal' then
			child.x = pos
			child.y = 1
			child.width = widgetSize
			child.height = height
		end
		pos = pos + self._spacing + widgetSize
		child:_createSurf()
	end
end

--- Draws each of the children.
function Stack:onDraw()
	self.surf:clear(' ', colors.black, colors.white)
	for i, child in ipairs(self._children) do
		-- Render the child to the surface
		child:draw()
		
		-- Render the child's surface to this widget's surface
		self.surf:drawSurface(child.x, child.y, child.surf)
	end
end

------------------------------------------------------------
--- A clickable button.
--	This can also be a button if the onClick handler is not implemented.
--	@type Button
Button = class(Widget)

function Button:__init(label, background, foreground)
	self.state = false
	self._label = label or 'Button'
	self._background = background or colors.blue
	self._foreground = foreground or colors.white
	self._activeBackground = activeBackground or colors.lightBlue
	self._activeForeground = activeForeground or colors.white
end

--- Sets the label for this button.
function Button:setLabel(label)
	self._label = label
	setDirty()
end

function Button:onClick()
	self.state = true
	self:setDirty()
	refresh()
	setTimeout(function ()
		self.state = false
		self:setDirty()
		refresh()
	end, 0.1)
end

--- Draws a button.
function Button:onDraw()
	local labelLen = #self._label
	local width, height = self.surf.width, self.surf.height
	
	local linesAboveLabel = math.floor((height-1)/2)+1
	local spacesBeforeLabel = math.ceil((width-labelLen)/2)

	local foreground
	local background
	if self.state then
		foreground, background = self._activeForeground, self._activeBackground
	else
		foreground, background = self._foreground, self._background	
	end

	self.surf:clear(' ', background)
	self.surf:drawText(spacesBeforeLabel, linesAboveLabel, self._label, nil, foreground)
end

------------------------------------------------------------
--- A toggleable button.
--	The state can be checked using button.state.
--	@type ToggleButton
ToggleButton = class(Widget)

function ToggleButton:__init(label, background, foreground, activeBackground, activeForeground)
	self.state = false
	self._label = label
	self._background = background or colors.gray
	self._foreground = foreground or colors.lightGray
	self._activeBackground = activeBackground or colors.blue
	self._activeForeground = activeForeground or colors.white
end

function ToggleButton:setLabel(label)
	self._label = label
	setDirty()
end

function ToggleButton:onClick()
	self.state = not self.state
	self:setDirty()
	refresh()
end

function ToggleButton:onDraw()
	local labelLen = #self._label
	local width, height = self.surf.width, self.surf.height
	
	local linesAboveLabel = math.floor((height-1)/2)+1
	local spacesBeforeLabel = math.ceil((width-labelLen)/2)

	local foreground
	local background
	if self.state then
		foreground, background = self._activeForeground, self._activeBackground
	else
		foreground, background = self._foreground, self._background	
	end

	self.surf:clear(' ', background)
	self.surf:drawText(spacesBeforeLabel, linesAboveLabel, self._label, nil, foreground)
end

------------------------------------------------------------
--- A progress bar.
--	@type ProgressBar
ProgressBar = class(Widget)

function ProgressBar:__init(direction, maxValue, foreground, background)
	self._direction = direction or 'right'
	self._value = 1
	self._maxValue = maxValue or 3
	self._foreground = foreground or colors.green
	self._background = background or colors.gray
end

--- Sets how full this bar is.
--	@tparam number value Divided by the maxValue.
function ProgressBar:setValue(value)
	self._value = value
	setDirty()
end

--- Draws a progress bar.
function ProgressBar:onDraw()
	local width, height = self.surf.width, self.surf.height
	if self._direction == 'right' then
		local colsToFill = math.floor((self._value/self._maxValue) * width)
		self.surf:fillRect(1, 1, colsToFill, height, ' ', self._foreground)
		self.surf:fillRect(colsToFill+1, 1, width, height, ' ', self._background)
	elseif self._direction == 'up' then
		local rowsToFill = math.floor((self._value/self._maxValue) * height)
		self.surf:fillRect(1, 1, width, height-rowsToFill, self._background)
		self.surf:fillRect(1, height-rowsToFill+1, width, height, self._foreground)
	else
		error('Invalid direction: ' .. self._direction, 2)
	end
end
