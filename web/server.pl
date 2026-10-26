% Local web application. Run .\run.ps1 or swipl -q server.pl 8080.
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_parameters)).
:- use_module('planner.pl').
:- initialization(start, main).
:- dynamic public_dir/1, server_port/1.
:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, public, Public), assertz(public_dir(Public)).

:- http_handler(root(api/state), guarded(read_state), [method(get)]).
:- http_handler(root(api/tasks), guarded(create_task), [method(post)]).
:- http_handler(root(api/task_status), guarded(change_status), [method(post)]).
:- http_handler(root(api/delete_task), guarded(delete_task), [method(post)]).
:- http_handler(root(api/classes), guarded(create_class), [method(post)]).
:- http_handler(root(api/delete_class), guarded(delete_class), [method(post)]).
:- http_handler(root(.), serve_public, [prefix]).

start :-
    current_prolog_flag(argv, Args),
    ( Args = [Arg|_] -> atom_number(Arg, Port) ; Port = 8080 ),
    planner:init_store,
    assertz(server_port(Port)),
    http_server(http_dispatch, [port(localhost:Port)]),
    format('Task planner running at http://localhost:~w~n', [Port]),
    thread_get_message(_).

serve_public(Request) :-
    public_dir(Dir), http_reply_from_files(Dir, [indexes(['index.html'])], Request).

guarded(Action, Request) :-
    catch((check_origin(Request), call(Action, Request)), Error, api_error(Error)).

check_origin(Request) :-
    ( memberchk(method(post), Request), memberchk(origin(Origin), Request)
    -> server_port(Port),
       format(atom(Local), 'http://localhost:~w', [Port]),
       format(atom(Loopback), 'http://127.0.0.1:~w', [Port]),
       (memberchk(Origin, [Local, Loopback]) -> true
       ; throw(error(api_error(403, 'This origin cannot change the planner.'), _)))
    ; true ).

api_error(error(validation_error(Message), _)) :- !,
    reply_json_dict(_{error:Message}, [status(400)]).
api_error(error(api_error(Status, Message), _)) :- !,
    reply_json_dict(_{error:Message}, [status(Status)]).
api_error(Error) :-
    print_message(error, Error),
    reply_json_dict(_{error:'The request could not be completed. Check the server console.'}, [status(500)]).

json_body(Request, Body) :-
    ( memberchk(content_length(N), Request), N > 32768
    -> throw(error(api_error(413, 'Request is too large.'), _)) ; true ),
    catch(http_read_json_dict(Request, Body), _,
          throw(error(validation_error('Send a valid JSON object.'), _))),
    (is_dict(Body) -> true ; throw(error(validation_error('Send a JSON object.'), _))).

read_state(Request) :-
    catch(http_parameters(Request, [minutes(Minutes, [integer, between(0, 10080), default(60)])]),
          _, throw(error(validation_error('Available minutes must be a whole number from 0 to 10080.'), _))),
    planner:snapshot(Minutes, State), reply_json_dict(State).

create_task(Request) :-
    json_body(Request, Body), planner:mutate(add_task(Body)),
    reply_json_dict(_{ok:true}, [status(201)]).
change_status(Request) :-
    json_body(Request, Body), planner:mutate(set_status(Body)), reply_json_dict(_{ok:true}).
delete_task(Request) :-
    json_body(Request, Body), planner:mutate(remove_task(Body)), reply_json_dict(_{ok:true}).
create_class(Request) :-
    json_body(Request, Body), planner:mutate(add_class(Body)),
    reply_json_dict(_{ok:true}, [status(201)]).
delete_class(Request) :-
    json_body(Request, Body), planner:mutate(remove_class(Body)), reply_json_dict(_{ok:true}).
