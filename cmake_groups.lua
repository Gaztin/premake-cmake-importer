local p            = premake
local m            = p.extensions.impcmake
local l            = { }
m.groups           = { }
m.groups.recording = false

-- Push new group
function m.groups.push( endfunc, endcommand, userData )
	local group = {
		endfunc    = endfunc,
		endcommand = endcommand,
		parent     = l.current,
		commands   = { },
		userData   = userData,
	}

	l.current          = group
	m.groups.recording = true
end

-- Pop group
function m.groups.pop()
	local group        = l.current
	l.current          = l.current.parent
	m.groups.recording = l.current ~= nil

	return group
end

-- Record command
function m.groups.record( cmd )
	if( cmd.name == l.current.endcommand ) then
		local group = m.groups.pop()
		group.endfunc( group.commands, group.userData )
	else
		table.insert( l.current.commands, cmd )
	end
end
