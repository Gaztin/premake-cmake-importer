local p = premake
local m = p.extensions.impcmake

function m.parseDirectory( filePath )
	-- Append 'CMakeLists.txt' if @filePath is just a directory
	if( os.isdir( filePath ) ) then
		filePath = path.join( filePath, 'CMakeLists.txt' )
	end

	m.parseScript( filePath )
end
