local p      = premake
local m      = p.extensions.impcmake
m.conditions = { }

function m.conditions.evalExpression( str )
	-- Recursively expand conditions within this condition. Resolves parentheses wthin parentheses.
	local leftParenthesis, rightParenthesis = m.findMatchingParentheses( str )
	while( leftParenthesis ) do
		local capturedConditions          = string.sub( str, leftParenthesis + 1, rightParenthesis - 1 )
		local capturedExpansion           = m.conditions.evalExpression( capturedConditions )
		str                               = string.sub( str, 1, leftParenthesis - 1 ) .. iif( capturedExpansion, m.TRUE, m.FALSE ) .. string.sub( str, rightParenthesis + 1 )
		leftParenthesis, rightParenthesis = m.findMatchingParentheses( str )
	end

	-- Parse symbols
	local conditions          = { }
	local insideStringLiteral = false
	local expressionStart     = 1
	for i = 1, #str do
		local c = str:sub( i, i )

		if( c == '"' ) then
			insideStringLiteral = not insideStringLiteral
		elseif( c == ' ' and not insideStringLiteral ) then
			if( expressionStart < i ) then
				table.insert( conditions, str:sub( expressionStart, i - 1 ) )
			end
			expressionStart = i + 1
		end
	end
	table.insert( conditions, str:sub( expressionStart ) )

	local expressions = { }
	local unary_ops   = {
		'EXISTS', 'COMMAND', 'DEFINED',
	}
	local binary_ops  = {
		'EQUAL',              'LESS',             'LESS_EQUAL',            'GREATER',
		'GREATER_EQUAL',      'STREQUAL',         'STRLESS',               'STRLESS_EQUAL',
		'STRGREATER',         'STRGREATER_EQUAL', 'VERSION_EQUAL',         'VERSION_LESS',
		'VERSION_LESS_EQUAL', 'VERSION_GREATER',  'VERSION_GREATER_EQUAL', 'MATCHES',
	}
	local bool_ops    = {
		'NOT', 'AND', 'OR',
	}

	-- Parse expressions
	for i = 1, #conditions do
		local expr   = { }
		expr.value   = conditions[ i ]
		expr.op_type = ( table.contains( unary_ops,  expr.value ) and m.OP_TYPE.UNARY  or 0 )
		             | ( table.contains( binary_ops, expr.value ) and m.OP_TYPE.BINARY or 0 )
		             | ( table.contains( bool_ops,   expr.value ) and m.OP_TYPE.BOOL   or 0 )

		-- Determine what type the constant is
		if( expr.op_type == m.OP_TYPE.CONSTANT ) then
			expr.value = m.resolveVariables( expr.value )
			if( m.isStringLiteral( expr.value ) ) then
				expr.value = string.sub( expr.value, 2, #expr.value - 1 )
			else
				expr.value = tonumber( expr.value ) or m.expandVariable( expr.value, expr.value )
			end
		end

		table.insert( expressions, expr )
	end

	-- Unary tests. Analyzes @expressions[ 2 ] -> @expressions[ #expressions ]
	local i = 1
	while( ( i + 1 ) <= #expressions ) do
		i = i + 1

		local which_op      = expressions[ i - 1 ].value
		local do_unary_test = table.contains( unary_ops, which_op )

		if( do_unary_test ) then
			local constexpr = expressions[ i ]
			local newExpr   = {
				op_type = m.OP_TYPE.CONSTANT,
				value   = nil,
			}

			if( which_op == 'EXISTS' ) then
				p.warn( 'conditions: EXISTS not supported!' )
				newExpr.value = false

			elseif( which_op == 'COMMAND' ) then
				p.warn( 'conditions: COMMAND not supported!' )
				newExpr.value = false

			elseif( which_op == 'DEFINED' ) then
				local defined = m.expandVariable( constexpr.value )
				newExpr.value = defined ~= m.NOTFOUND
			end

			-- Replace operator and argument with a combined evaluation
			i = i - 1
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.insert( expressions, i, newExpr )
		end
	end

	-- Binary tests. Analyzes @expressions[ 2 ] -> @expressions[ #expressions - 1 ]
	local i = 1
	while( ( i + 1 ) < #expressions ) do
		i = i + 1

		local which_op       = expressions[ i ].value
		local do_binary_test = table.contains( binary_ops, which_op )

		if( do_binary_test ) then
			local lhs     = expressions[ i - 1 ]
			local rhs     = expressions[ i + 1 ]
			local newexpr = {
				op_type = m.OP_TYPE.CONSTANT,
				value   = nil,
			}

			    if( which_op == 'EQUAL'                 ) then newexpr.value = ( lhs.value == rhs.value )
			elseif( which_op == 'LESS'                  ) then newexpr.value = ( lhs.value <  rhs.value )
			elseif( which_op == 'LESS_EQUAL'            ) then newexpr.value = ( lhs.value <= rhs.value )
			elseif( which_op == 'GREATER'               ) then newexpr.value = ( lhs.value >  rhs.value )
			elseif( which_op == 'GREATER_EQUAL'         ) then newexpr.value = ( lhs.value >= rhs.value )
			-- TODO: Properly implement these binary operators
			elseif( which_op == 'STREQUAL'              ) then newexpr.value = ( lhs.value == rhs.value )
			elseif( which_op == 'STRLESS'               ) then newexpr.value = ( lhs.value <  rhs.value )
			elseif( which_op == 'STRLESS_EQUAL'         ) then newexpr.value = ( lhs.value <= rhs.value )
			elseif( which_op == 'STRGREATER'            ) then newexpr.value = ( lhs.value >  rhs.value )
			elseif( which_op == 'STRGREATER_EQUAL'      ) then newexpr.value = ( lhs.value >= rhs.value )
			elseif( which_op == 'VERSION_EQUAL'         ) then newexpr.value = ( lhs.value == rhs.value )
			elseif( which_op == 'VERSION_LESS'          ) then newexpr.value = ( lhs.value <  rhs.value )
			elseif( which_op == 'VERSION_LESS_EQUAL'    ) then newexpr.value = ( lhs.value <= rhs.value )
			elseif( which_op == 'VERSION_GREATER'       ) then newexpr.value = ( lhs.value >  rhs.value )
			elseif( which_op == 'VERSION_GREATER_EQUAL' ) then newexpr.value = ( lhs.value >= rhs.value )
			elseif( which_op == 'MATCHES'               ) then newexpr.value = ( lhs.value == rhs.value )
			end

			if( newexpr.value == nil ) then
				p.error( 'Unable to solve test due to unhandled binary operator "%s"', which_op )
			end

			-- Replace both arguments and the operator with the combined evaluation
			i = i - 1
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.insert( expressions, i, newexpr )
		end
	end

	-- Boolean NOT operations. Analyzes @expressions[ 2 ] -> @expressions[ #expressions ]
	local i = 1
	while( ( i + 1 ) <= #expressions ) do
		i = i + 1

		local notexpr = expressions[ i - 1 ]

		if( notexpr.value == 'NOT' ) then
			local constexpr = expressions[ i ]
			local newexpr   = {
				op_type = m.OP_TYPE.CONSTANT,
				value   = ( not m.isTrue( constexpr.value ) ),
			}

			-- Replace both the NOT and the constant expressions with a combined evaluation
			i = i - 1
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.insert( expressions, i, newexpr )
		end
	end

	-- Boolean AND operations. Analyzes @expressions[ 2 ] -> @expressions[ #expressions - 1 ]
	local i = 1
	while( ( i + 1 ) < #expressions ) do
		i = i + 1

		local andexpr = expressions[ i ]

		if( andexpr.value == 'AND' ) then
			local lhs     = expressions[ i - 1 ]
			local rhs     = expressions[ i + 1 ]
			local newexpr = {
				op_type = m.OP_TYPE.CONSTANT,
				value   = ( lhs.value and rhs.value ),
			}

			-- Replace both arguments and the operator with a combined evaluation
			i = i - 1
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.insert( expressions, i, newexpr )
		end
	end

	-- Boolean OR operations. Analyzes @expressions[ 2 ] -> @expressions[ #expressions - 1 ]
	local i = 1
	while( ( i + 1 ) < #expressions ) do
		i = i + 1

		local orexpr = expressions[ i ]

		if( orexpr.value == 'OR' ) then
			local lhs     = expressions[ i - 1 ]
			local rhs     = expressions[ i + 1 ]
			local newexpr = {
				op_type = m.OP_TYPE.CONSTANT,
				value   = ( lhs.value or rhs.value ),
			}

			-- Replace both arguments and the operator with a combined evaluation
			i = i - 1
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.remove( expressions, i )
			table.insert( expressions, i, newexpr )
		end
	end

	local test = true
	for _,expr in ipairs( expressions ) do
		test = test and m.isTrue( expr.value )
	end

	return test
end
