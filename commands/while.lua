local p = premake
local m = p.extensions.impcmake

local function endwhile( commands, data )
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

	local iterations = 0
	while( m.conditions.evalExpression( data.expression ) ) do
		if( iterations > 0 ) then
			verbosef( m.indentation( -1 ) .. 'nextwhile' )
		end

		for i,command in ipairs( commands ) do
			m.executeCommand( command )

			if( shouldContinue ) then
				shouldContinue = false
				break
			end
		end

		iterations = iterations + 1

		if( shouldBreak ) then
			break
		end
	end

	m.unindent()
	verbosef( m.indentation() .. 'endwhile' )

	m.commands[ 'break' ]    = prevBreak
	m.commands[ 'continue' ] = prevContinue
end

m.commands[ 'while' ] = function( cmd )
	local data = {
		expression = cmd.argString,
	}

	m.groups.push( 'while', 'endwhile', endwhile, data )
end
