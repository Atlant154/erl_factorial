-ifndef(ERL_FACT_MESSAGES_HRL).

-record(fact_cluster_msg, {
                           header :: binary(),
                           node :: binary(),
                           cores :: binary()
}).

-record(fact_calc_msg, {
                        header :: binary(),
                        id :: reference(),
                        node :: atom(),
                        result :: integer()
}).

-define(ERL_FACT_MESSAGES_HRL,).
-endif.