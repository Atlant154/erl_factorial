-module(erl_factorial_config).

-export([rabbit_host/0]).

-spec rabbit_host() -> string().
rabbit_host() ->
    {ok, Host} = application:get_env(rabbit_host),
    lager:info("RabbitMQ host was requested. Host: ~p", [Host]),
    Host.