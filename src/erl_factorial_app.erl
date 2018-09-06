-module(erl_factorial_app).
-behaviour(application).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API:
-export([start/2]).
-export([stop/1]).

-define(CLUSTER_EXCHANGE, <<"erl_factorial cluster exchange">>).
-define(CLUSTER_ROUTING_KEY, <<"erl_factorial cluster">>).

%% Application:

start(_Type, _Args) ->
    {Connection, Channel} = cluster_connection_init(),
    lager:warning("Connection: ~p. Channel: ~p.", [Connection, Channel]),
    {Node, StateQueueName, ResQueueName} = cluster_connection_configuring(Channel),
	{ok, Pid} = erl_factorial_sup:start_link([StateQueueName, ResQueueName, ?CLUSTER_EXCHANGE, ?CLUSTER_ROUTING_KEY, Channel, Node]),
	{ok, Pid, {Channel, Connection}}.

stop({Channel, Connection}) ->
	%% If the Module:stop() is called, we think that the machine from the cluster is 
    %% removed under normal conditions and we can delete the queue.
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
	lager:info("Postman server was stopped. Queue was deleted."),
	ok.

-spec cluster_connection_init() -> {ok, pid()}.
cluster_connection_init() ->
    %% Start a network connection:
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = erl_factorial_config:rabbit_host()}),
    %% Open channel on the connection:
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {Connection, Channel}.

-spec cluster_connection_configuring(pid()) -> {binary(), binary(), binary()}.
cluster_connection_configuring(Channel) ->
    Node = erlang:atom_to_binary(node(), latin1),
    StateID = <<"cluster handler">>,
    ResID = <<"result">>,
    StateQueueName = <<Node/binary, <<":">>/binary, StateID/binary>>,
    ResQueueName = <<Node/binary, <<":">>/binary, ResID/binary>>,
    #'queue.declare_ok'{} = amqp_channel:call(Channel, 
                                              #'queue.declare'{queue = StateQueueName}),
    #'queue.declare_ok'{} = amqp_channel:call(Channel, 
                                              #'queue.declare'{queue = ResQueueName, exclusive = true}),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = ?CLUSTER_EXCHANGE, type = <<"direct">>}),
    amqp_channel:call(Channel, #'queue.bind'{exchange = ?CLUSTER_EXCHANGE, 
                                             queue = StateQueueName, 
                                             routing_key = ?CLUSTER_ROUTING_KEY}),
    amqp_channel:call(Channel, #'queue.bind'{exchange = ?CLUSTER_EXCHANGE, 
                                             queue = ResQueueName, 
                                             routing_key = Node}),
    {Node, StateQueueName, ResQueueName}.
