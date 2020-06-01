local p = premake
local m = p.extensions.impcmake

function m.isStringLiteral( str )
	return ( str:startswith( '"' ) and str:endswith( '"' ) )
end

function m.toRawString( str )
	if( m.isStringLiteral( str ) ) then
		return str:gsub( '^"(.*)"', '%1' )
	else
		return str
	end
end
