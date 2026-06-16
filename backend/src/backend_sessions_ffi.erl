-module(backend_sessions_ffi).
-export([mint_token/0]).

mint_token() ->
    binary:encode_hex(crypto:strong_rand_bytes(32)).
