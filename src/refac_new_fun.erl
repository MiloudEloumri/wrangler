%% Copyright (c) 2009, Huiqing Li, Simon Thompson
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are met:
%%     %% Redistributions of source code must retain the above copyright
%%       notice, this list of conditions and the following disclaimer.
%%     %% Redistributions in binary form must reproduce the above copyright
%%       notice, this list of conditions and the following disclaimer in the
%%       documentation and/or other materials provided with the distribution.
%%     %% Neither the name of the copyright holders nor the
%%       names of its contributors may be used to endorse or promote products
%%       derived from this software without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS''
%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
%% BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
%% BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
%% OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
%% ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%% ============================================================================================
%% Refactoring: Introduce a new function definition to represent a selected expression sequence.
%%
%% Author contact: hl@kent.ac.uk, sjt@kent.ac.uk
%% 
%% =============================================================================================

%% =============================================================================================
-module(refac_new_fun).

-export([fun_extraction/5, fun_extraction_eclipse/5]).


-include("../include/wrangler.hrl").
%% =============================================================================================
%% @spec new_fun(FileName::filename(), Start::Pos, End::Pos, NewFunName::string())-> term()
%%         
-spec(fun_extraction/5::(filename(), pos(), pos(), string(), integer()) ->
	      {'error', string()} | {'ok', string()}).
fun_extraction(FileName, Start, End, NewFunName, TabWidth) ->
    fun_extraction(FileName, Start, End, NewFunName, TabWidth, emacs).

-spec(fun_extraction_eclipse/5::(filename(), pos(), pos(), string(), integer()) ->
	      {error, string()} | {ok, [{filename(), filename(), string()}]}).
fun_extraction_eclipse(FileName, Start, End, NewFunName, TabWidth) ->
    fun_extraction(FileName, Start, End, NewFunName, TabWidth, eclipse).


fun_extraction(FileName, Start={Line, Col}, End={Line1, Col1}, NewFunName,TabWidth,Editor) ->
    ?wrangler_io("\nCMD: ~p:fun_extraction(~p, {~p,~p}, {~p,~p}, ~p, ~p).\n", [?MODULE,FileName, Line, Col, Line1, Col1, NewFunName, TabWidth]),
    case refac_util:is_fun_name(NewFunName) of 
	true ->
	    {ok, {AnnAST, Info}}= refac_util:parse_annotate_file(FileName,true, [], TabWidth),
	    case refac_util:pos_to_expr_list(FileName, AnnAST, Start, End, TabWidth) of 
		[] -> {error, "You have not selected an expression!"};
		ExpList ->
		    {ok,Fun} = refac_util:expr_to_fun(AnnAST, hd(ExpList)),
		    case side_cond_analysis(Info, Fun, ExpList, list_to_atom(NewFunName)) of 
			{ok, {BdVars, FrVars}} ->
			    FunName = refac_syntax:atom_value(refac_syntax:function_name(Fun)),
			    FunArity = refac_syntax:function_arity(Fun),
			    VarsToExport=vars_to_export(Fun, End, BdVars), 
			    AnnAST1=do_fun_extraction(AnnAST,ExpList, NewFunName, FrVars, VarsToExport, FunName, FunArity),
			    case Editor of 
				emacs ->
				    refac_util:write_refactored_files_for_preview([{{FileName,FileName}, AnnAST1}]),
				    {ok, [FileName]};
				eclipse ->
				    Res = [{FileName, FileName, refac_prettypr:print_ast(refac_util:file_format(FileName),AnnAST1)}],
				    {ok, Res}
			    end;
			{error, Reason} -> {error, Reason}
		    end
	    end;
	false  -> {error, "Invalid function name!"}
    end.  

side_cond_analysis(Info, Fun, ExpList, NewFunName) ->
    lists:foreach(fun(Exp) ->
			 case lists:keysearch(category,1, refac_syntax:get_ann(Exp)) of 
			     {value, {category, record_field}} -> throw({error, "Record field cannot be replaced by a function application."});
			     {value, {category, record_type}} -> throw({error, "Record type cannot be replaced by a function application."});	 
			     {value, {category, guard_expression}} -> throw({error, "Function abstraction whithin a guard expression is not supported."});
			     {value, {category, generator}} -> throw({error, "Function abstraction over a generator is not supported."});
			     {value, {category, application_op}} -> 
				 GuardRanges= refac_syntax_lib:fold(fun(N,S) ->
									    case lists:keysearch(category,1,refac_syntax:get_ann(N)) of
										{value, {category,guard_expression}} -> [refac_util:get_range(N)|S];
										_ -> S
									    end
								    end,[],Fun),
				 {Start, End} = refac_util:get_range(Exp),
				 case lists:any(fun({S1,E1}) -> (S1 =< Start) andalso ( End =< E1) end, GuardRanges) of 
				     true ->throw({error, "Function abastraction within a guard expression is not supported."});
				     _ -> ok
				 end;
			     _ -> ok  
			 end
		  end, ExpList),
    FrBdVars = lists:map(fun(E)-> envs_bounds_frees(E) end, ExpList),
    BdVars = lists:usort(lists:flatmap(fun({{bound, Vars}, _}) -> Vars end, FrBdVars)),
    FrVars1 = lists:usort(lists:flatmap(fun({_, {free, Vars}}) -> Vars end, FrBdVars)),
    FrVars = refac_util:remove_duplicates(lists:map(fun({VarName, _Pos}) -> VarName end, 
					  lists:keysort(2, lists:subtract(FrVars1, BdVars)))),
    InScopeFuns = lists:map(fun({_M, F, A}) ->
				    {F, A} end, refac_util:inscope_funs(Info)),
    case lists:member({NewFunName, length(FrVars)}, InScopeFuns) orelse 
	erlang:is_builtin(erlang, NewFunName, length(FrVars)) orelse erl_internal:bif(erlang, NewFunName, length(FrVars)) of
	true ->
	    {error, "The given function name has been used by this module, please choose another name!"};
	_ ->
	    case length(ExpList) ==1  of 
		true ->
		    Exp = hd(ExpList),
		    case is_guard_expr(Exp) of 
			true -> {error, "The selected guard expression cannot be replaced by a function call!"};
			_ ->{StartPos, EndPos} = refac_util:get_range(Exp),
			    Ranges = collect_prime_expr_ranges(Fun),
			    Res = lists:any(fun({StartPos1, EndPos1}) ->  
						    (StartPos >= StartPos1) andalso (EndPos =<EndPos1) end, Ranges),
			    case Res of 
				true -> {error, "The selected expression cannot be replaced by a function call!"};
				_ -> 
				    {ok, {BdVars, FrVars}}
			    end
		    end;				 
		_ ->
		    ExpList1 = filter_exprs_via_ast(Fun, ExpList),
		    case ExpList1 of 
			[] ->{ok, {BdVars, FrVars}};
			_ -> {error, "The selected expression sequence canot be replaced by  a function call!"}
		    end
	    end
    end.
    
collect_prime_expr_ranges(Tree) ->
     F= fun(T, S) ->
 		   case refac_syntax:type(T) of 
 		       application ->
			   Operator = refac_syntax:application_operator(T),
			   Range = refac_util:get_range(Operator),
		           S++[Range];
		       _ -> S
		   end
	end,
    refac_syntax_lib:fold(F, [], Tree).


is_guard_expr(Node) ->
    As = refac_syntax:get_ann(Node),
    case lists:keysearch(category,1, As) of
	{value, {category, guard_expression}} ->
	    true;
	_  -> false
    end.

do_fun_extraction(AnnAST, ExpList, NewFunName, ParNames, VarsToExport, EnclosingFunName, EnclosingFunArity) ->
    NewFunName1 = refac_syntax:atom(NewFunName),
    Pars = lists:map(fun(P) ->refac_syntax:variable(P) end, ParNames),
    ExpList1 = case VarsToExport of
		   [] -> ExpList;
		   [V] -> E = refac_syntax:variable(V),
			  ExpList++[E];
		   [_V|_Vs] -> E = refac_syntax:tuple([refac_syntax:variable(V)||V<-VarsToExport]),
			       ExpList ++ [E]
	       end,
    Clause = refac_syntax:clause(Pars, [], ExpList1),
    NewFun = refac_syntax:function(NewFunName1, [Clause]),
    Forms = refac_syntax:form_list_elements(AnnAST),
    Fun = fun(Form) ->
		  case refac_syntax:type(Form) of 
		      function -> Name = refac_syntax:atom_value(refac_syntax:function_name(Form)),
				  Arity = refac_syntax:function_arity(Form),
				  case {Name, Arity} == {EnclosingFunName, EnclosingFunArity} of
				      true -> 
					  Form1 = replace_expr_with_fun_call(Form, ExpList, NewFunName, ParNames, VarsToExport), 
					  [Form1, NewFun];
				      _ -> [Form]
				  end;
		      _ -> [Form]
		  end
	  end,
    refac_syntax:form_list([F||Form<-Forms, F <-Fun(Form)]).


replace_expr_with_fun_call(Form, ExpList, NewFunName, ParNames, VarsToExport) ->
    Op = refac_syntax:operator(NewFunName),
    Pars = [refac_syntax:variable(P)|| P <-ParNames],
    FunCall= refac_syntax:application(Op, Pars),
    NewExpr = case length(VarsToExport) of 
		  0  ->  FunCall;
		  1 -> Pats = refac_syntax:variable(hd(VarsToExport)),
		       refac_syntax:match_expr(Pats, FunCall);
		  _ -> Pats = refac_syntax:tuple([refac_syntax:variable(V) || V <- VarsToExport]),
		       refac_syntax:match_expr(Pats, FunCall)
	      end,
    case (length(ExpList)==1) andalso (refac_syntax:type(hd(ExpList))=/=match_expr) of
	true -> {Form1, _} =refac_util:stop_tdTP(fun do_replace_expr_with_fun_call_1/2, Form, {NewExpr, hd(ExpList)}),
		Form1;
	_ ->    {Form1, _} =refac_util:stop_tdTP(fun do_replace_expr_with_fun_call_2/2, Form, {NewExpr, ExpList}),
		Form1

    end.
    
do_replace_expr_with_fun_call_1(Tree, {NewExpr, Expr}) ->
    Range = refac_util:get_range(Expr),
    case refac_util:get_range(Tree) of
	Range -> {NewExpr, true};
	_  -> {Tree, false}
    end.
    
	    
do_replace_expr_with_fun_call_2(Tree, {MApp, ExpList}) ->
    Range1 = refac_util:get_range(hd(ExpList)),
    Range2 = refac_util:get_range(lists:last(ExpList)),
    case refac_syntax:type(Tree) of
	clause ->
	    Exprs = refac_syntax:clause_body(Tree),
	    {Exprs1, Exprs2} = lists:splitwith(fun(E) -> refac_util:get_range(E) =/= Range1 end, Exprs),
	    {NewBody, Modified} = case Exprs2 of 
				      [] -> {Exprs, false};
				      _ -> {_Exprs21, Exprs22} = lists:splitwith(fun(E) -> refac_util:get_range(E) =/= Range2 end, Exprs2),
					   case Exprs22 of 
					       [] -> {Exprs, false}; %% THIS SHOULD NOT HAPPEN.
					       _ -> {Exprs1 ++ [MApp|tl(Exprs22)], true}
					   end
				  end,
	    Pats = refac_syntax:clause_patterns(Tree),
	    G    = refac_syntax:clause_guard(Tree),
	    {refac_syntax:copy_attrs(Tree, refac_syntax:clause(Pats, G, NewBody)), Modified};
	block_expr -> 
	    Exprs = refac_syntax:block_expr_body(Tree),
	    {Exprs1, Exprs2} = lists:splitwith(fun(E) -> refac_util:get_range(E) =/= Range1 end, Exprs),
	    {NewBody, Modified} = case Exprs2 of 
				      [] -> {Exprs, false};
				      _ -> {_Exprs21, Exprs22} = lists:splitwith(fun(E) -> refac_util:get_range(E) =/= Range2 end, Exprs2),
					   case Exprs22 of 
					       [] -> {Exprs, false}; %% THIS SHOULD NOT HAPPEN.
					       _ -> {Exprs1 ++ [MApp|tl(Exprs22)], true}
					   end
				  end,
	    {refac_syntax:copy_attrs(Tree, refac_syntax:block_expr(NewBody)), Modified};	    
	_ -> {Tree, false}
    end.

envs_bounds_frees(Node) ->
    As = refac_syntax:get_ann(Node),
    BdVars = case lists:keysearch(bound,1,As) of
		 {value, {bound, BdVars1}} ->
		     BdVars1;
		 _ -> []
	     end,
    FrVars = case lists:keysearch(free,1, As) of 
		 {value, {free, FrVars1}} ->
		     FrVars1;
		 _ -> []
	     end,
    {{bound, BdVars},{free, FrVars}}.


vars_to_export(Fun,ExprEndPos, ExprBdVars) ->
    AllVars = collect_vars(Fun),
    ExprBdVarsPos = lists:map(fun({_Var, Pos}) -> Pos end, ExprBdVars),
    VarsToExport = lists:keysort(2, [{V, SourcePos} || {V, SourcePos, DefPos} <- AllVars,
				      SourcePos > ExprEndPos,
				      lists:subtract(DefPos, ExprBdVarsPos) == []]),
    VarsToExport1=lists:foldl(fun({V,_Pos}, Acc) -> case lists:member(V, Acc) of 
						       false -> [V|Acc];
						       _ -> Acc
						   end
			      end,[], VarsToExport),
    lists:reverse(VarsToExport1).

collect_vars(Tree) ->
     F= fun(T, S) ->
 		   case refac_syntax:type(T) of 
 		       variable ->
			   SourcePos = refac_syntax:get_pos(T),
			   case lists:keysearch(def, 1, refac_syntax:get_ann(T)) of
			       {value, {def, DefinePos}} ->
				   VarName = refac_syntax:variable_name(T),
				   S++[{VarName, SourcePos, DefinePos}];
			       _ -> S
			   end;
		       _  -> S
 		   end
	    end,
    refac_syntax_lib:fold(F, [], Tree).



%% The following functions should be combined with those in 'refac_expr_search.erl'

filter_exprs_via_ast(Tree, ExpList) ->
    F = fun(T, Acc) ->
		case refac_syntax:type(T) of
		    clause -> Exprs = refac_syntax:clause_body(T), 
			      Acc ++ [Exprs];
		    block_expr -> Exprs = refac_syntax:block_expr_body(T),
				  Acc++ [Exprs];    
		    _  -> Acc
		end
	end,
    AllExprSeqs = lists:flatten(refac_syntax_lib:fold(F, [], Tree)),
    case lists:subtract(ExpList, AllExprSeqs) of 
	[] ->  [];
	_  -> ExpList
    end.
		    
