local p = premake
local m = p.extensions.impcmake

function m.resolveVariables( str )
	-- Global variables
	repeat
		st, en = string.find( str, '${%S+}' )

		if( st ~= nil ) then
			local var   = string.sub( str, st + 2, en - 1 )
			local vars  = p.api.scope.current.cmakevariables
			local value = vars[ var ]

			if( value ~= nil ) then
				local detokenizedValue = p.detoken.expand( value, vars )
				str = string.sub( str, 1, st - 1 ) .. detokenizedValue .. string.sub( str, en + 1 )
			else
				str = string.sub( str, 1, st - 1 ) .. string.sub( str, en + 1 )
			end
		end
	until( st == nil )

	-- Environment variables
	repeat
		st, en = string.find( str, '$ENV{%S+}' )

		if( st ~= nil ) then
			local var   = string.sub( str, st + 5, en - 1 )
			local value = os.getenv( var )

			if( value ~= nil ) then
				local detokenizedValue = p.detoken.expand( value, vars )
				str = string.sub( str, 1, st - 1 ) .. detokenizedValue .. string.sub( str, en + 1 )
			else
				str = string.sub( str, 1, st - 1 ) .. string.sub( str, en + 1 )
			end
		end
	until( st == nil )

	-- TODO: $CACHE{%S+}

	return str
end

function m.expandVariable( var )
	return p.api.scope.current.cmakevariables[ var ] or m.NOTFOUND
end

function m.isStringLiteral( str )
	return ( str:startswith( '"' ) and str:endswith( '"' ) )
end

function m.toRawString( str )
	str = m.resolveVariables( str )

	if( m.isStringLiteral( str ) ) then
		return str:gsub( '^"(.*)"', '%1' )
	else
		return str
	end
end
