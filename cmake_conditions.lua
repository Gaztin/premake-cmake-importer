local p      = premake
local m      = p.extensions.impcmake
m.conditions = { }

local unaryOperators = {
	EXISTS = function( rhs )
		p.warn( 'conditions: EXISTS not supported!' )
	end,

	COMMAND = function( rhs )
		p.warn( 'conditions: COMMAND not supported!' )
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
	EQUAL                 = function( lhs, rhs )                                                     return lhs == rhs end,
	LESS                  = function( lhs, rhs )                                                     return lhs <  rhs end,
	LESS_EQUAL            = function( lhs, rhs )                                                     return lhs <= rhs end,
	GREATER               = function( lhs, rhs )                                                     return lhs >  rhs end,
	GREATER_EQUAL         = function( lhs, rhs )                                                     return lhs >= rhs end,
	STREQUAL              = function( lhs, rhs ) p.warn( 'STREQUAL(%s, %s)', lhs, rhs )              return lhs == rhs end,
	STRLESS               = function( lhs, rhs ) p.warn( 'STRLESS(%s, %s)', lhs, rhs )               return lhs <  rhs end,
	STRLESS_EQUAL         = function( lhs, rhs ) p.warn( 'STRLESS_EQUAL(%s, %s)', lhs, rhs )         return lhs <= rhs end,
	STRGREATER            = function( lhs, rhs ) p.warn( 'STRGREATER(%s, %s)', lhs, rhs )            return lhs >  rhs end,
	STRGREATER_EQUAL      = function( lhs, rhs ) p.warn( 'STRGREATER_EQUAL(%s, %s)', lhs, rhs )      return lhs >= rhs end,
	VERSION_EQUAL         = function( lhs, rhs ) p.warn( 'VERSION_EQUAL(%s, %s)', lhs, rhs )         return lhs == rhs end,
	VERSION_LESS          = function( lhs, rhs ) p.warn( 'VERSION_LESS(%s, %s)', lhs, rhs )          return lhs <  rhs end,
	VERSION_LESS_EQUAL    = function( lhs, rhs ) p.warn( 'VERSION_LESS_EQUAL(%s, %s)', lhs, rhs )    return lhs <= rhs end,
	VERSION_GREATER       = function( lhs, rhs ) p.warn( 'VERSION_GREATER(%s, %s)', lhs, rhs )       return lhs >  rhs end,
	VERSION_GREATER_EQUAL = function( lhs, rhs ) p.warn( 'VERSION_GREATER_EQUAL(%s, %s)', lhs, rhs ) return lhs >= rhs end,
	MATCHES               = function( lhs, rhs ) p.warn( 'MATCHES(%s, %s)', lhs, rhs )               return lhs == rhs end,
}

local booleanOperators = {
	NOT = function( rhs )      return not rhs end,
	AND = function( lhs, rhs ) return lhs and rhs end,
	OR  = function( lhs, rhs ) return lhs or rhs end,
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

	return terms[ 1 ]
end
