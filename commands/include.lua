local p = premake
local m = p.extensions.impcmake

function m.commands.include( cmd )
	local arguments = table.arraycopy( cmd.arguments )
	local file      = table.remove( arguments, 1 )
	local required  = true
	local resultVar = nil

	while( #arguments > 0 ) do
		local arg = table.remove( arguments, 1 )

		if( arg == 'OPTIONAL' ) then
			required = false

		elseif( arg == 'RESULT_VARIABLE' ) then
			resultVar = table.remove( arguments, 1 )

		elseif( arg == 'NO_POLICY_SCOPE' ) then
			p.warn( 'include: Ignoring NO_POLICY_SCOPE' )
		end
	end

	local cmakeModulePath = m.dereference( 'CMAKE_MODULE_PATH' )
	local filePaths       = {
		file,
		table.unpack( string.explode( cmakeModulePath or '', ';' ) ),
		path.join( m.modules.getCacheDir(), file ) .. '.cmake',
	}

	-- If we are in the module directory, search there before in designated directory
	local currentListDir      = m.dereference( 'CMAKE_CURRENT_LIST_DIR' ) or os.getcwd()
	local potentialMarkerPath = path.join( currentListDir, m.modules.getCacheMarkerPath() )
	if( os.isfile( potentialMarkerPath ) ) then
		local modulePath = table.remove( filePaths, #filePaths )
		table.insert( filePaths, 2, modulePath )
	end

	local scope = m.scope.current()
	for i,filePath in ipairs( filePaths ) do
		if( filePath ~= m.NOTFOUND and os.isfile( filePath ) ) then
			m.loadScript( filePath )
			
			if( resultVar ) then
				scope.variables[ resultVar ] = path.getabsolute( filePath )
			end

			return
		end
	end

	if( required ) then
		p.error( 'include: Failed to find file/module "%s"!', file )
	elseif( resultVar ) then
		scope.variables[ resultVar ] = m.NOTFOUND
	end
end
