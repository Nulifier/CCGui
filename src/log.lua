local logFile

loggingEnabled = true

function start(filename)
	local filename = filename or 'logFile'
	logFile = fs.open(filename, 'w')
	logFile.flush()
end

function log(message, ...)
	if loggingEnabled then
		-- Check if the log file has been created
		if not logFile then
			start()
		end
		
		logFile.writeLine(string.format(message, ...))
		logFile.flush()
	end
end
