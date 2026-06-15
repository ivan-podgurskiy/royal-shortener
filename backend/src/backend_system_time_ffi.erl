-module(backend_system_time_ffi).
-export([seconds/0]).

seconds() ->
  os:system_time(second).
