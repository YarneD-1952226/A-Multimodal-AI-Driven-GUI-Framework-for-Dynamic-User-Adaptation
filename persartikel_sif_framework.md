# AI die zich aanpast: een interface die jou begrijpt

Een “one‑size‑fits‑all” interface werkt prima, tot je net naast een knop tikt, je in fel zonlicht staat of je je toestel liever met je stem bedient. Een nieuwe masterproef stelt een **multimodaal, AI‑gedreven framework** voor dat gebruikersinterfaces zich **in real time** laat aanpassen aan de persoon én de situatie. Het richt zich op toepassingen in de **gezondheidszorg** en verbetert de toegankelijkheid voor **motorisch** en **visueel** beperkte gebruikers én voor **handsfree** bedienen.

## Wat is het?

De kern heet **Smart Intent Fusion (SIF)**. Dit is een **multi‑agent** architectuur die signalen uit **touch**, **toetsenbord**, **spraak** en **gebaren** combineert met **gebruikersprofielen** en **interactiegeschiedenis**. SIF probeert zo de **bedoeling** van de gebruiker te begrijpen en stelt **gerichte UI‑aanpassingen** voor, zoals:
- grotere knoppen of meer witruimte,
- hogere contrasten en duidelijkere randen,
- automatisch overschakelen naar een andere **bedieningsmodus** (bijv. spraak).

Onder de motorkap werkt SIF met twee hersenhelften:
1. **Regelgebaseerde logica** voor **voorspelbare, snelle** reacties (bv. na een misstap de doelknop vergroten).
2. **LLM‑redenering** via Google Gemini voor **complexe of ambigue** situaties (bv. afwegen of spraakmodus nu echt beter is).

Die combinatie levert zowel **lage latency** als **contextbewuste** voorstellen op.

## Ontwikkelaarsvriendelijk en overal inzetbaar

Het framework is **platform‑agnostisch**: het integreert met **Flutter**, **SwiftUI** en kan meegroeien naar web of VR/AR. Koppelen gebeurt via **gestandaardiseerde JSON‑contracten** en een **FastAPI‑backend**. Voor ontwikkelaars betekent dat: gebeurtenissen erin, **aanpassingssuggesties** eruit, zonder de apparchitectuur om te gooien. De aanpak is **draagbaar** naar andere domeinen dan gezondheid, van educatie tot publieke kiosken.

## Hoe werkt dat in de praktijk?

- Een gebruiker met motorische beperking tikt **net naast** “Start”. Het systeem ziet de fout en **vergroot** de knop onmiddellijk.
- Iemand met een visuele beperking krijgt **hogere contrasten** en **grotere lettertypes**, zodat belangrijke elementen beter opvallen.
- Wie handsfree wil werken, ziet **duidelijke spraak‑hints** en kan sneller schakelen tussen **spraak** en **touch** afhankelijk van de context.

SIF leert bovendien van de **recente interactiegeschiedenis**. Als meerdere misstappen zich opstapelen, kan het systeem bijvoorbeeld een **semi‑permanente** vergroting voorstellen of de UI‑layout vereenvoudigen.

## Wat is er precies getest?

De haalbaarheid werd geëvalueerd met **zes uiteenlopende gebruikersprofielen**, elk met andere toegankelijkheidsnoden. Voor elk profiel werden **twee opeenvolgende runs** uitgevoerd, telkens met **zeven multimodale interactie‑events**. Dat laat het systeem toe om zowel te reageren op **onmiddellijke fouten** (zoals miss‑taps of een slider die doorschiet) als om **aanpassingen te verfijnen** op basis van een groeiende geschiedenis.

De evaluatie keek naar:
- **Schema‑geldigheid** van de voorgestelde aanpassingen (klopt het formaat, zijn ze uitvoerbaar?),
- **Inhoudelijke afstemming** op het profiel (sluiten acties aan bij de daadwerkelijke noden?),
- **Latency‑verdeling** (hoe snel verschijnen de aanpassingen aan de UI?),
- én zowel **per‑profiel analyses** als een **globaal overzicht** van welke acties het vaakst en het nuttigst waren.

De kernconclusie: het systeem levert **consistent toegankelijkheidsgerichte aanpassingen** op. Tegelijk benoemt de studie **verbeterpunten** rond **personalisering** (fijner afstemmen op individuele voorkeuren) en **latency‑handling** (nog vlotter schakelen bij complexere scenario’s).

## Waarom dit ertoe doet

Digitale diensten zijn pas echt inclusief als de **interface meebeweegt** met de gebruiker. Vandaag vragen aanpassingen vaak handwerk of aparte “toegankelijkheidsmodi”. Met SIF wordt **persoonlijke toegankelijkheid** een **standaardonderdeel** van UI‑ontwerp: automatisch, multimodaal en **real‑time**.

Voor ontwikkelaars is het voordeel dubbel: ze hoeven geen aparte codepaden per doelgroep te onderhouden, en ze krijgen **uitlegbare voorstellen** terug die ze meteen kunnen toepassen. Voor organisaties in zorg en welzijn betekent het **snellere taakvoltooiing** en **minder fouten**, zonder elke app vanaf nul te herontwerpen.

## Wat volgt er?

De masterproef ziet dit als opstap naar **AI‑modellen die UI‑code autonoom kunnen herschrijven**. Denk aan componenten die zichzelf herstructureren voor leesbaarheid of bediening, of aan **on‑device** modellen voor offline omgevingen met privacy‑eisen. Nieuwe modaliteiten zoals **eye‑tracking**, kunnen in dezelfde pijplijn worden opgenomen, zonder de basisarchitectuur te wijzigen.

---
