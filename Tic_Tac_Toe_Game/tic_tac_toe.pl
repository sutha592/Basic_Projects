:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_session)).

server_port(8082).

:- http_handler(root(.), home_page, []).
:- http_handler(root(gametype), game_type_page, []).
:- http_handler(root(choose), choose_player, []).
:- http_handler(root(move), make_move, []).
:- http_handler(root(reset), reset_game, []).
:- http_handler(root(ai_move), ai_move, []).

start_server :-
    server_port(Port),
    http_server(http_dispatch, [port(Port)]),
    format('Server started at http://localhost:~w~n', [Port]).

initial_board([[' ', ' ', ' '],
               [' ', ' ', ' '],
               [' ', ' ', ' ']]).

% --- Gametype selection ---
game_type_page(Request) :-
    (member(method(post), Request) ->
        http_parameters(Request, [mode(Mode,[atom,oneof([two,bot])])]),
        reset_sessions,
        http_session_assert(game_mode(Mode)),
        http_redirect(see_other, '/choose', Request)
    ;
        reply_html_page(
            title('Choose Game Type'),
            [
                style([type='text/css'], [
                    'body { font-family: Arial, sans-serif; margin: 20px; text-align: center; background-color: #f0f8ff; }',
                    '.choose-container { max-width: 400px; margin: 100px auto; background: white; padding: 35px; border-radius: 15px; box-shadow: 0 0 20px rgba(0,0,0,0.12); }',
                    'h1 { color: #2c3e50; margin-bottom: 12px; font-size: 2.3em; }',
                    'h2 { font-size: 2em; margin-bottom: 24px; color: #2c3e50; }',
                    '.choose-btn { margin: 15px; padding: 16px 32px; font-size: 1.2em; background: #2ecc71; color: white; border: none; border-radius: 10px; cursor: pointer; }',
                    '.choose-btn:hover { background: #3498db; }'
                ]),
                div([class='choose-container'], [
                    h1('Tic Tac Toe'),
                    h2('Choose Game Type'),
                    form([method=post, action='/gametype'], [
                        button([type=submit, name=mode, value=two, class='choose-btn'], 'Two Player Mode'),
                        button([type=submit, name=mode, value=bot, class='choose-btn'], 'Play vs Bot')
                    ])
                ])
            ]
        )
    ).

reset_sessions :-
    http_session_retractall(user_player(_)),
    http_session_retractall(bot_player(_)),
    http_session_retractall(game_board(_)),
    http_session_retractall(player(_)),
    http_session_retractall(game_status(_)),
    http_session_retractall(game_mode(_)).

% --- Home page ---
home_page(Request) :-
    (http_session_data(game_mode(Mode)) ->
        (http_session_data(user_player(_)) ->
            (Mode = bot ->
                check_and_play_ai(Request)
            ;
                display_game_board)
        ;
            http_redirect(see_other, '/choose', Request))
    ;
        http_redirect(see_other, '/gametype', Request)
    ).

% --- Choose player side with correct handling ---
choose_player(Request) :-
    (member(method(post), Request)
    ->  catch(http_parameters(Request, [side(Side, [atom, oneof(['X','O']), optional(true)])]), _, Side = _),
        ( nonvar(Side)
        ->  % User selected side: start game
            http_session_retractall(user_player(_)),
            http_session_retractall(bot_player(_)),
            http_session_retractall(game_board(_)),
            http_session_retractall(player(_)),
            http_session_retractall(game_status(_)),
            http_session_data(game_mode(Mode)),
            ( Mode = bot ->
                (Side = 'X' -> Bot = 'O' ; Bot = 'X'),
                http_session_assert(user_player(Side)),
                http_session_assert(bot_player(Bot))
            ;
                % Two player mode: both players are humans
                http_session_assert(user_player(Side)),
                (Side = 'X' -> Second = 'O' ; Second = 'X'),
                http_session_assert(bot_player(Second))  % store as "other player"
            ),
            initial_board(Board),
            http_session_assert(game_board(Board)),
            http_session_assert(player('X')), % X always starts
            http_session_assert(game_status(playing)),
            http_redirect(see_other, '/', Request)
        ;   % POST but no side (invalid), show selection page
            display_choice_page
        )
    ;   % GET request, show selection page
        display_choice_page
    ).

% --- AI logic for bot mode ---
check_and_play_ai(Request) :-
    http_session_data(bot_player(Bot)),
    http_session_data(player(CurrentPlayer)),
    http_session_data(game_status(Status)),
    Status == playing,
    CurrentPlayer == Bot,
    !,
    ai_move_and_display(Request).
check_and_play_ai(_) :-
    display_game_board.

ai_move_and_display(Request) :-
    http_session_data(bot_player(BotPlayer)),
    http_session_data(game_board(Board)),
    find_best_move(Board, BotPlayer, Row, Col),
    make_move(Board, Row, Col, BotPlayer, NewBoard),
    http_session_retractall(game_board(_)),
    http_session_assert(game_board(NewBoard)),
    (winner(NewBoard, BotPlayer) ->
        (BotPlayer == 'X' -> StatusOut = x_wins ; StatusOut = o_wins),
        http_session_retractall(game_status(_)),
        http_session_assert(game_status(StatusOut))
    ; tie(NewBoard) ->
        http_session_retractall(game_status(_)),
        http_session_assert(game_status(draw))
    ;
        switch_player(BotPlayer, NextPlayer),
        http_session_retractall(player(_)),
        http_session_assert(player(NextPlayer))
    ),
    http_redirect(see_other, '/', Request).

% --- Player side select page ---
display_choice_page :-
    reply_html_page(
        title('Choose Your Side'),
        [
            style([type='text/css'], [
                'body { font-family: Arial, sans-serif; margin: 20px; text-align: center; background-color: #f0f8ff; }',
                '.choose-container { max-width: 400px; margin: 80px auto; background: white; padding: 35px; border-radius: 15px; box-shadow: 0 0 20px rgba(0,0,0,0.12); }',
                'h2 { font-size: 2em; margin-bottom: 24px; color: #2c3e50; }',
                '.choose-btn { margin: 15px; padding: 16px 32px; font-size: 1.2em; background: #2ecc71; color: white; border: none; border-radius: 10px; cursor: pointer; }',
                '.choose-btn:hover { background: #3498db; }'
            ]),
            div([class='choose-container'], [
                h2('Choose your player'),
                form([method=post, action='/choose'], [
                    button([type=submit, name=side, value='X', class='choose-btn'], 'Play as X'),
                    button([type=submit, name=side, value='O', class='choose-btn'], 'Play as O')
                ])
            ])
        ]
    ).

% --- Main game board ---
display_game_board :-
    http_session_data(user_player(UserPlayer)),
    http_session_data(bot_player(BotPlayer)),
    http_session_data(game_board(Board)),
    http_session_data(player(CurrentPlayer)),
    http_session_data(game_status(Status)),
    http_session_data(game_mode(Mode)),
    findall(Index, (winning_line(Board, CurrentPlayer, Index)), WinningLines),
    append(WinningLines, WinCells),
    status_message(Status, CurrentPlayer, StatusMsg),
    reply_html_page(
        title('Tic Tac Toe'),
        [
            style([type='text/css'], [
                'body { font-family: Arial, sans-serif; margin: 20px; text-align: center; background-color: #f0f8ff; }',
                '.game-container { max-width: 520px; margin: 0 auto; background: white; padding: 30px; border-radius: 15px; box-shadow: 0 0 20px rgba(0,0,0,0.15); }',
                '.rules { background: #e8f4f8; font-size: 1em; margin: 15px 0 25px 0; border-radius: 8px; padding: 14px 12px 14px 30px; color: #2c3e50; text-align: left; max-width: 410px; margin-left: auto; margin-right: auto; }',
                '.rules h3 { text-align: center; margin-bottom: 12px; font-size: 1.35em; }',
                '.rules ul { padding-left: 20px; margin: 0; }',
                '.rules li { margin: 6px 0; font-size: 1.09em; line-height: 1.4; }',
                '.board { display: grid; grid-template-columns: repeat(3, 100px); grid-template-rows: repeat(3, 100px); gap: 10px; margin: 25px auto; justify-content: center; }',
                '.cell { width: 100px; height: 100px; background-color: #e8f4f8; display: flex; justify-content: center; align-items: center; font-size: 3em; font-weight: bold; border-radius: 10px; border: 2px solid #3498db; transition: background-color 0.4s ease; }',
                '.cell.x { color: blue; }',
                '.cell.o { color: red; }',
                '.cell-link { text-decoration: none; color: inherit; display: block; width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; cursor: pointer;}',
                '.cell-disabled { opacity: 0.5; cursor: not-allowed; }',
                '.winner-cell { background-color: #f1c40f; box-shadow: 0 0 15px #f39c12, 0 0 40px #f39c12; animation: pulseGlow 1.5s infinite; }',
                '@keyframes pulseGlow { 0%, 100% { box-shadow: 0 0 15px #f39c12, 0 0 40px #f39c12; } 50% { box-shadow: 0 0 30px #f39c12, 0 0 60px #f39c12; } }',
                '.game-info { margin: 20px 0 12px 0; font-size: 1.3em; color: #2c3e50; }',
                '.player-info { font-weight: bold; color: #2c3e50; margin-bottom: 10px; }',
                '.status { font-weight: bold; margin: 15px 0; min-height: 30px; font-size: 1.2em; }',
                '.controls { margin: 25px 0; }',
                'button { padding: 12px 25px; font-size: 16px; background: #2ecc71; color: white; border: none; border-radius: 8px; cursor: pointer; }',
                'button:hover { background: #27ae60; }',
                'h1 { color: #2c3e50; margin-bottom: 20px; font-size: 2.5em; }',
                '.winner-text { font-size: 2em; color: #27ae60; font-weight: bold; margin-bottom: 20px; animation: winnerBounce 1.2s ease-in-out infinite alternate; }',
                '@keyframes winnerBounce { 0% { transform: scale(1); } 100% { transform: scale(1.1); } }',
                '.draw-text { font-size: 1.9em; color: #f39c12; font-weight: bold; margin-bottom: 20px; }'
            ]),
            div([class='game-container'], [
                h1('Tic Tac Toe'),
                (Status == x_wins ->
                    div([class='winner-text'], 'X wins!')
                ; Status == o_wins ->
                    div([class='winner-text'], 'O wins!')
                ; Status == draw ->
                    div([class='draw-text'], 'Game ended in a draw!')
                ; []
                ),
                div([class='rules'], [
                    h3('Game Rules'),
                    ul([], [
                        li('Pick X or O to play.'),
                        li('Take turns placing your mark.'), % applies to both modes
                        li('Get three in a row to win.'),
                        li('If all squares fill up with no winner, it is a draw.')
                    ])
                ]),
                div([class='game-info'], [
                    p([class='player-info'], \user_current_info(UserPlayer, BotPlayer, CurrentPlayer, Status, Mode)),
                    p([class='status'], StatusMsg)
                ]),
                div([class='board'], \board_cells(Board, Status, UserPlayer, CurrentPlayer, WinCells, Mode)),
                div([class='controls'], [
                    a([href='/reset'], button([], 'Reset Game'))
                ])
            ])
        ]).

user_current_info(UserPlayer, BotPlayer, CurrentPlayer, playing, Mode) -->
    { (Mode = bot -> format(atom(Text), 'You are: ~w | Bot is: ~w | Current player: ~w', [UserPlayer, BotPlayer, CurrentPlayer])
      ; format(atom(Text), 'Player X: ~w | Player O: ~w | Current player: ~w', [UserPlayer, BotPlayer, CurrentPlayer])
     )
    }, html(Text).
user_current_info(_, _, _, _, _) --> html('').

status_message(Status, CurrentPlayer, Message) :-
    (Status == playing ->
        format(atom(Message), 'Game in progress - Current player: ~w', [CurrentPlayer])
    ; Status == x_wins -> Message = 'X wins!'
    ; Status == o_wins -> Message = 'O wins!'
    ; Status == draw ->  Message = 'Game ended in a draw!'
    ; Message = 'Game status unknown').

board_cells(Board, Status, UserPlayer, CurrentPlayer, WinCells, Mode) -->
    {
        findall(CellHTML, (
            between(0, 2, Row),
            between(0, 2, Col),
            nth0(Row, Board, RowList),
            nth0(Col, RowList, Value),
            (member((Row,Col), WinCells) -> ClassList = ['cell','winner-cell'] ; ClassList = ['cell']),
            (
                Value == ' ', Status == playing,
                ((Mode = bot, CurrentPlayer == UserPlayer) ; (Mode = two))
                ->
                format(atom(Href), '/move?row=~w&col=~w', [Row, Col]),
                CellHTML = div([class=ClassList], a([class='cell-link', href=Href], ' '))
            ; Value == ' ', Status == playing
                -> CellHTML = div([class='cell cell-disabled'], ' ')
            ; Value == 'X' -> CellHTML = div([class=ClassList], 'X')
            ; Value == 'O' -> CellHTML = div([class=ClassList], 'O')
            ; CellHTML = div([class=ClassList], Value)
            )
        ), Cells)
    },
    html(Cells).

make_move(Request) :-
    http_session_data(user_player(UserPlayer)),
    http_session_data(player(CurrentPlayer)),
    http_session_data(game_board(Board)),
    http_session_data(game_status(Status)),
    http_session_data(game_mode(Mode)),
    http_parameters(Request, [
        row(Row,[integer,between(0,2)]),
        col(Col,[integer,between(0,2)])
    ]),
    (Status == playing, (Mode = bot -> CurrentPlayer == UserPlayer ; true) ->
        (valid_move(Board, Row, Col) ->
            make_move(Board, Row, Col, CurrentPlayer, NewBoard),
            http_session_retractall(game_board(_)),
            http_session_assert(game_board(NewBoard)),
            (winner(NewBoard, CurrentPlayer) ->
                (CurrentPlayer == 'X' -> StatusOut = x_wins ; StatusOut = o_wins),
                http_session_retractall(game_status(_)),
                http_session_assert(game_status(StatusOut))
            ; tie(NewBoard) ->
                http_session_retractall(game_status(_)),
                http_session_assert(game_status(draw))
            ;
                switch_player(CurrentPlayer, NextPlayer),
                http_session_retractall(player(_)),
                http_session_assert(player(NextPlayer))
            )
        ; true)
    ; true),
    http_redirect(see_other, '/', Request).

reset_game(Request) :-
    reset_sessions,
    http_redirect(see_other, '/', Request).

valid_move(Board, Row, Col) :-
    nth0(Row, Board, RowList),
    nth0(Col, RowList, ' ').

make_move(Board, Row, Col, Player, NewBoard) :-
    replace(Board, Row, Col, Player, NewBoard).

replace([Row|Rows], 0, Col, Value, [NewRow|Rows]) :-
    replace_in_row(Row, Col, Value, NewRow).
replace([Row|Rows], RowNum, Col, Value, [Row|NewRows]) :-
    RowNum > 0,
    NextRow is RowNum - 1,
    replace(Rows, NextRow, Col, Value, NewRows).

replace_in_row([_|Rest], 0, Value, [Value|Rest]).
replace_in_row([X|Rest], Col, Value, [X|NewRest]) :-
    Col > 0,
    NextCol is Col - 1,
    replace_in_row(Rest, NextCol, Value, NewRest).

winner(Board, Player) :-
    row_win(Board, Player);
    col_win(Board, Player);
    diag_win(Board, Player).

row_win(Board, Player) :-
    member([Player, Player, Player], Board).

col_win(Board, Player) :-
    transpose(Board, Transposed),
    row_win(Transposed, Player).

diag_win(Board, Player) :-
    diag1(Board, Player);
    diag2(Board, Player).

diag1([[Player, _, _],
       [_, Player, _],
       [_, _, Player]], Player).

diag2([[_, _, Player],
       [_, Player, _],
       [Player, _, _]], Player).

tie(Board) :-
    flatten(Board, FlatBoard),
    \+ member(' ', FlatBoard).

switch_player('X', 'O').
switch_player('O', 'X').

transpose([[]|_], []).
transpose(Matrix, [Row|Rows]) :-
    transpose_first(Matrix, Row, RestMatrix),
    transpose(RestMatrix, Rows).

transpose_first([], [], []).
transpose_first([[X|Xs]|Rest], [X|Ys], [Xs|RestRows]) :-
    transpose_first(Rest, Ys, RestRows).

find_best_move(Board, Player, BestRow, BestCol) :-
    findall(Score-Row-Col, (
        between(0, 2, Row),
        between(0, 2, Col),
        valid_move(Board, Row, Col),
        make_move(Board, Row, Col, Player, NewBoard),
        minimax(NewBoard, Player, 0, false, Score)
    ), Moves),
    keysort(Moves, SortedMoves),
    last(SortedMoves, _-BestRow-BestCol).

minimax(Board, _, _, _, Score) :-
    winner(Board, 'X'), !, Score = -10.
minimax(Board, _, _, _, Score) :-
    winner(Board, 'O'), !, Score = 10.
minimax(Board, _, _, _, Score) :-
    tie(Board), !, Score = 0.
minimax(Board, Player, Depth, IsMax, Score) :-
    findall(ChildScore, (
        between(0, 2, Row),
        between(0, 2, Col),
        valid_move(Board, Row, Col),
        switch_player(Player, NextPlayer),
        make_move(Board, Row, Col, Player, NewBoard),
        minimax(NewBoard, NextPlayer, Depth+1, \+ IsMax, ChildScore)
    ), Scores),
    (IsMax -> max_list(Scores, Score) ; min_list(Scores, Score)).

winning_line(Board, Player, Line) :- row_win_indices(Board, Player, Line).
winning_line(Board, Player, Line) :- col_win_indices(Board, Player, Line).
winning_line(Board, Player, Line) :- diag_win_indices(Board, Player, Line).

row_win_indices(Board, Player, [(R,C1),(R,C2),(R,C3)]) :-
    between(0,2,R),
    member((C1,C2,C3), [(0,1,2)]),
    nth0(R, Board, Row),
    nth0(C1, Row, Player),
    nth0(C2, Row, Player),
    nth0(C3, Row, Player).

col_win_indices(Board, Player, [(R1,C),(R2,C),(R3,C)]) :-
    between(0,2,C),
    member((R1,R2,R3), [(0,1,2)]),
    nth0(R1, Board, Row1), nth0(C, Row1, Player),
    nth0(R2, Board, Row2), nth0(C, Row2, Player),
    nth0(R3, Board, Row3), nth0(C, Row3, Player).

diag_win_indices(Board, Player, [(0,0),(1,1),(2,2)]) :-
    nth0(0, Board, R0), nth0(0, R0, Player),
    nth0(1, Board, R1), nth0(1, R1, Player),
    nth0(2, Board, R2), nth0(2, R2, Player).

diag_win_indices(Board, Player, [(0,2),(1,1),(2,0)]) :-
    nth0(0, Board, R0), nth0(2, R0, Player),
    nth0(1, Board, R1), nth0(1, R1, Player),
    nth0(2, Board, R2), nth0(0, R2, Player).
