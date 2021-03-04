local p = premake
local m = p.extensions.impcmake

local function endmacro( commands, data )
	m.commands[ data.name ] = function( cmd )
		for i,command in ipairs( commands ) do
			m.executeCommand( command )
		end
	end
end

m.commands[ 'macro' ] = function( cmd )
	local data = {
		name = cmd.arguments[ 1 ],
	}

	m.groups.push( 'macro', 'endmacro', endmacro, data )
end
