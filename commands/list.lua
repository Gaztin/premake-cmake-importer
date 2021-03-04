local p           = premake
local m           = p.extensions.impcmake
local subcommands = { }

-- TODO: LENGTH

function subcommands.get( list, ... )
	local scope      = m.scope.current()
	local argc       = select( '#', ... )
	local indexCount = argc - 1
	local outVar     = select( argc, ... )
	local results    = { }

	for i=1,indexCount do
		local index = 1 + select( indexCount, ... )
		local item  = list[ index ] or ''

		table.insert( results, item )
	end

	scope.variables[ outVar ] = table.concat( results, ';' )
end

-- TODO: JOIN
-- TODO: SUBLIST

function subcommands.find( list, value, outVar )
	local scope = m.scope.current()
	value       = m.resolveVariables( value )

	for i,item in ipairs( list ) do
		if( item == value ) then
			scope.variables[ outVar ] = i
			return
		end
	end

	scope.variables[ outVar ] = -1
end

-- TODO: APPEND
-- TODO: FILTER
-- TODO: INSERT
-- TODO: POP_BACK
-- TODO: POP_FRONT
-- TODO: PREPEND
-- TODO: REMOVE_ITEM
-- TODO: REMOVE_AT
-- TODO: REMOVE_DUPLICATES
-- TODO: TRANSFORM
-- TODO: REVERSE
-- TODO: SORT

function m.commands.list( cmd )
	local subcommandName = cmd.arguments[ 1 ]:lower()
	local subcommand     = subcommands[ subcommandName ]
	if( subcommand == nil ) then
		p.error( 'List subcommand "%s" is not implemented!', subcommandName )
	end

	local list = cmd.arguments[ 2 ]:explode( ';' )

	subcommand( list, table.unpack( cmd.arguments, 3 ) )
end
