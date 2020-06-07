local p = premake
local m = p.extensions.impcmake

-- Expression operator type enumerator
m.OP_TYPE          = { }
m.OP_TYPE.CONSTANT = 0x0
m.OP_TYPE.UNARY    = 0x1
m.OP_TYPE.BINARY   = 0x2
m.OP_TYPE.BOOL     = 0x4

function m.parseScript( filePath )
	local file = io.open( filePath, 'r' )

	if( file == nil ) then
		p.error( 'Failed to open "%s"', filePath )
		return
	end

	local line    = file:read( '*l' )
	local content = ''
	while( line ) do
		-- Trim leading whitespace
		line = string.match( line, '^%s*(.*%S)' ) or ''

		local firstChar = string.sub( line, 1, 1 )

		-- Skip empty lines and comments
		if( #line > 0 and firstChar ~= '#' ) then
			content = content .. line .. ' '
		end

		line = file:read( '*l' )
	end

	io.close( file )

	local baseDir = path.getdirectory( filePath )

	m.deserializeProject( content, baseDir )
end

function m.deserializeProject( content, baseDir )
	local commandList           = m.deserializeCommandList( content )
	local currentGroup          = p.api.scope.group
	local aliases               = { }
	local cache_entries         = { }
	local cache_entries_allowed = { }

	local function resolveAlias( name )
		for k,v in pairs( aliases ) do
			if( k == name ) then
				return v
			end
		end
		return name
	end

	-- Add predefined variables

	m.addSystemVariables()

	cmakevariables {
		PROJECT_SOURCE_DIR        = baseDir,
		CMAKE_CONFIGURATION_TYPES = table.implode( p.api.scope.workspace.configurations, '"', '"', ' ' ),
	}

	-- Execute commands in order

	local testScope  = { }
	testScope.parent = nil
	testScope.tests  = { true }

	for _,cmd in ipairs( commandList ) do
		local lastTest = iif( #testScope.tests > 0, testScope.tests[ #testScope.tests ], false )

		-- Skip commands if last test failed
		if( ( not lastTest ) and ( cmd.name ~= 'if' ) and ( cmd.name ~= 'elseif' ) and ( cmd.name ~= 'else' ) and ( cmd.name ~= 'endif' ) ) then
			goto continue
		end

		if( cmd.name == 'cmake_minimum_required' ) then

			-- TODO: Throw if higher than @m._LASTEST_CMAKE_VERSION
			m.downloadCMakeModules( m._LASTEST_CMAKE_VERSION )

		elseif( cmd.name == 'project' ) then
			local groupName = cmd.arguments[ 1 ]

			group( groupName )

		elseif( cmd.name == 'set' ) then
			local arguments    = cmd.arguments
			local variableName = table.remove( arguments, 1 )
			local values       = { }
			local parentScope  = false
			local isCache      = false

			local i = 0
			while( i < #arguments ) do
				i = i + 1

				if( arguments[ i ] == 'PARENT_SCOPE' ) then
					parentScope = true

				elseif( arguments[ i ] == 'CACHE' ) then
					local entrytype = arguments[ i + 1 ]
					local docstring = arguments[ i + 2 ]
					local force     = false
					i = i + 2

					isCache = true

					while( i < #arguments ) do
						i = i + 1

						if( arguments[ i ] == 'FORCE' ) then
							force = true
						else
							p.warn( 'Unhandled cache option "%s" for command "%s"', arguments[ i ], cmd.name )
						end
					end

					if( cache_entries[ variableName ] == nil or force ) then
						cache_entries[ variableName ] = table.implode( values, '', '', ' ' )
					end

				else
					table.insert( values, m.resolveVariables( arguments[ i ] ) )
				end
			end

			if( not isCache ) then
				if( parentScope ) then
					p.warn( 'Unsupported option PARENT_SCOPE was declared for command "%s"', cmd.name )
				end

				cmakevariables {
					[ variableName ] = table.implode( values, '', '', ' ' ),
				}
			end

		elseif( cmd.name == 'add_executable' ) then
			local arguments = cmd.arguments

			if( arguments[ 2 ] == 'IMPORTED' ) then

				p.error( 'Executable is an IMPORTED target, which is unsupported' )

			elseif( arguments[ 2 ] == 'ALIAS' ) then

				-- Add alias
				aliases[ arguments[ 1 ] ] = arguments[ 3 ]

			else
				local prj  = project( arguments[ 1 ] )
				prj._cmake = { }

				kind( 'ConsoleApp' )
				location( baseDir )

				for i=2,#arguments do
					if( arguments[ i ] == 'WIN32' ) then
						kind( 'WindowedApp' )
					elseif( arguments[ i ] == 'MACOSX_BUNDLE' ) then
						-- TODO: https://cmake.org/cmake/help/v3.0/prop_tgt/MACOSX_BUNDLE.html
					else
						local f = m.resolveVariables( arguments[ i ] )

						for _,v in ipairs( string.explode( f, ' ' ) ) do
							local rebasedSourceFile = path.rebase( v, baseDir, os.getcwd() )

							files { rebasedSourceFile }
						end
					end
				end
			end

		elseif( cmd.name == 'add_library' ) then
			local arguments = cmd.arguments

			if( table.contains( { 'STATIC', 'SHARED', 'MODULE' }, arguments[ 2 ] ) ) then

				-- Unused or unsupported modifiers
				if( arguments[ 3 ] == 'EXCLUDE_FROM_ALL' ) then
					table.remove( arguments, 3 )
				elseif( arguments[ 3 ] == 'IMPORTED' ) then
					p.error( 'Library uses unsupported modifier "%s"', arguments[ 3 ] )
				end

				local prj  = project( arguments[ 1 ] )
				prj._cmake = { }

				location( baseDir )

				-- Library type
				if( arguments[ 2 ] == 'STATIC' ) then
					kind( 'StaticLib' )
				elseif( arguments[ 2 ] == 'SHARED' ) then
					kind( 'SharedLib' )
				elseif( arguments[ 2 ] == 'MODULE' ) then
					p.error( 'Project uses unsupported library type "%s"', arguments[ 2 ] )
				end

				for i=3,#arguments do
					local f = m.resolveVariables( arguments[ i ] )

					for _,v in ipairs( string.explode( f, ' ' ) ) do
						local rebasedSourceFile = path.rebase( v, baseDir, os.getcwd() )

						files { rebasedSourceFile }
					end
				end

			elseif( arguments[ 2 ] == 'OBJECT' ) then

				p.error( 'Library is an object library, which is unsupported' )

			elseif( arguments[ 2 ] == 'ALIAS' ) then

				-- Add alias
				aliases[ arguments[ 1 ] ] = arguments[ 3 ]

			elseif( arguments[ 2 ] == 'INTERFACE' ) then

				p.error( 'Library is an interface library, which is unsupported' )

			end

		elseif( cmd.name == 'target_include_directories' ) then
			local arguments      = cmd.arguments
			local projectName    = resolveAlias( table.remove( arguments, 1 ) )
			local currentProject = p.api.scope.project
			local projectToAmend = p.workspace.findproject( p.api.scope.workspace, projectName )
			local modifiers      = { }

			-- Make sure project exists
			if( projectToAmend == nil ) then
				p.error( 'Project "%s" referenced in "%s" not found in workspace', addToProject, cmd.name )
			end

			-- Temporarily activate amended project
			p.api.scope.project = projectToAmend

			-- Add source files
			for _,arg in ipairs( arguments ) do
				if( table.contains( { 'SYSTEM', 'BEFORE', 'INTERFACE', 'PUBLIC', 'PRIVATE' }, arg ) ) then
					modifiers[ arg ] = true
				else
					local includeFunc = iif( modifiers[ 'SYSTEM' ] == true, sysincludedirs, includedirs )

					if( modifiers[ 'BEFORE'    ] == true ) then p.warn( 'Unhandled modifier "BEFORE" was specified for "target_include_directories"'    ) end
					if( modifiers[ 'INTERFACE' ] == true ) then p.warn( 'Unhandled modifier "INTERFACE" was specified for "target_include_directories"' ) end

					arg = m.resolveVariables( arg )

					for _,v in ipairs( string.explode( arg, ' ' ) ) do
						local rebasedIncludeDir = path.rebase( v, baseDir, os.getcwd() )

						includeFunc { rebasedIncludeDir }

						if( modifiers[ 'PUBLIC' ] == true ) then
							if( modifiers[ 'SYSTEM' ] == true ) then
								projectToAmend._cmake.publicsysincludedirs = projectToAmend._cmake.publicsysincludedirs or { }
								table.insert( projectToAmend._cmake.publicsysincludedirs, rebasedIncludeDir )
							else
								projectToAmend._cmake.publicincludedirs = projectToAmend._cmake.publicincludedirs or { }
								table.insert( projectToAmend._cmake.publicincludedirs, rebasedIncludeDir )
							end
						end
					end

					-- Reset modifiers
					modifiers = { }
				end

			end

			-- Restore scope
			p.api.scope.project = currentProject

		elseif( cmd.name == 'target_link_libraries' ) then
			local arguments      = cmd.arguments
			local projectName    = resolveAlias( table.remove( arguments, 1 ) )
			local currentProject = p.api.scope.project
			local projectToAmend = p.workspace.findproject( p.api.scope.workspace, projectName )
			local modifiers      = { }

			-- Make sure project exists
			if( projectToAmend == nil ) then
				p.error( 'Project "%s" referenced in "%s" not found in workspace', addToProject, cmd.name )
			end

			-- Temporarily activate amended project
			p.api.scope.project = projectToAmend

			-- Add source files
			for _,arg in ipairs( arguments ) do
				if( table.contains( { 'PRIVATE', 'PUBLIC', 'INTERFACE', 'LINK_INTERFACE_LIBRARIES', 'LINK_PRIVATE', 'LINK_PUBLIC' }, arg ) ) then
					modifiers[ arg ] = true
				else
					arg = m.resolveVariables( arg )

					for _,v in ipairs( string.explode( arg, ' ' ) ) do
						local targetName = resolveAlias( v )
						local prj        = p.workspace.findproject( p.api.scope.workspace, targetName )

						-- Add includedirs marked PUBLIC
						if( prj and prj._cmake ) then
							if( prj._cmake.publicincludedirs ) then
								for _,dir in ipairs( prj._cmake.publicincludedirs ) do
									includedirs { dir }
								end
							end
							if( prj._cmake.publicsysincludedirs ) then
								for _,dir in ipairs( prj._cmake.publicsysincludedirs ) do
									sysincludedirs { dir }
								end
							end
						end

						links { targetName }
					end

					-- Reset modifiers
					modifiers = { }
				end

			end

			-- Restore scope
			p.api.scope.project = currentProject

		elseif( cmd.name == 'target_compile_definitions' ) then
			local arguments      = cmd.arguments
			-- According to the docs, cannot be an alias target
			local targetName     = table.remove( arguments, 1 )
			local projectToAmend = p.workspace.findproject( p.api.scope.workspace, targetName )
			local allowedScopes  = { 'INTERFACE', 'PUBLIC', 'PRIVATE' }
			local i              = 0

			while( i < #arguments ) do
				i = i + 1

				if( table.contains( allowedScopes, arguments[ i ] ) ) then
					local items = { }

					while( ( i < #arguments ) and ( not table.contains( allowedScopes, arguments[ i + 1 ] ) ) ) do
						i = i + 1

						local item = arguments[ i ]

						-- Remove leading '-D'
						item = string.gsub( item, '-D', '', 1 )

						-- Ignore empty items
						local isEmpty = ( string.len( item ) == 0 ) or
						                ( ( string.sub( item, 1, 1 ) == '"' ) and
						                  ( string.sub( item, 2, 2 ) == '"' ) )

						if( not isEmpty ) then
							table.insert( items, arguments[ i ] )
						end
					end

					defines( items )
				end
			end

		elseif( cmd.name == 'install' ) then

			-- Skip installation rules
			p.warnOnce( p.api.scope.project, string.format( 'Skipping installation rules for project "%s"', p.api.scope.project.name ) )

		elseif( cmd.name == 'message' ) then
			local arguments    = cmd.arguments
			local allowedModes = { 'FATAL_ERROR', 'SEND_ERROR', 'WARNING',     'AUTHOR_WARNING',
			                       'DEPRECATION', 'NOTICE',     'STATUS',      'VERBOSE',
			                       'DEBUG',       'TRACE',      'CHECK_START', 'CHECK_PASS',
			                       'CHECK_FAIL' }

			if( #arguments > 1 ) then
				local mode = arguments[ 1 ]
				local msg  = m.toRawString( arguments[ 2 ] )

				if( mode == 'FATAL_ERROR' or mode == 'SEND_ERROR' ) then
					term.pushColor( term.red )
				elseif( mode == 'WARNING' or mode == 'AUTHOR_WARNING' ) then
					term.pushColor( term.yellow )
				elseif( mode == 'DEPRECATION' ) then
					term.pushColor( term.cyan )
				elseif( mode == 'NOTICE' or mode == 'STATUS' or mode == 'VERBOSE' or mode == 'DEBUG' or mode == 'TRACE' or mode == 'CHECK_START' or mode == 'CHECK_PASS' or mode == 'CHECK_FAIL' ) then
					term.pushColor( term.white )
				else
					p.warn( 'Unhandled message mode "%s"', mode )
					term.pushColor( term.white )
				end

				printf( '[CMake]<%s>: %s', mode, msg )
				term.popColor()

			else
				local msg = m.toRawString( arguments[ 1 ] )

				printf( '[CMake]: %s', msg )
			end

		elseif( cmd.name == 'set_property' ) then
			local index           = 1
			local scope           = cmd.arguments[ index ]
			local propertyHandler = nil
			local meta            = nil
			local options         = { 'APPEND', 'APPEND_STRING' }
			index                 = index + 1

			if( scope == 'GLOBAL' ) then
				propertyHandler = function( meta, property, values )
					p.warn( 'Unhandled property %s in GLOBAL scope', property )
				end

			elseif( scope == 'DIRECTORY' ) then
				local dir = cmd.arguments[ index ]
				index     = index + 1

				propertyHandler = function( dir, property, values )
					p.warn( 'Unhandled property %s in DIRECTORY scope', property )
				end
				meta = dir

			elseif( scope == 'TARGET' ) then
				local targets = { }

				propertyHandler = function( targets, property, values )
					p.warn( 'Unhandled property %s in TARGET scope', property )
				end

				while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
					table.insert( targets, cmd.arguments[ index ] )
					index = index + 1
				end

				meta = targets

			elseif( scope == 'SOURCE' ) then
				local sources = { }

				propertyHandler = function( sources, property, values )
					p.warn( 'Unhandled property %s in SOURCE scope', property )
				end

				while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
					table.insert( sources, cmd.arguments[ index ] )
					index = index + 1
				end

				meta = sources

			elseif( scope == 'INSTALL' ) then
				local installFiles = { }

				propertyHandler = function( installFiles, property, values )
					p.warn( 'Unhandled property %s in INSTALL scope', property )
				end

				while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
					table.insert( installFiles, cmd.arguments[ index ] )
					index = index + 1
				end

				meta = installFiles

			elseif( scope == 'TEST' ) then
				local tests = { }

				propertyHandler = function( tests, property, values )
					p.warn( 'Unhandled property %s in TEST scope', property )
				end

				while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
					table.insert( tests, cmd.arguments[ index ] )
					index = index + 1
				end

				meta = tests

			elseif( scope == 'CACHE' ) then
				local entries = { }

				propertyHandler = function( entries, property, values )
					if( property == 'STRINGS' ) then
						for _,entry in ipairs( entries ) do
							cache_entries_allowed[ entry ] = values
						end
					else
						p.warn( 'Unhandled property %s in CACHE scope', property )
					end
				end

				while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
					table.insert( entries, cmd.arguments[ index ] )
					index = index + 1
				end

				meta = entries

			else
				p.error( 'Unhandled scope for "%s"', cmd.name )
			end

			-- Additional options
			while( cmd.arguments[ index ] ~= 'PROPERTY' ) do
				local option = cmd.arguments[ index ]

				if( option == 'APPEND' ) then
					-- TODO: Implement APPEND
				elseif( option == 'APPEND_STRING' ) then
					-- TODO: Implement APPEND_STRING
				else
					p.error( 'Unhandled option "%s" for command "%s"', option, cmd.name )
				end

				index = index + 1
			end
			index = index + 1

			local property = cmd.arguments[ index ]
			local values   = { }
			index = index + 1

			for i = index, #cmd.arguments do
				table.insert( values, cmd.arguments[ i ] )
			end

			propertyHandler( meta, property, values )

		elseif( cmd.name == 'find_package' ) then

			if( os.isfile( m.CMAKE_MODULES_CACHE_AVAILABLE ) ) then
				-- TODO: Full signature
				-- TODO: COMPONENTS and OPTIONAL_COMPONENTS
				local arguments        = cmd.arguments
				local possible_options = { 'EXACT', 'QUIET', 'MODULE', 'REQUIRED', 'NO_POLICY_SCOPE' }
				local packageName      = table.remove( cmd.arguments, 1 )
				local version          = iif( arguments[ 1 ] and not table.contains( possible_options, arguments[ 1 ] ), table.remove( arguments, 1 ), '0.0.0' )
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
					term.pushColor( term.green )
					printf( 'Found module "%s" at "%s"', packageName, filePath )
					term.popColor()

					-- TODO: Let module do this instead
					cmakevariables {
						[ packageName .. '_FOUND' ] = m.YES,
					}
				end

			else
				p.error( 'CMake module cache is not available for command "%s"', cmd.name )
			end

		elseif( ( cmd.name == 'if' ) or ( cmd.name == 'elseif' ) ) then
			if( cmd.name == 'if' ) then
				local newScope  = { }
				newScope.parent = testScope
				newScope.tests  = { }
				testScope       = newScope

				if( ( #testScope.parent.tests > 0 ) and ( testScope.parent.tests[ #testScope.parent.tests ] ) ) then
					table.insert( testScope.tests, true )
				else
					goto continue
				end

			elseif( cmd.name == 'elseif' ) then
				if( #testScope.tests == 0 ) then
					goto continue
				end

				-- Look at all tests except the first one, which is always true
				local tests = table.pack( select( 2, table.unpack( testScope.tests ) ) )

				if( table.contains( tests, true ) ) then
					table.insert( testScope.tests, false )
					goto continue
				end
			end

			local test = m.expandConditions( cmd.argString )

			table.insert( testScope.tests, test )

		elseif( cmd.name == 'else' ) then

			if( #testScope.tests > 0 ) then
				-- Look at all tests except the first one, which is always true
				local tests = table.pack( select( 2, table.unpack( testScope.tests ) ) )

				table.insert( testScope.tests, not table.contains( tests, true ) )
			end

		elseif( cmd.name == 'endif' ) then

			testScope = testScope.parent

		else

			-- Warn about unhandled command
			p.warn( 'Unhandled command: "%s" with arguments: [%s]', cmd.name, table.implode( cmd.arguments, '', '', ', ' ) )

		end

		-- Continue label
		::continue::

	end

	-- TODO: Validate allowed cache entries against allowed cache entries

	-- Handle cache entries
	for entry,value in pairs( cache_entries ) do
		if( entry == 'CMAKE_CXX_FLAGS' ) then

			-- Replace surrounding quotation marks
			if( m.isStringLiteral( value ) ) then
				value = string.gsub( value, '"(.*)"', '%1' )
			end

			local options = value:explode( ' ' )

			buildoptions( options )

		else
			p.warn( 'Unhandled cache entry %s', entry )
		end
	end

	-- Handle allowed cache entries
	for entry,allowed in pairs( cache_entries_allowed ) do
		if( entry == 'CMAKE_BUILD_TYPE' ) then

			-- Remove surrounding quotation marks
			for i = 1, #allowed do
				allowed[ i ] = string.gsub( allowed[ i ], '"(.*)"', '%1' )
			end

			-- Replace allowed configurations
			removeconfigurations { '*' }
			configurations( allowed )

		else
			p.warn( 'Unhandled allowed values for entry %s: [%s]', entry, table.implode( allowed, '', '', ', ' ) )
		end
	end

	if( currentGroup ) then
		-- Restore current group
		p.api.scope.group = currentGroup
	end
end

function m.deserializeCommandList( content )
	local commandList = { }
	local begin       = 1

	while( begin < #content ) do
		local leftParenthesis, rightParenthesis = m.findMatchingParentheses( content, begin )
		local command = {
			name      = string.sub( content, begin, leftParenthesis - 1 ),
			argString = string.sub( content, leftParenthesis + 1, rightParenthesis - 1 ),
			arguments = { },
		}

		-- Trim surrounding whitespace
		command.name      = string.match( command.name,      '^%s*(.*%S)%s*' ) or command.name
		command.argString = string.match( command.argString, '^%s*(.*%S)%s*' ) or command.argString

		local it = string.find( content, '%S', leftParenthesis + 1, false )

		while( it and it < rightParenthesis ) do
			local leftQuotationMark = string.find( content, '"', it, true )

			if( leftQuotationMark and leftQuotationMark == it ) then
				local rightQuotationMark = string.find( content, '"', leftQuotationMark + 1, true )

				table.insert( command.arguments, string.sub( content, leftQuotationMark, rightQuotationMark ) )

				it = string.find( content, '%S', rightQuotationMark + 1, false )

			else
				local nextSpace = string.find( content, ' ',  it, true )
				local tail      = iif( ( nextSpace ~= nil ) and ( nextSpace < rightParenthesis ), nextSpace - 1, rightParenthesis - 1 )

				table.insert( command.arguments, string.sub( content, it, tail ) )

				it = string.find( content, '%S', tail + 1, false )
			end
		end

		-- Store command
		table.insert( commandList, command )

		begin = rightParenthesis + 1
	end

	return commandList
end

function m.addSystemVariables()
	local sys     = os.outputof( 'uname -s' )
	local host    = os.host()
	local target  = os.target()
	local sysinfo = os.getversion()
	local action  = _ACTION

	-- Constants

	cmakevariables {
		[ m.ON       ] = m.ON,
		[ m.YES      ] = m.YES,
		[ m.TRUE     ] = m.TRUE,
		[ m.Y        ] = m.Y,
		[ m.OFF      ] = m.OFF,
		[ m.NO       ] = m.NO,
		[ m.FALSE    ] = m.FALSE,
		[ m.N        ] = m.N,
		[ m.IGNORE   ] = m.IGNORE,
		[ m.NOTFOUND ] = m.NOTFOUND,
	}

	-- Host system

	cmakevariables {
		CMAKE_HOST_SYSTEM_NAME      = sys or host,
		CMAKE_HOST_SYSTEM_PROCESSOR = os.getenv( 'PROCESSOR_ARCHITECTURE' ) or os.outputof( 'uname -m' ) or os.outputof( 'arch' ),
		CMAKE_HOST_SYSTEM_VERSION   = string.format( '%d.%d.%d', sysinfo.majorversion, sysinfo.minorversion, sysinfo.revision ),
		CMAKE_HOST_SYSTEM           = '%{CMAKE_HOST_SYSTEM_NAME}.%{CMAKE_HOST_SYSTEM_VERSION}',
	}

	if( host == 'windows' ) then
		cmakevariables {
			CMAKE_HOST_WIN32 = m.TRUE,
		}
		if( sys and sys:startswith( 'CYGWIN' ) ) then
			cmakevariables {
				CMAKE_HOST_CYGWIN = m.TRUE,
			}
		elseif( sys and sys:startswith( 'MINGW' ) ) then
			cmakevariables {
				CMAKE_HOST_MINGW = m.TRUE,
			}
		end
	elseif( host == 'macosx' ) then
		cmakevariables {
			CMAKE_HOST_APPLE = m.TRUE,
			CMAKE_HOST_UNIX  = m.TRUE,
		}
	elseif( host == 'solaris' ) then
		cmakevariables {
			CMAKE_HOST_SOLARIS = m.TRUE,
			CMAKE_HOST_UNIX    = m.TRUE,
		}
	end

	-- Target system

	if( host == target ) then
		cmakevariables {
			CMAKE_SYSTEM_PROCESSOR = '%{CMAKE_HOST_SYSTEM_PROCESSOR}',
			CMAKE_SYSTEM_VERSION   = '%{CMAKE_HOST_SYSTEM_VERSION}',
		}
	end

	if( target == 'windows' ) then
		cmakevariables {
			CMAKE_SYSTEM_NAME = 'Windows',
			WIN32             = m.TRUE,
		}
	elseif( target == 'macosx' ) then
		cmakevariables {
			CMAKE_SYSTEM_NAME = 'Apple',
			APPLE             = m.TRUE,
			UNIX              = m.TRUE,
		}
	elseif( target == 'android' ) then
		cmakevariables {
			CMAKE_SYSTEM_NAME = 'Android',
			ANDROID           = m.TRUE,
		}
	elseif( target == 'ios' ) then
		cmakevariables {
			CMAKE_SYSTEM_NAME = 'iOS',
			IOS               = m.TRUE,
		}
	end

	cmakevariables {
		CMAKE_SYSTEM = '%{CMAKE_SYSTEM_NAME}.%{CMAKE_SYSTEM_VERSION}'
	}

	-- Generators

	-- TODO: MSVC*
	-- TODO: MSYS
	-- TODO: WINCE
	-- TODO: WINDOWS_PHONE
	-- TODO: WINDOWS_STORE

	if( action == 'Xcode4' ) then
		local xcodeVersion = os.outputof( '/usr/bin/xcodebuild -version' )

		cmakevariables {
			XCODE         = m.TRUE,
			XCODE_VERSION = xcodeVersion,
		}
	end
end
