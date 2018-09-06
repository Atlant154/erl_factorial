-module(postman_srv).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("erl_factorial/include/erl_fact_messages.hrl").

%% API export:
-export([start_link/2]).
-export([factorial/1]).

%% Generic server export:
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
				 calculations_map :: map(),
				 cores = erlang:system_info(schedulers_online) :: integer()
               }).

-define(RESULT_RESPONSE, <<"result_response">>).

%% API:

-spec start_link(binary(), pid()) -> {ok, pid()}.
start_link(ResQueueName, Channel) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ResQueueName, Channel], []).

%% Generic server:

init([ResQueueName, Channel]) ->
    lager:info("Postman server inicialization on node ~p started.", [node()]),
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = ResQueueName, no_ack = true}, self()),
	timer:sleep(100),
    {ok, #state{calculations_map = maps:new()}}.

handle_call(Request, From, State) ->
	lager:warning("Unhandled call. Request: ~p. From: ~p.", [Request, From]),
	{reply, ignored, State}.

handle_cast({factorial, N, _ResponcePid}, State = #state{}) ->
	lager:warning("Node received request to calculate the factorial(N), N: ~p.", [N]),
	ClusterMembersMap = cluster_message_handler_srv:get_cluster_members_map(),
	Cores = lists:sum(maps:values(ClusterMembersMap)),
	lager:info("Total number of cores in cluster: ~p", [Cores]),
	%% WIP.
	{noreply, State};

handle_cast(Message, State) ->
	lager:warning("Unhandled cast. Message: ~p", [Message]),
	{noreply, State}.

handle_info(#'basic.consume_ok'{}, State) ->
	lager:info("Node subscribed to the queue."),
	{noreply, State};

handle_info({#'basic.deliver'{}, #amqp_msg{payload = Message}}, State = #state{}) ->
	case erlang:binary_to_term(Message) of
		#fact_calc_msg{header = ?RESULT_RESPONSE, id = ID, node = Node, result = Result} ->
			lager:warning("Received result message. CalculationID = ~p, from node ~p, calculation result = ~p.", [ID, Node, Result]);
		_Else ->
			lager:warning("Unhandled info message: ~p", [Message])
	end,
	{noreply, State};

handle_info(Info, State = #state{}) ->
	lager:warning("Unhandled info message: ~p", [Info]),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

-spec factorial(integer()) -> integer() | atom().
factorial(0) -> 1;
factorial(1) -> 1;
factorial(N) when is_integer(N) andalso N > 0 ->
	gen_server:cast(postman_srv, {factorial, N, self()}),
	receive
		{factorial_result, Result} ->
			Result
	after 6000 ->
		lager:warning("Result not received.")
	end.