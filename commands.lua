local p    = premake
local m    = p.extensions.impcmake
m.commands = { }

function m.executeCommand( cmd, condscope__refwrap )
	local command = m.commands[ cmd.name ]
	if( command ~= nil ) then
		command( cmd, condscope__refwrap )
		return true
	else
		return false
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
