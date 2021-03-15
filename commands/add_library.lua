local p = premake
local m = p.extensions.impcmake

function m.commands.add_library( cmd )
	local arguments = table.arraycopy( cmd.arguments )

	if( table.contains( { 'STATIC', 'SHARED', 'MODULE' }, arguments[ 2 ] ) ) then
		-- Unused or unsupported modifiers
		if( arguments[ 3 ] == 'EXCLUDE_FROM_ALL' ) then
			table.remove( arguments, 3 )
		elseif( arguments[ 3 ] == 'IMPORTED' ) then
			p.error( 'Library uses unsupported modifier "%s"', arguments[ 3 ] )
		end
		
		local wks = p.api.scope.workspace
		if( p.workspace.findproject( wks, arguments[ 1 ] ) ) then
			p.error( 'add_library failed. A project by the name "%s" already exists in the current workspace.', arguments[ 1 ] )
		end

		local scope = m.scope.current()
		local prj   = project( arguments[ 1 ] )
		prj._cmake  = { }

		location( scope.variables.PROJECT_SOURCE_DIR )

		-- Library type
		if( arguments[ 2 ] == 'STATIC' ) then
			kind( 'StaticLib' )
		elseif( arguments[ 2 ] == 'SHARED' ) then
			kind( 'SharedLib' )
		elseif( arguments[ 2 ] == 'MODULE' ) then
			p.error( 'Project uses unsupported library type "%s"', arguments[ 2 ] )
		end

		for i=3,#arguments do
			local f = m.expandVariables( arguments[ i ] )

			for _,v in ipairs( string.explode( f, ' ' ) ) do
				local rebasedSourceFile = path.rebase( v, scope.variables.PROJECT_SOURCE_DIR, os.getcwd() )

				files { rebasedSourceFile }
			end
		end

	elseif( arguments[ 2 ] == 'OBJECT' ) then

		p.error( 'Library is an object library, which is unsupported' )

	elseif( arguments[ 2 ] == 'ALIAS' ) then

		-- Add alias
		m.aliases[ arguments[ 1 ] ] = arguments[ 3 ]

	elseif( arguments[ 2 ] == 'INTERFACE' ) then

		p.error( 'Library is an interface library, which is unsupported' )

	end
end
