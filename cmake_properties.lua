local p      = premake
local m      = p.extensions.impcmake
m.properties = { }

local targetPropertyHelpers = {
	IMPORTED_LOCATION = function( prj, value )
		prj._cmake.publiclibs = prj._cmake.publiclibs or { }
		table.insert( prj._cmake.publiclibs, value )
	end,

	INTERFACE_INCLUDE_DIRECTORIES = function( prj, value )
		prj._cmake.publicsysincludedirs = prj._cmake.publicsysincludedirs or { }
		table.insert( prj._cmake.publicsysincludedirs, value )
	end,
}

function m.properties.setTargetProperty( target, prop, value )
	local wks         = p.api.scope.workspace
	local projectName = m.aliases[ target ] or target
	local prj         = p.workspace.findproject( wks, projectName )

	if( not prj ) then
		p.error( 'Failed to set target property %s on project %s. No project found by that name.', prop, projectName )
	end

	local helper = targetPropertyHelpers[ prop ]
	if( not helper ) then
		p.error( 'Unsupported target property: %s', prop )
	end

	local prevProject   = p.api.scope.project
	p.api.scope.project = prj

	helper( prj, value )
	
	p.api.scope.project = prevProject
end
