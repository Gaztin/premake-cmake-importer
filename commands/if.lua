local p = premake
local m = p.extensions.impcmake

local function endif( commands, data )
	local nestLevel = 0
	m.indent()

	for i,command in ipairs( commands ) do
		if( not data.handled ) then
			if( command.name == 'if' ) then
				nestLevel = nestLevel + 1
			elseif( command.name == 'endif' ) then
				nestLevel = nestLevel - 1
			end

			if( nestLevel == 0 and command.name == 'elseif' ) then
				verbosef( m.indentation( -1 ) .. 'elseif (%s)', command.argString )
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = m.conditions.evalExpression( command.argString )
			elseif( nestLevel == 0 and command.name == 'else' ) then
				verbosef( m.indentation( -1 ) .. 'else' )
				data.handled   = data.handled or data.lastCheck
				data.lastCheck = not data.lastCheck
			elseif( data.lastCheck ) then
				m.executeCommand( command )
			end
		end
	end

	m.unindent()
	verbosef( m.indentation() .. 'endif' )
end

m.commands[ 'if' ] = function( cmd )
	local data = {
		lastCheck = m.conditions.evalExpression( cmd.argString ),
		handled   = false,
	}

	m.groups.push( 'if', 'endif', endif, data )
end
