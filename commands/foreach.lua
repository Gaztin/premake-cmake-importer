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

function m.commands.foreach( cmd )
	if( #cmd.arguments == 2 ) then
		local data = {
			loopVar = cmd.arguments[ 1 ],
			items   = string.explode( m.resolveVariables( cmd.arguments[ 2 ] ), ';' ),
		}

		m.groups.push( endfunc, 'endforeach', data )
	else
		local data = {
			loopVar = cmd.arguments[ 1 ],
			items   = { },
		}

		p.warn( 'Only simple foreach loops are fully supported' )

		m.groups.push( endfunc, 'endforeach', data )
	end
end
