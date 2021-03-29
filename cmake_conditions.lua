local p      = premake
local m      = p.extensions.impcmake
m.conditions = { }

local unaryOperators = {
	COMMAND = function( rhs )
		p.warn( 'conditions: COMMAND not supported!' )
		return false
	end,

	POLICY = function( rhs )
		p.warn( 'conditions: POLICY not supported!' )
		return false
	end,

	TARGET = function( rhs )
		p.warn( 'conditions: TARGET not supported!' )
		return false
	end,

	TEST = function( rhs )
		p.warn( 'conditions: TEST not supported!' )
		return false
	end,

	EXISTS = function( rhs )
		p.warn( 'conditions: EXISTS not supported!' )
		return false
	end,

	POLICY = function( rhs )
		p.warn( 'conditions: POLICY not supported!' )
		return false
	end,

	IS_DIRECTORY = function( rhs )
		p.warn( 'conditions: IS_DIRECTORY not supported!' )
		return false
	end,

	IS_SYMLINK = function( rhs )
		p.warn( 'conditions: IS_SYMLINK not supported!' )
		return false
	end,

	IS_ABSOLUTE = function( rhs )
		return path.isabsolute( rhs )
	end,
	
	DEFINED = function( rhs )
		local cacheVar = string.match( rhs, 'CACHE{(.+)}' )
		if( cacheVar ) then
			return m.cache_entries[ cacheVar ] ~= nil
		end

		local envVar = string.match( rhs, 'ENV{(.+)}' )
		if( envVar ) then
			return os.getenv( envVar ) ~= nil
		end

		return m.dereference( rhs ) ~= nil
	end,
}

local binaryOperators = {
	IS_NEWER_THAN = function( lhs, rhs )
		p.warn( 'conditions: %s IS_NEWER_THAN %s', lhs, rhs )
		return false
	end,

	MATCHES = function( lhs, regex )
		lhs = m.dereference( lhs ) or lhs
		return string.find( lhs, regex ) ~= nil
	end,

	LESS = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return lhs < rhs
	end,

	GREATER = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return lhs > rhs
	end,

	EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return lhs == rhs
	end,

	LESS_EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return lhs <= rhs
	end,

	GREATER_EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return lhs >= rhs
	end,

	STRLESS = function( lhs, rhs )
		p.warn( 'conditions: %s STRLESS %s', lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return false
	end,

	STRGREATER = function( lhs, rhs )
		p.warn( 'conditions: %s STRGREATER %s', lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return false
	end,

	STREQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return type( lhs ) == 'string' and type( rhs ) == 'string' and lhs == rhs
	end,

	STRLESS_EQUAL = function( lhs, rhs )
		p.warn( 'conditions: %s STRLESS_EQUAL %s', lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return false
	end,

	STRGREATER_EQUAL = function( lhs, rhs )
		p.warn( 'conditions: %s STRGREATER_EQUAL %s', lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return false
	end,

	VERSION_LESS = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		if( m.isVersionString( lhs ) and m.isVersionString( rhs ) ) then
			return m.compareVersions( lhs, rhs ) < 0
		end
		return false
	end,

	VERSION_GREATER = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		if( m.isVersionString( lhs ) and m.isVersionString( rhs ) ) then
			return m.compareVersions( lhs, rhs ) > 0
		end
		return false
	end,

	VERSION_EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		if( m.isVersionString( lhs ) and m.isVersionString( rhs ) ) then
			return m.compareVersions( lhs, rhs ) == 0
		end
		return false
	end,

	VERSION_LESS_EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		if( m.isVersionString( lhs ) and m.isVersionString( rhs ) ) then
			return m.compareVersions( lhs, rhs ) <= 0
		end
		return false
	end,

	VERSION_GREATER_EQUAL = function( lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		if( m.isVersionString( lhs ) and m.isVersionString( rhs ) ) then
			return m.compareVersions( lhs, rhs ) >= 0
		end
		return false
	end,

	IN_LIST = function( lhs, rhs )
		p.warn( 'conditions: %s IN_LIST %s', lhs, rhs )
		lhs = m.dereference( lhs ) or lhs
		rhs = m.dereference( rhs ) or rhs
		return false
	end,
}

local booleanOperators = {
	NOT = function( rhs )
		return not m.isTrue( rhs )
	end,

	AND = function( lhs, rhs )
		return m.isTrue( lhs ) and m.isTrue( rhs )
	end,

	OR = function( lhs, rhs )
		return m.isTrue( lhs ) or m.isTrue( rhs )
	end,
}

function m.conditions.evalExpression( str )
	-- Recursively expand conditions within this condition. Resolves parentheses wthin parentheses.
	local leftParenthesis, rightParenthesis = m.findMatchingParentheses( str )
	while( leftParenthesis ) do
		local capturedConditions          = string.sub( str, leftParenthesis + 1, rightParenthesis - 1 )
		local capturedExpansion           = m.conditions.evalExpression( capturedConditions )
		str                               = string.sub( str, 1, leftParenthesis - 1 ) .. iif( capturedExpansion, m.TRUE, m.FALSE ) .. string.sub( str, rightParenthesis + 1 )
		leftParenthesis, rightParenthesis = m.findMatchingParentheses( str )
	end

	-- Turn expression: (NOT ${var1} EQUAL "Foo Bar") into array: {NOT, ${var1}, EQUAL, "Foo Bar"}
	local terms = m.splitTerms( str )

	-- Expand variables and convert numbers
	for i=1,#terms do
		terms[ i ] = m.expandVariables( terms[ i ] )
	end

	-- Unary operations
	local i = 1
	while( i < #terms ) do
		local operator = unaryOperators[ terms[ i ] ]
		if( operator ) then
			terms[ i ] = operator( terms[ i + 1 ] )
			table.remove( terms, i + 1 )
			i = i + 0
		end
		i = i + 1
	end

	-- Binary operations
	local i = 1
	while( i < #terms ) do
		local operator = binaryOperators[ terms[ i ] ]
		if( operator ) then
			terms[ i ] = operator( terms[ i - 1 ], terms[ i + 1 ] )
			table.remove( terms, i + 1 )
			table.remove( terms, i - 1 )
			i = i - 1
		end
		i = i + 1
	end

	-- Boolean NOT operations
	local i = 1
	while( i < #terms ) do
		if( terms[ i ] == 'NOT' ) then
			terms[ i ] = booleanOperators.NOT( terms[ i + 1 ] )
			table.remove( terms, i + 1 )
			i = i + 0
		end
		i = i + 1
	end

	-- Boolean AND operations
	local i = 1
	while( i < #terms ) do
		if( terms[ i ] == 'AND' ) then
			terms[ i ] = booleanOperators.AND( terms[ i - 1 ], terms[ i + 1 ] )
			table.remove( terms, i + 1 )
			table.remove( terms, i - 1 )
			i = i - 1
		end
		i = i + 1
	end

	-- Boolean OR operations
	local i = 1
	while( i < #terms ) do
		if( terms[ i ] == 'OR' ) then
			terms[ i ] = booleanOperators.OR( terms[ i - 1 ], terms[ i + 1 ] )
			table.remove( terms, i + 1 )
			table.remove( terms, i - 1 )
			i = i - 1
		end
		i = i + 1
	end

	-- Terms should have boiled down to a single one at this point
	if( #terms ~= 1 ) then
		p.error( str, #terms )
	end

	return m.isTrue( terms[ 1 ] )
end
