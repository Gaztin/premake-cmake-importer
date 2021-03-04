local p = premake
local m = p.extensions.impcmake

local function specializeCommands( cmd, commands, params )
	-- Make sure the number of arguments are equal or more than the number of parameters
	if( #cmd.arguments < #params ) then
		p.error( 'Macro "%s" was called with too few arguments. Expected %d but received %d!', cmd.name, #params, #cmd.arguments )
	end

	local replacements = {
		[ '${ARGC}' ] = #cmd.arguments,
		[ '${ARGV}' ] = table.concat( cmd.arguments, ';' ),
		[ '${ARGN}' ] = table.concat( { table.unpack( cmd.arguments, #params + 1 ) }, ';' ),
	}

	for i,param in ipairs( params ) do
		replacements[ '${' .. param .. '}' ] = cmd.arguments[ i ]
	end

	for i,arg in ipairs( cmd.arguments ) do
		replacements[ '${ARGV' .. i .. '}' ] = arg
	end

	local newCommands = table.deepcopy( commands )
	for _,command in ipairs( newCommands ) do
		for i=1,#command.arguments do
			for replacee,replacement in pairs( replacements ) do
				command.arguments[ i ] = string.gsub( command.arguments[ i ], replacee, replacement )
			end
		end
	end

	return newCommands
end

local function endmacro( commands, data )
	m.commands[ data.name:lower() ] = function( cmd )
		local specializedCommands = specializeCommands( cmd, commands, data.parameters )

		for i,command in ipairs( specializedCommands ) do
			m.executeCommand( command )
		end
	end
end

m.commands[ 'macro' ] = function( cmd )
	local data = {
		name       = cmd.arguments[ 1 ],
		parameters = { table.unpack( cmd.arguments, 2 ) },
	}

	m.groups.push( 'macro', 'endmacro', endmacro, data )
end
