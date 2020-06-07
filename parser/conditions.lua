local p = premake
local m = p.extensions.impcmake

function m.expandConditions( str )
	-- Recursively expand conditions within this condition. Resolves parentheses wthin parentheses.
	local leftParenthesis, rightParenthesis = m.findMatchingParentheses( str )
	while( leftParenthesis ~= nil ) do
		local capturedConditions          = string.sub( str, leftParenthesis + 1, rightParenthesis - 1 )
		local capturedExpansion           = m.expandConditions( capturedConditions )
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
			
			if( m.isStringLiteral( expr.value ) ) then
				expr.const = m.resolveVariables( expr.value )

			elseif( tonumber( expr.value ) ~= nil ) then
				expr.const = tonumber( expr.value )

			else
				expr.const = m.expandVariable( expr.value )
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
				value   = ( which_op .. ' ' .. constexpr.value ),
				const   = nil
			}

			if( which_op == 'EXISTS' ) then

				-- TODO: Implement EXISTS
				newExpr.const = false

			elseif( which_op == 'COMMAND' ) then

				-- TODO: Implement COMMAND
				newExpr.const = false

			elseif( which_op == 'DEFINED' ) then

				-- DEFINED yields true as long as the constant is not nil or NOTFOUND
				newExpr.const = ( ( constexpr.const ~= nil ) and ( constexpr.const ~= m.NOTFOUND ) )

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
				value   = string.format( '(%s %s %s)', lhs.value, which_op, rhs.value ),
				const   = nil
			}

			-- TODO: Properly implement these binary operators
			    if( which_op == 'EQUAL'                 ) then newexpr.const = ( lhs.const == rhs.const )
			elseif( which_op == 'LESS'                  ) then newexpr.const = ( lhs.const <  rhs.const )
			elseif( which_op == 'LESS_EQUAL'            ) then newexpr.const = ( lhs.const <= rhs.const )
			elseif( which_op == 'GREATER'               ) then newexpr.const = ( lhs.const >  rhs.const )
			elseif( which_op == 'GREATER_EQUAL'         ) then newexpr.const = ( lhs.const >= rhs.const )
			elseif( which_op == 'STREQUAL'              ) then newexpr.const = ( lhs.const == rhs.const )
			elseif( which_op == 'STRLESS'               ) then newexpr.const = ( lhs.const <  rhs.const )
			elseif( which_op == 'STRLESS_EQUAL'         ) then newexpr.const = ( lhs.const <= rhs.const )
			elseif( which_op == 'STRGREATER'            ) then newexpr.const = ( lhs.const >  rhs.const )
			elseif( which_op == 'STRGREATER_EQUAL'      ) then newexpr.const = ( lhs.const >= rhs.const )
			elseif( which_op == 'VERSION_EQUAL'         ) then newexpr.const = ( lhs.const == rhs.const )
			elseif( which_op == 'VERSION_LESS'          ) then newexpr.const = ( lhs.const <  rhs.const )
			elseif( which_op == 'VERSION_LESS_EQUAL'    ) then newexpr.const = ( lhs.const <= rhs.const )
			elseif( which_op == 'VERSION_GREATER'       ) then newexpr.const = ( lhs.const >  rhs.const )
			elseif( which_op == 'VERSION_GREATER_EQUAL' ) then newexpr.const = ( lhs.const >= rhs.const )
			elseif( which_op == 'MATCHES'               ) then newexpr.const = ( lhs.const == rhs.const )
			end

			if( newexpr.const == nil ) then
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
				value   = string.format( '(NOT %s)', constexpr.value ),
				const   = ( not m.isTrue( constexpr.const ) )
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
				value   = string.format( '(%s AND %s)', lhs.value, rhs.value ),
				const   = ( lhs.const and rhs.const )
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
				value   = string.format( '(%s OR %s)', lhs.value, rhs.value ),
				const   = ( lhs.const or rhs.const )
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
		test = test and m.isTrue( expr.const )
	end

	return test
end
