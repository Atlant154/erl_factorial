-module(erl_factorial_app).
-behaviour(application).

-include_lib("amqp_client/include/amqp_client.hrl").

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	%% Start a network connection:
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = erl_factorial_config:rabbit_host()}),
    %% Open channel on the connection:
    {ok, Channel} = amqp_connection:open_channel(Connection),
    %% Declare the queue for the node:
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{queue = erlang:atom_to_binary(node(), latin1)}),
	%% Declare the exchange for all nodes(fanout type).
	amqp_channel:call(Channel, #'exchange.declare'{exchange = <<"erl_factorial">>, type = <<"fanout">>}),
    %% Bind queue to "erl_factorial" exchange:
    amqp_channel:call(Channel, #'queue.bind'{exchange = <<"erl_factorial">>, queue = Queue}),
	{ok, Pid} = erl_factorial_sup:start_link([Queue, Channel]),
	{ok, Pid, {Queue, Channel}}.

stop({Queue, Channel}) ->
	%% If the Module:stop() is called, we think that the machine from the cluster is 
    %% removed under normal conditions and we can delete the queue.
	#'queue.delete_ok'{message_count = MsgCount} = amqp_channel:call(Channel, #'queue.delete'{queue = Queue}),
	lager:info("Postman server was stopped. Queue was deleted. Message count: ~p", [MsgCount]),
	ok.
