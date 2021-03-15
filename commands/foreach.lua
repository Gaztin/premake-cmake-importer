local p = premake
local m = p.extensions.impcmake

local function endforeach( commands, data )
	local scope          = m.scope.current()
	local prevLoopVar    = scope.variables[ data.loopVar ]
	local prevContinue   = m.commands[ 'continue' ]
	local prevBreak      = m.commands[ 'break' ]
	local shouldContinue = false
	local shouldBreak    = false

	m.commands[ 'continue' ] = function( cmd )
		shouldContinue = true
	end

	m.commands[ 'break' ] = function( cmd )
		shouldBreak = true
	end

	m.indent()

	for i,item in ipairs( data.items ) do
		scope.variables[ data.loopVar ] = item
		
		for i,command in ipairs( commands ) do
			m.executeCommand( command )

			if( shouldContinue ) then
				shouldContinue = false
				break
			end
		end

		if( i < #data.items and not shouldBreak ) then
			verbosef( m.indentation( -1 ) .. 'nextforeach (%s = %d)', data.loopVar, i )
		end

		if( shouldBreak ) then
			break
		end
	end

	m.unindent()
	verbosef( m.indentation() .. 'endforeach' )

	m.commands[ 'break' ]           = prevBreak
	m.commands[ 'continue' ]        = prevContinue
	scope.variables[ data.loopVar ] = prevLoopVar
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
	local step  = #cmd.arguments > 4 and tonumber( m.expandVariables( cmd.arguments[ 5 ] ) ) or 1
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
	p.warn( 'for: IN loops are not supported!' )
	
	return {
		loopVar = 'i',
		items   = { },
	}
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
