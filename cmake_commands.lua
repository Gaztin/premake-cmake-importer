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
			cmd.argString = m.expandVariables( cmd.argString )

			local i = 1
			repeat
				cmd.arguments[ i ] = m.expandVariables( cmd.arguments[ i ] )
				-- After resolving, ${my_var} may have been expanded into 'Foo Bar' which should
				-- replace the previous argument as two new arguments
				local splitArguments = m.splitTerms( cmd.arguments[ i ] )
				if( #splitArguments > 1 ) then
					table.remove( cmd.arguments, i )
					for _,arg in ipairs( splitArguments ) do
						table.insert( cmd.arguments, i, arg )
						i = i + 1
					end
				end

				i = i + 1
			until( i > #cmd.arguments )

			m.indent()

			if( _OPTIONS.verbose ) then
				m.profiling.recordFunction( cmd.name, callback, cmd )
			else
				callback( cmd )
			end

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
