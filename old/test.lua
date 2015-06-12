os.unloadAPI('gui')
os.loadAPI('gui')
os.unloadAPI('log')
os.loadAPI('log')

log.start()

local page1 = gui.Row()
page1.hSpacingWeight = 0
page1:add(gui.Button('A'))
page1:add(gui.Button('B'))
page1:add(gui.Button('C'))

local page2 = gui.Row()
page2.hSpacingWeight = 0
page2:add(gui.Button('A'))
page2:add(gui.Button('B'))
page2:add(gui.Button('C'))
	
local tabs = gui.TabContainer()
tabs:add('Page 1', page1)
tabs:add('Page 2', page2)

tabs:run()
