![erl_factorial](documentation/pic/logo.png)

# Кластерное вычисление факториала на языке Erlang

В данной программе реализован многопоточный подсчёт факториала на одной или нескольких машинах, в качестве брокера сообщений выступает [RabbitMQ](https://github.com/rabbitmq).

## Запуск

1. Клонировать репозиторий: `git clone https://github.com/Atlant154/erl_factorial.git erl_factorial`
2. Перейти в папку с программой: `cd erl_factorial`
3. Сконфигурировать **ip** адрес брокера сообщений, для этого требуется изменить `etc/erl_factorial.config`.  
По умолчанию установлен "localhost".
4. Убедиться, что **RabbitMQ** запущен, в противном случае все вычисления будут произведены на одной машине,  
а также возможны проблемы с работой `src/cluster_message_handler_srv.erl`.
4. Скачать зависимости, скомпилировать и запустить: `make deps && make && make shell`
5. Для подсчёта факториала N, ввести следующую команду: `postman_srv:factorial(N)`