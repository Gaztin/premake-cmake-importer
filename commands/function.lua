local p = premake
local m = p.extensions.impcmake

local function endfunction( commands, data )
	m.commands[ data.name:lower() ] = function( cmd )
		local scope = m.scope.push()

		-- Make sure number of arguments are equal or more than the number of parameters
		if( #cmd.arguments < #data.parameters ) then
			p.error( 'Function "%s" was called with too few arguments. Expected %d but received %d!', cmd.name, #data.parameters, #cmd.arguments )
		end

		scope.variables[ 'CMAKE_CURRENT_FUNCTION' ]           = cmd.name
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_DIR' ]  = scope.parent.variables[ 'CMAKE_CURRENT_LIST_DIR' ]
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_FILE' ] = scope.parent.variables[ 'CMAKE_CURRENT_LIST_FILE' ]
		scope.variables[ 'ARGC' ]                             = #cmd.arguments
		scope.variables[ 'ARGV' ]                             = table.concat( cmd.arguments, ';' )
		scope.variables[ 'ARGN' ]                             = table.concat( { table.unpack( cmd.arguments, #data.parameters + 1 ) }, ';' )

		for i,param in ipairs( data.parameters ) do
			scope.variables[ param ] = cmd.arguments[ i ]
		end

		for i,arg in ipairs( cmd.arguments ) do
			scope.variables[ 'ARGV' .. ( i - 1 ) ] = arg
		end

		for i,command in ipairs( commands ) do
			m.executeCommand( command )
		end

		m.scope.pop()
	end
end

m.commands[ 'function' ] = function( cmd )
	local data = {
		name       = cmd.arguments[ 1 ],
		parameters = { table.unpack( cmd.arguments, 2 ) }
	}

	m.groups.push( 'function', 'endfunction', endfunction, data )
end
