local p            = premake
local m            = p.extensions.impcmake
m.parser           = m.parser or { }
m.parser.directory = { }
local directory    = m.parser.directory

function directory.parse( filePath )
	local projectName = path.getbasename( filePath )

	-- Allow @filePath to just be the directory name.
	-- Append 'CMakeLists.txt' in that case.
	if( path.getname( filePath ) ~= 'CMakeLists.txt' ) then
		filePath = path.normalize( filePath .. '/CMakeLists.txt' )
	end

	local file = io.open( filePath, "r" )

	if( file == nil ) then
		p.error( 'Failed to open "%s"', filePath )
		return nil
	end

	local prj = project( projectName )

	kind( 'WindowedApp' )

	io.close( file )

	return prj
end
