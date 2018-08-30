-module(erl_factorial_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	erl_factorial_sup:start_link().

stop(_State) ->
	ok.
