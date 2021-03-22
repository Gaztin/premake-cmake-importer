local p      = premake
local m      = p.extensions.impcmake
local indent = 0
m.commands   = { }

function m.indent()
	indent = indent + 1
end

function m.unindent()
	indent = indent - 1
end

local function getScopeDepthString()
	local scope = m.scope.current()
	local level = 0

	while( scope ) do
		scope = scope.parent
		level = level + 1
	end

	return string.format( 'L%X| ', level )
end

function m.verbose( str, offset )
	local indentation = string.rep( '  ', indent + ( offset or 0 ) )
	verbosef( getScopeDepthString() .. indentation .. str )
end

function m.executeCommand( cmd )
	if( m.groups.recording ) then
		m.groups.record( cmd )
	else
		local callback = m.commands[ cmd.name ]
		if( callback ) then
			m.verbose( cmd.name .. '(' .. cmd.argString .. ')' )

			-- Resolve variables and remove quotation marks before invoking command
			cmd           = table.deepcopy( cmd )
			cmd.argString = m.expandVariables( cmd.argString )
			for i, arg in ipairs( cmd.arguments ) do
				cmd.arguments[ i ] = m.expandVariables( arg )
			end

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
