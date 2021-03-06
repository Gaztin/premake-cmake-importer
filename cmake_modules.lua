local p               = premake
local m               = p.extensions.impcmake
local cacheDir        = '.modulecache'
local cacheMarkerPath = path.join( cacheDir, '.marker' )
m.modules             = { }

function m.modules.getCacheDir()
	return cacheDir
end

function m.modules.getCacheMarkerPath()
	return cacheMarkerPath
end

function m.modules.download( version )
	local url = string.format( 'https://gitlab.kitware.com/cmake/cmake/-/archive/v%s/cmake-v%s.zip?path=Modules', version, version )

	local function progress( total, current )
		local kb     = 1024.0
		local width  = 16
		local n      = math.floor( current * width / total )
		local bar    = string.rep( '=', n ) .. string.rep( ' ', width - n )
		local result = string.format( 'CMake Modules (Downloading): [%s] %7.2fKB / %7.2fKB\r', bar, current / kb, total / kb )

		io.write( result )
	end

	local zipSrc           = 'modulecache.zip'
	local result, response = http.download( url, zipSrc, { progress = progress } )

	if( response == 200 ) then
		io.write( 'CMake Modules (Extracting)  \r' )

		if( zip.extract( zipSrc, cacheDir ) == 0 ) then
			io.write( 'CMake Modules (Tidying)     \r' )

			local modules_dir = path.join( cacheDir, 'cmake-v' .. version .. '-Modules/Modules' )
			local pattern     = modules_dir .. '/**'
			local matches     = os.matchfiles( pattern )

			for i, match in ipairs( matches ) do
				local subdir = path.getrelative( modules_dir, path.getdirectory( match ) )
				local dst    = path.join( cacheDir, subdir, path.getname( match ) )

				os.mkdir( path.getdirectory( dst ) )
				os.rename( match, dst )
			end

			io.write( 'CMake Modules (Done)        \n' )

			local cacheMarkerFile = io.open( cacheMarkerPath, 'w+b' )
			cacheMarkerFile:close()

		else
			term.pushColor( term.red )
			io.write( 'CMake Modules (Failed)      \n' )
			term.popColor()
		end

		os.remove( zipSrc )

	else
		p.error( result )
	end
end
