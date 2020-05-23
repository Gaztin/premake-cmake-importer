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

	local baseDir = path.getdirectory( filePath )

	return directory.deserializeProject( content, baseDir )
end

function directory.deserializeProject( content, baseDir )
	local commandList     = directory.deserializeCommandList( content )
	local projectCommands = table.filter( commandList, function( cmd ) return cmd.name == 'project' end )
	local projectName     = 'CMakeProject'

	if( #projectCommands > 0 ) then
		projectName = projectCommands[ 1 ].arguments[ 1 ]
	end

	local prj = project( projectName )

	local setCommands = table.filter( commandList, function( cmd ) return cmd.name == 'set' end )
	local sets        = { }
	for _,cmd in ipairs( setCommands ) do
		local arguments = cmd.arguments
		local setName   = table.remove( arguments, 1 )
		sets[ setName ] = table.implode( arguments, '', '', ' ' )
	end

	local projectKind  = 'WindowedApp'
	local projectFiles = { }

	for i,cmd in ipairs( commandList ) do
		if( cmd.name == 'add_executable' ) then
			-- TODO: Add to given project at @cmd.arguments[ 1 ] instead of main project
			local arguments         = cmd.arguments
			local projectInQuestion = table.remove( arguments, 1 )

			-- Resolve variables
			arguments = table.implode( arguments, '', '', ' ' )
			for k,v in pairs( sets ) do
				local pattern = string.format( '${%s}', k )

				arguments = string.gsub( arguments, pattern, v )
			end

			local sourceFiles = string.explode( arguments, ' ' )
			for i,v in ipairs( sourceFiles ) do
				local rebasedSourceFile = path.rebase( v, baseDir, os.getcwd() )

				table.insert( projectFiles, rebasedSourceFile )
			end
		end
	end

	kind( projectKind )
	files( projectFiles )

	return prj
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
