local p = premake
local m = p.extensions.impcmake

function m.commands.target_compile_definitions( cmd )
	local arguments      = table.arraycopy( cmd.arguments )
	-- According to the docs, cannot be an alias target
	local targetName     = table.remove( arguments, 1 )
	local projectToAmend = p.workspace.findproject( p.api.scope.workspace, targetName )
	local allowedScopes  = { 'INTERFACE', 'PUBLIC', 'PRIVATE' }
	local i              = 0

	while( i < #arguments ) do
		i = i + 1

		if( table.contains( allowedScopes, arguments[ i ] ) ) then
			local items = { }

			while( ( i < #arguments ) and ( not table.contains( allowedScopes, arguments[ i + 1 ] ) ) ) do
				i = i + 1

				local item = arguments[ i ]

				-- Remove leading '-D'
				item = string.gsub( item, '-D', '', 1 )

				-- Ignore empty items
				local isEmpty = ( string.len( item ) == 0 ) or
				                ( ( string.sub( item, 1, 1 ) == '"' ) and
				                  ( string.sub( item, 2, 2 ) == '"' ) )

				if( not isEmpty ) then
					table.insert( items, arguments[ i ] )
				end
			end

			defines( items )
		end
	end
end
