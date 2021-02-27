local p = premake
local m = p.extensions.impcmake

m.commands[ 'if' ] = function( cmd, condscope__refwrap )
	if( cmd.name == 'if' ) then
		local newscope         = { }
		newscope.parent        = condscope__refwrap.ptr
		newscope.tests         = { }
		condscope__refwrap.ptr = newscope

		if( ( #condscope__refwrap.ptr.parent.tests > 0 ) and ( condscope__refwrap.ptr.parent.tests[ #condscope__refwrap.ptr.parent.tests ] ) ) then
			table.insert( condscope__refwrap.ptr.tests, true )
		else
			return
		end

	elseif( cmd.name == 'elseif' ) then
		if( #condscope__refwrap.ptr.tests == 0 ) then
			return
		end

		-- Look at all tests except the first one, which is always true
		local tests = table.pack( select( 2, table.unpack( condscope__refwrap.ptr.tests ) ) )

		if( table.contains( tests, true ) ) then
			table.insert( condscope__refwrap.ptr.tests, false )
			return
		end
	end

	local test = m.expandConditions( cmd.argString )

	table.insert( condscope__refwrap.ptr.tests, test )
end

m.commands[ 'elseif' ] = m.commands[ 'if' ]

m.commands[ 'else' ] = function( cmd, condscope__refwrap )
	if( #condscope__refwrap.ptr.tests > 0 ) then
		-- Look at all tests except the first one, which is always true
		local tests = table.pack( select( 2, table.unpack( condscope__refwrap.ptr.tests ) ) )

		table.insert( condscope__refwrap.ptr.tests, not table.contains( tests, true ) )
	end
end

m.commands[ 'endif' ] = function( cmd, condscope__refwrap )
	condscope__refwrap.ptr = condscope__refwrap.ptr.parent
end
