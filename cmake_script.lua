local p = premake
local m = p.extensions.impcmake

-- Expression operator type enumerator
m.OP_TYPE          = { }
m.OP_TYPE.CONSTANT = 0x0
m.OP_TYPE.UNARY    = 0x1
m.OP_TYPE.BINARY   = 0x2
m.OP_TYPE.BOOL     = 0x4

function m.loadScript( filePath )
	local file = io.open( filePath, 'r' )
	if( file == nil ) then
		p.error( 'Failed to open "%s"', filePath )
		return
	end

	local content = file:read( '*a' )

	io.close( file )

	-- Remove bracket comments
	repeat
		local st,en,cap = content:find( '[^#]#%[(=*)%[' )
		if( st ~= nil ) then
			-- Find matching end brackets with the same amount of '=' characters between the brackets (']]')
			local closingBrackets = ']' .. cap .. ']'
			local st2             = content:find( closingBrackets, en + 1, true )

			if( st2 == nil ) then
				p.error( 'Bracket comment with %d #s was opened but not closed in "%s"', #cap, filePath )
				return
			end

			content = content:sub( 1, st - 1 ) .. content:sub( st2 + #closingBrackets )
		end
	until st == nil

	-- Remove trailing comments
	repeat
		local index = m.findUncaptured( content, '#' )
		if( index ~= nil ) then
			local en = content:find( '\n', index + 1 )
			content = content:sub( 1, index - 1 ) .. ( en and content:sub( en ) or '' )
		end
	until index == nil

	-- Remove all control characters (mainly newlines)
	content = content:gsub( '%c', ' ' )

	local commandList  = m.deserializeCommandList( content )
	local currentGroup = p.api.scope.group
	local scope        = m.scope.current()
	local prevListFile = scope.CMAKE_CURRENT_LIST_FILE
	scope.variables[ 'CMAKE_CURRENT_LIST_FILE' ] = filePath
	scope.variables[ 'CMAKE_CURRENT_LIST_DIR' ]  = path.getdirectory( filePath )

	-- Add predefined variables
	m.addSystemVariables()

	-- Execute commands in order
	for _,cmd in ipairs( commandList ) do
		m.executeCommand( cmd )
	end

	-- Handle cache entries
	for entry,value in pairs( m.cache_entries ) do
		m.handleLeftoverCacheEntry( entry, value )
	end

	-- Restore previous list file
	if( prevListFile ) then
		scope.variables[ 'CMAKE_CURRENT_LIST_FILE' ] = prevListFile
		scope.variables[ 'CMAKE_CURRENT_LIST_DIR' ]  = path.getdirectory( prevListFile )
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

		if( leftParenthesis == nil ) then
			p.error( 'No matching parenthesis found: "%s"...', content:sub( begin, begin + 100 ) )
		end

		local command = {
			name      = string.sub( content, begin, leftParenthesis - 1 ),
			argString = string.sub( content, leftParenthesis + 1, rightParenthesis - 1 ),
			arguments = { },
		}

		-- Trim surrounding whitespace
		command.name      = string.match( command.name,      '%s*(.*%S)%s*' ) or command.name
		command.argString = string.match( command.argString, '%s*(.*%S)%s*' ) or command.argString
		-- Commands in CMake are case insensitive
		command.name      = command.name:lower()
		command.arguments = m.splitTerms( command.argString )

		-- Store command
		table.insert( commandList, command )

		begin = rightParenthesis + 1
	end

	return commandList
end

function m.addSystemVariables()
	local host    = os.host()
	local target  = os.target()
	local sysinfo = os.getversion()
	local scope   = m.scope.current()

	-- Constants
	scope.variables[ m.ON       ] = m.ON
	scope.variables[ m.YES      ] = m.YES
	scope.variables[ m.TRUE     ] = m.TRUE
	scope.variables[ m.Y        ] = m.Y
	scope.variables[ m.OFF      ] = m.OFF
	scope.variables[ m.NO       ] = m.NO
	scope.variables[ m.FALSE    ] = m.FALSE
	scope.variables[ m.N        ] = m.N
	scope.variables[ m.IGNORE   ] = m.IGNORE
	scope.variables[ m.NOTFOUND ] = m.NOTFOUND

	-- Host system
	scope.variables[ 'CMAKE_HOST_SYSTEM_NAME' ]      = m.HOST_SYSTEM_NAME
	scope.variables[ 'CMAKE_HOST_SYSTEM_PROCESSOR' ] = m.HOST_SYSTEM_PROCESSOR
	scope.variables[ 'CMAKE_HOST_SYSTEM_VERSION' ]   = string.format( '%d.%d.%d', sysinfo.majorversion, sysinfo.minorversion, sysinfo.revision )
	scope.variables[ 'CMAKE_HOST_SYSTEM' ]           = '%{CMAKE_HOST_SYSTEM_NAME}.%{CMAKE_HOST_SYSTEM_VERSION}'
	scope.variables[ 'CMAKE_SIZEOF_VOID_P' ]         = iif( os.is64bit(), 8, 4 )

	if( host == 'windows' ) then
		scope.variables[ 'CMAKE_HOST_WIN32' ] = m.TRUE

		if( m.HOST_SYSTEM_NAME:startswith( 'CYGWIN' ) ) then
			scope.variables[ 'CMAKE_HOST_CYGWIN' ] = m.TRUE
		elseif( m.HOST_SYSTEM_NAME:startswith( 'MINGW' ) ) then
			scope.variables[ 'CMAKE_HOST_MINGW' ] = m.TRUE
		end
	elseif( host == 'macosx' ) then
		scope.variables[ 'CMAKE_HOST_APPLE' ] = m.TRUE
		scope.variables[ 'CMAKE_HOST_UNIX' ]  = m.TRUE
	elseif( host == 'solaris' ) then
		scope.variables[ 'CMAKE_HOST_SOLARIS' ] = m.TRUE
		scope.variables[ 'CMAKE_HOST_UNIX' ]    = m.TRUE
	end

	-- Target system

	if( host == target ) then
		scope.variables[ 'CMAKE_SYSTEM_PROCESSOR' ] = '%{CMAKE_HOST_SYSTEM_PROCESSOR}'
		scope.variables[ 'CMAKE_SYSTEM_VERSION' ]   = '%{CMAKE_HOST_SYSTEM_VERSION}'
	end

	if( target == 'windows' ) then
		scope.variables[ 'CMAKE_SYSTEM_NAME' ] = 'Windows'
		scope.variables[ 'WIN32' ]             = m.TRUE
	elseif( target == 'macosx' ) then
		scope.variables[ 'CMAKE_SYSTEM_NAME' ] = 'Apple'
		scope.variables[ 'APPLE' ]             = m.TRUE
		scope.variables[ 'UNIX' ]              = m.TRUE
	elseif( target == 'android' ) then
		scope.variables[ 'CMAKE_SYSTEM_NAME' ] = 'Android'
		scope.variables[ 'ANDROID' ]           = m.TRUE
	elseif( target == 'ios' ) then
		scope.variables[ 'CMAKE_SYSTEM_NAME' ] = 'iOS'
		scope.variables[ 'IOS' ]               = m.TRUE
	end

	scope.variables[ 'CMAKE_SYSTEM' ] = '%{CMAKE_SYSTEM_NAME}.%{CMAKE_SYSTEM_VERSION}'

	-- Generators

	local generators = {
		xcode4   = 'Xcode',
		codelite = 'CodeLite',
		gmake    = 'Unix Makefiles',
		gmake2   = 'Unix Makefiles',
		vs2005   = 'Visual Studio 8 2005',
		vs2008   = 'Visual Studio 9 2008',
		vs2010   = 'Visual Studio 10 2010',
		vs2012   = 'Visual Studio 11 2012',
		vs2013   = 'Visual Studio 12 2013',
		vs2015   = 'Visual Studio 14 2015',
		vs2017   = 'Visual Studio 15 2017',
		vs2019   = 'Visual Studio 16 2019',
	}

	scope.variables[ 'CMAKE_GENERATOR' ] = generators[ _ACTION ] or 'Unknown'
	
	-- TODO: MSVC*
	-- TODO: MSYS
	-- TODO: WINCE
	-- TODO: WINDOWS_PHONE
	-- TODO: WINDOWS_STORE

	if( _ACTION == 'xcode4' ) then
		local xcodeVersion = os.outputof( '/usr/bin/xcodebuild -version' )

		scope.variables[ 'XCODE' ]         = m.TRUE
		scope.variables[ 'XCODE_VERSION' ] = xcodeVersion
	end

	-- TODO: CMAKE_LIBRARY_ARCHITECTURE
end

function m.handleLeftoverCacheEntry( name, value )
	if( name == 'CMAKE_CXX_FLAGS' ) then
		buildoptions( value )
	end
end
