-- Includes
local class = loadfile('class')()

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

------------------------------------------------------------
Gui = class()

function Gui:__init(monitor)
	self._monitor = monitor or getDefaultMonitor()
	self.root = nil
end

function Gui:setRoot(widget)
	self.root = widget
	if widget then
		-- Set the window
		width, height = self._monitor.getSize()
		--widget.win = window.create(self._monitor, 1, 1, width, height)
		widget.dirty = true
	end
end

function Gui:run()
	self:_draw()
	
	self.quit = false
	while not self.quit do
		self:_handleEvent(os.pullEvent())
	end
end

function Gui:_handleEvent(event, ...)
	local args = {...}
	
	if event == 'char' then
		
	elseif event == 'key' then
		
	elseif event == 'mouse_click' or event == 'monitor_touch' then
		
	elseif event == 'redraw_needed' then
		self:_draw()
	end
end

function Gui:_draw()
	self._monitor.clear()
	if self.root then
		self.root:draw()
	end
end

------------------------------------------------------------
Widget = class()

function Widget:__init()
	self.win = nil
	self._dirty = true
end

Widget.onChar = nop
Widget.onKey = nop
Widget.onClick = nop
Widget.onDraw = nop

function Widget:draw()
	if self.isDirty() then
		-- The content of the window has changed, we need a re-draw
		self.win.clear()
		self:onDraw()
		self._dirty = false
	else
		-- No change, just use the buffer
		self.win.redraw()
	end
end

function Widget:isDirty()
	return self._dirty
end

------------------------------------------------------------
Container = class(Widget)

function Container:__init()
	self.children = {}
end

function Container:isDirty()
	-- Check if this container is dirty
	if Widget.isDirty(self) then
		return true
	end
	
	-- Check each of the children
	for k, child in pairs(self.children) do
		if child.isDirty() then
			return true
		else
	end
	
	return false
end

------------------------------------------------------------
Button = class(Widget)

function Button:__init(label)
	self._label = label
end
