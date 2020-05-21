local p = premake

function cmake_project( relativePath )
	local projectName = path.getbasename( relativePath )

	project( projectName )
	kind( 'WindowedApp' )
end
