local p = premake
local m = p.extensions.impcmake

function m.commands.target_link_libraries( cmd )
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
		if( table.contains( { 'PRIVATE', 'PUBLIC', 'INTERFACE', 'LINK_INTERFACE_LIBRARIES', 'LINK_PRIVATE', 'LINK_PUBLIC' }, arg ) ) then
			modifiers[ arg ] = true
			-- TODO: Do something with this information
		else
			arg = m.expandVariables( arg )

			for _,v in ipairs( string.explode( arg, ' ' ) ) do
				local targetName = m.resolveAlias( v )
				local prj        = p.workspace.findproject( p.api.scope.workspace, targetName )

				-- Add includedirs marked PUBLIC
				if( prj and prj._cmake ) then
					if( prj._cmake.publicincludedirs ) then
						for _,dir in ipairs( prj._cmake.publicincludedirs ) do
							includedirs { dir }
						end
					end
					if( prj._cmake.publicsysincludedirs ) then
						for _,dir in ipairs( prj._cmake.publicsysincludedirs ) do
							sysincludedirs { dir }
						end
					end
				end

				links { targetName }
			end

			-- Reset modifiers
			modifiers = { }
		end

	end

	-- Restore scope
	p.api.scope.project = currentProject
end
