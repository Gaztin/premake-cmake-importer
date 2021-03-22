local p = premake
local m = p.extensions.impcmake

local modes = {
	FATAL_ERROR    = { color = term.red,        hint = 'Fatal error' },
	SEND_ERROR     = { color = term.red,        hint = 'Send error' },
	WARNING        = { color = term.yellow,     hint = 'Warning' },
	AUTHOR_WARNING = { color = term.yellow,     hint = 'Author warning' },
	DEPRECATION    = { color = term.purple,     hint = 'Deprecation' },
	NOTICE         = { color = term.cyan,       hint = 'Notice' },
	STATUS         = { color = term.white,      hint = 'Status' },
	VERBOSE        = { color = term.gray,       hint = 'Verbose' },
	DEBUG          = { color = term.gray,       hint = 'Debug' },
	TRACE          = { color = term.lightGreen, hint = 'Trace' },
	CHECK_START    = { color = term.lightCyan,  hint = 'Check start' },
	CHECK_PASS     = { color = term.lightCyan,  hint = 'Check pass' },
	CHECK_FAIL     = { color = term.lightCyan,  hint = 'Check fail' },
	__default      = { color = nil,             hint = nil }
}

function m.commands.message( cmd )
	local mode  = modes[ cmd.arguments[ 1 ] ]
	local start = mode and 2 or 1
	mode        = mode or modes.__default

	for i = start, #cmd.arguments do
		term.pushColor( mode.color )
		if( mode.hint ) then
			print( '[CMake] ' .. mode.hint .. ': ' .. cmd.arguments[ i ] )
		else
			print( '[CMake]:' .. cmd.arguments[ i ] )
		end
		term.popColor()
	end
end
