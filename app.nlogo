init
  create nodes
  connect nodes 
  add variables state_of_mind (calm, concerned, withdraw)
forgetfullness / inertia** (how likely to change state to calm)
naitivity (how many neighbors to change state)
credibility (how much influenence does one neighbor hold, (credibility score needs to  be calculated when the node changes state)), size
link-strength – starke Links (Familie) vs. schwache Links (Twitter-Follow); Granovetter
connectivity: Links to other node
stubbornness Wahrscheinlichkeit den eigenen State zu behalten trotz Umfeld (Heterogenität!)
insider** /**outsider** bool
Schwellvariable S, wann state switch

bank init 
`health` für die Gesundheit der Bankenbilanz (stetige Funktion / schieberegler)
- `reserve-ratio` – wie viel Liquidität hat die Bank; bestimmt ab wann sie wirklich kollabiert
- `deposit-insurance` – versicherte Deposits reagieren träger; wichtiger Dämpfer

to go 
random rumor is set into motion, to insider
check nachbarn, die mit link verbunden
r_state_change_function anwenden, um zu bestimmen, ob man seinen state ändern sollte
ändern, falls r>=S ist, -> zu beunruhigt / abheben.
check if the bank is abankrupt
end


