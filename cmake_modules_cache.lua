local p = premake
local m = p.extensions.impcmake

m.CMAKE_MODULES_CACHE           = '.cmake-modules-cache'
m.CMAKE_MODULES_CACHE_AVAILABLE = path.join( m.CMAKE_MODULES_CACHE, '.ready' )

function m.downloadCMakeModules( version )
	local url = string.format( 'https://gitlab.kitware.com/cmake/cmake/-/archive/v%s/cmake-v%s.zip?path=Modules', version, version )

	local function progress( total, current )
		local kb     = 1024.0
		local width  = 16
		local n      = math.floor( current * width / total )
		local bar    = string.rep( '=', n ) .. string.rep( ' ', width - n )
		local result = string.format( 'CMake Modules (Downloading): [%s] %7.2fKB / %7.2fKB\r', bar, current / kb, total / kb )

		io.write( result )
	end

	local src_zip = 'cmake-modules.zip'
	local dst_dir = m.CMAKE_MODULES_CACHE

	if( not os.isfile( m.CMAKE_MODULES_CACHE_AVAILABLE ) ) then
		local result, response = http.download( url, src_zip, { progress = progress } )

		if( response == 200 ) then
			io.write( 'CMake Modules (Extracting)  \r' )

			if( zip.extract( src_zip, dst_dir ) == 0 ) then
				io.write( 'CMake Modules (Tidying)     \r' )

				local modules_dir = path.join( dst_dir, 'cmake-v' .. version .. '-Modules/Modules' )
				local pattern     = modules_dir .. '/**'
				local matches     = os.matchfiles( pattern )

				for i, match in ipairs( matches ) do
					local subdir = path.getrelative( modules_dir, path.getdirectory( match ) )
					local dst    = path.join( dst_dir, subdir, path.getname( match ) )

					os.mkdir( path.getdirectory( dst ) )
					os.rename( match, dst )
				end

				io.write( 'CMake Modules (Done)        \n' )

				local done_file = io.open( m.CMAKE_MODULES_CACHE_AVAILABLE, 'w+b' )
				done_file:close()
			else
				term.pushColor( term.red )
				io.write( 'CMake Modules (Failed)      \n' )
				term.popColor()
			end

			os.remove( src_zip )

		else
			p.error( result )
		end
	end
end
