local p      = premake
local m      = p.extensions.impcmake
m.indent     = 0
m.commands   = { }

function m.executeCommand( cmd )
	if( m.groups.recording ) then
		m.groups.record( cmd )
	else
		local callback = m.commands[ cmd.name ]
		if( callback ) then
			verbosef( '%s> %s (%s)', string.rep( '-', m.indent + 1 ), cmd.name, cmd.argString )

			-- Resolve variables and remove quotation marks before invoking command
			cmd           = table.deepcopy( cmd )
			cmd.argString = m.resolveVariables( cmd.argString )

			for i=1,#cmd.arguments do
				cmd.arguments[ i ] = m.resolveVariables( cmd.arguments[ i ] )

				if( m.isStringLiteral( cmd.arguments[ i ] ) ) then
					cmd.arguments[ i ] = string.sub( cmd.arguments[ i ], 2, string.len( cmd.arguments[ i ] ) - 1 )
				end
			end

			m.indent = m.indent + 1
			callback( cmd )
			m.indent = m.indent - 1

			return true
		else
			p.warn( 'Unhandled command: "%s" with arguments: [%s]', cmd.name, table.concat( cmd.arguments, ', ' ) )
			return false
		end
	end
end

function m.resolveAlias( name )
	for k,v in pairs( m.aliases ) do
		if( k == name ) then
			return v
		end
	end
	return name
end

-- Require all scripts inside the commands directory
for i,match in ipairs( os.matchfiles( 'commands/*.lua' ) ) do
	require( path.replaceextension( match, '' ) )
end
