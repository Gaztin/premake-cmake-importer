local p = premake
local m = p.extensions.impcmake
local l = { }
m.scope = { }

-- Push new scope
function m.scope.push()
	local prev_scope = l.current
	local next_scope = {
		variables = { }
	}

	l.current        = next_scope
	l.current.parent = prev_scope

	return next_scope
end

-- Pop scope
function m.scope.pop()
	l.current = l.current.parent
end

-- Get current scope
function m.scope.current()
	return l.current
end
