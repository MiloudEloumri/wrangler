%% =====================================================================
%% Refactoring: Generalise a function definition.
%%
%% Copyright (C) 2006-2008  Huiqing Li, Simon Thompson

%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.

%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.

%% Author contact: hl@kent.ac.uk, sjt@kent.ac.uk
%% 
%% =====================================================================
%%
%% @doc Generalise a function by selecting a sub-expression of the right-hand side and 
%% making this the value of a new argument added to the definition of the function. The 
%% sub-expression becomes the actual parameter at the call sites. 
%%
%% <p> To apply this refactoring, highlight the expression first, then  select 
%% <em> Generalise Function Definition </em> from the <em>Refactor</em> menu, after 
%% that the refactorer will prompt to enter the parameter name in the mini-buffer. </p>
%% 
%% <p> Here is an example of generalisation, in which the function <code> add_one </code> defined 
%% on  the left-hand side is generalised on the expression <code> 1 </code>, and the result is 
%% shown on the right-hand side. 
%%
%%        ```    -module (test).                          -module (test). 
%%               -export([f/1]).                          -export([f/1]).
%%        
%%               add_one ([H|T]) ->                       add_one (N, [H|T]) ->
%%                  [H+1 | add_one(T)];                      [H+N | add_one(N,T)];
%%               add_one ([]) -> [].                      add_one (N, []) -> [].
%%
%%               f(X) -> add_one(X).                      f(X) -> add_one(1,X)
%%        ''' 
%%  </p>
%% <p> In the case that the selected expression has a side-effect, the refactorer will wrap this expression 
%% in an function expression before passing it at the actual parameter to the call-sites. This is illustrated 
%% in the following example, in which function <code>repeat/1</code> is generalised on the expression 
%% <code>io:format("Hello\n")</code>.
%% 
%%         ```   -module (test).                          -module (test).                          
%%               -export([f/0]).                          -export([f/0]).
%%
%%               repeat(0) -> ok;                         repeat(A, 0) -> ok;
%%               repeat(N) ->                             repeat(A, N) ->
%%                 io:format("Hello\n"),                    A( ),
%%                 repeat(N-1).                             repeat(A,N-1).
%%
%%               f() -> repeat(5).                        f( ) -> 
%%                                                           repeat (fun( )->io:format ("Hello\n") end, 5).
%%          '''
%% </p>
%%
%% <p> This refactoring <em>only </em> affects the module in which the refactoring is initialised. In the case that 
%% the generalised function is exported by the module, an auxiliary function will be created 
%% to wrap the generalised function up, so that the module's interface is not changed.
%% </p>
%% <p> The following <em> side-condtions </em> apply to this refactoring:
%% <li> Supporse the function to be generalised is <code>foo/n </code>, then <code>foo/n+1</code> should not  
%% be in scope before the generalisation;</li>
%% <li> The selected expression should not contain locally declared variable(s), unless the selected expression 
%% has side effect; </li>
%% <li> The user-provided parameter name should not conflict with the existing parameters or
%% change the semantics of the function to be generalised; </li>
%% </p>
%% @end
%% =====================================================================

-module(refac_gen).

-include("../include/wrangler.hrl").

-export([generalise/6, generalise_eclipse/6]).

-export([gen_fun_1/8, gen_fun_1_eclipse/8, gen_fun_2_eclipse/8]).

%% =====================================================================
%% @spec generalise(FileName::filename(), Start::Pos, End::Pos, ParName::string(), SearchPaths::[string()])-> term()
%%         Pos = {integer(), integer()}
-spec(generalise/6::(filename(),pos(), pos(),string(), [dir()], integer()) -> {ok, string()} | {error, string()}
								    |{unknown_side_effect, {atom(), atom(),integer(), pos(), syntaxTree()}}).     

generalise(FileName, Start, End, ParName, SearchPaths, TabWidth) ->
    generalise(FileName, Start, End, ParName, SearchPaths, TabWidth, emacs).

-spec(generalise_eclipse/6::(filename(),pos(), pos(),string(), dir(), integer()) -> {ok, [{filename(), filename(), string()}]}
                              |{unknown_side_effect, {atom(), atom(),integer(), pos(), syntaxTree()}}).
generalise_eclipse(FileName, Start, End, ParName, SearchPaths, TabWidth) ->
    generalise(FileName, Start, End, ParName, SearchPaths, TabWidth, eclipse).
    
generalise(FileName, Start={Line, Col}, End={Line1, Col1}, ParName, SearchPaths, TabWidth, Editor) ->
    ?wrangler_io("\nCMD: ~p:generalise(~p, {~p,~p}, {~p,~p}, ~p,~p,~p).\n", 
				 [?MODULE,FileName, Line, Col, Line1, Col1, ParName, SearchPaths, TabWidth]),
    case refac_util:is_var_name(ParName) of 
	true ->
	    {ok, {AnnAST, Info}} =refac_util:parse_annotate_file(FileName,true, SearchPaths, TabWidth),
	    {ok, ModName} = get_module_name(Info),
	    case refac_util:pos_to_expr(AnnAST, Start, End) of  
		{ok, Exp1} ->
		    case  refac_util:expr_to_fun(AnnAST, Exp1) of 
			{ok, Fun} ->
			    FunName = refac_syntax:data(refac_syntax:function_name(Fun)),
			    FunArity = refac_syntax:function_arity(Fun),
			    Inscope_Funs = lists:map(fun({_M1,F, A})->{F, A} end, refac_util:inscope_funs(Info)),
			    case lists:member({FunName, FunArity+1}, Inscope_Funs) of 
				true ->{error, "Function "++ atom_to_list(FunName)++"/"++
					integer_to_list(FunArity+1)++" is already in scope!"};
				_   -> FunDefPos =get_fun_def_loc(Fun), 
				       ParName1 = list_to_atom(ParName),
				       case gen_cond_analysis(Fun, Exp1, ParName1) of 
					   ok -> 
					       SideEffect = refac_util:has_side_effect(FileName, Exp1, SearchPaths),
					       case SideEffect of  
						   unknown -> {unknown_side_effect, {ParName1, FunName, FunArity, FunDefPos,Exp1}};
						   _ ->AnnAST1=gen_fun(ModName, AnnAST, ParName1, FunName, FunArity, FunDefPos,Info, Exp1, SideEffect),
						       case Editor of 
							   emacs ->
							       refac_util:write_refactored_files_for_preview([{{FileName,FileName}, AnnAST1}]),
							       {ok, [FileName]};
							   eclipse  ->
							       Res = [{FileName, FileName, refac_prettypr:print_ast(refac_util:file_format(FileName),AnnAST1)}],
							       {ok, Res}
						       end
					       end;	     
					   {error, Reason} -> {error, Reason}
				       end
			    end;
			{error, _} -> {error, "You have not selected an expression within a function."}		    
		    end;
		{error, Reason} -> {error, Reason}
	    end;
	false  -> {error, "Invalid parameter name!"}
    end.  

%% =====================================================================
%% @spec_to_fun_expr(Exp::expression())->expression()

%% TODO: make the free variables as parameters.
make_actual_parameter(ModName, Exp, SideEffect) ->
    FreeVars = lists:map(fun({V,_}) -> V end, refac_util:get_free_vars(Exp)),
    case FreeVars==[] of 
	true -> 
	    case refac_syntax:type(Exp) of 
		fun_expr -> Exp;
		implicit_fun -> Exp;
		_ ->  case lists:keysearch(fun_def, 1, refac_syntax:get_ann(Exp)) of 
			  {value, {fun_def, {M, _N, A, _P1, _P2}}} ->
			      case refac_syntax:type(Exp) of 
				  atom -> case M == ModName of 
					      true -> refac_syntax:implicit_fun(Exp, refac_syntax:integer(A));				       
					      _ -> Exp1 = refac_syntax:module_qualifier(refac_syntax:atom(M), Exp),
						   refac_syntax:implicit_fun(Exp1, refac_syntax:integer(A))
					  end;
				  module_qualifier -> refac_syntax:implicit_fun(Exp, refac_syntax:integer(A));
				  _ -> throw({error, 
					      "Wrangler failed to perform this refactoring, because it could not get enough information about the expression selected."})
			      end;					     
			  _ -> case SideEffect of 
				   true -> case refac_syntax:type(Exp) of
					       fun_expr -> Exp;
					       _ -> C = refac_syntax:clause([],[],[Exp]),
						    refac_syntax:copy_attrs(Exp, refac_syntax:fun_expr([C]))
					   end;
				   _ -> Exp
			       end
		      end
	    end;
	false -> Pars  = lists:map(fun(P) ->refac_syntax:variable(P) end, FreeVars),
		 C = refac_syntax:clause(Pars,[],[Exp]),
		 refac_syntax:copy_attrs(Exp, refac_syntax:fun_expr([C]))    
    end.
	    
%% =====================================================================
%% @spec gen_cond_analysis(Fun::function(), Exp::expression(), ParName::atom())-> term()
%%
gen_cond_analysis(Fun, Exp, ParName) ->
     case lists:keysearch(category,1, refac_syntax:get_ann(Exp)) of 
	{value, {category, record_field}} -> throw({error, "Record field cannot be replaced by a variable."});
        {value, {category, record_type}} -> throw({error, "Record type cannot be replaced by a variable."});	 
        {value, {category, guard_expression}} -> throw({error, "Generalisation of a guard expression is not supported."});
	{value, {category, application_op}} -> 
	     GuardRanges= refac_syntax_lib:fold(fun(N,S) ->
							case lists:keysearch(category,1,refac_syntax:get_ann(N)) of
							    {value, {category,guard_expression}} -> [refac_util:get_range(N)|S];
							    _ -> S
							end
						end,[],Fun),
	     {Start, End} = refac_util:get_range(Exp),
	     case lists:any(fun({S1,E1}) -> (S1 =< Start) andalso ( End =< E1) end, GuardRanges) of 
		 true ->throw({error, "Generalisation of a function application in a guard expression is not supported."});
		 _ -> ok
	     end;
	 _ -> ok     
     end,
    Exp_Free_Vars = refac_util:get_free_vars(Exp),
    Exp_Export_Vars =refac_util:get_var_exports(Exp),
    if (Exp_Export_Vars /=[]) ->
	    {error, "The selected expression exports locally declared variable(s)!"};
       true -> Cs = refac_syntax:function_clauses(Fun),
	       Vars0 = lists:foldl(fun(C,Accum)->Accum++
						     refac_syntax_lib:fold(fun(C1, A) -> A++refac_util:get_bound_vars(C1) end, [],C)
						     ++Exp_Free_Vars end, [], Cs),
	       Vars= lists:map(fun({X,_Y})->X end, Vars0),
	       case lists:member(ParName, Vars) of 
		   true ->
		       {error, ("The given parameter name conflicts with the existing parameters or"++
				" will change the semantics of the function to be generalised!")};
		   _ ->
		      ok
	       end
    end.



%% =====================================================================
%% @spec gen_fun(Tree::syntaxTree(),ParName::atom(), FunName::atom(), Arity::integer(), DefPos::Pos,
%% Info::[{Key, term()}], Exp::expression(),SideEffect::bool()) -> syntaxTree()
%%
%%          Key = attributes | errors | exports | functions | imports
%%                | module | records | rules | warnings
%%    
gen_fun(ModName, Tree, ParName, FunName, Arity, DefPos,Info, Exp, SideEffect) ->
      R = refac_util:is_exported({FunName, Arity}, Info),
      Tree1 = if R  -> add_function(ModName, Tree, FunName,DefPos, Exp, SideEffect);
		 true -> Tree
	      end,		  
       {Tree2, _} = refac_util:stop_tdTP(fun do_gen_fun/2, Tree1, {ModName, ParName, FunName, Arity, DefPos,Info, Exp,SideEffect}),
       Tree2.


-spec(gen_fun_1/8::(boolean(), filename(),atom(), atom(), integer(), pos(), syntaxTree(), integer()) 
	  -> {ok, string()}).
gen_fun_1(SideEffect, FileName,ParName, FunName, Arity, DefPos, Exp, TabWidth) ->
    gen_fun_1(SideEffect, FileName,ParName, FunName, Arity, DefPos, Exp, TabWidth,emacs).

-spec(gen_fun_1_eclipse/8::(boolean(), filename(),atom(), atom(), integer(), pos(), syntaxTree(), integer()) 
	  -> {ok, [{filename(), filename(),string()}]}).
gen_fun_1_eclipse(SideEffect, FileName,ParName, FunName, Arity, DefPos, Exp, TabWidth) ->
    gen_fun_1(SideEffect, FileName,ParName, FunName, Arity, DefPos, Exp, TabWidth, eclipse).

gen_fun_1(SideEffect, FileName,ParName, FunName, Arity, DefPos, Exp, TabWidth, Editor) ->
    %% somehow I couldn't pass AST to elisp part, as some occurrences of 'nil' were turned into '[]'.
    {ok, {AnnAST, Info}} = refac_util:parse_annotate_file(FileName,true, [],TabWidth),  
    {ok, ModName} = get_module_name(Info),
    R = refac_util:is_exported({FunName, Arity}, Info),
    AnnAST1 = if R  -> add_function(ModName, AnnAST, FunName,DefPos, Exp, SideEffect);
	       true -> AnnAST
	    end,		       
    {AnnAST2, _} = refac_util:stop_tdTP(fun do_gen_fun/2, AnnAST1, {ModName, ParName, FunName, Arity, DefPos,Info, Exp,SideEffect}),
    case Editor of 
	emacs ->
	    refac_util:write_refactored_files([{{FileName,FileName}, AnnAST2}]),
	    {ok, "Refactor succeeded"};
	eclipse ->
	    Res = [{FileName, FileName, refac_prettypr:print_ast(refac_util:file_format(FileName),AnnAST2)}],
	    {ok, Res}
    end.


-spec(gen_fun_2_eclipse/8::(filename(), atom(), atom(), integer(), pos(), syntaxTree(), [dir()], integer()) 
	  ->{ok, [{filename(), filename(),string()}]}|{unknown_side_effect, {atom(),atom(),integer(), pos(), syntaxTree()}}).
gen_fun_2_eclipse(FileName, ParName1, FunName, FunArity, FunDefPos, Exp, SearchPaths, TabWidth) ->
    %% somehow I couldn't pass AST to elisp part, as some occurrences of 'nil' were turned into '[]'.
    {ok, {AnnAST, Info}} = refac_util:parse_annotate_file(FileName,true, SearchPaths, TabWidth),
    {ok, ModName} = get_module_name(Info),
    SideEffect = refac_util:has_side_effect(FileName, Exp, SearchPaths),
    case SideEffect of  
	false ->AnnAST1=gen_fun(ModName, AnnAST, ParName1, 
				FunName, FunArity, FunDefPos,Info, Exp, SideEffect),
		Res = [{FileName, FileName, refac_prettypr:print_ast(refac_util:file_format(FileName),AnnAST1)}],
		{ok, Res};		
	true -> AnnAST1=gen_fun(ModName, AnnAST, ParName1,FunName, FunArity, FunDefPos,Info, Exp, SideEffect),
		Res = [{FileName, FileName, refac_prettypr:print_ast(refac_util:file_format(FileName),AnnAST1)}],
		{ok, Res};		
	unknown ->
	    {unknown_side_effect, {ParName1, FunName, FunArity, FunDefPos,Exp}}
    end.	  
    
    

%% =====================================================================
%% @spec add_function(Tree::syntaxTree(),FunName::atom(),DefPos::Pos, Exp::expression()) ->syntaxTree()
%%
add_function(ModName, Tree, FunName, DefPos, Exp, SideEffect) -> 				
    Forms = refac_syntax:form_list_elements(Tree),
    MakeClause = fun(C, Expr, Name) ->
			  Pats = refac_syntax:clause_patterns(C),
			  Pats1 = lists:map(fun(P)->{P1, _} =refac_util:stop_tdTP(fun do_replace_underscore/2, P, []), P1 end, Pats),
			  G =  refac_syntax:clause_guard(C),
			  Op = refac_syntax:operator(Name),    
			  Args = Pats1 ++ [Expr],
			  Body = [refac_syntax:application(Op, Args)],
			  refac_syntax:clause(Pats, G, Body)
		  end,
    F = fun(Form) ->
		case refac_syntax:type(Form) of 
		    function -> case get_fun_def_loc(Form) of 
				    DefPos -> 
					Exp1 = make_actual_parameter(ModName, Exp, SideEffect),
					NewForm = refac_syntax:function(refac_syntax:atom(FunName), 
									[MakeClause(C, Exp1,FunName) 
									 || C <- refac_syntax:function_clauses(Form)]),
					[refac_util:reset_attrs(NewForm), Form];
				    _ -> [Form]
				end;
		    _ -> [Form] 
		end
	end,		
    refac_syntax:form_list([T|| Form<-Forms, T <- F(Form)]).

do_replace_underscore(Tree, _Others) ->
    case refac_syntax:type(Tree) of 
	underscore ->
	   {refac_syntax:atom(undefined), true};
	_ -> {Tree,false}
    end.
%% =====================================================================
%%
do_gen_fun(Tree, {ModName, ParName, FunName, Arity, DefPos,Info, Exp, SideEffect}) ->    
     Exp1 =  make_actual_parameter(ModName, Exp, SideEffect),
    case  refac_syntax:type(Tree) of 
	function -> 
	    case get_fun_def_loc(Tree) of 
		DefPos -> 
		    A1 = refac_syntax:function_arity(Tree),
		    if A1 == Arity -> 
			    Name = refac_syntax:function_name(Tree),
			    NewPar= refac_syntax:variable(ParName),
			    Cs=[add_parameter(C1, NewPar) 
				||  C1 <-[ add_actual_parameter(replace_exp_with_var(C, {ParName, Exp, SideEffect}),
								{FunName, Arity , NewPar, Info})
					   || C <- refac_syntax:function_clauses(Tree)]],
			    {refac_syntax:copy_pos(Tree, 
						   refac_syntax:copy_attrs(Tree, refac_syntax:function(Name, Cs))), true};
		       true -> 		    
			    {add_actual_parameter(Tree, {FunName, Arity, Exp1, Info}), true}
		    end;
		_ -> {add_actual_parameter(Tree, {FunName, Arity, Exp1, Info}), true}
	    end;
	_ -> {Tree, false}
    end.


replace_exp_with_var(Tree, {ParName, Exp, SideEffect}) ->
    {Tree1, _} =refac_util:stop_tdTP(fun do_replace_exp_with_var/2, Tree, {ParName, Exp, SideEffect}),
    Tree1.

do_replace_exp_with_var(Tree, {ParName, Exp, SideEffect}) ->
    Range = refac_util:get_range(Exp),
    case refac_util:get_range(Tree) of 
	Range ->
	    FreeVars = lists:map(fun({V,_}) -> V end, refac_util:get_free_vars(Exp)),
	    Pars  = lists:map(fun(P) ->refac_syntax:variable(P) end, FreeVars),
	    case SideEffect of 
			false -> case FreeVars==[] of 
			     true ->{refac_syntax:variable(ParName), true};
			     _ -> Op1 = refac_syntax:operator(ParName),
				  {refac_syntax:application(Op1, Pars), true}
			 end;
	        _ ->  Op1 = refac_syntax:operator(ParName),
		      {refac_syntax:application(Op1, Pars),true}
	    end;
	_ -> {Tree, false}
    end.
   
		
add_actual_parameter(Tree, {FunName, Arity,Exp, Info})->
   {Tree1, _} =refac_util:stop_tdTP(fun do_add_actual_parameter/2, Tree, {FunName, Arity, Exp, Info}),
    Tree1.
    

do_add_actual_parameter(Tree, {FunName, Arity, Exp, Info}) ->
  {ok, ModName} = get_module_name(Info),
   Message = fun (Pos) -> ?wrangler_io("WARNING: function ***apply*** is used at location({line, col}):~p, and wrangler " 
				    "could not decide whether this site should be refactored, please check manually!\n",
				    [Pos])
	     end,
   case refac_syntax:type(Tree) of 
	  application ->
	      Operator = refac_syntax:application_operator(Tree),
	      Arguments = refac_syntax:application_arguments(Tree),
	      case application_info(Tree) of 
		  {{none, FunName}, Arity} ->
		      Exp1 = refac_util:update_ann(Exp, {range, {0, 0}}),
		      Arguments1 = Arguments ++ [Exp1],
		      {refac_syntax:copy_attrs(Tree, refac_syntax:application(Operator, Arguments1)), false}; 
		  {{ModName, FunName}, Arity} ->
		      Exp1 = refac_util:update_ann(Exp, {range, {0,0}}),
		      Arguments1 = Arguments ++ [Exp1],
		      {refac_syntax:copy_attrs(Tree, refac_syntax:application(Operator, Arguments1)), false};
		  {{_, apply},2} ->
		      F = lists:nth(1, Arguments),
		      T = lists:nth(2, Arguments),
		      case refac_syntax:type(F) of 
			   implicit_fun ->
			      Name = refac_syntax:implicit_fun_name(F),
			      B = refac_syntax:atom_value(refac_syntax:arity_qualifier_body(Name)),
			      A = refac_syntax:integer_value(refac_syntax:arity_qualifier_argument(Name)),
			      case {B, A} of 
				  {FunName, Arity} ->
				      Exp1 = refac_util:update_ann(Exp, {range, {0,0}}),
				      case refac_syntax:type(T) of 
					  list -> Args1 = refac_syntax:copy_attrs(T, refac_syntax:list( refac_syntax:list_elements(T) ++[Exp1]));
					  _ -> Op = refac_syntax:operator('++'),
					       L = refac_syntax:list([Exp1]),
					       Args1 = refac_syntax:copy_attrs(T, refac_syntax:infix_expr(T,Op, L))
				      end,
				      F1 = refac_syntax:implicit_fun(refac_syntax:atom(FunName),
								       refac_syntax:integer(Arity+1)),
				      {refac_syntax:copy_pos(Tree, (refac_syntax:copy_attrs(Tree, refac_syntax:application
									    (Operator, [F1, Args1])))), false};
				      
				  _ -> {Tree, false}
			      end;
			   _ -> {Tree, false}
		       end;
		  {{_, apply},3} ->
		      [Mod,Fun,Args] = Arguments,
		      Mod1 = refac_util:try_evaluation([refac_syntax:revert(Mod)]),
		      Fun1 = refac_util:try_evaluation([refac_syntax:revert(Fun)]),
		      {value,{module, M}} = lists:keysearch(module, 1, Info),
		      Pos = refac_syntax:get_pos(Tree),
		      case Fun1 of 
			  {value, FunName} ->
			      case Mod1 of 
				  {value,M} ->
				      case refac_syntax:type(Args) of 
					  list ->
					      case refac_syntax:list_length(Args) of 
						  Arity ->
						      Exp1 =refac_util:update_ann(Exp, {range, {0,0}}),
						      Args1 =refac_syntax:copy_attrs(Args, 
										     refac_syntax:list(refac_syntax:list_elements(Args) ++[Exp1])),
						      {refac_syntax:copy_pos(Tree, (refac_syntax:copy_attrs(Tree, 
							refac_syntax:application(Operator, [Mod, Fun, Args1])))), false};
						 _ -> {Tree, true}
					      end;
					  _ -> Message(Pos),
					       {Tree, true}
				      end;
				  {value, _}-> {Tree, true};
				  {error, _Reason} -> case refac_syntax:type(Args) of 
							  list -> case refac_syntax:list_length(Args) of 
								      Arity -> Message(Pos),
									       {Tree, true};
								      _ -> {Tree, true}
								  end;
							  _ -> Message(Pos),
							       {Tree, true}
						      end
			      end;
			  {value, _} -> {Tree, true};
			  {error, _Reason} ->  
			      case Mod1 of 
				  {value, M} ->
				      case refac_syntax:type(Args) of 
					  list -> case refac_syntax:list_length(Args) of 
						      Arity -> Message(Pos),
							       {Tree, true};
						      _ -> {Tree, true}
						  end;
					  _ -> Message(Pos),
					       {Tree, true}
				      end;
				  {value, _} -> {Tree, true};
				  {error, _Reason} -> case refac_syntax:type(Args) of 
							  list-> case refac_syntax:list_length(Args) of 
								     Arity -> Message(Pos),
									      {Tree, true};
								     _ -> {Tree, true}
								 end;
							  _  -> Message(Pos),
								{Tree, true}
						      end
			      end
		      end;     
		  {{_, spawn}, 3} ->transform_spawn_call(Tree, {FunName, Arity, Exp, Info});
		  {{_, spawn}, 4} -> transform_spawn_call(Tree, {FunName, Arity, Exp, Info}); 
		  {{_, spawn_link}, 3} ->transform_spawn_call(Tree, {FunName, Arity, Exp, Info});
		  {{_, spawn_link}, 4} ->transform_spawn_call(Tree, {FunName, Arity, Exp, Info});
		  _ -> {Tree, false}
	      end;
       implicit_fun ->
	   Name = refac_syntax:implicit_fun_name(Tree),
	   B = refac_syntax:atom_value(refac_syntax:arity_qualifier_body(Name)),
	   A = refac_syntax:integer_value(refac_syntax:arity_qualifier_argument(Name)),
	   case {B, A} of 
	       {FunName, Arity} ->
		   {refac_syntax:copy_attrs(Tree, refac_syntax:implicit_fun(refac_syntax:atom(FunName),
								       refac_syntax:integer(Arity+1))), true};
	       _ -> {Tree, false}
	   end;				     
       _  -> {Tree, false}  
   end.

transform_spawn_call(Node,{FunName, Arity, Exp, Info}) ->
    {ok, ModName} = get_module_name(Info),
     Message = fun (Pos) -> ?wrangler_io("WARNING: function ***spawn*** is used at location({line, col}):~p, and wrangler " 
				    "could not decide whether this site should be refactored, please check!!!\n",
				     [Pos])
	      end,
    Operator = refac_syntax:application_operator(Node),
    Arguments = refac_syntax:application_arguments(Node),
    [N, Mod, Fun, Args] = if length(Arguments)==4 -> Arguments;			       
				true -> [none] ++ Arguments
			     end,
    Mod1 = refac_util:try_evaluation([refac_syntax:revert(Mod)]),
    Fun1 = refac_util:try_evaluation([refac_syntax:revert(Fun)]),
    Pos = refac_syntax:get_pos(Node),
    case Fun1 of 
	{value, FunName} ->
	    case Mod1 of 
		{value,ModName} ->
		    case refac_syntax:type(Args) of 
			list ->
			    case refac_syntax:list_length(Args) of 
				Arity ->
				    Exp1 =refac_util:update_ann(Exp, {range, {0,0}}),
				    Args1 =refac_syntax:copy_attrs(Args, 
								   refac_syntax:list(refac_syntax:list_elements(Args)++[Exp1])), 
				    App = if length(Arguments) == 4 ->
						  refac_syntax:application(Operator, [N, Mod, Fun, Args1]);
					     true -> refac_syntax:application(Operator, [Mod, Fun, Args1])
					  end,
				    {refac_syntax:copy_pos(Node,(refac_syntax:copy_attrs(Node, App))), true};
				_ -> {Node, false}
			    end;
			nil -> if Arity==0 ->
				    Exp1 =refac_util:update_ann(Exp, {range, {0,0}}),
				    Args1 =refac_syntax:copy_attrs(Args, 
								   refac_syntax:list(refac_syntax:list_elements(Args) ++[Exp1])), 

				   App = if length(Arguments) == 4 ->
					  refac_syntax:application(Operator, [N, Mod, Fun, Args1]);
					  true -> refac_syntax:application(Operator, [Mod, Fun, Args1])
					  end,
				       {refac_syntax:copy_pos(Node,(refac_syntax:copy_attrs(Node, App))), true};
				  true -> {Node, false}
			       end;
			_ -> Message(Pos),
			     {Node, false}
		    end;
		{value, _}-> {Node, false};
		{error, _Reason} -> 
		    case refac_syntax:type(Args) of 
			list -> case refac_syntax:list_length(Args) of 
				    Arity -> Message(Pos),
					     {Node, false};
				    _ -> {Node, false}
				end;
			_ -> Message(Pos),
			     {Node, false}
		    end
	    end;
	{value, _} -> {Node, false};
	{error, _Reason} ->  
	    case Mod1 of 
		{value, ModName} ->
		    case refac_syntax:type(Args) of 
			list -> case refac_syntax:list_length(Args) of 
				    Arity -> Message(Pos),
					     {Node, false};
				    _ -> {Node, false}
				end;
			_ -> Message(Pos),
			     {Node, false}
		    end;
		{value, _} -> {Node, false};
		{error, _Reason} -> case refac_syntax:type(Args) of 
					list-> case refac_syntax:list_length(Args) of 
						   Arity -> Message(Pos),
							    {Node, false};
						   _ -> {Node, false}
					       end;
					_  -> Message(Pos),
					      {Node, false}
				    end
	    end
    end.



%% =====================================================================
%% @spec application_info(Tree::syntaxTree())->term()
%%       
application_info(Node) ->
    case refac_syntax:type(Node) of 
	application ->
	    Operator = refac_syntax:application_operator(Node),
	    Arguments = refac_syntax:application_arguments(Node),
	    Arity = length(Arguments),
	    case refac_syntax:type(Operator) of 
		atom -> Op = refac_syntax:atom_value(Operator),
			{{none,Op}, Arity}; 
		module_qualifier ->
		        Mod = refac_syntax:module_qualifier_argument(Operator),
		        Fun = refac_syntax:module_qualifier_body(Operator),
		        T1 = refac_syntax:type(Mod), 
		        T2 = refac_syntax:type(Fun),
		        case T1 of 
		  	    atom -> 
				Mod1 = refac_syntax:atom_value(Mod),
				case T2 of 
					atom -> Fun1 = refac_syntax:atom_value(Fun),
						{{Mod1, Fun1}, Arity};
				        _ ->{{Mod1, expressionfunname}, Arity}
					end;
			    _ -> case T2 of 
				     atom -> Fun1 = refac_syntax:atom_value(Fun),
					     {{expressionmodname, Fun1}, Arity};
				     _ -> {{expressionmodname,expressionfunname}, Arity}
				 end
			    end;
		_  -> {{none,expressionoperator}, Arity}
	    end;
	_ -> erlang:error(badarg)
    end.

%% =====================================================================
%% @spec add_parameter(C::clause(),NewPar::pattern()) ->clause()
%%
add_parameter(C, NewPar) ->       
    Pats = refac_syntax:clause_patterns(C),
    G    = refac_syntax:clause_guard(C),
    Body = refac_syntax:clause_body(C),
    Pats1 = Pats ++ [NewPar],
    refac_syntax:copy_pos(C, refac_syntax:copy_attrs(C, refac_syntax:clause(Pats1, G, Body))).


get_fun_def_loc(Node) ->
     As = refac_syntax:get_ann(Node),
     case lists:keysearch(fun_def, 1, As) of 
	  {value, {fun_def, {_M, _N, _A, _P, DefinePos}}} -> DefinePos;
	 _ -> false
     end.


get_module_name(ModInfo) ->				      
    case lists:keysearch(module, 1, ModInfo) of
	{value, {module, ModName}} -> {ok, ModName};
	false ->
	    {error, "Can not get the current module name."}
    end.
