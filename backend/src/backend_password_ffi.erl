-module(backend_password_ffi).
-export([hash_password/1, verify_password/2]).

hash_password(Password) ->
    P = to_binary(Password),
    Salt = crypto:strong_rand_bytes(32),
    case jargon:hash(P, Salt, argon2id, 3, 65536, 1, 32) of
        {ok, _Raw, EncodedHash} ->
            {ok, binary_to_list(EncodedHash)};
        {error, _} ->
            {error, nil}
    end.

verify_password(EncodedHash, Password) ->
    H = to_binary(EncodedHash),
    P = to_binary(Password),
    case jargon:verify(H, P) of
        {ok, true} -> true;
        _ -> false
    end.

to_binary(X) when is_binary(X) ->
    X;
to_binary(X) when is_list(X) ->
    list_to_binary(X).
