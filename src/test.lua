os.unloadAPI('gui')
os.loadAPI('gui')
os.unloadAPI('log')
os.loadAPI('log')

log.start()

local button = gui.Button('test')

local screen = gui.Gui()
screen:setRoot(button)
screen:run()
