local p = premake
local m = p.extensions.impcmake

function m.commands.set_target_properties( cmd )
	local keywordIndex = table.indexof( cmd.arguments, 'PROPERTIES' )
	local targets      = table.pack( table.unpack( cmd.arguments, 1, keywordIndex - 1 ) )

	for i = keywordIndex + 1, #cmd.arguments, 2 do
		local prop  = cmd.arguments[ i ]
		local value = cmd.arguments[ i + 1 ]
		for _,target in ipairs( targets ) do
			m.properties.setTargetProperty( target, prop, value )
		end
	end
end
