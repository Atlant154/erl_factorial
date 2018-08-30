-module(multiplier_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
	Specs = #{
              strategy => simple_one_for_one,
              intensity => 100,
              period => 1
            },
	Childrens = [
                   #{id => multiplier,
                   start => {multiplier_srv, start_link, []},
                   restart => transient,
                   shutdown => 5,
                   type => worker,
                   modules => [multiplier_srv]}
                ],
	{ok, {Specs, Childrens}}.
