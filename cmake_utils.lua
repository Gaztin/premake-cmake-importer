local p = premake
local m = p.extensions.impcmake

function m.splitTerms( text )
	local head  = string.find( text, '%S' )
	local terms = { }

	while( head ) do
		local leftQuotationMark = string.find( text, '"', head, true )

		if( leftQuotationMark and leftQuotationMark == head ) then
			local rightQuotationMark = string.find( text, '"',  leftQuotationMark  + 1, true )
			local term               = string.sub( text, leftQuotationMark, rightQuotationMark )
			head                     = string.find( text, '%S', rightQuotationMark + 1, false )
			table.insert( terms, term )
		else
			local nextSpace = string.find( text, '%s', head )
			local tail      = nextSpace and ( nextSpace - 1 )
			local term      = string.sub( text, head, tail )
			head            = tail and string.find( text, '%S', tail + 1, false )
			table.insert( terms, term )
		end
	end

	return terms
end

function m.isTrue( value )
	if( value == nil ) then
		return false
	end

	local t = type( value )

	if( t == 'boolean' ) then
		return value
	elseif( t == 'number' ) then
		return ( value ~= 0 )
	elseif( t == 'string' ) then
		if( m.isStringLiteral( value ) ) then
			return true
		elseif( ( value == m.ON ) or ( value == m.YES ) or ( value == m.TRUE ) or ( value == m.Y ) ) then
			return true
		elseif( ( value == m.OFF ) or ( value == m.NO ) or ( value == m.FALSE ) or ( value == m.N ) or ( value == m.IGNORE ) or ( value == m.NOTFOUND ) ) then
			return false
		elseif( tonumber( value ) ~= nil ) then
			return ( tonumber( value ) ~= 0 )
		end

		return m.isTrue( m.expandVariable( value ) )
	end

	p.error( '"%s" is not an eligible type for a CMake constant', t )

	return false
end

function m.resolveVariables( str )
	-- Global variables
	repeat
		local st, en = string.find( str, '${%S+}' )

		if( st ~= nil ) then
			local var   = m.resolveVariables( string.sub( str, st + 2, en - 1 ) )
			local scope = m.scope.current()
			local value

			-- Find variable definition in parent scopes
			while( value == nil and scope ~= nil ) do
				value = scope.variables[ var ]
				scope = scope.parent
			end

			str = string.sub( str, 1, st - 1 ) .. ( value or '' ) .. string.sub( str, en + 1 )
		end
	until( st == nil )

	-- Environment variables
	repeat
		local st, en = string.find( str, '$ENV{%S+}' )

		if( st ~= nil ) then
			local var   = m.resolveVariables( string.sub( str, st + 5, en - 1 ) )
			local value = os.getenv( var ) or ''
			str         = string.sub( str, 1, st - 1 ) .. value .. string.sub( str, en + 1 )
		end
	until( st == nil )

	-- Cache variables
	repeat
		local st, en = string.find( str, '$CACHE{%S+}' )

		if( st ~= nil ) then
			local var   = m.resolveVariables( string.sub( str, st + 5, en - 1 ) )
			local value = m.cache_entries[ var ] or ''

			str = string.sub( str, 1, st - 1 ) .. value .. string.sub( str, en + 1 )
		end
	until( st == nil )

	return str
end

function m.expandVariable( var, defaultValue )
	local cacheVar = string.match( var, 'CACHE{(.+)}' )
	if( cacheVar ) then
		return m.cache_entries[ cacheVar ]
	end

	local envVar = string.match( var, 'ENV{(.+)}' )
	if( envVar ) then
		return os.getenv( envVar )
	end

	local scope = m.scope.current()
	while( scope ~= nil ) do
		local scopeVar = scope.variables[ var ]
		if( scopeVar ~= nil ) then
			return scopeVar
		end

		scope = scope.parent
	end

	return m.cache_entries[ var ] or defaultValue or m.NOTFOUND
end

function m.isStringLiteral( str )
	return ( str:startswith( '"' ) and str:endswith( '"' ) )
end

function m.toStringLiteral( str )
	return m.isStringLiteral( str ) and str or ( '"' .. str .. '"' )
end

function m.findUncaptured( str, delim, startIndex )
	-- Finds a substring within a string, but ignores any delimeters inside quotation marks
	-- Firstly, replace all occurrances of: \"
	-- But be careful, because we might run into a string that looks like: "\\" in which case we do not want to replace \" because that will turn into "\
	-- So first of all, replace all occurrances of \\ with something else, THEN replace every occurrance of \".
	local temp = str
	temp       = temp:gsub( '\\\\', '__' )
	temp       = temp:gsub( '\\\"', '__' )

	startIndex = startIndex or 1

	local captured = false
	for i = startIndex, #temp do
		-- TODO: delim might be multiple characters
		local char = temp:sub( i, i )

		if( char == '\"' ) then
			captured = not captured
		elseif( char == delim and not captured ) then
			return i
		end
	end

	return nil
end

function m.findMatchingParentheses( str, index )
	local left = m.findUncaptured( str, '(', index )
	if( left == nil ) then
		return nil
	end

	local numOpenParentheses = 1
	local nxt = left

	repeat
		local nextRight = m.findUncaptured( str, ')', nxt + 1 )
		nxt             = m.findUncaptured( str, '(', nxt + 1 )

		if( nxt and ( nextRight and nxt < nextRight ) or ( not nextRight ) ) then
			numOpenParentheses = numOpenParentheses + 1
		elseif( nextRight ) then
			numOpenParentheses = numOpenParentheses - 1
			nxt = nextRight

			if( numOpenParentheses == 0 ) then
				return left, nxt
			end
		end

	until( nxt == nil )

	return nil
end

function m.replace( text, replacee, replacement )
	local st, en = string.find( text, replacee, 1, true )
	if( st ) then
		return string.sub( text, 1, st - 1 ) .. replacement .. m.replace( string.sub( text, en + 1 ), replacee, replacement )
	else
		return text
	end
end
