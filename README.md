# Bankrun_netlogo_simmulation

## Eigenschaften nodes
- **state_of_mind** (calm, concerned, withdraw), color
- **forgetfullness / inertia** (how likely to change state to calm)
- **naitivity** (how many neighbors to change state)
	- **credibility** (how much influenence does one neighbor hold, (credibility score needs to  be calculated when the node changes state)), size
	-  `link-strength` – starke Links (Familie) vs. schwache Links (Twitter-Follow); Granovetter
- **connectivity**: Links to other node
	- `stubbornness` Wahrscheinlichkeit den eigenen State zu behalten trotz Umfeld (Heterogenität!)
- **insider** /**outsider** Typ
- **wealth** wie viel in Bank gelagert, kann % oder total sein

## Instanz der Bank
- `health` für die Gesundheit der Bankenbilanz (stetige Funktion)
- `reserve-ratio` – wie viel Liquidität hat die Bank; bestimmt ab wann sie wirklich kollabiert
- `deposit-insurance` – versicherte Deposits reagieren träger; wichtiger Dämpfer

## Structure of the map `init`
- nodes generieren
- links zwischen den node

## Aktionen pro Tick
- random rumor is set into motion
	- bank sends rumor depending on the health function to insiders.
- observe neighbors
- adjust state_of_mind
	-  `rewiring-probability` – Watts-Strogatz-Parameter (Parameter, der angibt wie stark die Nodes in Gruppen verbunden sind): zwischen reinem Gitter (Dorf) und random (Internet) (randmly reconnect to other nodes) (Beachten, das die Länge der Verbindungen egal ist. jede Verbindung hat das Gewicht 1)
- check if the bank is abankrupt
- klick on nodes to spread akute panic

## Mögliche Erweiterung
- mehrere Banken, nur eine schlecht, trotzdem spread auf andere durch social media ??
- können auch noch Speed of communication einführen: Kommunikation über social media schneller als über normale...hier Frage ob das nicht schon durch connectivity gegeben?
- unterschiedliche wealth Verteilung (siehe Santos und Nakane)


🐈‍⬛
