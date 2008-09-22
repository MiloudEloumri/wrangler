%% =====================================================================
%% Refactoring Interface Functions.
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

%% Author contact: H.Li@kent.ac.uk, Simon.J.Thompson@kent.ac.uk
%%
%% =====================================================================

%% @copyright 2006-2009 Huiqing Li, Simon Thompson
%%
%% @author Huiqing Li <hl@kent.ac.uk>
%%   [http://www.cs.kent.ac.uk/projects/forse]

%% @version  0.5
%% @end
%%
%% @doc This module describes the refactorings that are currently supported by Wrangler.
-module(wrangler).

-export([rename_var/5, rename_fun/5, rename_mod/3,
	 rename_process/5, rename_mod_batch/3, generalise/5,
	 move_fun/6, duplicated_code_in_buffer/3,
	 duplicated_code_in_dirs/3, expression_search/3,
	 fun_extraction/4, fold_expr/1,  fold_expr_by_loc/4, fold_expr_by_name/6, 
	 instrument_prog/2,
	 uninstrument_prog/2, add_a_tag/5, tuple_funpar/5,
	 tuple_to_record/8, register_pid/5, fun_to_process/5]).

-export([rename_var_eclipse/5, rename_fun_eclipse/5,
	 rename_mod_eclipse/3, generalise_eclipse/5,
	 move_fun_eclipse/6, fun_extraction_eclipse/4,
	 gen_fun_1_eclipse/7, gen_fun_2_eclipse/7,
	 tuple_funpar_eclipse/5, tuple_to_record_eclipse/8,
	 fold_expr_by_loc_eclipse/4, fold_expr_by_name_eclipse/6,
	 fold_expression_1_eclipse/4,fold_expression_2_eclipse/6]).

-include("../hrl/wrangler.hrl").

%% ====================================================================================================
%% @doc Rename a variable name with a user-supplied new name.
%% <p> To apply this refactoring, point the cursor to  any occurrence of this variable, then select
%% <em> Rename Variable Name </em> from the <em> Refactor </em> menu, after that the refactorer will prompt
%% to enter the new parameter name in the mini-buffer. 
%% </p>
%% <p> This refactoring has a local effect, i.e., it only affects the function in which the refactoring is initialised. 
%% </p>
%% <p> The following <em> side-conditions </em> apply to this refactoring: 
%% <li> The new variable name should not conflict with any of the declared variable names in the same scope;</li>
%% <li> The new name should not shadow any of the existing variables in the outer scopes, or be shadowed by any of 
%% of existing variables in the inner scopes, i.e., renaming to the new name should not change the semantics of the 
%% program.</li>
%% </p>
%% @spec rename_var(FileName::filename(), Line::integer(), Col::integer(), NewName::string(), SearchPaths::[dir()]) ->{error, string()} | {ok, string()}

-spec(rename_var/5::(filename(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, string()}).
rename_var(FileName, Line, Col, NewName, SearchPaths) ->
    refac_rename_var:rename_var(FileName, Line, Col, NewName, SearchPaths).

%% @private
-spec(rename_var_eclipse/5::(filename(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [{filename(), filename(), string()}]}).
rename_var_eclipse(FileName, Line, Col, NewName, SearchPaths) ->
    refac_rename_var:rename_var_eclipse(FileName, Line, Col, NewName, SearchPaths).

%%=========================================================================================
%% @doc Rename a function name with a user-supplied new name.
%% <p> To apply this refactoring, point the cursor to any occurrence of this 
%% function name, then select <em> Rename Function Name </em> from the <em> Refactor </em> menu, 
%% after that the refactorer will prompt to enter  the new function name in the mini-buffer.
%% </p>
%% <p>
%% When renaming an exported function name, this refactoring has a global effect, i.e.,
%% it affects all those modules in which this function is imported/used.
%% </p>
%% <p> The following <em> side-conditions </em> apply to this refactoring:
%% <li> The new function name should not cause confliction with any of the functions which are in scope in the 
%% current module;</li>
%% <li> In the case that the function to be renamed is imported by another module, the new function name (with the same 
%% arity) should not be already in scope (either defined or imported) in that module. </li>
%% </p>
%% @spec rename_fun(FileName::filename(), Line::integer(), Col::integer(), NewName::string(), SearchPaths::[dir()])
%% -> {error, string()} | {ok, [filename()]}

-spec(rename_fun/5::(string(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [filename()]}).
rename_fun(FileName, Line, Col, NewName, SearchPaths) ->
    refac_rename_fun:rename_fun(FileName, Line, Col, NewName, SearchPaths).

%%@private
-spec(rename_fun_eclipse/5::(string(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [{filename(), filename(), string()}]}).
rename_fun_eclipse(FileName, Line, Col, NewName, SearchPaths) ->
    refac_rename_fun:rename_fun_eclipse(FileName, Line, Col, NewName, SearchPaths).

%%======================================================================================
%% @doc Rename a module with a user-supplied new name.
%% <p> To apply this refactoring, point the cursor to anywhere in the module to be renamed, then select 
%% <em> Rename Module Name </em> from the <em> Refactor </em> menu, after that, the refactorer will prompt to enter 
%% the new module name in the mini-buffer.
%% </p>
%% <p> This refactoring has a global effect, i.e., it affects all those modules in which the module to be renamed is 
%% imported, or used as a module qualifier.
%% </p>
%% <p>
%% The following <em> side-conditions </em> apply to this refactoring:
%% <li> The new module name should not have been used as a module name in the program under consideration. </li>
%% <li> This refactoring assume that the file basename is always the same as the module name, therefore this 
%% refactoring changes the filename as well. </li>
%% </p>
%% @spec rename_mod(FileName::filename(), NewName::string(), SearchPaths::[dir()])-> {error, string()} | {ok, [filename()]} 
%%   
-spec(rename_mod/3::(filename(), string(), [dir()]) -> {error, string()} | {ok, [filename()]}).
rename_mod(FileName, NewName, SearchPaths) ->
    refac_rename_mod:rename_mod(FileName, NewName, SearchPaths).

%%@private
-spec(rename_mod_eclipse/3::(filename(), string(), [dir()]) ->
	     {error, string()} | {ok, [{filename(), filename(), string()}]}).
rename_mod_eclipse(FileName, NewName, SearchPaths) ->
    refac_rename_mod:rename_mod_eclipse(FileName, NewName, SearchPaths).

%% =====================================================================
%% @doc Rename a collection of module names in batch mode. 
%% <p> This refactoring is supposed to be run from the Erlang shell. For example, 
%% to rename all those module names which match the regular expression "foo_*" to 
%% "foo_*_1_0" in the directory <code> c:/wrangler/test </code>, just type the following command:
%% <code> wrangler:rename_mod_batch("foo_*, "foo_*_1_0", ["c:/wrangler/test"]) </code>.
%% </p>
%% <p> This refactoring has a global effect. </p>
%% <p> The following <em> side-conditions </em> apply to this refactoring:
%% <li> The new module names should not conflict with each other, or any existing module names 
%% in the same scope which will not be renamed. </li>
%% <li> This refactorings assumes that the file basename is always the same as the module name. </li>
%% </p>
% @spec rename_mod_batch(OldNamePattern::string(), NewNamePattern::string(), 
%%                        SearchPaths::[dir()])-> ok | {error, string()}
%%   
-spec(rename_mod_batch/3::(string(), string(), [dir()])->
	     ok | {error, string()}).
rename_mod_batch(OldNamePattern, NewNamePattern, SearchPaths) ->
    refac_batch_rename_mod:batch_rename_mod(OldNamePattern, NewNamePattern, SearchPaths).


%% ==========================================================================================
%% @doc  Generalise a function definition.
%% <p>Generalise a function definition by selecting a sub-expression of its right-hand 
%% side and making this the value of a new argument added to the definition of the function. 
%% The sub-expression becomes the actual parameter at the call sites. </p>
%%
%% <p> To apply this refactoring, highlight the expression first, then  select 
%% <em> Generalise Function Definition </em> from the <em>Refactor</em> menu, after 
%% that the refactorer will prompt to enter the parameter name in the mini-buffer. </p>
%% 
%% <p> Here is an example of generalisation, in which the function <code> add_one </code> defined 
%% on the left-hand side is generalised on the expression <code> 1 </code>, and the result is 
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
%%
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
%% <p> The following <em> side-conditions </em> apply to this refactoring:
%% <li> Suppose the function to be generalised is <code>foo/n </code>, then <code>foo/n+1</code> should not  
%% be in scope before the generalisation;</li>
%% <li> The selected expression should not contain any locally declared variable(s), unless the selected expression 
%% has side effect, in which case the locally declared variables will become the parameters of the function expression.
%% </li>
%% <li> The new parameter name provided by the user should not conflict with the existing parameters or
%% change the semantics of the function to be generalised. </li>
%% </p>

%% @spec generalise(FileName::filename(), Start::Pos, End::Pos, ParName::string(), SearchPaths::[dir()])-> {ok, string()} | {error, string()}
%%         Pos = {integer(), integer()}
-spec(generalise/5::(filename(),pos(), pos(),string(), dir()) -> {ok, string()} | {error, string()}).
generalise(FileName, Start, End, ParName, SearchPaths) ->
    refac_gen:generalise(FileName, Start, End, ParName,  SearchPaths).

%%@private
-spec(generalise_eclipse/5::(filename(),pos(), pos(),string(), dir()) -> {ok, [{filename(), filename(), string()}]}).
generalise_eclipse(FileName, Start, End, ParName, SearchPaths) ->
    refac_gen:generalise_eclipse(FileName, Start, End, ParName,  SearchPaths).

%%@private
-spec(gen_fun_1_eclipse/7::(boolean(), filename(),atom(), atom(), integer(), pos(), syntaxTree()) -> {ok, [{filename(), filename(),string()}]}).
gen_fun_1_eclipse(SideEffect, FileName, ParName, FunName, Arity, DefPos, Expr) ->
    refac_gen:gen_fun_1_eclipse(SideEffect, FileName, ParName, FunName, Arity, DefPos, Expr).

%%@private
-spec(gen_fun_2_eclipse/7::(filename(),atom(), atom(), integer(), pos(), syntaxTree(), [dir()]) -> {ok, [{filename(), filename(), string()}]}).
gen_fun_2_eclipse(FileName, ParName, FunName, Arity, DefPos, Expr, SearchPaths) ->
    refac_gen:gen_fun_2_eclipse(FileName, ParName, FunName, Arity, DefPos, Expr, SearchPaths).

%% ================================================================================
%% @doc Move a function definition from its current module to another module.
%% <p> To apply this refactoring, point the cursor at the function definition, then 
%% select <em> Move Definition to Another Module</em> from the <em> Refactor </em> menu, 
%% after that the refactorer will prompt to enter the target module name in the mini-buffer. 
%% </p>
%% <p> This refactoring has a global effect, i.e., it affects all the modules in which 
%%     the function is imported/used.
%% </p>
%% <p> This refactoring assumes that an Erlang module name always matches it file name.
%% </p>
%% <p> Suppose we move functin <em> foo/n </em> from its current module <em> M </em> 
%%     to module <em> N </em>, then the following <em> side-conditions </em> apply to 
%%     this refactoring: 
%% <li> If <em> foo/n </em> is already in scope in module <em> N </em>, then its defining 
%%      module should be  <em> M </em>.
%% </li>
%% <li> Function <em> foo/n </em> should not contain any uses of <em> implicit fun expressions </em> (Note: move a 
%% collection of modules together to another module will be supported by another refactoring).
%% </li>
%% </p>
%% @spec move_fun(FileName::filename(),Line::integer(),Col::integer(),TargetModName::string(), 
%%                CreateNewFile::boolean(),SearchPaths::[dir()])-> {ok, [{filename(), filename()}]} | {error, string()}
%%         

-spec(move_fun/6::(filename(),integer(),integer(), string(), atom(),[dir()])
        -> {ok, [{filename(), filename()}]}
           | {error, string()}).
move_fun(FileName, Line, Col, TargetModName, CreateNewFile, SearchPaths) ->
    refac_move_fun:move_fun(FileName, Line, Col, TargetModName, CreateNewFile, SearchPaths).


%%@private
-spec(move_fun_eclipse/6::(filename(),integer(),integer(), string(), atom(),[dir()])
        -> {ok, [{filename(), filename(), string()}]}
           | {error, string()}).
move_fun_eclipse(FileName, Line, Col, TargetModName, CreateNewFile, SearchPaths) ->
    refac_move_fun:move_fun_eclipse(FileName, Line, Col, TargetModName, CreateNewFile, SearchPaths).


%% ==================================================================================
%% @doc A duplicated code detector that only works with the current Erlang buffer.
%% <p> This function reports the duplicated code fragments found in the current Erlang buffer. It does 
%% not remove those code clones. The user will be prompted for two parameters: the minimum number of 
%% tokens a cloned code fragment should have, and the minimum number of times a code fragment is duplicated.
%% </p>
%% <p> The current version of the duplicated code detector can report clones that are syntactically 
%% identical after consistent renaming of variables, except for variations in literals, layout and comments.
%% </p>
%% @spec duplicated_code_in_buffer(FileName::filename(),MinToks::integer(),MinClones::integer()) -> {ok, string()}
%% 
-spec(duplicated_code_in_buffer/3::(filename(), string(), string()) ->{ok, string()}).     
duplicated_code_in_buffer(FileName, MinToks, MinClones) -> 
    refac_duplicated_code:duplicated_code([FileName], MinToks, MinClones).


%% =====================================================================================
%% @doc A duplicated code detector that works with multiple Erlang modules.
%% <p> This function reports duplicated code fragments found in the directories specified by SearchPaths.
%% The user will be prompted for two parameters: the minimum number of 
%% tokens that a cloned code fragment should have, and the minimum number of times a code fragment is duplicated.
%% </p>
%% <p> The current version of the duplicated code detector can report clones that are syntactically 
%% identical after consistent renaming of variables, except for variations in literals, layout and comments.
%% </p>
%% @spec duplicated_code_in_dirs(FileNameList::[filename()|dir()], MinToks::integer(), MinClones::integer()) -> {ok, string()}
-spec(duplicated_code_in_dirs/3::([dir()], string(), string()) ->{ok, string()}).
duplicated_code_in_dirs(FileDirList, MinToks, MinClones) ->
    refac_duplicated_code:duplicated_code(FileDirList, MinToks, MinClones).
    

%% ==================================================================================================
%% @doc Search for clones of a user-selected expression/expression sequence in the current file.
%% 
%% <p> This functionality allows searchingh for clones of a selected expression or expression 
%% sequence.  The found clones are syntactically identical to the user-selected code fragment after consistent renaming of variables, 
%% except for variations in literals, layout and comments. 
%% </p>
%% <p> When the selected code contains multiple, but non-continuous sequence of, expressions, the first
%% continuous sequence of expressions is taken as the user-selected expression. A continuous sequence of
%% expressions is a sequence of expressions separated by ','. </p>
%% @spec expression_search(FileName::filename(),Start::Pos, End::Pos) -> term()

-spec(expression_search/3::(filename(), pos(), pos()) -> {ok, [{integer(), integer(), integer(), integer()}]} | {error, string()}).
expression_search(FileName, Start, End) ->
    refac_expr_search:expr_search(FileName, Start, End).

%% =====================================================================================================
%%@doc Introduce a new function to represent a user-selected expression or expression sequence.
%% <p> This refactoring allows the user to introduce a new function to represent a selected expression or expression 
%% sequence, and replace the selected expression/expression sequence with a call to the new function.  Those free variables
%% within the expression/expression sequence become the formal parameters of the function.
%% </p>
%% @spec fun_extraction(FileName::filename(), Start::Pos, End::Pos, FunName::string()) ->{error, string()} | {ok, string()}

-spec(fun_extraction/4::(filename(), pos(), pos(), string()) ->
	      {error, string()} | {ok, string()}).
fun_extraction(FileName, Start, End, FunName) -> 
    refac_new_fun:fun_extraction(FileName, Start, End, FunName).

%%@private
-spec(fun_extraction_eclipse/4::(filename(), pos(), pos(), string()) ->
	      {error, string()} | {ok, [{filename(), filename(), string()}]}).
fun_extraction_eclipse(FileName, Start, End, FunName) -> 
    refac_new_fun:fun_extraction_eclipse(FileName, Start, End, FunName).

%% =============================================================================================
%% @doc Fold expressions against a function definition.
%% <p>
%% This refactoring replaces instances of the right-hand side of a function clause definition by
%% the corresponding left-hand side with necessary parameter substitutions. The function clause can 
%% be defined in either the current module or another module.
%% </p>
%% <p> To apply this refactoring, first point the cursor the function clause against which expresssion will be 
%% folded if the function is defined in the current module, or leave the cursor anywhere if you want to 
%% fold against a function clause defined in another module; then select <em> Fold Expresssion Against Function </em> 
%% from the <em> Refactor </em> menu; after that, the refactorer will ask you to confirm that you want to fold against 
%% the function clause pointed to by the cursor, if you answer 'no', the refactorer will ask you to provide the 
%% module name, function name and the arity of the function. After all these initial interaction, Wrangler will search 
%% the current module for expressions which are instances of the right-hand side of the selected function clause.
%% </p>
%% <p> If no candidate expression has been found, a message will be given, and the refactoring 
%% finishes; otherwise, Wrangler will go through the found candidate expressions one by one, and ask 
%% the user whether she/he wants to replace the expression with an application of selected function.
%% If the user answers 'yes' to one instance,  that instance will be replaced by function application,
%% otherwise it will remain unchanged.
%% </p>
%% <p> In the case that a candidate expression/expression sequence  need to export some variables which 
%% are used by the following code, that expression/expression sequence will be replaced by a match 
%% expression, whose left-hand side it the exported variable(s), and right-hand side is the function
%% application.
%%</p>
%% <p> This refactoring does not support folding against function clauses with guard expressions, or 
%% function clauses with complex formal parameters, such as tuples, lists, or records. 
%% </p>
%%@spec fold_expr(X::{{FileName::filename(), Line::integer(), Col::integer(), SearchPaths::[dir()]}
%%                  |{FileName::filename(), ModName::modulename(), Arity::integer(), ClauseIndex::integer(), SearchPaths::[dir()]}}) ->
%%           {ok, [{{{integer(), integer()}, {integer(), integer()}}, syntaxTree()}]} | {error, string()}

%% This function is just for documentation purpose; and should not be called by any other functions.
fold_expr({FileName, Line, Col, SearchPaths}) -> 
    fold_expr_by_loc(FileName, Line, Col, SearchPaths);
fold_expr({FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths}) ->
    fold_expr_by_name(FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths).

%%@private
-spec(fold_expr_by_loc/4::
      (filename(), integer(), integer(), [dir()]) -> {ok, [{integer(), integer(), integer(), integer(), syntaxTree(), {syntaxTree(), integer()}}]}
						 | {error, string()}).
fold_expr_by_loc(FileName, Line, Col, SearchPaths) ->
    refac_fold_expression:fold_expr_by_loc(FileName, Line, Col, SearchPaths).

%%@private
-spec(fold_expr_by_loc_eclipse/4::(filename(), integer(), integer(), [dir()]) -> {ok, [{{{integer(), integer()}, {integer(), integer()}}, syntaxTree()}]} 
									 | {error, string()}).
fold_expr_by_loc_eclipse(FileName, Line, Col, SearchPaths) ->
    refac_fold_expression:fold_expr_by_loc_eclipse(FileName, Line, Col, SearchPaths).

%%@private
-spec(fold_expr_by_name/6::(filename(), string(), string(), string(), string(), [dir()]) ->
	     {ok, [{integer(), integer(), integer(), integer(), syntaxTree(), {syntaxTree(), integer()}}]}
		 | {error, string()}).

fold_expr_by_name(FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths) ->
    refac_fold_expression:fold_expr_by_name(FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths).

%%@private
-spec(fold_expr_by_name_eclipse/6::(filename(), string(), string(), string(), string(), [dir()]) ->
	     {ok, [{{{integer(), integer()}, {integer(), integer()}}, syntaxTree()}]} 
		 | {error, string()}).

fold_expr_by_name_eclipse(FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths) ->
    refac_fold_expression:fold_expr_by_name_eclipse(FileName, ModName, FunName, Arity, ClauseIndex, SearchPaths).

%%@private
-spec(fold_expression_1_eclipse/4::(filename(), syntaxTree(), [{{{integer(), integer()}, {integer(), integer()}}, syntaxTree}],[dir()]) ->
	     {ok, [{filename(), filename(), string()}]}).
fold_expression_1_eclipse(FileName, FunClauseDef, StartEndExpList, SearchPaths)->  %% StartEndExpList: {{{StartLine, StartCol}, {EndLine, EndCol}}, NewExp}
    refac_fold_expression:fold_expression_1_eclipse(FileName, FunClauseDef, StartEndExpList, SearchPaths).

%%@private
-spec(fold_expression_2_eclipse/6::(filename(), atom(),integer(), integer(), integer(), [dir()]) -> 
	     {ok, [{integer(), integer(), integer(), integer(), syntaxTree(), {syntaxTree(), integer()}}]}
             | {error, string()}).
fold_expression_2_eclipse(FileName, FunName, Arity, ClauseIndex, StartLine, SearchPaths) ->
    refac_fold_expression:fold_expression_2_eclipse(FileName, FunName, Arity, ClauseIndex, StartLine, SearchPaths).


%%@private
%%@spec instrument_prog(FileName::filename(), SearchPaths::[dir()]) -> term()
-spec(instrument_prog/2::(filename(), [dir()]) ->{ok, [filename()]} | {error, string()}).  
instrument_prog(FileName, SearchPaths) ->
     refac_instrument:instrument_prog(FileName, SearchPaths).


%%@private
%%@spec uninstrument_prog(FileName::filename(), SearchPaths::[dir()]) -> term()
-spec(uninstrument_prog/2::(filename(), [dir()]) ->{ok, [filename()]} | {error, string()}).
uninstrument_prog(FileName, SearchPaths) ->
     refac_instrument:uninstrument_prog(FileName, SearchPaths).


%%=========================================================================================
%% @doc Add a tag to all the messages received by a server process.
%% <p> This refactoring should be initiated from the main receive function of a server process.
%% To apply this refactoring, point the cursor to the function name, then select <em> Add a 
%% Tag to Messages </em> from the <em> Refactor </em> menu, and Wrangler will prompt to 
%% enter the tag, which must be an atom.</p>
%%
%% <p> This refactoring is still in an experimental stage, and has a number of limitations:
%% <li> The current implementation assumes that the process does not send enquiries, 
%%      using the <code> send ... receive </code> pattern, to other processes 
%% </li>
%% <li> The current implementation only handles processes spawned using <code>spawn</code> 
%%      or <code>spawn_link</code>
%% </li>
%% </p>
%%@spec add_a_tag(Filename::filename(), Line::integer(), Col::integer(), Tag::string(), SearchPaths::[dir()]) -> 
%%   {error, string()} | {ok, [filename()]}
-spec(add_a_tag/5::(filename(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [filename()]}).
add_a_tag(FileName, Line, Col, Tag, SearchPaths) ->
    refac_add_a_tag:add_a_tag(FileName, Line, Col, Tag, SearchPaths).



%%=========================================================================================
%% @doc Register a process which is not already registered.
%% <p>This refactoring register a process id, <code>Pid</code> say, with a name, regname say, and replace
%% the uses of <code>Pid ! Msg </code> with  <code>regname ! Msg</code> if possible. To initiate this refactoring, the 
%% user should select a match expression whose left-hand side is a process indentifier, and right-hand 
%% side is a spawn expression. </p>
%% <p>
%% The following side-conditions apply to this refactoring:
%% <li> The process name provided by the user should be lexically valid.</li>
%% <li>  The name provided by the user should not have been used as a process name. </li>
%% <li> The process under consideration should not have been registered. </li>
%% <li> Only one process spawned by the spawn expression selected should exist anytime during the running of the system. </li>
%% </p>
%% 
%%@spec register_pid(Filename::filename(), Start::pos(), End::pos(), RegName::atom(), SearchPaths::[dir()]) 
%%    ->{error, string()} | {ok, [filename()]}
-spec(register_pid/5::(filename(), pos(), pos(), string(), [dir()]) ->
    {error, string()}|{ok, [filename()]}).
register_pid(FileName, Start, End, RegName, SearchPaths) ->
    refac_register_pid:register_pid(FileName, Start, End, RegName, SearchPaths).
    
%%=========================================================================================
%% @doc Turn some consecutive parameters of a function into a tuple parameter.
%% <p> To apply this refactoring, point the cursor to the parameter which is going to be the first 
%% element of the tuple, then select <em> Tuple Function Arguments </em> from the <em> Refactor </em> menu, 
%% after that the refactorer will prompt to enter the number of parameters to include into the tuple in the minibuffer.
%% </p>
%% <p>
%% When the function under consideration is exported by the module where it is defined, this refactoring has a global effect, i.e.,
%% it affects all those modules in which this function is imported/used.
%% </p>
%% <p> Suppose the new function after refactoring is <code>f/n</code>, then the following <em> side-conditions </em> apply 
%% to this refactoring:
%% <li> <code> f/n</code> should not cause confliction with any of the functions which are in scope in the 
%% current module;</li>
%% <li> In the case that the function is imported by another module, then <code>f/n</code> 
%% should not be already in scope (either defined or imported) in that module. </li>
%% </p>
%% @spec tuple_funpar(FileName::filename(), Line::integer(), Col::integer(), Number::string(), SearchPaths::[dir()])
%% -> {error, string()} | {ok, [filename()]}
-spec(tuple_funpar/5::(filename(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [filename()]}).

tuple_funpar(FileName, Line, Col, Number, SearchPaths) ->
    refac_tuple:tuple_funpar(FileName, Line, Col, list_to_integer(Number), SearchPaths).

%%@private
%% @spec tuple_funpar_eclipse(FileName::filename(), Line::integer(), Col::integer(), Number::string(), SearchPaths::[dir()]) -> term()

-spec(tuple_funpar_eclipse/5::(filename(), integer(), integer(), string(), [dir()]) ->
	     {error, string()} | {ok, [{filename(), filename(), string()}]}).

tuple_funpar_eclipse(FileName, Line, Col, Number, SearchPaths) ->
    refac_tuple:tuple_funpar_eclipse(FileName, Line, Col, list_to_integer(Number), SearchPaths).


%%=========================================================================================
%% @doc From tuple to record representation.
%% <p> To apply this refactoring, highlight the tuple, which should be a function parameter,  
%% then select <em> From Tuple To Record </em> from the <em> Refactor </em> menu, 
%% after that the refactorer will prompt to enter the record name and  the record field names.
%% </p>
%% <p>
%% This refactoring has a global effect, i.e., it affects all those modules in 
%% which this function is imported/used.
%% </p>
%% <p> The following <em> side-conditions </em> apply to this refactoring:
%% <li> The record and field names must be lexically legal; </li>
%% <li> The number of record fields must equal to the selected tuple size; </li>
%% <li> The function must be defined in the current module; </li>
%% <li> The selected part must be a tuple.  </li>
%% </p>
%% NOTE: this refacotoring is still at an experimental stage.
%% @spec tuple_to_record(File::filename(),FLine::integer(),FCol::integer(),
%%           LLine::integer(),LCol::integer(), RecName::string(),
%%           FieldString::[string()], SearchPaths::[dir()]) ->  {error, string()} | {ok, [filename()]} 
%% @end
-spec(tuple_to_record/8::(filename(), integer(), integer(), integer(), integer(), string(), [string()], [dir()]) ->
	     {error, string()} | {ok, [filename()]}).

tuple_to_record(File, FLine, FCol, LLine, LCol, RecName, FieldString,
		SearchPaths) ->
    refac_tuple_to_record:tuple_to_record(File, FLine, FCol, LLine, LCol, RecName,
					  FieldString, SearchPaths).

%%@private
%% @spec tuple_to_record_eclipse(File::filename(),FLine::integer(),FCol::integer(),
%%           LLine::integer(),LCol::integer(), RecName::string(),
%%           FieldString::[string()], SearchPaths::[dir()]) -> term()
-spec(tuple_to_record_eclipse/8::(filename(), integer(), integer(), integer(), integer(), string(), [string()], [dir()]) ->
	     {error, string()} | {ok, [{filename(), filename(), string()}]}).

tuple_to_record_eclipse(File, FLine, FCol, LLine, LCol, RecName, FieldString,
			SearchPaths) ->
    refac_tuple_to_record:tuple_to_record_eclipse(File, FLine, FCol, LLine, LCol,
						  RecName, FieldString, SearchPaths).


%%=========================================================================================
%% @doc Turn a function into a server process, and all the function calls to this function to process communication.
%%  This refactoring provides potential for memorisation of calculated values, adding states to the process, etc.
%% <p> To apply this refactoring, point the cursor to the function which you are interested, then select 
%% <em> From Function to Process </em> from the <em> Refactor </em> menu, after that Wrangler will prompt 
%% you to enter the name of the new process in the mini-buffer.
%% </p>
%% <p> The following example shows the application of this refactoring to the function <code>f/2</code> on the 
%% left-hand side, and the result is shown on the right-hand side. 
%%
%%    ``` f(add,X,Y) -> X +Y;                        f_rpc(RegName, Request) ->                  
%%        f(sub,X,Y) ->  X - Y.                            case whereis(RegName) of
%%                                                              undefined -> register(RegName, spawn(fun f/0));
%%        g(X, Y) ->                                            _ -> ok
%%            f(add, X,Y)*f(sub, X, Y).                    end,
%%                                                   f_rpc(RegName, Request) ->
%%                                                       case whereis(RegName) of
%%                                                            undefined -> register(RegName, spawn(fun f/0));
%%                                                            _ -> ok
%%                                                       end,
%%                                                       RegName ! {self(), Request},
%%                                                       receive {RegName, Response} -> Response end.
%%
%%                                                   f() ->
%%                                                      receive
%%                                                         {From, {add, X, Y}} -> From ! {f, X + Y}, f();
%%                                                         {From, {sub, X, Y}} -> From ! {f, X - Y}, f()
%%                                                      end.
%%
%%                                                   g(X, Y) ->
%%                                                      f_rpc(f, {add, X, Y}) * f_rpc(f, {sub, X, Y}).
%%
%%    '''
%% </p>
%% The following side-conditions apply to this refactoring:
%% <p>
%% <li> The process name provided by the user should be lexically legal, and not conflict with existing process names. </li>   
%% <li> The function should not be a recursive function, either directly or indirectly. </li>
%% <li> The current function or functions called by this function should not register the <code>Pid</code> returned by <code>self()</code>. </li>
%% </p>
%% <p>
%% Wrangler generates the new function name and the rpc function name automatically, but the user could always rename it afterwards.
%% Suppose the original function is <code>f/n</code>, then the new function name would be <code>f/0</code> and the <code>rpc</code> 
%% function name would be <code>f_rpc/2</code>; if any conflicts occur, <code>'_i'</code> will be attached to the end of the function
%% name where <code>i</code> is a smallest number that makes the name fresh.
%% </p>
%% @spec fun_to_process(FileName::filename(), Line::integer(), Col::integer(), ProcessName::string(), SearchPaths::[dir()]) ->
%%  {ok, [filename()]} | {error, string()}
-spec(fun_to_process/5::(filename(), integer(), integer(), string(), [dir()]) -> {ok, [filename()]} | {error, string()}).
fun_to_process(FileName, Line, Col, ProcessName, SearchPaths) ->
    refac_fun_to_process:fun_to_process(FileName, Line, Col, ProcessName, SearchPaths).


%%=========================================================================================
%% @doc Rename a registered process with a user-supplied new name.
%% <p> To apply this refactoring, point the cursor to the process name, then select
%% <em> Rename a Process </em> from the  <em> Refactor </em> menu, after that Wrangler will prompt
%% to enter the new process name in the mini-buffer. 
%% </p>
%% <p> This refactoring has a global effect, i.e. it needs to check the whole program for places where the 
%% original process name is used.
%% </p>
%% <p> The following <em> side-conditions </em> apply to this refactoring:
%% <li> The new process name should not be the atom 'undefined' </li>
%% <li> The new process name should not have been used as a process name in the program under consideration.  </li>
%% <li> Since there are some cases where Wrangler cannot infer whether an atom represents a process name or not, for example, 
%% a process name in a message, it would be help the refactoring process to select the process name from expressions, such as 
%% registration expressions, where it is easier for Wrangler to infer that the atom is a process name.</li>
%% </p>
%% @spec rename_process(FileName::filename(), Line::integer(), Col::integer(),NewName::string(), SearchPaths::[dir()]) ->
%%     {error, string()} | {undecidables, string()}| {ok, [filename()]}
-spec(rename_process/5::(filename(), integer(), integer(), string(), [dir()]) ->
	       {error, string()} | {undecidables, string()}| {ok, [filename()]}).
rename_process(FileName, Line, Col, NewName, SearchPaths) ->
    refac_rename_process:rename_process(FileName, Line, Col, NewName, SearchPaths).




%% trace_send({ModName, FunName, Arity}, Index, Pid, TraceCacheFile) ->
%%     PInfo = erlang:process_info(Pid),
%%     {value, InitialCall} = lists:keysearch(initial_call, 1, PInfo),
%%     {value, CurrentFun} = lists:keysearch(current_function,1, PInfo),
%%     SendInfo =case lists:keysearch(registered_name, 1, PInfo) of 
%% 		  {value, RegisteredName} ->
%% 		      {send, {ModName, FunName, Arity, Index}, Pid, InitialCall, CurrentFun, RegisteredName};
%% 		  false ->
%% 		      {send, {ModName, FunName, Arity, Index}, Pid, InitialCall, CurrentFun}
%% 	      end,
%%     case dets:open_file(TraceCacheFile, [{type, bag}]) of 
%% 	{ok, TraceCacheFile} -> 
%% 	   dets:insert(TraceCacheFile, SendInfo),
%% 	   dets:close(TraceCacheFile);
%% 	{error, Reason}  -> eralng:error(Reason)
%%     end.

%% trace_spawn({ModName, FunName, Arity}, Index, Pid, TraceCacheFile) ->
%%     SpawnInfo = {spawn, {ModName, FunName, Arity, Index}, Pid},
%%     case dets:open_file(TraceCacheFile, [{type, bag}]) of 
%% 	{ok, TraceCacheFile} -> 
%% 	    dets:insert(TraceCacheFile, SpawnInfo),
%% 	    dets:close(TraceCacheFile);
%% 	{error, Reason}  -> eralng:error(Reason)
%%     end.    
