local p = premake
local m = p.extensions.impcmake

function m.commands.message( cmd )
	local arguments    = cmd.arguments
	local allowedModes = { 'FATAL_ERROR', 'SEND_ERROR', 'WARNING',     'AUTHOR_WARNING',
	                       'DEPRECATION', 'NOTICE',     'STATUS',      'VERBOSE',
	                       'DEBUG',       'TRACE',      'CHECK_START', 'CHECK_PASS',
	                       'CHECK_FAIL' }

	if( #arguments > 1 ) then
		local mode = arguments[ 1 ]
		local msg  = m.toRawString( arguments[ 2 ] )

		if( mode == 'FATAL_ERROR' or mode == 'SEND_ERROR' ) then
			term.pushColor( term.red )
		elseif( mode == 'WARNING' or mode == 'AUTHOR_WARNING' ) then
			term.pushColor( term.yellow )
		elseif( mode == 'DEPRECATION' ) then
			term.pushColor( term.cyan )
		elseif( mode == 'NOTICE' or mode == 'STATUS' or mode == 'VERBOSE' or mode == 'DEBUG' or mode == 'TRACE' or mode == 'CHECK_START' or mode == 'CHECK_PASS' or mode == 'CHECK_FAIL' ) then
			term.pushColor( term.white )
		else
			p.warn( 'Unhandled message mode "%s"', mode )
			term.pushColor( term.white )
		end

		printf( '[CMake]<%s>: %s', mode, msg )
		term.popColor()

	else
		local msg = m.toRawString( arguments[ 1 ] )

		printf( '[CMake]: %s', msg )
	end
end
