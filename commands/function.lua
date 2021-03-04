local p = premake
local m = p.extensions.impcmake

local function endfunction( commands, data )
	m.commands[ data.name ] = function( cmd )
		local scope = m.scope.push()

		scope.variables[ 'CMAKE_CURRENT_FUNCTION' ]           = cmd.name
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_DIR' ]  = scope.parent.variables[ 'CMAKE_CURRENT_LIST_DIR' ]
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_FILE' ] = scope.parent.variables[ 'CMAKE_CURRENT_LIST_FILE' ]

		for i,command in ipairs( commands ) do
			m.executeCommand( command )
		end

		m.scope.pop()
	end
end

m.commands[ 'function' ] = function( cmd )
	local data = {
		name = cmd.arguments[ 1 ],
	}

	m.groups.push( 'function', 'endfunction', endfunction, data )
end
