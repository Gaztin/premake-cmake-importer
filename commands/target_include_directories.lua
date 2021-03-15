local p = premake
local m = p.extensions.impcmake

function m.commands.target_include_directories( cmd )
	local arguments      = table.arraycopy( cmd.arguments )
	local projectName    = m.resolveAlias( table.remove( arguments, 1 ) )
	local currentProject = p.api.scope.project
	local projectToAmend = p.workspace.findproject( p.api.scope.workspace, projectName )
	local modifiers      = { }

	-- Make sure project exists
	if( projectToAmend == nil ) then
		p.error( 'Project "%s" referenced in "%s" not found in workspace', addToProject, cmd.name )
	end

	-- Temporarily activate amended project
	p.api.scope.project = projectToAmend

	-- Add source files
	for _,arg in ipairs( arguments ) do
		if( table.contains( { 'SYSTEM', 'BEFORE', 'INTERFACE', 'PUBLIC', 'PRIVATE' }, arg ) ) then
			modifiers[ arg ] = true
		else
			local includeFunc = iif( modifiers[ 'SYSTEM' ] == true, sysincludedirs, includedirs )

			if( modifiers[ 'BEFORE'    ] == true ) then p.warn( 'Unhandled modifier "BEFORE" was specified for "target_include_directories"'    ) end
			if( modifiers[ 'INTERFACE' ] == true ) then p.warn( 'Unhandled modifier "INTERFACE" was specified for "target_include_directories"' ) end

			arg = m.expandVariables( arg )

			for _,v in ipairs( string.explode( arg, ' ' ) ) do
				local rebasedIncludeDir = path.rebase( v, baseDir, os.getcwd() )

				includeFunc { rebasedIncludeDir }

				if( modifiers[ 'PUBLIC' ] == true ) then
					if( modifiers[ 'SYSTEM' ] == true ) then
						projectToAmend._cmake.publicsysincludedirs = projectToAmend._cmake.publicsysincludedirs or { }
						table.insert( projectToAmend._cmake.publicsysincludedirs, rebasedIncludeDir )
					else
						projectToAmend._cmake.publicincludedirs = projectToAmend._cmake.publicincludedirs or { }
						table.insert( projectToAmend._cmake.publicincludedirs, rebasedIncludeDir )
					end
				end
			end

			-- Reset modifiers
			modifiers = { }
		end

	end

	-- Restore scope
	p.api.scope.project = currentProject
end
