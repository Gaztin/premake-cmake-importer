local p = premake
local m = p.extensions.impcmake

local function endfunc( commands, data )
	local scope   = m.scope.current()
	local restore = scope.variables[ data.loopVar ]

	for _,item in ipairs( data.items ) do
		scope.variables[ data.loopVar ] = item

		local condscope = {
			parent = nil,
			tests  = { true },
		}

		for _,command in ipairs( commands ) do

			if( m.groups.recording ) then
				m.groups.record( command )
			else
				local lastTest = iif( #condscope.tests > 0, condscope.tests[ #condscope.tests ], false )

				if( lastTest or command.name == 'if' or command.name == 'elseif' or command.name == 'else' or command.name == 'endif' ) then
					local condscope__refwrap = { ptr = condscope }

					if( not m.executeCommand( command, condscope__refwrap ) ) then
						p.warn( 'Unhandled command: "%s" with arguments: [%s]', command.name, table.concat( command.arguments, ', ' ) )
					end

					condscope = condscope__refwrap.ptr
				end
			end
		end
	end

	scope.variables[ data.loopVar ] = restore
end

local function foreachBasic( cmd )
	return {
		loopVar = cmd.arguments[ 1 ],
		items   = string.explode( m.resolveVariables( cmd.arguments[ 2 ] ), ';' ),
	}
end

local function foreachRange( cmd )
	local start = #cmd.arguments > 3 and tonumber( m.resolveVariables( cmd.arguments[ 3 ] ) ) or 0
	local stop  = tonumber( m.resolveVariables( cmd.arguments[ #cmd.arguments > 3 and 4 or 3 ] ) )
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

function m.commands.foreach( cmd )
	local data
	if( #cmd.arguments == 2 ) then
		data = foreachBasic( cmd )
	elseif( #cmd.arguments >= 3 and cmd.arguments[ 2 ] == 'RANGE' ) then
		data = foreachRange( cmd )
	else
		p.error( 'This type of foreach loop is not supported' )
	end

	m.groups.push( endfunc, 'endforeach', data )
end
