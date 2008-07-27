%% =====================================================================
%% Some program slicing algorithms.
%%
%% Copyright (C) 2006-2009  Huiqing Li, Simon Thompson

%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.


%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.

%% @private
%% @copyright 2006-2009 Huiqing Li, Simon Thompson
%%
%% @author Huiqing Li <hl@kent.ac.uk>
%%   [http://www.cs.kent.ac.uk/projects/forse]

%% @version  0.1
%%
%% @doc Forward and backward slicing of Erlang programs. The current implementation does 
%%      not handle message passing, and is not fully tested yet.
%% @end

-module(refac_slice). 

-export([forward_slice/5, backward_slice/5]). 

-include("../hrl/wrangler.hrl").

%% @spec forward_slice(Files:[filename()], AnnAST:syntaxTree(), ModName::atom(), FunDef::syntaxTree(), Expr::syntaxTree()) -> [syntaxTree()].
%% @doc Forward slice the program with expression Expr, which in contained in function FunDef, as the slicing criterion.                     

-spec(forward_slice/5::([filename()], syntaxTree(), atom(), syntaxTree(), syntaxTree())->
	     [syntaxTree()]).
forward_slice(Files, AnnAST, ModName, FunDef, Expr)  ->
    start_slice_env_process(),
    Res = forward_slice_1(Files, AnnAST, ModName, {FunDef, Expr}),
    stop_slice_env_process(),
    Res.
    
    
forward_slice_1(Files, AnnAST, ModName, {FunDef, Expr}) ->
    FunName = refac_syntax:function_name(FunDef),
    FunName1 = refac_syntax:data(FunName),
    Arity = refac_syntax:function_arity(FunDef),
    FunClauses = refac_syntax:function_clauses(FunDef),
    NewFunClauses = lists:map(fun(Cs) ->
			    process_a_clause(AnnAST, ModName,Cs, Expr) end, FunClauses),
    NewFunDef = refac_syntax:function(FunName, NewFunClauses),
    sliced_funs ! {add, {{ModName, FunName1, Arity}, NewFunDef}},
    case returns_undefined(NewFunDef) of 
	true ->    %% None of the variables depending on the selected expression is exported.
	    get_all_sliced_funs();
	false -> CallerFuns = get_caller_funs(Files, {ModName, FunName1, Arity}),
		 F = fun(T,Acc) -> case refac_syntax:type(T) of 
				       application ->
					   Op = refac_syntax:application_operator(T),
					   Ann = refac_syntax:get_ann(Op),
					   case lists:keysearch(fun_def,1, Ann) of
					       {value, {fun_def, {ModName, FunName1, Arity, _, _}}} ->
						   [T|Acc];
					       _ ->  Acc
					   end;
				       _ -> Acc
				   end
		     end,	 
		 case CallerFuns of 
		     [] -> get_all_sliced_funs();
		     _ ->  SliceCriterion = lists:flatmap(fun(FunDef1) -> AppExprs = refac_syntax_lib:fold(F, [], FunDef1),
								     lists:map(fun(E) -> {FunDef1, E} end, AppExprs)
						      end, CallerFuns),
			   lists:flatmap(fun(SC) ->forward_slice_1(Files, AnnAST, ModName,SC) end, SliceCriterion)
		 end		 
    end.

returns_undefined(FunDef) ->
   F= fun(C) ->
	       Body = refac_syntax:clause_body(C),
	       Expr = lists:last(Body),
	       case refac_syntax:type(Expr) of 
		   atom -> refac_syntax:atom_value(Expr) == undefined;
		   _ -> false
	       end
       end,
    FunClauses = refac_syntax:function_clauses(FunDef),
    lists:all(fun(C) -> F(C) end, FunClauses).
    


get_caller_funs(Files, {ModName, FunName, Arity}) ->
    CallGraph = refac_util:build_call_graph(Files, []),
    lists:flatmap(fun ({{_Caller, CallerDef}, Callee}) -> 
			  case lists:member({ModName, FunName, Arity}, Callee) of
			      true -> [CallerDef];
			      _ -> []
			  end
		  end, CallGraph).
    


start_slice_env_process() ->    
    case erlang:whereis(sliced_funs) of 
	undefined -> ok;
	_         -> erlang:unregister(sliced_funs)
    end,
    register(sliced_funs, spawn(fun()->sliced_funs([]) end)).

stop_slice_env_process() ->
    sliced_funs!stop.

get_all_sliced_funs() ->
    sliced_funs!{self(), get_all},
    receive 
	{sliced_funs, State} ->
	    State
    end.
	
sliced_funs(State) ->
    receive
	{From, get, Key} ->
	    From ! case lists:keysearch(Key, 1, State) of
		       {value, {Key, Value}} ->
			   {sliced_funs, value, Value};
		       false -> {sliced_funs, false}
		   end,
	    sliced_funs(State);
	{add, {Key, Value}} ->
	    case lists:keysearch(Key, 1, State) of 
		    {value, {Key, _}} ->  %% This should not happen.
			State1 = lists:keyreplace(Key,1, State, {Key, Value}), 
			sliced_funs(State1);
		    false -> sliced_funs([{Key, Value}|State])
		end;
	 {From, get_all} ->
	    io:format("\nAll sliced funs:\n"),
	    lists:foreach(fun({_Key, Value}) ->
			      io:format("Fun:\n~p\n", [Value]) end, State),
	    From ! {sliced_funs, State},
	    sliced_funs(State);
	 stop ->
		ok
	end.


process_a_clause(AnnAST, ModName,C, Expr) ->
    ExportedVars = get_exported_vars(C, Expr),
    Patterns = refac_syntax:clause_patterns(C),
    Body = refac_syntax:clause_body(C),
    Body1 = rm_unrelated_exprs(AnnAST, ModName, Body, ExportedVars),
    refac_syntax:clause(Patterns, none, Body1).

get_exported_vars(Body, Expr) ->
    F1 =fun(Node, _Others) ->
		case Node of 
		    Expr ->
			{true, true};
		    _ ->
			{[], false}
		end
	end,		    
    F = fun(T,S) ->
		case refac_syntax:type(T) of 
		    match_expr ->  %% TO THINK: assume only match expressions export variables, is this correct?
			case refac_util:once_tdTU(F1, T, []) of 
			    {_, true} -> S++refac_util:get_var_exports(T);
			    _ -> S
			end;
		    _ -> S
		end
	end,
    refac_syntax_lib:fold(F, [], Body).

rm_unrelated_exprs(_AnnAST, _ModName, [], _Vars) ->
    [];
rm_unrelated_exprs(_AnnAST, _ModName, [E], Vars) ->
    FreeVars = refac_util:get_free_vars(E),
    ExportedVars = refac_util:get_var_exports(E),
    case (ExportedVars -- Vars =/= ExportedVars) of 
	true -> [E];
	false -> case FreeVars -- Vars =/= FreeVars of 
		     true ->
			 [E];
		     _ ->
			 [refac_syntax:atom(undefined)]
		 end
    end;
rm_unrelated_exprs(AnnAST, ModName,[E |Exprs], Vars) ->
    FreeVars = refac_util:get_free_vars(E),
    ExportedVars = refac_util:get_var_exports(E),
    case (ExportedVars -- Vars =/= ExportedVars) of 
	true -> 
	    [E | rm_unrelated_exprs(AnnAST, ModName,Exprs, lists:usort(Vars++ExportedVars))];
	false -> case FreeVars -- Vars =/= FreeVars of 
		     true ->
			 Env = refac_util:get_env_vars(E),
			 E1 = process_fun_applications(AnnAST, ModName, E, Vars),
			 E2 = refac_syntax_lib:annotate_bindings(reset_attrs(E1), Env),
			 FreeVars1 = refac_util:get_free_vars(E2),
			 case FreeVars1 --Vars =/= FreeVars1 of 
			     true ->
				 [E2 | rm_unrelated_exprs(AnnAST, ModName, Exprs, lists:sort(Vars++refac_util:get_var_exports(E2)))];
			     _ -> rm_unrelated_exprs(AnnAST, ModName, Exprs, Vars)
			 end;
		     _ ->
			 rm_unrelated_exprs(AnnAST, ModName, Exprs, Vars)
		 end
    end.

    
reset_attrs(Node) ->
    refac_util:full_buTP(fun (T, _Others) ->  
				 As =refac_syntax:get_ann(T),
				 As0 = lists:keydelete(free, 1, As),
				 As1 = lists:keydelete(bound, 1, As0),
				 As2 = lists:keydelete(env,1,As1),
				 refac_syntax:set_ann(T, As2)				 
			 end, Node, {}).

	    
	    
  
intra_fun_forward_slice(AnnAST, ModName, FunDef, PatIndex) ->
    FunName = refac_syntax:function_name(FunDef),
    Cs = refac_syntax:function_clauses(FunDef),
    Cs1 = lists:map(fun(C) ->
			    process_a_clause_1(AnnAST, ModName,C, PatIndex) end, Cs),
    refac_syntax:function(FunName, Cs1).

process_a_clause_1(AnnAST, ModName, C, PatIndex) ->
    Patterns = refac_syntax:clause_patterns(C),
    Body = refac_syntax:clause_body(C),
    Vars =refac_util:get_var_exports(lists:nth(PatIndex, Patterns)),
    Body1 = process_fun_body(AnnAST, ModName, Body, Vars),
    refac_syntax:clause(Patterns, none, Body1).    

process_fun_body(_AnnAST, _ModName, [], _Vars) ->			    
    [];
process_fun_body(AnnAST, ModName, [E], Vars) ->
    E1 = process_fun_applications(AnnAST, ModName, E, Vars),
    FreeVars = refac_util:get_free_vars(E1),
    ExportedVars = refac_util:get_var_exports(E1),
    case (ExportedVars -- Vars =/= ExportedVars) of 
	true -> [E];
	false -> case FreeVars -- Vars =/= FreeVars of 
		     true ->
			   %% check free/exported vars again?
			 [E1];
		     _ ->
			 [refac_syntax:atom(undefined)]
		 end
    end;
process_fun_body(AnnAST, ModName,[E |Exprs], Vars) ->
    E1 = process_fun_applications(AnnAST, ModName, E, Vars),
    FreeVars = refac_util:get_free_vars(E1),
    ExportedVars = refac_util:get_var_exports(E1),
    case (ExportedVars -- Vars =/= ExportedVars) of 
	true -> [E | process_fun_body(AnnAST, ModName,Exprs, lists:usort(Vars++ExportedVars))];
	false -> case FreeVars -- Vars =/= FreeVars of 
		     true ->
			 [E1 | process_fun_body(AnnAST, ModName, Exprs, lists:sort(Vars++refac_util:get_var_exports(E1)))];
		     _ ->
			 process_fun_body(AnnAST, ModName, Exprs, Vars)
		 end
    end.


process_fun_applications(AnnAST, ModName, E, Vars) ->
    refac_util:full_buTP(fun do_process_fun_applications/2, E, {AnnAST, ModName, Vars}).

do_process_fun_applications(Node, {AnnAST, ModName, Vars}) ->
    case refac_syntax:type(Node) of 
	application ->
	    FreeVars = refac_util:get_free_vars(Node),
	    case FreeVars -- Vars =/= FreeVars of   %% the function application makes use of some of the variables in Vars;
		true -> Operator = refac_syntax:application_operator(Node),
			Ann = refac_syntax:get_ann(Operator),
			case lists:keysearch(fun_def, 1, Ann) of 
			    {value, {fun_def, {ModName, F, A, _, DefPos}}} ->   %% TO CHANGE. temperoary only check functions defined in this module;
				sliced_funs ! {self(), get, {ModName, F, A}},
				receive 
				    {value, {{ModName, F, A}, FunDef1}} ->
					case returns_undefined(FunDef1) of 
					    true ->refac_syntax:atom(undefined);
					    _ ->Node
					end;
				    _ -> case refac_util:pos_to_fun_def(AnnAST, DefPos) of 
					     {ok, FunDef} -> FunDef1= intra_fun_forward_slice(AnnAST, ModName, FunDef, 1), %% TOCHANGE: use 1 temporally;
							     sliced_funs ! {add, {{ModName, F, A}, FunDef1}},
							     case returns_undefined(FunDef1) of 
								 true -> refac_syntax:atom(undefined);
								 _ -> Node
							     end;
					     _ -> Node
					 end
				end;
			    _ -> Node
			end;			    
		_  -> refac_syntax:atom(undefined)
	    end;
	_ -> Node
    end.

%%=========================================================================================================
%% @spec backward_slice(Files:[filename()], AnnAST:syntaxTree(), ModName::atom(), FunDef::syntaxTree() Expr::syntaxTree()) -> term(). %% Need to think what term() really is.
%% @doc Backward slice the program with expression Expr, which in contained in function FunDef, as the slicing criterion.      

-spec(backward_slice/5::([filename()], syntaxTree(), atom(), syntaxTree(), syntaxTree())->[any()]).  %% any needs to be refined here.
	     
backward_slice(Files,AnnAST, ModName, FunDef, Expr) ->
    FunName = refac_syntax:data(refac_syntax:function_name(FunDef)),
    Arity= refac_syntax:function_arity(FunDef),
    NewFunDef1 = backward_slice(Expr, FunDef),
    NewFunDef2 = unfold_fun_defs(Files, AnnAST, ModName, NewFunDef1),
    C = hd(refac_syntax:function_clauses(NewFunDef2)),
    Body = refac_syntax:clause_body(C),
    %% Patterns = refac_syntax:clause_patterns(C),
    {_Bound2, FreeVarsInBody} = lists:foldl(fun (E, {Bd, Fr}) ->
						    {Bd1, Fr1} = {refac_util:get_bound_vars(E), refac_util:get_free_vars(E)},
						    {ordsets:union(Bd, Bd1), ordsets:union(Fr, ordsets:subtract(Fr1, Bd))}
					    end,
					    {[], []}, Body),
    case FreeVarsInBody of 
	[] ->
	    [Body];  %% TODO: need a block expression?
	_ -> 
	    SlicePoints = collect_app_sites(AnnAST, ModName, FunName, Arity),
	    Slices = lists:flatmap(fun({Fun, E}) ->
				       backward_slice(Files, AnnAST, ModName, Fun, E) end, SlicePoints),
	    FunExpr = refac_syntax:fun_expr(
			[refac_syntax:clause(lists:map(fun({V, _}) -> refac_syntax:variable(V) end, FreeVarsInBody), none, Body)]),  
	    %% IMPORTANT: ORDER OF VARIABLES MATTERS HERE.
	    Res = lists:map(fun(S) ->
				    [refac_syntax:application(FunExpr, S)] end, Slices),
	    Res
    end. 
		 
	    
collect_app_sites(AnnAST, ModName, FunName, Arity) ->    			
    F1 = fun(T,Acc) ->
		case refac_syntax:type(T) of 
		    application ->
			Op = refac_syntax:application_operator(T),
			Ann = refac_syntax:get_ann(Op),
			case lists:keysearch(fun_def,1, Ann) of
			    {value, {fun_def, {ModName, FunName, Arity, _, _}}} ->
				Args = refac_syntax:application_arguments(T),
				case Args of 
				    [] -> Acc;
				    _ -> Acc ++ [hd(Args)]  %% TODO: THIS NEED TO BE CHANGED, TEMORALLY ASSUME THE FIRST ARGUMENT.
				    end;
			    _ ->
				Acc
			end;
		    _ -> Acc
		end
	 end,			
    F = fun(T, Acc) ->
		case refac_syntax:type(T) of 
		    function ->
		       Acc1 = refac_syntax_lib:fold(F1,[], T),
		       case Acc1 of 
			   [] -> Acc;
			   _ -> Acc ++ lists:map(fun(E) -> {T, E} end, Acc1)
		       end;
		    _ -> Acc
		end
	end,
    refac_syntax_lib:fold(F, [], AnnAST).
			

unfold_fun_defs(_Files, AnnAST, ModName, FunDef) -> %% How about recursive functions?
    F = fun(Node, _Others) ->
		case refac_syntax:type(Node) of 
		    application ->
			Operator = refac_syntax:application_operator(Node),
			Ann = refac_syntax:get_ann(Operator),
			case lists:keysearch(fun_def,1,Ann) of 
			    {value, {fun_def, {ModName, _F, _A, _, DefPos}}} ->  %% TOCHANGE: temporaly assume the function is local.
				case refac_util:pos_to_fun_def(AnnAST, DefPos) of 
				    {ok, Def} -> 
					Cs = refac_syntax:function_clauses(Def),
					FunExpr = refac_syntax:fun_expr(Cs),
					Args = refac_syntax:application_arguments(Node),
					{refac_syntax:application(FunExpr, Args),true};
				    _ -> {Node, false}
				end;
			    _ -> {Node, false}
			end;
		    _ -> {Node, false}
		end
	end,	
    {FunDef1, _} = refac_util:stop_tdTP(F, FunDef, []),
    FunDef2 = refac_syntax_lib:annotate_bindings(reset_attrs(FunDef1), []),
    FunDef2.
    



backward_slice(Expr, FunDef) ->
    FunName = refac_syntax:function_name(FunDef),
    {S, E} = refac_util:get_range(Expr),
    FunClauses = refac_syntax:function_clauses(FunDef),
    Pred = fun (Node) ->
		   {StartPos, EndPos} = refac_util:get_range(Node),
		   S >= StartPos andalso E =< EndPos
	   end,
    %% Get the function clause to which the expression belongs.
    C = hd(lists:filter(fun (Clause) -> Pred(Clause) end, FunClauses)),
    Patterns = refac_syntax:clause_patterns(C),
    C1 = process_a_clause(C, Expr),
    NewFun = refac_syntax:function(FunName, C1),
    %% to keep the annotation info correct.
    NewFun1 = refac_syntax_lib:annotate_bindings(reset_attrs(NewFun), []),
    Body = refac_syntax:clause_body(hd(refac_syntax:function_clauses(NewFun1))),
    Body1 = rm_unused_exprs(Body),  %%Qn: how about the guard expression?
    NewFun2 = refac_syntax:function(FunName, [refac_syntax:clause(Patterns, none, Body1)]),
    %%io:format("Fun after slicing:\n"),
    %%io:format(refac_prettypr:format(NewFun2)),				    
    %% Body1.
    NewFun2.
    

process_a_clause(C, Expr) ->
    Patterns = refac_syntax:clause_patterns(C),
    Body = refac_syntax:clause_body(C),
    NewBody = process_body(Body, Expr),
    FreeVars = refac_util:get_free_vars(Expr),
    case NewBody == [refac_syntax:tuple([refac_syntax:atom(error), refac_syntax:atom("Error with evaluation")])] of
      true -> [];
      _ ->
	  BoundVars = lists:flatmap(fun (P) -> refac_util:get_bound_vars(P) end, Patterns),
	  case FreeVars -- BoundVars =/= FreeVars of
	    true ->  %% Expr uses some of the vars declared in Patterns.
		C1 = refac_syntax:clause(Patterns, none, NewBody),
		{Bound1, Free1} = lists:foldl(fun (P, {Bd, Fr}) ->
						      {Bd1, Fr1} = {refac_util:get_bound_vars(P), refac_util:get_free_vars(P)},
						      {ordsets:union(Bd, Bd1), ordsets:union(Fr, Fr1)}
					      end,
					      {[], []}, Patterns),
		{Bound2, Free2} = lists:foldl(fun (E, {Bd, Fr}) ->
						      {Bd1, Fr1} = {refac_util:get_bound_vars(E), refac_util:get_free_vars(E)},
						      {ordsets:union(Bd, Bd1), ordsets:union(Fr, ordsets:subtract(Fr1, Bd))}
					      end,
					      {[], []}, NewBody),
		Bound = ordsets:union(Bound1, Bound2),
		Free = ordsets:union(Free1, ordsets:subtract(Free2, Bound1)),
		C2 = refac_util:update_ann(refac_util:update_ann(C1, {bound, Bound}), {free, Free}),
		[C2];
	    _ -> %% Expr does not use any of the vars declared in Patterns.
		%%io:format("NewBody:\n~p\n", [NewBody]),
		{Bound, Free} = lists:foldl(fun (E, {Bd, Fr}) ->
						    {Bd1, Fr1} = {refac_util:get_bound_vars(E), refac_util:get_free_vars(E)},
						    {ordsets:union(Bd, Bd1), ordsets:union(Fr, ordsets:subtract(Fr1, Bd))}
					    end,
					    {[], []}, NewBody),
		C1 = refac_syntax:clause([refac_syntax:underscore()], none, NewBody),  %% replace patterns with undersocre.
		C2 = refac_util:update_ann(refac_util:update_ann(C1, {bound, Bound}), {free, Free}),
		[C2]
	  end
    end.

%% If Expr belongs to Body, then remove those expressions that will be evaluated after Expr, since 
%% those expressions do not contribute to the value of Expr.
process_body(Body, Expr) ->
    {S, E} = refac_util:get_range(Expr),
    FreeVars = refac_util:get_free_vars(Expr),
    FstExp = hd(Body),
    LstExp = lists:last(Body),
    {S1, _} = refac_util:get_range(FstExp),
    {_, E1} = refac_util:get_range(LstExp),
    case S1 =< S andalso E =< E1 of
      true ->
	  %% Expr is part of body.
	  case FreeVars of
	    [] -> [Expr];        %% The selected expr does not has any free vars.
	    _ ->
		FreeVarDefLocs = lists:map(fun ({_V, DefLoc}) -> DefLoc end, FreeVars),
		LastLoc = lists:last(lists:sort(FreeVarDefLocs)),
		Exprs1 = lists:takewhile(fun (BodyExpr) ->
						 {StartPos, EndPos} = refac_util:get_range(BodyExpr),
						 (EndPos =< S) or (S >= StartPos andalso E =< EndPos)
					 end,
					 Body),
		LastExpr1 = lists:last(Exprs1), %% The expression that contains Expr.
		{LastExprStartPos, _} = refac_util:get_range(LastExpr1),
		LastExpr = case LastLoc >= LastExprStartPos of
			     false -> Expr;  %% The last expr does not declare any free vars of Expr
			     true -> %% some of the free vars in Expr are introduced in the LastExpr1.
				 %% This function needs to make sure Expr or {error, error with evalution} is 
				 %% the lasted expression to evaluate in the processed LastExpr1.
				 process_expr(LastExpr1, Expr)  %% LastExpr1 is a complex expr, such as case/if/receive exprs.
			   end,
		NewExprs = lists:reverse(tl(lists:reverse(Exprs1))) ++ [LastExpr], 
		rm_unused_exprs(NewExprs)
	  end;
      %% Expr is not part of Body.
      false -> [refac_syntax:tuple([refac_syntax:atom(error), refac_syntax:atom("Error with evaluation")])]
    end.

%% Expr is part of LastExpr. This function tries to simplify LastExpr to remove those parts that do not 
%% affect the value of Expr.
%% IMPORTANT:
%% 1) Make sure that the last evaluated expression is either Expr or {error, "Error with evaluation"}.
%% 2) The slicing process should not change the binding structure of variables.
process_expr(LastExpr, Expr) ->
    GetExprBody = fun (E) ->
			  case refac_syntax:type(E) of
			    match_expr -> get_match_expr_body(E);
			    _ -> E
			  end
		  end,
    E = GetExprBody(LastExpr),
    case refac_syntax:type(E) of
	case_expr ->
	    Args = refac_syntax:case_expr_argument(E),
	    {Bound1, Free1} = {refac_util:get_bound_vars(Args), refac_util:get_free_vars(Args)},
	    Clauses = refac_syntax:case_expr_clauses(E),
	    NewClauses = lists:flatmap(fun (C) -> process_a_clause(C, Expr) end, Clauses), %% process each case clause.
	    {Bound2, Free2} = lists:foldl(fun (C, {Bd, Fr}) ->
						  {Bd1, Fr1} = {refac_util:get_bound_vars(C), refac_util:get_free_vars(C)},
						  {ordsets:intersection(Bd, Bd1), ordsets:union(Fr, Fr1)}
					  end,
					  {[], []}, NewClauses),
	    Bound = ordsets:union(Bound1, Bound2),
	    Free = ordsets:union(Free1, Free2),
	    E1 = refac_syntax:case_expr(Args, NewClauses),
	    %% updated the annotation.
	    E2 = refac_util:update_ann(refac_util:update_ann(E1, {bound, Bound}), {free, Free}),
	    E2;
	block_expr ->
	    Body = refac_syntax:block_expr_body(E),
	    NewBody = process_body(Body, Expr),
	    {Bound, Free} = lists:foldl(fun (E1, {Bd, Fr}) ->
						{Bd1, Fr1} = {refac_util:get_bound_vars(E1), refac_util:get_free_vars(E1)},
						{ordsets:union(Bd, Bd1), ordsets:union(Fr, ordsets:subtract(Fr1, Bd))}
					end,
					{[], []}, NewBody),
	    BE = refac_syntax:block_expr(NewBody),
	    refac_util:update_ann(refac_util:update_ann(BE, {bound, Bound}), {free, Free});
	if_expr ->
	    Clauses = refac_syntax:if_expr_clauses(E),
	    NewClauses = lists:flatmap(fun (C) -> process_a_clause(C, Expr) end, Clauses),
	    {Bound, Free} = lists:foldl(fun (C, {Bd, Fr}) ->
						  {Bd1, Fr1} = {refac_util:get_bound_vars(C), refac_util:get_free_vars(C)},
						  {ordsets:intersection(Bd, Bd1), ordsets:union(Fr, Fr1)}
					  end,
					  {[], []}, NewClauses),
	    IE = refac_syntax:if_expr(NewClauses),          
	    refac_util:update_ann(refac_util:update_ann(IE, {bound, Bound}), {free, Free});
%%	receive_expr -> LastExpr;
	%%fun_expr ->  %% IMPORTANT: fun exprs need more attection, as it is a function closure. 
	%% lists comprehension is another problem. (find the example !!)
	%% catch_expr ->
	%% Any other possibilities?
	_ -> refac_syntax:tuple([refac_syntax:atom(error), refac_syntax:atom("Error with evaluation")])
    end.
 

%% this is the function that does the backward slicing.
rm_unused_exprs([]) -> [];
rm_unused_exprs(Exprs) ->
    %%io:format("Initial:\n"),
    %%io:format(lists:concat(lists:map(fun(B) ->refac_prettypr:format(B) end, Exprs))),
    LastExpr = lists:last(Exprs),
    FreeVars = refac_util:get_free_vars(LastExpr),
    %%io:format("LastExpr:\n~p\n", [refac_prettypr:format(LastExpr)]),
    %%io:format("FreeVars:\n~p\n", [FreeVars]),
    ReversedPrevExprs = tl(lists:reverse(Exprs)),
    Res = rm_unused_exprs_1(ReversedPrevExprs, FreeVars, [LastExpr]),
    %%io:format("Result:\n"),
    %%io:format(lists:concat(lists:map(fun(B) ->refac_prettypr:format(B) end, Res))),
    Res.

rm_unused_exprs_1([], _FreeVars, Acc) -> Acc;
rm_unused_exprs_1([E | Exprs], FreeVars, Acc) ->
    ExportedVars = refac_util:get_var_exports(E),
    case FreeVars -- ExportedVars =/= FreeVars of
      true ->
	  FreeVarsInE = refac_util:get_free_vars(E),
	  NewFreeVars = lists:usort((FreeVars -- ExportedVars) ++ FreeVarsInE),
	  rm_unused_exprs_1(Exprs, NewFreeVars, [E | Acc]);
      false -> rm_unused_exprs_1(Exprs, FreeVars, Acc)
    end.

get_match_expr_body(E) ->
    Body = refac_syntax:match_expr_body(E),
    case Body of
      match_expr -> get_match_expr_body(Body);
      _ -> Body
    end.
