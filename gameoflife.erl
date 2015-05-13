-module(gameoflife).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1,connect/3,bench/1,send/5,init/1,ctrl/3]).

bench(N) ->
	%Grid = szybowiec(), % zmienny w czasie
	Grid = zaba(), % zmienny cyklicznie
	%Grid = staw(), % niezmienny
	%Grid = blinker(),
	connect(5,5,Grid),
	Ctrl = spawn(gameoflife,ctrl,[Grid,1,N]), % wywoluje proces kontrolny czekajacy na informacje o zmianie statusow
	io:format("~n",[]),
	send(5,5,Grid,N,Ctrl).

szybowiec() ->
{{start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(aliv),start(aliv),start(aliv),start(dead)},
 {start(dead),start(dead),start(aliv),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(aliv),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)}}.

zaba() ->
{{start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(aliv),start(aliv),start(dead),start(dead)},
 {start(dead),start(aliv),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(aliv),start(dead)},
 {start(dead),start(dead),start(aliv),start(aliv),start(dead),start(dead)}}.

staw() ->
{{start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(aliv),start(aliv),start(dead),start(dead)},
 {start(dead),start(aliv),start(dead),start(dead),start(aliv),start(dead)},
 {start(dead),start(aliv),start(dead),start(dead),start(aliv),start(dead)},
 {start(dead),start(dead),start(aliv),start(aliv),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)}}.

blinker() ->
{{start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(aliv),start(aliv),start(aliv),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)},
 {start(dead),start(dead),start(dead),start(dead),start(dead),start(dead)}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


cell(0, Ctrl, _State, _Neighbours) ->
	done;
cell(N, Ctrl, State, Neighbours) -> %funkcja odpowiadajaca za proces jednej komorki
	multicast(State, Neighbours), % wysyla informacje o statusie do sasiadow
	All = collect(Neighbours), % zbiera informacje
	Next = rule(All, State), % wyznacza nastepny stan
	Ctrl ! {done,self(),Next}, % wysyla status do procesu CTRL
	cell(N-1, Ctrl, Next, Neighbours). % rekurencja

multicast(State, Neighbours) -> % wysyla informacje o statusie do sasiadow
	Self = self(),
	lists:foreach(fun(Pid) -> Pid ! {state, Self, State} end, Neighbours).

collect(Neighbours) -> % zbiera informacje o statusie od sasiadow
	lists:map(fun(Pid) ->
		receive {state, Pid, State} -> State end
		end, Neighbours).

rule(Neighbours, State) -> % wyznacza ilosc zywych sasiadow w oparciu o funkcje alive
	Alive = alive(Neighbours),
	
if State == aliv ->
					if
						Alive < 2 -> dead;
						Alive == 2 -> State;
						Alive == 3 -> aliv;
						Alive > 3 -> dead
					end;

true ->
					if
						Alive == 3 -> aliv;
						Alive < 3 -> dead;
						Alive > 3 -> dead
					end
end.

alive(Neighbours) -> % liczy zywych sasiadow
	lists:foldl(fun(State, Sum) -> if State == aliv -> Sum+1; 
								  	  State == dead -> Sum=Sum  
							   	   end 
				end, 0, Neighbours).




start(State) -> % uruchamia proces funkcji init(state)
	spawn_link(fun() -> init(State) end).

init(State) -> %glowna funkcja oczekujaca na wiadomosci od funkcji connect i send
	receive
		{init, Neighbours} -> % oczekuje na wiadomosc initiate z lista sasiadow od funkcji connect
			receive
				{go,N,Ctrl} -> cell(N,Ctrl,State,Neighbours) % oczekuje na wiadomosc o zaczeciu dzialania czyli wywolywaniu funkcji cell
			end
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	

element(Row, Col, Grid) -> % wybieranie elementu macierzy
	element(Col+1, element(Row+1, Grid)).

s(R, C, Grid) -> %sasiad poludniowy
	element((R+1) rem 6, C, Grid).
sw(R, C, Grid) -> %sasiad zachodni
	element((R+1) rem 6, (C+5) rem 6, Grid).
se(R, C, Grid) -> % sasiad wschodni poludniowy
	element((R+1) rem 6, (C+1) rem 6, Grid).
n(R, C, Grid) -> % polnocny
	element((R+5) rem 6, C, Grid).
nw(R, C, Grid) -> % polnocno zachodni
	element((R+5) rem 6, (C+5) rem 6, Grid). %polnocno zachodni
ne(R, C, Grid) -> % polnocno wschodni
	element((R+5) rem 6, (C+1) rem 6 , Grid).
w(R, C, Grid) -> % zachodni
	element(R, (C+5) rem 6, Grid).
e(R, C, Grid) -> % wschodni
	element(R, (C+1) rem 6, Grid).

this(R, C, Grid) -> % biezacej komorki
	element(R, C, Grid).

connect(-1, C, Grid) ->  
	done;

connect(R, -1, Grid) ->
	connect(R-1, 5, Grid);

connect(R, C, Grid) -> % wysyla listy sasiadow do komorek
	S = s(R, C, Grid),
	SW = sw(R, C, Grid),
	SE = se(R, C, Grid),
	N = n(R, C, Grid),
	NW = nw(R, C, Grid),
	NE = ne(R, C, Grid),
	W = w(R, C, Grid),
	E = e(R, C, Grid),
	This = this(R,C, Grid),
	This ! {init, [S,SW,SE,N,NW,NE,W,E]},
	connect(R, C-1, Grid).

	
send(-1, C, Grid, N,Ctrl) ->
	Ctrl;

send(R, -1, Grid, N,Ctrl) ->
	send(R-1, 5, Grid, N,Ctrl);

send(R, C, Grid, N,Ctrl) -> % wysyka do kazdej komorki wiadomosc aby zaczely dzialac po uprzednim odebraniu wiadomosci od connect
	element(R, C, Grid) ! {go, N, Ctrl},
	send(R, C-1, Grid, N,Ctrl).


ctrl(Grid,R,0) -> done;

ctrl(Grid,7,N) -> io:format("~n"), ctrl(Grid,1,N-1);

ctrl(Grid,R,N) ->
	Row = swap(R,Grid),
	Result = lists:map(fun(Pid) ->
		receive {done, Pid, State} -> State end
		end, Row),
	io:format("~n",[]), io:write(Result),
	ctrl(Grid,R+1,N).

	
swap(R,Grid) ->
	tuple_to_list(element(R,Grid)).
	






