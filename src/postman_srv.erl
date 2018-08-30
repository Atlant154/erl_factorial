-module(postman_srv).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API export:
-export([start_link/2]).

%% Generic server export:
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
                 node_queue :: binary(),
				 channel :: pid()
               }).

%% API:

-spec start_link(binary(), pid()) -> {ok, pid()}.
start_link(Queue, Channel) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [Queue, Channel], []).

%% Generic server:

init([Queue, Channel]) ->
    lager:info("Postman server inicialization on node ~p started.", [node()]),
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue, no_ack = false}, self()),
    {ok, #state{node_queue = Queue, channel = Channel}}.

handle_call(_Request, _From, State) ->
	{reply, ignored, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.