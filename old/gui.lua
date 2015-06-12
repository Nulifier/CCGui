-- Includes
local class = loadfile('class')()

-- Defaults
defaultButtonForeground = colors.white
defaultButtonBackground = colors.blue
defaultSliderForeground = colors.white
defaultSliderBackground = colors.gray
defaultFlagMonitorForeground = colors.white
defaultProgressBarForeground = colors.white
defaultProgressBarBackground = colors.gray
terminalBackground = colors.black

-- State
local monitor
local redrawNeeded = false

-- Functions
local function nop()
end

function getMonitor()
	return monitor
end

function setMonitor(mon)
	monitor = mon
end

function getDefaultMonitor()
	local mon = peripheral.find('monitor', function(name, obj) return obj.isColor() end)
	
	-- Check if we found a monitor
	if mon then
		return mon
	end
	
	-- We didn't find one, check if we can use the terminal
	if term.isColor() then
		print('Using default terminal')
		return term
	else
		error('No advanced monitor or advanced computer found', 2)
	end
end

----------------------------------------------------------------------------
Widget = class()

function Widget:__init()
	-- Weight
	self.hWeight = 1
	self.vWeight = 1
	
	-- Size
	self.width = nil
	self.height = nil
	
	-- Position
	self.x1 = nil
	self.y1 = nil
	self.x2 = nil
	self.y2 = nil
end

-- Callbacks
Widget.draw = nop
Widget.onClick = nop
Widget.onResize = nop

-- Updates the widget's size
function Widget:size()
	if (monitor == nil) then
		monitor = getDefaultMonitor()
	end
	
	self.width, self.height = monitor.getSize()
		
	self.x1 = 1
	self.y1 = 1
	self.x2 = self.width
	self.y2 = self.height
	self.onResize(self)
	self.sized = true
end

-- Runs the widget
function Widget:run()
	if not self then
		error('Invalid call to Widget:run', 2)
	end
	
	-- Make sure the widget is sized
	if not self.sized then
		self:size()
	end
	
	monitor.setBackgroundColor(terminalBackground)
	monitor.clear()
	self:draw()
	self.quit = false
	
	-- Loop until self.quit is true
	while not self.quit do
		local event, p1, p2, p3, p4, p5 = os.pullEvent()
		
		if (event == "monitor_touch" or event == "mouse_click") then
			self:onClick(p2, p3)
		end
		
		if event == "key" and p1 == keys.grave then
			self.quit = true
		end
		
		if redrawNeeded then
			monitor.setBackgroundColor(terminalBackground)
			monitor.clear()
			self:draw()
		end
	end
	
	-- Cleanup
	monitor.setBackgroundColor(terminalBackground)
	monitor.clear()
end

----------------------------------------------------------------------------
Container = class(Widget)

function Container:__init()
	self.children = {}
	self.vSpacingWeight = 0.1
	self.hSpacingWeight = 0.1
end

function Container:draw()
	for key, child in pairs(self.children) do
		child:draw()
	end
end

function Container:onClick(x, y)
	for key, child in pairs(self.children) do
		if x >= child.x1 and x <= child.x2 and y >= child.y1 and y <= child.y2 then
			child:onClick(x,y)
		end
	end
end

function Container:resizeChildren()
	for key, child in pairs(self.children) do
		child:onResize()
	end
end

Container.onResize = resizeChildren

function Container:add(widget)
	if not widget then
		error('Attempted to add nil widget to container', 2)
	end
	table.insert(self.children, widget)
end

----------------------------------------------------------------------------
Row = class(Container)

function Row:onResize()
	-- Calculate the space between each child widget
	local totalWeight = self.hSpacingWeight * (#self.children-1)
	
	-- Sum the weights of all the child widgets
	for key, child in pairs(self.children) do
		totalWeight = totalWeight + child.hWeight
	end
	
	-- Calculate the widths of each of the children based on their
	-- percentage of the overall weights
	local widths = {}
	local totalWidgetWidth = 0
	for key, child in pairs(self.children) do
		widths[key] = math.floor(self.width * child.hWeight/totalWeight)
		totalWidgetWidth = totalWidgetWidth + widths[key]
	end
	
	local remainingWidth = self.width - totalWidgetWidth
	
	local separatorWidth
	if (#self.children >= 1) then
		separatorWidth = 1
	else
		separatorWidth = math.floor(remainingWidth/(#self.children-1))
	end
	
	local currentPosition = self.x1 + math.floor((self.width - totalWidgetWidth - separatorWidth*(#self.children-1))/2)
	for key, child in pairs(self.children) do
		child.x1 = currentPosition
		child.y1 = self.y1
		currentPosition = currentPosition + widths[key] - 1
		child.x2 = currentPosition
		child.y2 = self.y2
		currentPosition = currentPosition + separatorWidth + 1
		child.width = widths[key]
		child.height = self.height
	end
	self:resizeChildren()
end

----------------------------------------------------------------------------
TabContainer = class(Widget)

function TabContainer:__init()
	self.tabs = {}
	self.activeTab = nil
	
	-- Colors
	self.activeForeground = colors.white
	self.activeBackground = colors.blue
	self.inactiveForeground = colors.white
	self.inactiveBackground = colors.grey
end

function TabContainer:add(name, tab)
	table.insert(self.tabs, {name=name, tab=tab})
		
	-- The first tab added will be the default tab
	if not self.activeTab then
		self.activeTab = tab
	end
end

function TabContainer:onResize()
	-- Bascially we just reduce the height by one for the active tab
	if self.activeTab then
		local tab = self.activeTab
		tab.width = self.width
		tab.height = self.height-1
		tab.x1 = self.x1
		tab.x2 = self.x2
		tab.y1 = self.y1+1
		tab.y2 = self.y2
		tab:onResize()
	end
end

function TabContainer:draw()
	-- Draw the header bar
	for i, tab in ipairs(self.tabs) do
		monitor.setCursorPos(self.x1, self.y1)
	end
	
	if self.activeTab then
		self.activeTab:draw()
	end
end

----------------------------------------------------------------------------
Button = class(Widget)

function Button:__init(label)
	Widget.__init(self)
	
	self.label = label
	self.backgroundColor = defaultButtonBackground
	self.foregroundColor = defaultButtonForeground
	self.labelX = nil
	self.labelY = nil
end

function Button:drawFilled()
	self.labelX = math.floor((self.x1+self.x2-self.label:len())/2)
	self.labelY = (self.y1 + self.y2)/2
	
	monitor.setBackgroundColor(self.backgroundColor)
	monitor.setTextColor(self.foregroundColor)
	
	for x = self.x1, self.x2 do
		for y = self.y1, self.y2 do
			monitor.setCursorPos(x, y)
			monitor.write(' ')
		end
	end
	
	monitor.setCursorPos(self.labelX, self.labelY)
	monitor.write(self.label)
end

Button.draw = Button.drawFilled

----------------------------------------------------------------------------
Label = class(Widget)

function Label:__init(text)
	self.text = text
	self.textColor = defaultButtonForeground
end

function Label:draw()
	local leftMargin = math.floor((self.width - self.text:len())/2)
	local rightMargin = self.width - self.text:len() - leftMargin
	local y = math.floor((self.y1 - self.y2)/2)
	local paddedText = string.rep(' ', leftMargin) .. self.text .. string.rep(' ', rightMargin)
	
	monitor.setTextColor(self.textColor)
	monitor.setCursorPos(self.x1, y)
	monitor.write(paddedText)
end
