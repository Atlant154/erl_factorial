-module(erl_factorial_sup).
-behaviour(supervisor).

-export([start_link/1]).
-export([init/1]).

start_link([StateQueueName, 
            ResQueueName,
            ClusterExchange, 
            ClusterRoutingKey,
            Channel,
            Node]) ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, [StateQueueName, 
                                                      ResQueueName,
                                                      ClusterExchange,
                                                      ClusterRoutingKey,
                                                      Channel,
                                                      Node]).

init([StateQueueName, ResQueueName, ClusterExchange, ClusterRoutingKey, Channel, Node]) ->
	Specs = #{
            %% One down -> all restart.		
            strategy => one_for_all,
            %% It can be restarted a thousand times per second.
            intensity => 1000,
            period => 1},
	Childrens = [
                  #{id => postman,
                  start => {postman_srv, start_link, [ResQueueName, Channel]},
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

                  #{id => cluster_checker,
                  start => {cluster_message_handler_srv, start_link, [StateQueueName, ClusterExchange, ClusterRoutingKey, Channel, Node]},
                  restart => permanent,
                  shutdown => infinity,
                  type => worker,
                  modules => [cluster_message_handler_srv]}
              ],
	{ok, {Specs, Childrens}}.
