local p = premake
local m = p.extensions.impcmake

function m.commands.include( cmd )
	local arguments = table.arraycopy( cmd.arguments )
	local file      = m.toRawString( table.remove( arguments, 1 ) )
	local required  = true
	local resultVar = nil

	while( #arguments > 0 ) do
		local arg = table.remove( arguments, 1 )

		if( arg == 'OPTIONAL' ) then
			required = false

		elseif( arg == 'RESULT_VARIABLE' ) then
			local var = table.remove( arguments, 1 )

			resultVar = var

		elseif( arg == 'NO_POLICY_SCOPE' ) then
			-- TODO: CMake Policies
		end
	end

	if( os.isfile( file ) ) then
		m.parseScript( file )

		if( resultVar ) then
			m.cache_entries[ resultVar ] = file
		end
	else
		-- TODO: May be module, try to find <modulename>.cmake

		if( required ) then
			p.error( 'Failed to find the file "%s" for command "include"', file )
		end
	end
end
