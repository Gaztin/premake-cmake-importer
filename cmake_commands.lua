local p      = premake
local m      = p.extensions.impcmake
local indent = 0
m.commands   = { }

function m.indentation( offset )
	return string.rep( '  ', indent + ( offset or 0 ) )
end

function m.indent()
	indent = indent + 1
end

function m.unindent()
	indent = indent - 1
end

function m.executeCommand( cmd )
	if( m.groups.recording ) then
		m.groups.record( cmd )
	else
		local callback = m.commands[ cmd.name ]
		if( callback ) then
			verbosef( m.indentation() .. '%s (%s)', cmd.name, cmd.argString )

			-- Resolve variables and remove quotation marks before invoking command
			cmd           = table.deepcopy( cmd )
			cmd.argString = m.resolveVariables( cmd.argString )

			for i=1,#cmd.arguments do
				cmd.arguments[ i ] = m.resolveVariables( cmd.arguments[ i ] )

				if( m.isStringLiteral( cmd.arguments[ i ] ) ) then
					cmd.arguments[ i ] = string.sub( cmd.arguments[ i ], 2, string.len( cmd.arguments[ i ] ) - 1 )
				end
			end

			m.indent()
			callback( cmd )
			m.unindent()

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
