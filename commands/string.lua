local p           = premake
local m           = p.extensions.impcmake
local subcommands = { }

-- TODO: FIND

function subcommands.REPLACE( match, replacement, outVar, ... )
	local input = select( 1, ... )
	local scope = m.scope.current()
	
	if( select( '#', ... ) > 1 ) then
		p.error( 'string: REPLACE with multiple inputs is not supported!' )
	end

	scope.variables[ outVar ] = m.replace( input, match, replacement )
end

-- TODO: REGEX

function subcommands.APPEND( strVar, ... )
	local scope = m.scope.current()
	local value = scope.variables[ strVar ]

	for i=1,select( '#', ... ) do
		value = value .. select( i, ... )
	end

	scope.variables[ strVar ] = value
end

-- TODO: PREPEND
-- TODO: CONCAT
-- TODO: JOIN

function subcommands.TOLOWER( str, outVar )
	local scope               = m.scope.current()
	scope.variables[ outVar ] = string.lower( m.expandVariables( str ) )
end

function subcommands.TOUPPER( str, outVar )
	local scope               = m.scope.current()
	scope.variables[ outVar ] = string.upper( m.expandVariables( str ) )
end

-- TODO: LENGTH
-- TODO: SUBSTRING
-- TODO: STRIP
-- TODO: GENEX_STRIP
-- TODO: REPEAT
-- TODO: COMPARE
-- TODO: MD5
-- TODO: SHA1
-- TODO: SHA224
-- TODO: SHA256
-- TODO: SHA384
-- TODO: SHA512
-- TODO: SHA3_224
-- TODO: SHA3_256
-- TODO: SHA3_384
-- TODO: SHA3_512
-- TODO: ASCII
-- TODO: CONFIGURE
-- TODO: MAKE_C_IDENTIFIER
-- TODO: RANDOM
-- TODO: TIMESTAMP
-- TODO: UUID

function m.commands.string( cmd )
	local subcommandName = cmd.arguments[ 1 ]
	local subcommand     = subcommands[ subcommandName ]
	if( subcommand == nil ) then
		p.warn( 'String subcommand "%s" is not implemented!', subcommandName )
		return
	end

	subcommand( table.unpack( cmd.arguments, 2 ) )
end
