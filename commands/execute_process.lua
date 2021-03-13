local p       = premake
local m       = p.extensions.impcmake
local options = { }

local function getOptionArgs( ... )
	local args = { }
	for i=1,select( '#', ... ) do
		local arg = select( i, ... )
		if( options[ arg ] ) then
			break
		end

		table.insert( args, arg )
	end

	return args
end

function options.COMMAND( process, ... )
	local args    = getOptionArgs( ... )
	local command = table.concat( args, ' ' )

	table.insert( process.commands, command )

	return #args
end

-- TODO: WORKING_DIRECTORY
-- TODO: TIMEOUT

function options.RESULT_VARIABLE( process, variable )
	process.resultVar = variable
	return 1
end

function options.RESULTS_VARIABLE( process, variable )
	process.resultsVar = variable
	return 1
end

function options.OUTPUT_VARIABLE( process, variable )
	process.outputVar = variable
	return 1
end

-- TODO: ERROR_VARIABLE
-- TODO: INPUT_FILE
-- TODO: OUTPUT_FILE
-- TODO: ERROR_FILE
-- TODO: OUTPUT_QUIET

function options.ERROR_QUIET( process )
	return 0
end

function options.COMMAND_ECHO( process, where )
	process.echo = where
	return 1
end

function options.OUTPUT_STRIP_TRAILING_WHITESPACE( process )
	process.stripTrailingWhitespaceInOutput = true
	return 0
end

-- TODO: ERROR_STRIP_TRAILING_WHITESPACE
-- TODO: ENCODING

function m.commands.execute_process( cmd )
	local i       = 1
	local process = {
		commands = { },
		echo     = m.expandVariable( 'CMAKE_EXECUTE_PROCESS_COMMAND_ECHO', 'STDOUT' ),
	}

	repeat
		local callback = options[ cmd.arguments[ i ] ]
		if( not callback ) then
			p.error( 'execute_process: The "%s" option is not implemented!', cmd.arguments[ i ] )
		end

		i = i + 1 + callback( process, table.unpack( cmd.arguments, i + 1 ) )
	until( i > #cmd.arguments )

	if( #process.commands == 0 ) then
		p.error( 'execute_process: No commands given!' )
	end

	local outputs = { }
	local results = { }
	for i,command in ipairs( process.commands ) do
		if( process.echo == 'STDOUT' ) then
			io.stdout:write( '[CMake Process]: ' .. command .. '\n' )
		else
			io.stderr:write( '[CMake Process]: ' .. command .. '\n' )
		end

		local pipe   = io.popen( command )
		local output = pipe:read( '*a' ) or ''
		local success, exitCause, exitCode = pipe:close()

		if( process.stripTrailingWhitespaceInOutput ) then
			output = string.match( output, '(.*)%s*' ) or output
		end

		p.error( output )

		table.insert( outputs, output )
		table.insert( results, result )
	end

	local scope = m.scope.current()
	if( process.resultVar ) then
		scope.variables[ process.resultVar ]  = results[ #results ]
	end
	if( process.resultsVar ) then
		scope.variables[ process.resultsVar ] = table.concat( results, ';' )
	end
	if( process.outputVar ) then
		scope.variables[ process.outputVar ]  = table.concat( outputs, '\n' )
	end
end
