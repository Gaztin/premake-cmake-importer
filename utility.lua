local p = premake
local m = premake.extensions.impcmake

function m.isStringLiteral( str )
	return ( str:startswith( '"' ) and str:endswith( '"' ) )
end
