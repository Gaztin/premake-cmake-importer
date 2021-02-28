local p = premake
local m = p.extensions.impcmake

function m.commands.unset( cmd )
	local scope        = m.scope.current()
	local variableName = cmd.arguments[ 1 ]
	local option       = cmd.arguments[ 2 ]

	if( option == 'CACHE' ) then
		m.cache_entries[ variableName ] = nil
	elseif( option == 'PARENT_SCOPE' ) then
		scope.parent.variables[ variableName ] = nil
	else
		scope.variables[ variableName ] = nil
	end
end
