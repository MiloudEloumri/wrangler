%%% This is an -*- Erlang -*- file.
%%%-------------------------------------------------------------------
%%% File    : wrangler.hrl
%%%-------------------------------------------------------------------

-record(options, {search_paths=[],
		  include_dirs=[],
		  plt_libs= [kernel,stdlib]
		  }).

-record(callgraph, {scc_order, external_calls}).

-record(attr, {pos = {0,0}, ann = [], com = none}).

%% Will be edited by Makefile 
-define(WRANGLER_DIR, "C:/cygwin/home/hl/wrangler/share/distel/wrangler").


-define(DEFAULT_LOC, 
        {0, 0}).  %% default defining location.
-define(DEFAULT_MODULE,
	unknown).  %% default module name.

-type(filename()::string()).
-type(dir()::string()).
-type(syntaxTree()::any()).    %% any() should be refined.
-type(pos()::{integer(), integer()}).
-type(boolean()::true|false).
-type(key():: attributes | errors | exports | functions | imports | module | records | rules | warnings).
-type(moduleInfo()::[{key(), any()}]).  %% any() should be refined.
-type(term()::any()).
-type(token()::{var, pos(), atom()} | {integer, pos(), integer()}|{string, pos(), string()}|
               {float, pos(), float()} | {char, pos(), char()} |{atom, pos(), atom()} |{atom(), pos()}).
               
