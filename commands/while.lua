local p = premake
local m = p.extensions.impcmake

local function endwhile( commands, data )
	while( m.conditions.evalExpression( data.expression ) ) do
		for i,command in ipairs( commands ) do
			m.executeCommand( command )
		end
	end
end

m.commands[ 'while' ] = function( cmd )
	local data = {
		expression = cmd.argString,
	}

	m.groups.push( 'while', 'endwhile', endwhile, data )
end
