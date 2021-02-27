local p = premake
local m = p.extensions.impcmake

function m.commands.find_path( cmd )
	-- Find include directories
	m.findPath( cmd, 'INCLUDE' )
end
