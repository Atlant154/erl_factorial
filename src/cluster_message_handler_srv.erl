-module(cluster_message_handler_srv).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API.
-export([start_link/5]).
-export([get_cluster_members_map/0]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
                exchange :: binary(),
				channel :: pid(),
                queue :: binary(),
				cluster_members :: map(),
				cores :: binary(),
				routing_key :: binary(),
				node :: binary()
			    }).

-define(INTERVAL, 50).
-define(CORES_REQ, <<"cores_request">>).
-define(CORES_RESP, <<"cores_response">>).

%% API.

-spec start_link(binary(), binary(), binary(), pid(), binary()) -> {ok, pid()}.
start_link(StateQueueName, ClusterExchange, ClusterRouteKey, Channel, Node) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [StateQueueName, ClusterExchange, ClusterRouteKey, Channel, Node], []).

%% gen_server.

init([StateQueueName, ClusterExchange, ClusterRouteKey, Channel, Node]) ->
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = StateQueueName, no_ack = true}, self()),
	request_cluster_members(Channel, ClusterExchange, ClusterRouteKey, Node),
	erlang:send_after(?INTERVAL, self(), time_to_update),
	{ok, #state{exchange = ClusterExchange, 
				channel = Channel,
				queue = StateQueueName,
				cores = erlang:integer_to_binary(erlang:system_info(schedulers_online)),
				routing_key = ClusterRouteKey,
				node = Node,
				cluster_members = #{Node => erlang:system_info(schedulers_online)}}}.

handle_call(get_cluster_members_map, _From, State = #state{}) ->
	{reply, State#state.cluster_members, State};

handle_call(Request, From, State) ->
	lager:warning("Unhandled call. Request: ~p. From: ~p.", [Request, From]),
	{reply, ignored, State}.

handle_cast(Message, State) ->
	lager:warning("Unhandled cast. Message: ~p", [Message]),
	{noreply, State}.

handle_info(time_to_update, State = #state{}) ->
	request_cluster_members(State#state.channel, State#state.exchange, State#state.routing_key, State#state.node),
	erlang:send_after(?INTERVAL, self(), time_to_update),
	{noreply, State};

handle_info(#'basic.consume_ok'{}, State) ->
	lager:info("Node subscribed to the queue."),
	{noreply, State};

handle_info({#'basic.deliver'{}, #amqp_msg{payload = Body}}, State = #state{}) ->
	Message = jsone:decode(Body),
	case Message of
		#{<<"header">> := ?CORES_REQ, <<"request_node">> := RequestNode} ->
			case RequestNode =/= State#state.node of
				true ->
					Response = jsone:encode(#{<<"header">> => ?CORES_RESP, <<"node">> => State#state.node, <<"cores">> => State#state.cores}),
					amqp_channel:cast(State#state.channel,
                    				  #'basic.publish'{exchange = State#state.exchange,
													   routing_key = Body},
                    								   #amqp_msg{payload = Response}),
					lager:debug("Get number of cores request. Node: ~p.", [RequestNode]);
				false ->
					ok
			end,
			{noreply, State};
		#{<<"header">> := ?CORES_RESP, <<"node">> := ClusterMember, <<"cores">> := NumberOfCores} ->
			case ClusterMember =/= State#state.node of
				true ->
					ClusterMembers = maps:put(ClusterMember, NumberOfCores, State#state.cluster_members),
					lager:info("Map of cluster members upadted. New map: ~p", ClusterMembers),
					{noreply, State#state{cluster_members = ClusterMembers}};
				false ->
					lager:info("Map of cluster members: ~p", [State#state.cluster_members]),
					{noreply, State}
			end;
		Else ->
			lager:warning("Unhandled message from RabbitMQ: ~p", [Else]),
			{noreply, State}
	end;

handle_info(Info, State) ->
	lager:warning("Unhandled info request: ~p", [Info]),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

-spec get_cluster_members_map() -> map().
get_cluster_members_map() ->
	gen_server:call(?MODULE, get_cluster_members_map).

-spec request_cluster_members(pid(), binary(), binary(), binary()) -> ok.
request_cluster_members(Channel, Exchange, RoutingKey, Node) ->
	ClusterMemberReq = jsone:encode(#{header => ?CORES_REQ, request_node => Node}),
	amqp_channel:cast(Channel,
                      #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
                      #amqp_msg{payload = ClusterMemberReq}),
	ok.