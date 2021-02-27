local p = premake
local m = p.extensions.impcmake

function m.commands.find_program( cmd )
	-- Find program directories
	m.findPath( cmd, 'PROGRAM', iif( os.ishost( 'windows' ), '.exe', nil ) )
end
