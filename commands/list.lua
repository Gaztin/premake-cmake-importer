local p           = premake
local m           = p.extensions.impcmake
local subcommands = { }

local function getList( listVar )
	local listValue = m.dereference( listVar )
	if( listValue ) then
		return string.explode( listValue, '[; ]' )
	else
		return { }
	end
end

-- TODO: LENGTH

function subcommands.GET( listVar, ... )
	local scope      = m.scope.current()
	local list       = getList( listVar )
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

function subcommands.FIND( listVar, value, outVar )
	local scope = m.scope.current()
	local list  = getList( listVar )

	for i,item in ipairs( list ) do
		if( item == value ) then
			scope.variables[ outVar ] = i
			return
		end
	end

	scope.variables[ outVar ] = -1
end

function subcommands.APPEND( listVar, ... )
	local scope = m.scope.current()
	local list  = getList( listVar )

	for i=1,select( '#', ... ) do
		local item = select( i, ... )
		table.insert( list, item )
	end

	scope.variables[ listVar ] = table.concat( list, ';' )
end

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
	local subcommandName = cmd.arguments[ 1 ]
	local subcommand     = subcommands[ subcommandName ]
	if( subcommand == nil ) then
		p.warn( 'List subcommand "%s" is not implemented!', subcommandName )
		return
	end

	subcommand( table.unpack( cmd.arguments, 2 ) )
end
