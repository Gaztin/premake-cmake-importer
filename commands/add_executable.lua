local p = premake
local m = p.extensions.impcmake

function m.commands.add_executable( cmd )
	local arguments = cmd.arguments

	if( arguments[ 2 ] == 'IMPORTED' ) then

		p.error( 'Executable is an IMPORTED target, which is unsupported' )

	elseif( arguments[ 2 ] == 'ALIAS' ) then

		-- Add alias
		m.aliases[ arguments[ 1 ] ] = arguments[ 3 ]

	else
		local wks = p.api.scope.workspace
		if( p.workspace.findproject( wks, arguments[ 1 ] ) ) then
			p.error( 'add_executable failed. A project by the name "%s" already exists in the current workspace.', arguments[ 1 ] )
		end

		local scope = m.scope.current()
		local prj   = project( arguments[ 1 ] )
		prj._cmake  = { }

		kind( 'ConsoleApp' )
		location( scope.variables.PROJECT_SOURCE_DIR )

		for i=2,#arguments do
			if( arguments[ i ] == 'WIN32' ) then
				kind( 'WindowedApp' )
			elseif( arguments[ i ] == 'MACOSX_BUNDLE' ) then
				-- TODO: https://cmake.org/cmake/help/v3.0/prop_tgt/MACOSX_BUNDLE.html
			else
				local f = m.expandVariables( arguments[ i ] )
				for _,v in ipairs( string.explode( f, ' ' ) ) do
					local rebasedSourceFile = path.rebase( v, scope.variables.PROJECT_SOURCE_DIR, os.getcwd() )

					files { rebasedSourceFile }
				end
			end
		end
	end
end
