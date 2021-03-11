local p = premake
local m = p.extensions.impcmake

local function endforeach( commands, data )
	local scope   = m.scope.current()
	local restore = scope.variables[ data.loopVar ]

	for _,item in ipairs( data.items ) do
		scope.variables[ data.loopVar ] = item

		for _,command in ipairs( commands ) do
			if( m.groups.recording ) then
				m.groups.record( command )
			else
				m.executeCommand( command )
			end
		end
	end

	scope.variables[ data.loopVar ] = restore
end

local function foreachBasic( cmd )
	return {
		loopVar = cmd.arguments[ 1 ],
		items   = string.explode( cmd.arguments[ 2 ], '[ ;]+' ),
	}
end

local function foreachRange( cmd )
	local start = #cmd.arguments > 3 and tonumber( cmd.arguments[ 3 ] ) or 0
	local stop  = tonumber( cmd.arguments[ #cmd.arguments > 3 and 4 or 3 ] )
	local step  = #cmd.arguments > 4 and tonumber( m.resolveVariables( cmd.arguments[ 5 ] ) ) or 1
	if( stop == nil ) then
		p.error( 'Stopping point for range-variant foreach was not a number (%s)', stop )
	end

	local items = { }
	for i=start,stop,step do
		table.insert( items, i )
	end

	return {
		loopVar = cmd.arguments[ 1 ],
		items   = items,
	}
end

local function foreachBasicMultiArg( cmd )
	return {
		loopVar = cmd.arguments[ 1 ],
		items   = table.pack( table.unpack( cmd.arguments, 2 ) ),
	}
end

local function foreachIn( cmd )
	p.error( 'This type of foreach loop is not supported' )
end

function m.commands.foreach( cmd )
	local data
	if( #cmd.arguments == 2 ) then
		data = foreachBasic( cmd )
	elseif( #cmd.arguments >= 3 and cmd.arguments[ 2 ] == 'RANGE' ) then
		data = foreachRange( cmd )
	elseif( #cmd.arguments >= 3 and table.indexof( cmd.arguments, 'IN' ) ~= nil ) then
		data = foreachIn( cmd )
	else
		data = foreachBasicMultiArg( cmd )
	end

	m.groups.push( 'foreach', 'endforeach', endforeach, data )
end
