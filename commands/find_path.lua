local p           = premake
local m           = p.extensions.impcmake
local keywordDirs = {
	INCLUDE = 'include',
	LIBRARY = 'lib',
	PROGRAM = 'bin',
}

-- @cmd is the command table.
-- @keyword is one of 'INCLUDE', 'LIBRARY' or 'PROGRAM'.
-- @extension(optional) is added at the end of the searched file paths.
local function findPath( cmd, keyword, extension )
	extension = extension or ''

	local possibleOptions    = { 'HINTS', 'PATHS', 'PATH_SUFFIXES', 'DOC', 'REQUIRED',
	                            'NO_DEFAULT_PATH', 'NO_PACKAGE_ROOT_PATH', 'NO_CMAKE_PATH',
	                            'NO_CMAKE_ENVIRONMENT_PATH', 'NO_SYSTEM_ENVIRONMENT_PATH',
	                            'NO_CMAKE_SYSTEM_PATH', 'CMAKE_FIND_ROOT_PATH_BOTH',
	                            'ONLY_CMAKE_FIND_ROOT_PATH', 'NO_CMAKE_FIND_ROOT_PATH' }
	local arguments          = table.arraycopy( cmd.arguments )
	local var                = table.remove( arguments, 1 )
	local names              = { }
	local hints              = { }
	local paths              = { }
	local subDirs            = { }
	local docString          = ''
	local isRequired         = false
	local searchPackageRoot  = m.isTrue( m.expandVariable( 'CMAKE_FIND_USE_PACKAGE_ROOT_PATH', iif( m.currentPackage ~= nil, m.TRUE, m.FALSE ) ) )
	local searchCMakePath    = m.isTrue( m.expandVariable( 'CMAKE_FIND_USE_CMAKE_PATH', m.TRUE ) )
	local searchCMakeEnvPath = m.isTrue( m.expandVariable( 'CMAKE_FIND_USE_CMAKE_ENVIRONMENT_PATH', m.TRUE ) )
	local searchSysEnvPath   = m.isTrue( m.expandVariable( 'CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH', m.TRUE ) )
	local searchCMakeSysPath = m.isTrue( m.expandVariable( 'CMAKE_FIND_USE_CMAKE_SYSTEM_PATH', m.TRUE ) )
	local useFindRootPathVar = true
	local searchOnlyRoots    = false

	-- Names
	if( arguments[ 1 ] == 'NAMES' ) then
		table.remove( arguments, 1 )
		while( not table.contains( possibleOptions, arguments[ 1 ] ) ) do
			table.insert( names, table.remove( arguments, 1 ) .. extension )
		end
	else
		table.insert( names, table.remove( arguments, 1 ) .. extension )
	end

	-- Parse options
	while( #arguments > 0 ) do
		local option = table.remove( arguments, 1 )

		if( option == 'HINTS' ) then
			-- Directories to search in
			while( #arguments > 0 and not table.contains( possibleOptions, arguments[ 1 ] ) ) do
				local arg = table.remove( arguments, 1 )

				if( arg == 'ENV' ) then
					local env = table.remove( arguments, 1 )

					table.insert( hints, os.getenv( env ) )
				else
					table.insert( hints, arg )
				end
			end

		elseif( option == 'PATHS' ) then
			-- Directories to search in (prioritized last)
			while( #arguments > 0 and not table.contains( possibleOptions, arguments[ 1 ] ) ) do
				local arg = table.remove( arguments, 1 )

				if( arg == 'ENV' ) then
					local env = table.remove( arguments, 1 )

					table.insert( paths, os.getenv( env ) )
				else
					table.insert( paths, arg )
				end
			end

		elseif( option == 'PATH_SUFFIXES' ) then
			-- Subdirectories to search in
			while( #arguments > 0 and not table.contains( possibleOptions, arguments[ 1 ] ) ) do
				local arg = table.remove( arguments, 1 )

				table.insert( subDirs, arg )
			end

		elseif( option == 'DOC' ) then
			-- Documentation string
			local arg = table.remove( arguments, 1 )

			docString = arg

		elseif( option == 'REQUIRED' ) then
			-- Abort if nothing is found
			local arg = table.remove( arguments, 1 )

			isRequired = m.isTrue( arg )

		elseif( option == 'NO_DEFAULT_PATH' ) then
			searchPackageRoot  = false
			searchCMakePath    = false
			searchCMakeEnvPath = false
			searchSysEnvPath   = false
			searchCMakeSysPath = false

		elseif( option == 'NO_PACKAGE_ROOT_PATH' ) then
			searchPackageRoot = false

		elseif( option == 'NO_CMAKE_PATH' ) then
			searchCMakePath = false

		elseif( option == 'NO_CMAKE_ENVIRONMENT_PATH' ) then
			searchCMakeEnvPath = false

		elseif( option == 'NO_SYSTEM_ENVIRONMENT_PATH' ) then
			searchSysEnvPath = false

		elseif( option == 'NO_CMAKE_SYSTEM_PATH' ) then
			searchCMakeSysPath = false

		elseif( option == 'CMAKE_FIND_ROOT_PATH_BOTH' ) then
			-- Don't need to change any settings

		elseif( option == 'ONLY_CMAKE_FIND_ROOT_PATH' ) then
			searchOnlyRoots = true

		elseif( option == 'NO_CMAKE_FIND_ROOT_PATH' ) then
			useFindRootPathVar = false
		end
	end

	-- Apply options

	if( searchPackageRoot ) then
		local packageRoot = p.api.scope.workspace.cmakecache[ m.currentPackage .. '_ROOT' ]

		if( packageRoot ) then
			for _,name in ipairs( names ) do
				local filePath = path.join( packageRoot, name )

				if( os.isfile( filePath ) ) then
					cmakecache {
						[ var ] = packageRoot,
					}

					return packageRoot
				end
			end
		end
	end

	if( searchCMakePath ) then
		local libraryArchitecture = m.expandVariable( 'CMAKE_LIBRARY_ARCHITECTURE' )
		local prefixPath          = m.expandVariable( 'CMAKE_PREFIX_PATH' )
		local prefixes            = string.explode( prefixPath, ';' )

		for _,prefix in ipairs( prefixes ) do
			prefix = m.toRawString( prefix )

			local dir = path.join( prefix, keywordDirs[ keyword ] )

			for _,name in ipairs( names ) do
				if( libraryArchitecture ~= m.NOTFOUND ) then
					local archDir  = path.join( dir, libraryArchitecture )
					local filePath = path.join( archDir, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = archDir,
						}

						return archDir
					end
				end

				local filePath = path.join( dir, name )

				if( os.isfile( filePath ) ) then
					cmakecache {
						[ var ] = dir,
					}

					return dir
				end
			end
		end

		local keyPath = m.expandVariable( 'CMAKE_' .. keyword .. '_PATH' )

		if( keyPath ~= m.NOTFOUND ) then
			local paths = string.explode( keyPath, ';' )

			for _,pathh in ipairs( paths ) do
				pathh = m.toRawString( pathh )

				for _,name in ipairs( names ) do
					local filePath = path.join( pathh, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = pathh,
						}

						return pathh
					end
				end
			end
		end

		local frameworkPath = m.expandVariable( 'CMAKE_FRAMEWORK_PATH' )

		if( frameworkPath ~= m.NOTFOUND ) then
			local paths = string.explode( frameworkPath, ';' )

			for _,pathh in ipairs( paths ) do
				pathh = m.toRawString( pathh )

				for _,name in ipairs( names ) do
					local filePath = path.join( pathh, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = pathh,
						}

						return pathh
					end
				end
			end
		end
	end

	if( searchCMakeEnvPath ) then
		local separator           = iif( os.ishost( 'windows' ), ';', ':' )
		local libraryArchitecture = os.getenv( 'CMAKE_LIBRARY_ARCHITECTURE' )
		local prefixPath          = os.getenv( 'CMAKE_PREFIX_PATH' )
		local prefixes            = prefixPath and string.explode( prefixPath, separator ) or { }

		for _,prefix in ipairs( prefixes ) do
			prefix = m.toRawString( prefix )

			local dir = path.join( prefix, keywordDirs[ keyword ] )

			for _,name in ipairs( names ) do
				if( libraryArchitecture ) then
					local archDir  = path.join( dir, libraryArchitecture )
					local filePath = path.join( archDir, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = archDir,
						}

						return archDir
					end
				end

				local filePath = path.join( dir, name )

				if( os.isfile( filePath ) ) then
					cmakecache {
						[ var ] = dir,
					}

					return dir
				end
			end
		end

		local includePath = os.getenv( 'CMAKE_INCLUDE_PATH' )

		if( includePath ) then
			local paths = string.explode( includePath, separator )

			for _,pathh in ipairs( paths ) do
				pathh = m.toRawString( pathh )

				for _,name in ipairs( names ) do
					local filePath = path.join( pathh, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = pathh,
						}

						return pathh
					end
				end
			end
		end

		local frameworkPath = os.getenv( 'CMAKE_FRAMEWORK_PATH' )

		if( frameworkPath ) then
			local paths = string.explode( frameworkPath, separator )

			for _,pathh in ipairs( paths ) do
				pathh = m.toRawString( pathh )

				for _,name in ipairs( names ) do
					local filePath = path.join( pathh, name )

					if( os.isfile( filePath ) ) then
						cmakecache {
							[ var ] = pathh,
						}

						return pathh
					end
				end
			end
		end
	end

	for _,hint in ipairs( hints ) do
		hint = m.toRawString( hint )

		for _,name in ipairs( names ) do
			local filePath = path.join( hint, name )

			if( os.isfile( filePath ) ) then
				cmakecache {
					[ var ] = hint,
				}

				return hint
			end
		end
	end

	-- TODO: 5. Search standard system environment variables
	-- TODO: 6. Search CMake variables in the Platform files

	for _,pathh in ipairs( paths ) do
		pathh = m.toRawString( pathh )

		for _,name in ipairs( names ) do
			local filePath = path.join( pathh, name )

			if( os.isfile( filePath ) ) then
				cmakecache {
					[ var ] = pathh,
				}

				return pathh
			end
		end
	end

	return m.NOTFOUND
end

function m.commands.find_path( cmd )
	-- Find include directories
	findPath( cmd, 'INCLUDE' )
end

function m.commands.find_program( cmd )
	-- Find program directories
	findPath( cmd, 'PROGRAM', iif( os.ishost( 'windows' ), '.exe', nil ) )
end

function m.commands.find_library( cmd )
	-- Find library directories
	findPath( cmd, 'LIBRARY', iif( os.istarget( 'windows' ), '.lib', '.a' ) )
end

function m.commands.find_package( cmd )
	if( os.isfile( m.CMAKE_MODULES_CACHE_AVAILABLE ) ) then
		-- TODO: Full signature
		-- TODO: COMPONENTS and OPTIONAL_COMPONENTS
		local arguments        = table.arraycopy( cmd.arguments )
		local possible_options = { 'EXACT', 'QUIET', 'MODULE', 'REQUIRED', 'NO_POLICY_SCOPE' }
		local packageName      = table.remove( arguments, 1 )
		local version          = ( arguments[ 1 ] and not table.contains( possible_options, arguments[ 1 ] ) ) and table.remove( arguments, 1 ) or '0.0.0'
		local options          = table.intersect( possible_options, arguments )

		if( table.contains( options, 'EXACT' ) ) then
			-- TODO: EXACT
		end
		if( table.contains( options, 'QUIET' ) ) then
			-- TODO: QUET
		end
		if( table.contains( options, 'MODULE' ) ) then
			-- TODO: MODULE
		end
		if( table.contains( options, 'REQUIRED' ) ) then
			-- TODO: REQUIRED
		end
		if( table.contains( options, 'NO_POLICY_SCOPE' ) ) then
			-- TODO: NO_POLICY_SCOPE
		end

		local fileName = string.format( 'Find%s.cmake', packageName )
		local filePath = path.join( m.CMAKE_MODULES_CACHE, fileName )

		if( os.isfile( filePath ) ) then
			local prevPackage = m.currentPackage
			m.currentPackage = packageName

			cmakecache {
				[ packageName .. '_ROOT' ] = path.getdirectory( filePath ),
			}

			-- Load module script
			m.parseScript( filePath )

			m.currentPackage = prevPackage
		end

	else
		p.error( 'CMake module cache is not available for command "%s"', cmd.name )
	end
end
