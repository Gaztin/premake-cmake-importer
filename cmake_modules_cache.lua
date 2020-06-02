local p = premake
local m = p.extensions.impcmake

function m.downloadCMakeModules( version )
	local url = string.format( 'https://gitlab.kitware.com/cmake/cmake/-/archive/v%s/cmake-v%s.zip?path=Modules', version, version )

	local function progress( total, current )
		local kb     = 1024.0
		local width  = 16
		local n      = math.floor( current * width / total )
		local bar    = string.rep( '=', n ) .. string.rep( ' ', width - n )
		local result = string.format( 'Downloading CMake Modules: [%s] %7.2fKB / %7.2fKB\r', bar, current / kb, total / kb )

		io.write( result )
	end

	http.download( url, 'cmake-modules.zip', { progress = progress } )

	p.outln( '' )
end
