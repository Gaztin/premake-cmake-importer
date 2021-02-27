local p = premake
local m = p.extensions.impcmake

function m.commands.find_library( cmd )
	-- Find library directories
	m.findPath( cmd, 'LIBRARY', iif( os.istarget( 'windows' ), '.lib', '.a' ) )
end
