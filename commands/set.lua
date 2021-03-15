local p = premake
local m = p.extensions.impcmake

function m.commands.set( cmd )
	local scope        = m.scope.current()
	local arguments    = table.arraycopy( cmd.arguments )
	local variableName = table.remove( arguments, 1 )
	local values       = { }
	local parentScope  = false
	local isCache      = false

	local i = 0
	while( i < #arguments ) do
		i = i + 1

		if( arguments[ i ] == 'PARENT_SCOPE' ) then
			parentScope = true

		elseif( arguments[ i ] == 'CACHE' ) then
			local entrytype = arguments[ i + 1 ]
			local docstring = arguments[ i + 2 ]
			local force     = false
			i = i + 2

			isCache = true

			while( i < #arguments ) do
				i = i + 1

				if( arguments[ i ] == 'FORCE' ) then
					force = true
				else
					p.warn( 'Unhandled cache option "%s" for command "%s"', arguments[ i ], cmd.name )
				end
			end

			if( m.cache_entries[ variableName ] == nil or force ) then
				m.cache_entries[ variableName ] = table.implode( values, '', '', ' ' )
			end

		else
			table.insert( values, m.expandVariables( arguments[ i ] ) )
		end
	end

	if( not isCache ) then
		local value = table.concat( values, ' ' )

		if( parentScope ) then
			scope.parent.variables[ variableName ] = value
		else
			scope.variables[ variableName ] = value
		end
	end
end
