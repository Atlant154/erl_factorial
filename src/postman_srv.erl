-module(postman_srv).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

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
				 used_cores :: integer()
               }).


-define(RESP, <<"result_response">>).

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

handle_cast(Message, State) ->
	lager:warning("Unhandled cast. Message: ~p", [Message]),
	{noreply, State}.

handle_info(#'basic.consume_ok'{}, State) ->
	lager:info("Node subscribed to the queue."),
	{noreply, State};

handle_info({#'basic.deliver'{}, #amqp_msg{payload = Message}}, State = #state{}) ->
	[Head, Body] = binary:split(Message, <<":">>),
	case Head of
		?RESP ->
			lager:warning("Get result message. Body: ~p", [Body]);
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
	after 600 ->
		lager:warning("Result not received")
	end.