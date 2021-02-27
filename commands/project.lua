local p = premake
local m = p.extensions.impcmake

function m.commands.project( cmd )
	local groupName = cmd.arguments[ 1 ]

	group( groupName )
end
