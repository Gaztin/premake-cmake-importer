local p = premake
local m = p.extensions.impcmake

function m.commands.option( cmd )
	local variable   = cmd.arguments[ 1 ]
	local helpText   = cmd.arguments[ 2 ]
	local value      = cmd.arguments[ 3 ] or m.OFF
	local infoString = '[CMake Option]: ' .. variable .. ' - "' .. helpText

	-- If not already defined, set the default value for this option
	if( not m.options[ variable ] ) then
		infoString            = infoString .. '" (defaulted to ' .. value .. ')'
		m.options[ variable ] = value
	else
		infoString            = infoString .. '" (predefined to ' .. m.options[ variable ] .. ')'
	end

	print( infoString )
end
