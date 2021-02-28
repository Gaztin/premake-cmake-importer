local p               = premake
local m               = p.extensions.impcmake
m.functions           = { }
m.functions.entries   = { }
m.functions.recording = false

local function findEntry( name )
	for i,entry in ipairs( m.functions.entries ) do
		if( entry.name == name ) then
			return entry
		end
	end
end

function m.functions.startRecording( name )
	local entry = findEntry( name )
	if( not entry ) then
		entry = { name = name }
		table.insert( m.functions.entries, entry )
	end

	entry.commands        = { }
	m.functions.recording = true
end

function m.functions.endRecording()
	m.functions.recording = false
end

function m.functions.record( cmd )
	if( cmd.name == 'endfunction' or cmd.name == 'endmacro' ) then
		m.functions.endRecording()
	else
		local entry = m.functions.entries[ #m.functions.entries ]
		table.insert( entry.commands, cmd )
	end
end

function m.functions.invoke( name, ... )
	local entry = findEntry( name )
	if( entry == nil ) then
		p.error( 'Cannot invoke function "%s". Function entry missing!', name )
	end

	local condscope  = { }
	condscope.parent = nil
	condscope.tests  = { true }

	for i,cmd in ipairs( entry.commands ) do
		local lastTest = iif( #condscope.tests > 0, condscope.tests[ #condscope.tests ], false )

		-- Skip commands if last test failed
		if( lastTest or cmd.name == 'if' or cmd.name == 'elseif' or cmd.name == 'else' or cmd.name == 'endif' ) then
			-- Create pointer wrapper so that @m.executeCommand may modify our original @condscope variable
			local condscope__refwrap = { ptr = condscope }

			if( not m.executeCommand( cmd, condscope__refwrap ) ) then
				-- Warn about unhandled command
				p.warn( 'Unhandled command: "%s" with arguments: [%s]', cmd.name, table.implode( cmd.arguments, '', '', ', ' ) )
			end

			-- Patch possibly new pointer
			condscope = condscope__refwrap.ptr
		end
	end
end
