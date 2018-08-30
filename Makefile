PROJECT = erl_factorial
PROJECT_DESCRIPTION = Cluster for the calculation of factorials.
PROJECT_VERSION ?= $(shell git describe --tags --always | sed 's/-/./g')
ROJECT_MOD = erl_factorial_app

ERLC_OPTS += +'{parse_transform, lager_transform}'

DEPS = lager amqp_client

dep_lager = hex 3.6.4
dep_amqp_client = hex 3.7.7

ETC_DIR ?= etc
SHELL_ERL = erl -name $(PROJECT) -eval 'application:ensure_all_started($(PROJECT))'


include erlang.mk
