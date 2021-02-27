local p = premake
local m = p.extensions.impcmake

function m.commands.set_property( cmd )
	local index           = 1
	local scope           = cmd.arguments[ index ]
	local propertyHandler = nil
	local meta            = nil
	local options         = { 'APPEND', 'APPEND_STRING' }
	index                 = index + 1

	if( scope == 'GLOBAL' ) then
		propertyHandler = function( meta, property, values )
			p.warn( 'Unhandled property %s in GLOBAL scope', property )
		end

	elseif( scope == 'DIRECTORY' ) then
		local dir = cmd.arguments[ index ]
		index     = index + 1

		propertyHandler = function( dir, property, values )
			p.warn( 'Unhandled property %s in DIRECTORY scope', property )
		end
		meta = dir

	elseif( scope == 'TARGET' ) then
		local targets = { }

		propertyHandler = function( targets, property, values )
			p.warn( 'Unhandled property %s in TARGET scope', property )
		end

		while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
			table.insert( targets, cmd.arguments[ index ] )
			index = index + 1
		end

		meta = targets

	elseif( scope == 'SOURCE' ) then
		local sources = { }

		propertyHandler = function( sources, property, values )
			p.warn( 'Unhandled property %s in SOURCE scope', property )
		end

		while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
			table.insert( sources, cmd.arguments[ index ] )
			index = index + 1
		end

		meta = sources

	elseif( scope == 'INSTALL' ) then
		local installFiles = { }

		propertyHandler = function( installFiles, property, values )
			p.warn( 'Unhandled property %s in INSTALL scope', property )
		end

		while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
			table.insert( installFiles, cmd.arguments[ index ] )
			index = index + 1
		end

		meta = installFiles

	elseif( scope == 'TEST' ) then
		local tests = { }

		propertyHandler = function( tests, property, values )
			p.warn( 'Unhandled property %s in TEST scope', property )
		end

		while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
			table.insert( tests, cmd.arguments[ index ] )
			index = index + 1
		end

		meta = tests

	elseif( scope == 'CACHE' ) then
		local entries = { }

		propertyHandler = function( entries, property, values )
			if( property == 'STRINGS' ) then
				for _,entry in ipairs( entries ) do
					m.cache_entries_allowed[ entry ] = values
				end
			else
				p.warn( 'Unhandled property %s in CACHE scope', property )
			end
		end

		while( ( not table.contains( options, cmd.arguments[ index ] ) ) and ( cmd.arguments[ index ] ~= 'PROPERTY' ) ) do
			table.insert( entries, cmd.arguments[ index ] )
			index = index + 1
		end

		meta = entries

	else
		p.error( 'Unhandled scope for "%s"', cmd.name )
	end

	-- Additional options
	while( cmd.arguments[ index ] ~= 'PROPERTY' ) do
		local option = cmd.arguments[ index ]

		if( option == 'APPEND' ) then
			-- TODO: Implement APPEND
		elseif( option == 'APPEND_STRING' ) then
			-- TODO: Implement APPEND_STRING
		else
			p.error( 'Unhandled option "%s" for command "%s"', option, cmd.name )
		end

		index = index + 1
	end
	index = index + 1

	local property = cmd.arguments[ index ]
	local values   = { }
	index = index + 1

	for i = index, #cmd.arguments do
		table.insert( values, cmd.arguments[ i ] )
	end

	propertyHandler( meta, property, values )
end
