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
	local commandList = directory.deserializeCommandList( content )
	local variables   = { }

	local function resolveVariables( str )
		for k,v in pairs( variables ) do
			local pattern = string.format( '${%s}', k )

			str = string.gsub( str, pattern, v )
		end
		return str
	end

	for i,cmd in ipairs( commandList ) do
		if( cmd.name == 'project' ) then
			local projectName = cmd.arguments[ 1 ]

			-- Declare new project
			project( projectName )

		elseif( cmd.name == 'set' ) then
			local arguments    = cmd.arguments
			local variableName = table.remove( arguments, 1 )

			-- Store new variable
			variables[ variableName ] = table.implode( arguments, '', '', ' ' )

		elseif( cmd.name == 'add_executable' ) then
			local arguments      = cmd.arguments
			local projectName    = table.remove( arguments, 1 )
			local currentProject = p.api.scope.project
			local projectToAmend = p.workspace.findproject( p.api.scope.workspace, projectName )

			-- Make sure project exists
			if( projectToAmend == nil ) then
				p.error( 'Project "%s" referenced in "add_executable" not found in workspace', addToProject )
			end

			-- Temporarily activate amended project
			p.api.scope.project = projectToAmend

			-- Add source files
			for _,arg in ipairs( arguments ) do
				arg = resolveVariables( arg )

				for _,v in ipairs( string.explode( arg, ' ' ) ) do
					local rebasedSourceFile = path.rebase( v, baseDir, os.getcwd() )

					files { rebasedSourceFile }
				end
			end

			-- Restore scope
			p.api.scope.project = currentProject

		else
			-- Warn about unhandled command
			p.warn( 'Unhandled command: "%s" with arguments: [%s]', cmd.name, table.implode( cmd.arguments, '', '', ', ' ) )
		end
	end

	kind( 'ConsoleApp' )
	location( baseDir )

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
