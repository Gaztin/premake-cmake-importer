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
		return nil
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

	return directory.deserializeProject( content )
end

function directory.deserializeProject( content )
	local commandList = directory.deserializeCommandList( content )
	local prj         = project( commandList[ 'project' ] or 'CMakeProject' )

	kind( 'WindowedApp' )

	return prj
end

function directory.deserializeCommandList( content )
	local commandList = { }
	local begin       = 1

	while( begin < #content ) do
		local nextLeftParenthesis  = string.find( content, '(', begin,               true )
		local nextRightParenthesis = string.find( content, ')', nextLeftParenthesis, true )
		local commandName          = string.sub( content, begin, nextLeftParenthesis - 1 )
		local commandArguments     = string.sub( content, nextLeftParenthesis + 1, nextRightParenthesis - 1 )

		-- Trim surrounding whitespace
		commandName      = string.match( commandName,      '^%s*(.*%S)%s*' ) or commandName
		commandArguments = string.match( commandArguments, '^%s*(.*%S)%s*' ) or commandArguments

		-- Store command
--		commandList[ commandName ] = string.explode( commandArguments, ' ' )
		commandList[ commandName ] = commandArguments

		printf( '%s(%s)', commandName, commandArguments )

		begin = nextRightParenthesis + 1
	end

	return commandList
end
