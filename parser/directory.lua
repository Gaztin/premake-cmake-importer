local p            = premake
local m            = p.extensions.impcmake
m.parser           = m.parser or { }
m.parser.directory = { }
local directory    = m.parser.directory

function directory.parse( filePath )
	-- Allow @filePath to just be the directory name.
	-- Append 'CMakeLists.txt' in that case.
	if( path.getname( filePath ) ~= 'CMakeLists.txt' ) then
		filePath = path.normalize( filePath .. '/CMakeLists.txt' )
	end

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

	directory.deserializeProject( content, baseDir )
end

function directory.deserializeProject( content, baseDir )
	local commandList  = directory.deserializeCommandList( content )
	local currentGroup = p.api.scope.group
	local variables    = { }
	local aliases      = { }

	local function resolveVariables( str )
		for k,v in pairs( variables ) do
			local pattern = string.format( '${%s}', k )

			str = string.gsub( str, pattern, v )
		end
		return str
	end

	local function expandVariable( name )
		for k,v in pairs( variables ) do
			if( k == name ) then
				return v
			end
		end

		return m.NOTFOUND
	end

	local function isConstantTrue( value )
		if( value == nil ) then
			return false
		end

		local t = type( value )

		if( t == 'boolean' ) then
			return value
		elseif( t == 'number' ) then
			return ( value ~= 0 )
		elseif( t == 'string') then
			if( ( value == m.ON ) or ( value == m.YES ) or ( value == m.TRUE ) or ( value == m.Y ) ) then
				return true
			elseif( ( value == m.OFF ) or ( value == m.NO ) or ( value == m.FALSE ) or ( value == m.N ) or ( value == m.IGNORE ) or ( value == m.NOTFOUND ) ) then
				return false
			end

			return isConstantTrue( tonumber( value ) )
		end

		p.error( '"%s" is not an eligible type for a CMake constant', t )

		return false
	end

	local function resolveAlias( name )
		for k,v in pairs( aliases ) do
			if( k == name ) then
				return v
			end
		end
		return name
	end

	-- Add predefined variables
	variables[ 'PROJECT_SOURCE_DIR' ] = baseDir

	local tests = { }

	for _,cmd in ipairs( commandList ) do
		local last_test = iif( #tests > 0, tests[ #tests ], true )

		-- Skip commands if last test failed
		if( ( not last_test ) and ( cmd.name ~= 'elseif' ) and ( cmd.name ~= 'else' ) and ( cmd.name ~= 'endif' ) ) then
			goto continue
		end

		if( cmd.name == 'cmake_minimum_required' ) then
			-- Do nothing

		elseif( cmd.name == 'project' ) then
			local groupName = cmd.arguments[ 1 ]

			group( groupName )

		elseif( cmd.name == 'set' ) then
			local arguments    = cmd.arguments
			local variableName = table.remove( arguments, 1 )

			-- Store new variable
			variables[ variableName ] = table.implode( arguments, '', '', ' ' )

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
						local f = resolveVariables( arguments[ i ] )

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
					local f = resolveVariables( arguments[ i ] )

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

					arg = resolveVariables( arg )

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
					arg = resolveVariables( arg )

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

		elseif( cmd.name == 'install' ) then

			-- Skip installation rules
			p.warnOnce( p.api.scope.project, string.format( 'Skipping installation rules for project "%s"', p.api.scope.project.name ) )

		elseif( cmd.name == 'message' ) then

			-- Print message
			printf( '[CMake]: %s', table.implode( cmd.arguments, '', '', ' ' ) )

		elseif( ( cmd.name == 'if' ) or ( cmd.name == 'elseif' ) ) then

			-- Don't evaluate elseif if any previous tests were successful
			if( cmd.name == 'elseif' and table.contains( tests, true ) ) then
				table.insert( tests, false )
				goto continue
			end

			local unary_tests = {
				'EXISTS', 'COMMAND', 'DEFINED',
			}
			local binary_tests = {
				'EQUAL',              'LESS',             'LESS_EQUAL',            'GREATER',
				'GREATER_EQUAL',      'STREQUAL',         'STRLESS',               'STRLESS_EQUAL',
				'STRGREATER',         'STRGREATER_EQUAL', 'VERSION_EQUAL',         'VERSION_LESS',
				'VERSION_LESS_EQUAL', 'VERSION_GREATER',  'VERSION_GREATER_EQUAL', 'MATCHES',
			}
			local bool_ops = {
				'NOT', 'AND', 'OR',
			}
			local all_ops   = table.join( unary_tests, binary_tests, bool_ops )
			local constants = { }

			-- Look for constants
			for i=1,#cmd.arguments do
				local is_unary_test  = table.contains( unary_tests, cmd.arguments[ i ] )
				local is_binary_test = table.contains( binary_tests, cmd.arguments[ i ] )
				local is_bool_op     = table.contains( bool_ops, cmd.arguments[ i ] )
				local is_constant    = not ( is_unary_test or is_binary_test or is_bool_op )

				if( is_constant ) then
					local const = { }

					const.name = cmd.arguments[ i ]

					-- Determine what type the constant is
					if( string.sub( cmd.arguments[ i ], 1, 1 ) == '"' ) then
						const.eval = cmd.arguments[ i ]
					elseif( tonumber( cmd.arguments[ i ] ) ~= nil ) then
						const.eval = tonumber( cmd.arguments[ i ] )
					else
						const.eval = expandVariable( cmd.arguments[ i ] )
					end

					const.bool  = isConstantTrue( const.eval )
					const.index = i

					table.insert( constants, const )
				end
			end

			local new_test = true

			-- TODO: Inner parentheses

			-- Unary tests
			for _,const in ipairs( constants ) do
				if( const.index > 1 ) then
					local unary_test    = cmd.arguments[ const.index - 1 ]
					local do_unary_test = table.contains( unary_tests, unary_test )

					if( do_unary_test ) then
						if( unary_test == 'EXISTS' ) then
							-- TODO: Implement EXISTS
							const.bool = false
						elseif( unary_test == 'COMMAND' ) then
							-- TODO: Implement COMMAND
							const.bool = false
						elseif( unary_test == 'DEFINED' ) then
							const.bool = ( ( const.eval ~= nil ) and ( const.eval ~= m.NOTFOUND ) )
						end
					end
				end
			end

			-- Binary tests
			local i            = 0
			local newConstants = { }

			while( i < #constants ) do
				i         = i + 1
				local lhs = constants[ i ]

				if( lhs.index < #cmd.arguments ) then
					local binary_test    = cmd.arguments[ lhs.index + 1 ]
					local do_binary_test = table.contains( binary_tests, binary_test )

					if( do_binary_test and i < #constants ) then
						local rhs    = constants[ i + 1 ]
						local result = nil

						if( binary_test == 'EQUAL'                 ) then result = ( lhs.eval == rhs.eval ) end
						if( binary_test == 'LESS'                  ) then result = ( lhs.eval < rhs.eval  ) end
						if( binary_test == 'LESS_EQUAL'            ) then result = ( lhs.eval <= rhs.eval ) end
						if( binary_test == 'GREATER'               ) then result = ( lhs.eval > rhs.eval  ) end
						if( binary_test == 'GREATER_EQUAL'         ) then result = ( lhs.eval >= rhs.eval ) end
--							if( binary_test == 'STREQUAL'              ) then result = ( lhs.eval == rhs.eval ) end
--							if( binary_test == 'STRLESS'               ) then result = ( lhs.eval < rhs.eval  ) end
--							if( binary_test == 'STRLESS_EQUAL'         ) then result = ( lhs.eval <= rhs.eval ) end
--							if( binary_test == 'STRGREATER'            ) then result = ( lhs.eval > rhs.eval  ) end
--							if( binary_test == 'STRGREATER_EQUAL'      ) then result = ( lhs.eval >= rhs.eval ) end
--							if( binary_test == 'VERSION_EQUAL'         ) then result = ( lhs.eval == rhs.eval ) end
--							if( binary_test == 'VERSION_LESS'          ) then result = ( lhs.eval < rhs.eval  ) end
--							if( binary_test == 'VERSION_LESS_EQUAL'    ) then result = ( lhs.eval <= rhs.eval ) end
--							if( binary_test == 'VERSION_GREATER'       ) then result = ( lhs.eval > rhs.eval  ) end
--							if( binary_test == 'VERSION_GREATER_EQUAL' ) then result = ( lhs.eval >= rhs.eval ) end
--							if( binary_test == 'MATCHES'               ) then result = ( lhs.eval == rhs.eval ) end

						if( result ~= nil ) then
							local const  = {
								name=string.format( '(%s %s %s)', tostring( lhs.eval ), binary_test, tostring( rhs.eval ) ),
								eval=result,
								bool=result,
								index=#newConstants
							}

							table.insert( newConstants, const )

							-- Skip rhs for next iteration
							i = i + 1
						end
					else
						local const = { name=lhs.name, eval=lhs.eval, bool=lhs.bool, index=#newConstants }

						table.insert( newConstants, const )
					end
				else
					local const = { name=lhs.name, eval=lhs.eval, bool=lhs.bool, index=#newConstants }

					table.insert( newConstants, const )
				end
			end

			constants = newConstants

			-- Boolean NOT operation
			for _,const in ipairs( constants ) do
				if( const.index > 1 ) then
					local do_negate = cmd.arguments[ const.index - 1 ] == 'NOT'

					if( do_negate ) then
						const.bool = not const.bool
					end
				end
			end

			-- Boolean AND operation
			for i=1,#constants do
				if( i < #constants ) then
					local lhs = constants[ i ].bool
					local rhs = constants[ i + 1 ].bool

					new_test = new_test and ( lhs and rhs )
				end
			end

			-- Boolean OR operation
			for i=1,#constants do
				if( i < #constants ) then
					local lhs = constants[ i ].bool
					local rhs = constants[ i + 1 ].bool

					new_test = new_test and ( lhs or rhs )
				end
			end

			-- Fix single constant without relationships
			if( #constants == 1 ) then
				new_test = constants[ 1 ].bool
			end

			table.insert( tests, new_test )

		elseif( cmd.name == 'else' ) then

			table.insert( tests, not table.contains( tests, true ) )

		elseif( cmd.name == 'endif' ) then

			-- Reset tests
			tests = { }

		else

			-- Warn about unhandled command
			p.warn( 'Unhandled command: "%s" with arguments: [%s]', cmd.name, table.implode( cmd.arguments, '', '', ', ' ) )

		end

		-- Continue label
		::continue::

	end

	if( currentGroup ) then
		-- Restore current group
		p.api.scope.group = currentGroup
	end
end

function directory.deserializeCommandList( content )
	local commandList = { }
	local begin       = 1

	while( begin < #content ) do
		local nextLeftParenthesis  = string.find( content, '(', begin,               true )
		local nextRightParenthesis = string.find( content, ')', nextLeftParenthesis, true )
		local command              = { }
		command.name               = string.sub( content, begin, nextLeftParenthesis - 1 )
		command.arguments          = string.sub( content, nextLeftParenthesis + 1, nextRightParenthesis - 1 )

		-- Trim surrounding whitespace
		command.name               = string.match( command.name,      '^%s*(.*%S)%s*' ) or command.name
		command.arguments          = string.match( command.arguments, '^%s*(.*%S)%s*' ) or command.arguments

		-- Explode arguments into array
		command.arguments          = string.explode( command.arguments, ' ' )

		-- Store command
		table.insert( commandList, command )

		begin = nextRightParenthesis + 1
	end

	return commandList
end
