local p = premake
local m = p.extensions.impcmake

function m.commands.install( cmd )
	-- Skip installation rules
	p.warnOnce( p.api.scope.project, string.format( 'Skipping installation rules for project "%s"', p.api.scope.project.name ) )
end
