local p = premake
local m = p.extensions.impcmake

function m.commands.cmake_policy( cmd )
	printf( 'cmake_policy(%s)', table.concat( cmd.arguments, ', ' ) )
end
