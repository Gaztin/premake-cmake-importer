local p = premake
local m = p.extensions.impcmake

local function endif( commands, data )
	local i = 1
	repeat
		if( not m.groups.recording ) then
			if( commands[ i ].name == 'elseif' ) then
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = m.conditions.evalExpression( table.concat( commands[ i ].arguments, ' ' ) )
				i              = i + 1
			elseif( commands[ i ].name == 'else' ) then
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = not data.lastCheck
				i              = i + 1
			end
		end

		if( data.lastCheck and not data.handled ) then
			m.executeCommand( commands[ i ] )
		end
		
		i = i + 1
	until( i > #commands )
end

m.commands[ 'if' ] = function( cmd )
	local data = {
		lastCheck = m.conditions.evalExpression( table.concat( cmd.arguments, ' ' ) ),
		handled   = false,
	}

	m.groups.push( 'if', 'endif', endif, data )
end
