local p = premake
local m = p.extensions.impcmake

local function endif( commands, data )
	local nestLevel = 0
	for i,command in ipairs( commands ) do
		if( command.name == 'if' ) then
			nestLevel = nestLevel + 1
		elseif( command.name == 'endif' ) then
			nestLevel = nestLevel - 1
		end

		if( not data.handled ) then
			if( nestLevel == 0 and command.name == 'elseif' ) then
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = m.conditions.evalExpression( table.concat( command.arguments, ' ' ) )
			elseif( nestLevel == 0 and command.name == 'else' ) then
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = not data.lastCheck
			else
				if( data.lastCheck ) then
					m.executeCommand( command )
				end
			end
		end
	end
end

m.commands[ 'if' ] = function( cmd )
	local data = {
		lastCheck = m.conditions.evalExpression( table.concat( cmd.arguments, ' ' ) ),
		handled   = false,
	}

	m.groups.push( 'if', 'endif', endif, data )
end
