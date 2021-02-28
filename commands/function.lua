local p = premake
local m = p.extensions.impcmake

m.commands[ 'function' ] = function( cmd )
	local functionName = cmd.arguments[ 1 ]

	m.commands[ functionName ] = function( cmd )
		local scope = m.scope.push()
		scope.variables[ 'CMAKE_CURRENT_FUNCTION' ]           = name
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_DIR' ]  = scope.parent.variables[ 'CMAKE_CURRENT_LIST_DIR' ]
		scope.variables[ 'CMAKE_CURRENT_FUNCTION_LIST_FILE' ] = scope.parent.variables[ 'CMAKE_CURRENT_LIST_FILE' ]
		
		m.functions.invoke( cmd )
	end

	m.functions.startRecording( functionName )
end
