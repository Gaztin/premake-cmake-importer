local p = premake
local m = p.extensions.impcmake

-- Expression operator type enumerator
m.OP_TYPE          = { }
m.OP_TYPE.CONSTANT = 0x0
m.OP_TYPE.UNARY    = 0x1
m.OP_TYPE.BINARY   = 0x2
m.OP_TYPE.BOOL     = 0x4

function m.parseScript( filePath )
	if( os.isdir( filePath ) ) then
		filePath = path.join( filePath, 'CMakeLists.txt' )
	end

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

	-- Add predefined variables
	m.addSystemVariables()

	local scope = m.scope.current()

	scope.variables[ 'PROJECT_SOURCE_DIR' ]        = path.getdirectory( filePath )
	scope.variables[ 'CMAKE_CURRENT_LIST_FILE' ]   = filePath
	scope.variables[ 'CMAKE_CURRENT_LIST_DIR' ]    = path.getdirectory( filePath )
	scope.variables[ 'CMAKE_CONFIGURATION_TYPES' ] = table.implode( p.api.scope.workspace.configurations, '"', '"', ' ' )

	-- Execute commands in order

	for _,cmd in ipairs( commandList ) do
		m.executeCommand( cmd )
	end

	-- TODO: Validate allowed cache entries against allowed cache entries

	-- Handle cache entries
	for entry,value in pairs( m.cache_entries ) do
		if( entry == 'CMAKE_CXX_FLAGS' ) then

			-- Replace surrounding quotation marks
			if( m.isStringLiteral( value ) ) then
				value = string.gsub( value, '"(.*)"', '%1' )
			end

			local options = value:explode( ' ' )

			buildoptions( options )
		end
	end

	-- Handle allowed cache entries
	for entry,allowed in pairs( m.cache_entries_allowed ) do
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

		if( leftParenthesis == nil ) then
			p.error( 'No matching parenthesis found: "%s"...', content:sub( begin, begin + 100 ) )
		end

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
	local host    = os.host()
	local target  = os.target()
	local sysinfo = os.getversion()
	local action  = _ACTION
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

	-- TODO: MSVC*
	-- TODO: MSYS
	-- TODO: WINCE
	-- TODO: WINDOWS_PHONE
	-- TODO: WINDOWS_STORE

	if( action == 'Xcode4' ) then
		local xcodeVersion = os.outputof( '/usr/bin/xcodebuild -version' )

		scope.variables[ 'XCODE' ]         = m.TRUE
		scope.variables[ 'XCODE_VERSION' ] = xcodeVersion
	end

	-- TODO: CMAKE_LIBRARY_ARCHITECTURE
end
