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
		local packageRoot = m.cache_entries[ m.currentPackage .. '_ROOT' ]

		if( packageRoot ) then
			for _,name in ipairs( names ) do
				local filePath = path.join( packageRoot, name )

				if( os.isfile( filePath ) ) then
					m.cache_entries[ var ] = packageRoot

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
						m.cache_entries[ var ] = archDir

						return archDir
					end
				end

				local filePath = path.join( dir, name )

				if( os.isfile( filePath ) ) then
					m.cache_entries[ var ] = dir

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
						m.cache_entries[ var ] = pathh

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
						m.cache_entries[ var ] = pathh

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
						m.cache_entries[ var ] = archDir

						return archDir
					end
				end

				local filePath = path.join( dir, name )

				if( os.isfile( filePath ) ) then
					m.cache_entries[ var ] = dir

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
						m.cache_entries[ var ] = pathh

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
						m.cache_entries[ var ] = pathh

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
				m.cache_entries[ var ] = hint

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
				m.cache_entries[ var ] = pathh

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
		local arguments              = table.arraycopy( cmd.arguments )
		local packageName            = table.remove( arguments, 1 )
		local possible_basic_options = { 'EXACT', 'QUIET', 'MODULE', 'REQUIRED', 'COMPONENTS', 'OPTIONAL_COMPONENTS', 'NO_POLICY_SCOPE' }
		local possible_extra_options = { 'CONFIG', 'NO_MODULE', 'NAMES', 'CONFIGS', 'HINTS', 'PATHS',
		                                 'PATH_SUFFIXES', 'NO_DEFAULT_PATH', 'NO_PACKAGE_ROOT_PATH',
		                                 'NO_CMAKE_PATH', 'NO_CMAKE_ENVIRONMENT_PATH',
		                                 'NO_SYSTEM_ENVIRONMENT_PATH', 'NO_CMAKE_PACKAGE_REGISTRY',
		                                 'NO_CMAKE_BUILDS_PATH', 'NO_CMAKE_SYSTEM_PATH',
		                                 'NO_CMAKE_SYSTEM_PACKAGE_REGISTRY', 'CMAKE_FIND_ROOT_PATH_BOTH',
		                                 'ONLY_CMAKE_FIND_ROOT_PATH', 'NO_CMAKE_FIND_ROOT_PATH' }
		local possible_full_options  = table.join( possible_basic_options, possible_extra_options )
		local version                = ( arguments[ 1 ] and not table.contains( possible_full_options, arguments[ 1 ] ) ) and table.remove( arguments, 1 )
		local basic_options          = table.intersect( possible_basic_options, arguments )
		local exact                  = false
		local quiet                  = false
		local required               = false
		local requiredComponents     = { }
		local optionalComponents     = { }

		while( #arguments > 0 ) do
			local arg = table.remove( arguments, 1 )

			if( table.contains( possible_extra_options, arg ) ) then
				configMode = true
			end

			if( arg == 'EXACT' ) then
				exact = true

			elseif( arg == 'QUIET' ) then
				quiet = true

			elseif( arg == 'MODULE' ) then
				-- TODO: MODULE

			elseif( arg == 'REQUIRED' or arg == 'COMPONENTS' ) then
				required = true
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
					table.insert( requiredComponents, arg )
				end

			elseif( arg == 'OPTIONAL_COMPONENTS' ) then
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
					table.insert( optionalComponents, arg )
				end

			elseif( arg == 'NO_POLICY_SCOPE' ) then
				-- TODO: NO_POLICY_SCOPE

			elseif( arg == 'CONFIG' ) then
				-- TODO: CONFIG

			elseif( arg == 'NO_MODULE' ) then
				-- TODO: NO_MODULE

			elseif( arg == 'NAMES' ) then
				-- TODO: NAMES
				arg = table.remove( arguments, 1 )
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
				end

			elseif( arg == 'CONFIGS' ) then
				-- TODO: CONFIGS
				arg = table.remove( arguments, 1 )
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
				end

			elseif( arg == 'HINTS' ) then
				-- TODO: HINTS
				arg = table.remove( arguments, 1 )
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
				end

			elseif( arg == 'PATHS' ) then
				-- TODO: PATHS
				arg = table.remove( arguments, 1 )
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
				end

			elseif( arg == 'PATH_SUFFIXES' ) then
				-- TODO: PATH_SUFFIXES
				arg = table.remove( arguments, 1 )
				while( #arguments > 0 and not table.contains( possible_full_options, arg ) ) do
					arg = table.remove( arguments, 1 )
				end

			elseif( arg == 'NO_DEFAULT_PATH' ) then
				-- TODO: NO_DEFAULT_PATH

			elseif( arg == 'NO_PACKAGE_ROOT_PATH' ) then
				-- TODO: NO_PACKAGE_ROOT_PATH

			elseif( arg == 'NO_CMAKE_PATH' ) then
				-- TODO: NO_CMAKE_PATH

			elseif( arg == 'NO_CMAKE_ENVIRONMENT_PATH' ) then
				-- TODO: NO_CMAKE_ENVIRONMENT_PATH

			elseif( arg == 'NO_SYSTEM_ENVIRONMENT_PATH' ) then
				-- TODO: NO_SYSTEM_ENVIRONMENT_PATH

			elseif( arg == 'NO_CMAKE_PACKAGE_REGISTRY' ) then
				-- TODO: NO_CMAKE_PACKAGE_REGISTRY

			elseif( arg == 'NO_CMAKE_BUILDS_PATH' ) then
				-- TODO: NO_CMAKE_BUILDS_PATH

			elseif( arg == 'NO_CMAKE_SYSTEM_PATH' ) then
				-- TODO: NO_CMAKE_SYSTEM_PATH

			elseif( arg == 'NO_CMAKE_SYSTEM_PACKAGE_REGISTRY' ) then
				-- TODO: NO_CMAKE_SYSTEM_PACKAGE_REGISTRY

			elseif( arg == 'CMAKE_FIND_ROOT_PATH_BOTH' or arg == 'ONLY_CMAKE_FIND_ROOT_PATH' or arg == 'NO_CMAKE_FIND_ROOT_PATH' ) then
				-- TODO: CMAKE_FIND_ROOT_PATH_BOTH | ONLY_CMAKE_FIND_ROOT_PATH | NO_CMAKE_FIND_ROOT_PATH

			end
		end

		if( not configMode ) then
			local fileName = string.format( 'Find%s.cmake', packageName )
			local filePath = path.join( m.CMAKE_MODULES_CACHE, fileName )

			if( os.isfile( filePath ) ) then
				local prevPackage = m.currentPackage
				m.currentPackage = packageName

				local fileDir = path.getdirectory( filePath )
				m.cache_entries[ packageName .. '_ROOT' ] = fileDir
				m.cache_entries[ packageName .. '_DIR'  ] = fileDir

				local verCount   = 0
				local verNumbers = { }
				for it in string.gmatch( version, '%d+' ) do
					verCount               = verCount + 1
					verNumbers[ verCount ] = it
				end

				-- Set up scope
				local scope = m.scope.push()
				scope.variables[ 'CMAKE_FIND_PACKAGE_NAME'            ] = packageName
				scope.variables[ packageName .. '_FIND_REQUIRED'      ] = required and m.TRUE or m.FALSE
				scope.variables[ packageName .. '_FIND_QUIETLY'       ] = quiet and m.TRUE or m.FALSE
				scope.variables[ packageName .. '_FIND_VERSION'       ] = verison or m.NOTFOUND
				scope.variables[ packageName .. '_FIND_VERSION_MAJOR' ] = verNumbers[ 1 ] or m.NOTFOUND
				scope.variables[ packageName .. '_FIND_VERSION_MINOR' ] = verNumbers[ 2 ] or m.NOTFOUND
				scope.variables[ packageName .. '_FIND_VERSION_PATCH' ] = verNumbers[ 3 ] or m.NOTFOUND
				scope.variables[ packageName .. '_FIND_VERSION_TWEAK' ] = verNumbers[ 4 ] or m.NOTFOUND
				scope.variables[ packageName .. '_FIND_VERSION_COUNT' ] = verCount
				scope.variables[ packageName .. '_FIND_VERSION_EXACT' ] = exact and m.TRUE or m.FALSE
				scope.variables[ packageName .. '_FIND_COMPONENTS'    ] = table.implode( table.join( requiredComponents, optionalComponents ), '"', '"', ' ' )

				for i,requiredComponent in ipairs( requiredComponents ) do
					scope.variables[ packageName .. '_FIND_REQUIRED_' .. requiredComponent ] = m.TRUE
				end
				for i,optionalComponent in ipairs( optionalComponents ) do
					scope.variables[ packageName .. '_FIND_REQUIRED_' .. optionalComponent ] = m.FALSE
				end

				-- Load module script
				m.parseScript( filePath )
				m.scope.pop()

				m.currentPackage = prevPackage
			end
		end
	else
		p.error( 'CMake module cache is not available for command "%s"', cmd.name )
	end
end
