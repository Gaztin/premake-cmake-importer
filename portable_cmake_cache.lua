local p = premake
local m = p.extensions.impcmake

function m.downloadCMakePortable( version )
	local url = string.format( 'https://github.com/Kitware/CMake/releases/download/v%s/cmake-%s-win64-x64.zip', version, version )

	local function progress( total, current )
		local mb = ( 1024.0 * 1024.0 )

		-- Skip redirection pages
		if( total < mb ) then
			current = 0
		end

		local width  = 16
		local n      = math.floor( current * width / total )
		local bar    = string.rep( '=', n ) .. string.rep( ' ', width - n )
		local result = string.format( 'Downloading CMake: [%s] %5.2fMB / %5.2fMB\r', bar, current / mb, total / mb )

		io.write( result )
	end

	http.download( url, 'cmake-portable.zip', { progress = progress } )

	p.outln( '' )
end
