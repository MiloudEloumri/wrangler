-module(core_boolean_operators).
-include_lib("wrangler/include/wrangler.hrl").
-export([rules/2]).

rules(_,_) ->
    [   
     gt_rule(),
     gte_rule(),
     lt_rule(),
     lte_rule(),
     equal_rule(),
     different_rule(),
     exactly_equal_rule(),
     exactly_different_rule(),
     and_rule(),
     andalso_rule(),
     or_rule(),
     orelse_rule(),
     xor_rule(),
     not_rule(),
     is_list_rule(),
     is_integer_rule(),
     is_float_rule(),
     is_number_rule(),
     is_boolean_rule(),
     is_atom_rule(),
     is_tuple_rule(),
     is_function_rule()
    ]. 
%%------------------------------------------------------------------
equal_rule() ->
    ?RULE(
         ?T("Op1@ == Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv == Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

different_rule() ->
    ?RULE(
         ?T("Op1@ /= Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv /= Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

exactly_equal_rule() ->
    ?RULE(
         ?T("Op1@ =:= Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv =:= Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

exactly_different_rule() ->
    ?RULE(
         ?T("Op1@ =/= Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv =/= Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

gt_rule() ->
    ?RULE(
         ?T("Op1@ > Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv > Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

gte_rule() ->
    ?RULE(
         ?T("Op1@ >= Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv >= Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

lt_rule() ->
    ?RULE(
         ?T("Op1@ < Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv < Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

lte_rule() ->
    ?RULE(
         ?T("Op1@ =< Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv =< Op2_conv)
	 end,
         utils_convert:convertable_type(Op1@) andalso utils_convert:convertable_type(Op2@)
	).

and_rule() ->
    ?RULE(
         ?T("Op1@ and Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv and Op2_conv)
	 end,
         boolean_cond(Op1@,Op2@)
	).

andalso_rule() ->
    ?RULE(
         ?T("Op1@ andalso Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv andalso Op2_conv)
	 end,
         boolean_cond(Op1@,Op2@)
	).

or_rule() ->
    ?RULE(
         ?T("Op1@ or Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv or Op2_conv)
	 end,
         boolean_cond(Op1@,Op2@)
	).

orelse_rule() ->
    ?RULE(
         ?T("Op1@ orelse Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv orelse Op2_conv)
	 end,
         boolean_cond(Op1@,Op2@)
	).

xor_rule() ->
    ?RULE(
         ?T("Op1@ xor Op2@"),
         begin
	     Op1_conv = utils_convert:convert_elem(Op1@),
	     Op2_conv = utils_convert:convert_elem(Op2@),
	     wrangler_syntax:atom(Op1_conv xor Op2_conv)
	 end,
         boolean_cond(Op1@,Op2@)
	).

not_rule() ->
    ?RULE(
         ?T("not(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(not(Op_conv))
	 end,
         is_boolean(utils_convert:convert_elem(Op@))
	).

is_list_rule() ->
    ?RULE(
         ?T("is_list(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_list(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_integer_rule() ->
    ?RULE(
         ?T("is_integer(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_integer(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_float_rule() ->
    ?RULE(
         ?T("is_float(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_float(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_number_rule() ->
    ?RULE(
         ?T("is_number(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_number(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_boolean_rule() ->
    ?RULE(
         ?T("is_boolean(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_boolean(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_atom_rule() ->
    ?RULE(
         ?T("is_atom(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_atom(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_tuple_rule() ->
    ?RULE(
         ?T("is_tuple(Op@)"),
         begin
	     Op_conv = utils_convert:convert_elem(Op@),
	     wrangler_syntax:atom(is_tuple(Op_conv))
	 end,
         utils_convert:convertable_type(Op@)
	).

is_function_rule() ->
    ?RULE(
         ?T("is_function(Args@@)"),
         wrangler_syntax:atom(utils_guards:evaluateIsFun(Args@@)),
         true
	).

boolean_cond(Op1@,Op2@) ->
    is_boolean(utils_convert:convert_elem(Op1@)) andalso is_boolean(utils_convert:convert_elem(Op2@)).
    

