-module(erl_factorial_sup).
-behaviour(supervisor).

-export([start_link/1]).
-export([init/1]).

start_link([Queue, Channel]) ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, [Queue, Channel]).

init([Queue, Channel]) ->
	Specs = #{%% One down -> all restart.		
            strategy => one_for_all,
            %% It can be restarted a thousand times per second.
            intensity => 1000,
            period => 1},
	Childrens = [
                  #{id => postman,
                  start => {postman_srv, start_link, [Queue, Channel]},
                  restart => permanent,
                  shutdown => infinity,
                  type => worker,
                  modules => [postman_srv]},

    			  #{id => multiplier_sup,
                  start => {multiplier_sup, start_link, []},
                  restart => permanent,
                  shutdown => infinity,
                  type => supervisor,
                  modules => [multiplier_sup]}
              ],
	{ok, {Specs, Childrens}}.
