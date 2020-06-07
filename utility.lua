local p = premake
local m = p.extensions.impcmake

function m.isTrue( value )
	if( value == nil ) then
		return false
	end

	local t = type( value )

	if( t == 'boolean' ) then
		return value
	elseif( t == 'number' ) then
		return ( value ~= 0 )
	elseif( t == 'string') then
		if( ( value == m.ON ) or ( value == m.YES ) or ( value == m.TRUE ) or ( value == m.Y ) ) then
			return true
		elseif( ( value == m.OFF ) or ( value == m.NO ) or ( value == m.FALSE ) or ( value == m.N ) or ( value == m.IGNORE ) or ( value == m.NOTFOUND ) ) then
			return false
		end

		return m.isTrue( m.expandVariable( value ) )
	end

	p.error( '"%s" is not an eligible type for a CMake constant', t )

	return false
end

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

function m.findMatchingParentheses( str, index )
	index = index or 1

	-- TODO: Don't count any parentheses inside string literals

	local left = string.find( str, '(', index, true )
	if( left == nil ) then
		return nil
	end

	local numOpenParentheses = 1

	-- Find matching right parenthesis
	for i = left + 1, #str do
		local c = str:sub( i, i )

		if( c == '(' ) then
			numOpenParentheses = numOpenParentheses + 1
		elseif( c == ')' ) then
			numOpenParentheses = numOpenParentheses - 1

			if( numOpenParentheses == 0 ) then
				return left, i
			end
		end
	end

	return nil
end
