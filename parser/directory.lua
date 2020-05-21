local p            = premake
local m            = p.extensions.impcmake
m.parser           = m.parser or { }
m.parser.directory = { }
local directory    = m.parser.directory

function directory.parse( relativePath )
	local projectName = path.getbasename( relativePath )
	local prj         = project( projectName )

	kind( 'WindowedApp' )

	return prj
end
