local p             = premake
local m             = p.extensions.impcmake
m.profiling         = { }
m.profiling.entries = { }

function m.profiling.recordFunction( key, func, ... )
	local now = os.clock()

	func( ... )

	m.profiling.entries[ key ] = ( m.profiling.entries[ key ] or 0 ) + ( os.clock() - now )
end

function m.profiling.printReport()
	term.pushColor( term.yellow )

	print( '\n[[-Profiling report-]]' )

	local sortedEntries = { }
	for key,duration in pairs( m.profiling.entries ) do
		if( duration > 0 ) then
			local sortableEntry = { key = key, duration = duration }
			table.insertsorted( sortedEntries, sortableEntry, function( a, b ) return a.duration > b.duration end )
		end
	end

	for i,entry in ipairs( sortedEntries ) do
		printf( '%5.3fs: %s', entry.duration, entry.key )
	end

	print( '' )

	term.popColor()
end
