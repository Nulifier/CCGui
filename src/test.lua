os.unloadAPI('gui')
os.loadAPI('gui')
os.unloadAPI('log')
os.loadAPI('log')
os.unloadAPI('profiler')
os.loadAPI('profiler')

log.start()

local profiler = profiler.newProfiler()
profiler:start()

local g = gui.Gui()

local stack = gui.VStack()
g:setRoot(stack)

local button1 = gui.Button('Click')
local button2 = gui.Button('Click2')

stack:addWidget(button1)
stack:addWidget(button2)

profiler:stop()
	
local outfile = io.open('profile.txt', 'w')
profiler:report(outfile)
outfile:close()

g:run()
