-module(backend_geoip_ffi).
-export([start/1, country/1]).

-define(DB_ID, royal_geoip).

start(Path) ->
    case filelib:is_regular(Path) of
        true ->
            case locus:start_loader(?DB_ID, Path) of
                {ok, _} -> ok;
                {error, already_started} -> ok;
                {error, _} = Error -> Error
            end;
        false ->
            ok
    end.

country(Ip) when is_list(Ip); is_binary(Ip) ->
    case locus:lookup(?DB_ID, Ip) of
        {ok, Entry} ->
            case country_code(Entry) of
                undefined -> undefined;
                Code -> list_to_binary(Code)
            end;
        _ ->
            undefined
    end;
country(_) ->
    undefined.

country_code(Entry) when is_map(Entry) ->
    case maps:get(country, Entry, undefined) of
        #{iso_code := Code} when is_binary(Code) ->
            binary_to_list(Code);
        _ ->
            case maps:get(registered_country, Entry, undefined) of
                #{iso_code := Code} when is_binary(Code) ->
                    binary_to_list(Code);
                _ ->
                    undefined
            end
    end;
country_code(_) ->
    undefined.
