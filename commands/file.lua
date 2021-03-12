local p           = premake
local m           = p.extensions.impcmake
local subcommands = { }

-- TODO: READ
-- TODO: STRINGS
-- TODO: <HASH>
-- TODO: TIMESTAMP
-- TODO: GET_RUNTIME_DEPENDENCIES
-- TODO: {WRITE | APPEND}

function subcommands.TOUCH( ... )
	for i=1,select( '#', ... ) do
		local filePath = select( i, ... )

		if( os.isfile( filePath ) ) then
			os.touchfile( filePath )
		else
			local file = io.open( filePath, 'a' )
			if( not file ) then
				p.error( 'Failed to touch "%s". File cannot be opened!', filePath )
			end

			io.close( file )
		end
	end
end

function subcommands.TOUCH_NOCREATE( ... )
	for i=1,select( '#', ... ) do
		local filePath = select( i, ... )

		if( os.isfile( filePath ) ) then
			os.touchfile( filePath )
		end
	end
end

-- TODO: GENERATE OUTPUT

function subcommands.GLOB( var, ... )
	local files   = { }
	local options = {
		relativeTo = nil,
		listDirs   = true,

		LIST_DIRECTORIES = function( value )
			options.listDirs = m.isTrue( value )
			return 1
		end,

		RELATIVE = function( path )
			options.relativeTo = path
			return 1
		end,

		CONFIGURE_DEPENDS = function()
			p.warn( 'file: GLOB with CONFIGURE_DEPENDS option has no effect!' )
			return 0
		end,

		__globbingExpressions = function( ... )
			local expressionCount = select( '#', ... )
			for i=1,expressionCount do
				local pattern = select( i, ... )
				local matches = os.matchfiles( pattern )
				files         = table.join( files, matches )
			end
			return expressionCount
		end
	}

	local argCount = select( '#', ... )
	local i        = 1
	repeat
		local arg = select( i, ... )
		i = i + 1
		
		local option = options[ arg ] or options.__globbingExpressions
		i = i + option( select( i, ... ) )
	until( i > argCount )

	local scope            = m.scope.current()
	scope.variables[ var ] = table.concat( files, ';' )
end

-- TODO: GLOB_RECURSE
-- TODO: RENAME
-- TODO: {REMOVE | REMOVE_RECURSE}
-- TODO: MAKE_DIRECTORY
-- TODO: {COPY | INSTALL}
-- TODO: SIZE
-- TODO: READ_SYMLINK
-- TODO: CREATE_LINK
-- TODO: RELATIVE_PATH

function subcommands.TO_CMAKE_PATH( pathToBeConverted, outVar )
	local scope               = m.scope.current()
	scope.variables[ outVar ] = path.translate( pathToBeConverted, '/' )
end

function subcommands.TO_NATIVE_PATH( pathToBeConverted, outVar )
	local scope               = m.scope.current()
	scope.variables[ outVar ] = path.translate( pathToBeConverted )
end

-- TODO: DOWNLOAD
-- TODO: UPLOAD
-- TODO: LOCK

function m.commands.file( cmd )
	local subcommandName = cmd.arguments[ 1 ]
	local subcommand     = subcommands[ subcommandName ]
	if( subcommand == nil ) then
		p.error( 'File subcommand "%s" is not implemented!', subcommandName )
	end

	subcommand( table.unpack( cmd.arguments, 2 ) )
end
