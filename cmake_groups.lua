local p            = premake
local m            = p.extensions.impcmake
local l            = { }
m.groups           = { }
m.groups.recording = false

-- Push new group
function m.groups.push( head, tail, callback, userData )
	local group = {
		head       = head,
		tail       = tail,
		callback   = callback,
		parent     = l.current,
		commands   = { },
		userData   = userData,
		nestLevel  = 0,
	}

	l.current          = group
	m.groups.recording = true
end

-- Record command
function m.groups.record( cmd )
	if( cmd.name == l.current.head ) then
		l.current.nestLevel = l.current.nestLevel + 1
	elseif( cmd.name == l.current.tail ) then
		if( l.current.nestLevel > 0 ) then
			l.current.nestLevel = l.current.nestLevel - 1
		else
			local group        = l.current
			l.current          = l.current.parent
			m.groups.recording = l.current ~= nil
			group.callback( group.commands, group.userData )

			-- Avoid inserting tail command into list
			return
		end
	end

	table.insert( l.current.commands, cmd )
end
