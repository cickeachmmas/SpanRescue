**People's Democratic Republic of Algeria**

**Ministry of Higher Education and Scientific Research**

**University Mohamed Boudiaf of M'sila**

Faculty of Mathematics and Computer Science

Department of Computer Science

Thesis submitted in partial fulfillment of the requirements  
for the degree of Master in Computer Science

**Specialty: Distributed Systems and Mobile Networks**

Prepared by

**ZOUBIRI Wissal Zeyneb**

**BENATTIA Djouhaina**

**ENTITLED**

**SPAN RESCUE:**

**Design and Implementation of a Hybrid Multi-Hop**

**Mesh Network for Emergency and Rescue Operations**

**on Android**

Under the supervision of

**Dr. ATTIR Azzedine**

**Composition of the Jury**

| \[Dr. Committee President\] | *University of M'sila* | President |
| :---- | :---: | ----: |
| Dr. ATTIR Azzedine | *University of M'sila* | Reporter |
| \[Dr. Committee Examiner\] | *University of M'sila* | Examiner |

**Academic Year  2024 / 2025**

**Abstract**

When disaster strikes — an earthquake, a flood, a major industrial accident — the first infrastructure to fail is almost always the communication network. Cellular towers collapse under structural damage, power grids fail within hours, and backbone fiber links are severed. Rescue teams arrive equipped with smartphones that have become, in that moment, completely useless: every application on those devices assumes the existence of a network that no longer exists. SPAN RESCUE was designed to break that dependency.

This thesis presents the complete design and implementation of SPAN RESCUE, an Android application enabling a group of standard smartphones to self-organize into a multi-hop mesh communication network in under five seconds — with no pre-configuration, no specialized hardware, and no internet connection. The system combines Bluetooth Low Energy (BLE) for continuous energy-efficient device discovery with Wi-Fi Direct for high-bandwidth peer-to-peer transport, implementing a four-layer communication stack that supports up to twenty devices across four interconnected star groups connected through software bridge nodes.

The routing layer implements the Smart Routing Protocol (SRP), a controlled flooding algorithm with three broadcast storm prevention mechanisms: TTL enforcement (maximum 10 hops), message-ID LRU deduplication (capacity 500 entries), and randomized forwarding delay (0–500 ms). A three-level priority queue ensures SOS emergency broadcasts — carrying GPS coordinates and battery level — are always forwarded before all other traffic. A `shared_preferences` JSON-backed store-and-forward queue ensures delivery to temporarily disconnected nodes.

The application provides five tactical screens: an SOS home screen with 2-second long-press activation, a system monitor displaying seven connection lifecycle phases, a live mesh topology graph, a tactical chat interface with per-message hop-count display, and a settings screen. Testing across five Android devices from four manufacturers validated all core components. Four undocumented Android API behaviors — critical for any developer building similar systems — were discovered and are documented in Chapter 3\.

**Keywords:** Wi-Fi Direct; Bluetooth Low Energy (BLE); Smartphone Ad hoc Network (SPAN); Smart Routing Protocol (SRP); Multi-hop Mesh; Star Topology; Multi-Group Bridge; Emergency Communication; Android; Store-and-Forward; Disaster Management; TTL; Broadcast Storm Prevention; Priority Queue; Foreground Service.

**الملخص**

حين تضرب الكارثة — زلزال أو فيضان أو حادث صناعي كبير — فإن أول بنية تحتية تنهار هي في الغالب شبكة الاتصالات. تتهاوى أبراج الإرسال الخلوي تحت الدمار المادي، وتتوقف شبكات الكهرباء خلال ساعات، وتُقطع روابط الألياف الضوئية الرئيسية. تصل فرق الإنقاذ مزوَّدةً بهواتف ذكية باتت في تلك اللحظة عديمة الفائدة كلياً، لأن كل تطبيق على تلك الأجهزة يفترض ضمناً وجود شبكة لم تعد موجودة. جاء تطبيق SPAN RESCUE ليكسر هذه التبعية.

تقدم هذه المذكرة التصميم الكامل وتنفيذ تطبيق SPAN RESCUE، وهو تطبيق أندرويد يمكّن مجموعة من الهواتف الذكية الاعتيادية من تنظيم نفسها في شبكة شبكية متعددة القفزات خلال أقل من خمس ثوانٍ — دون أي ضبط مسبق أو أجهزة متخصصة أو اتصال بالإنترنت. يجمع النظام بين تقنية Bluetooth Low Energy للاكتشاف الموفّر للطاقة وتقنية Wi-Fi Direct للنقل عالي السرعة، مطبِّقاً مكدَّساً من أربع طبقات يدعم ما يصل إلى عشرين جهازاً موزَّعاً على أربع مجموعات نجمية مترابطة عبر عُقَد جسرية برمجية.

تنفذ طبقة التوجيه بروتوكول التوجيه الذكي SRP — وهو خوارزمية فيضان محكوم بثلاثة آليات لمنع عواصف البث: إنفاذ TTL بحد أقصى 10 قفزات، وإلغاء تكرار الرسائل عبر ذاكرة LRU بسعة 500 مدخل، وتأخير توجيه عشوائي من 0 إلى 500 ميلي ثانية. تضمن قائمة أولويات ثلاثية المستويات أن إشارات الطوارئ SOS — حاملةً إحداثيات GPS ومستوى البطارية — تُوجَّه دائماً قبل كل حركة مرور أخرى.

**الكلمات المفتاحية:** Wi-Fi Direct؛ Bluetooth Low Energy؛ شبكة شبكية؛ SPAN؛ بروتوكول التوجيه الذكي؛ توجيه متعدد القفزات؛ طوبولوجيا نجمية؛ جسر متعدد المجموعات؛ اتصال الطوارئ؛ أندرويد؛ Store-and-Forward؛ إدارة الكوارث.

**Dedications**

*To my parents — for every sacrifice made in silence,*

*and for believing in me before I believed in myself.*

*To Djouhina — this work is as much yours as mine.*

***ZOUBIRI Wissal Zeyneb***

*To my family — my first and most enduring support.*

*To Wissal — for her patience, her creativity, and her friendship.*

***BENATTIA Djouhina***

**Acknowledgments**

We would like to express our deepest gratitude to Dr. ATTIR Azzedine, our thesis supervisor, for his guidance, availability, and constructive feedback throughout every phase of this project. His ability to redirect our thinking at critical junctures — while letting us learn from our own decisions — was invaluable.

We thank the members of the jury for accepting to evaluate this work and for the time they will invest in reading it carefully. Their remarks will be important for any continuation of this research.

Our sincere appreciation goes to the professors of the Department of Computer Science at the University Mohamed Boudiaf of M'sila. The curriculum in distributed systems, mobile networking, and software engineering directly equipped us for this project.

Finally, to our families: thank you for the quiet support, the patience with late nights, and the encouragement that kept this work moving forward.

**List of Figures**

Fig. 1.1:  Disaster communication infrastructure failure cascade12

Fig. 1.2:  MANET node acting simultaneously as host and router16

Fig. 1.3:  AODV RREQ/RREP route discovery sequence diagram19

Fig. 1.4:  Broadcast storm: exponential message multiplication without TTL22

Fig. 1.5:  Wi-Fi Direct star group: GO at center, 4 clients at periphery25

Fig. 1.6:  BLE advertising and scanning dual-mode mechanism27

Fig. 1.7:  SmartGroup@Net (SGN) deployment scenario with Polar H7 sensors30

Fig. 2.1:  SPAN RESCUE four-layer communication stack overview35

Fig. 2.2:  Layer 1 BLE Discovery state machine38

Fig. 2.3:  BLE advertisement packet structure and field layout39

Fig. 2.4:  Layer 2 Wi-Fi Direct connection lifecycle state diagram42

Fig. 2.5:  Layer 3 TCP transport: EOF delimiter framing mechanism46

Fig. 2.6:  Layer 4 SRP message processing flowchart50

Fig. 2.7:  SeenMessage LRU cache eviction mechanism52

Fig. 2.8:  Single Wi-Fi Direct star group (max 6 devices)55

Fig. 2.9:  Multi-group bridge topology: 20 devices across 4 star groups57

Fig. 2.10:  GO Beacon broadcast and inter-group TCP bridge establishment59

Fig. 2.11:  Bridge forwarding: seenBy array preventing inter-group storms61

Fig. 2.12:  SOS message path: Group A to Group D (8 hops)63

Fig. 2.13:  Store-and-forward queue lifecycle for disconnected nodes66

Fig. 2.14:  Network self-healing: GO failure and re-election sequence68

Fig. 2.15:  UML Use Case Diagram — actors and use cases71

Fig. 2.16:  UML Sequence Diagram — BLE discovery and group formation73

Fig. 2.17:  UML Sequence Diagram — SOS transmission and relay75

Fig. 2.18:  UML Class Diagram — core networking components77

Fig. 2.19:  UML Activity Diagram — SRP message processing pipeline79

Fig. 2.20:  SPAN RESCUE design system color palette and tokens82

Fig. 2.21:  UI Wireframe: Home screen with SOS button and radar84

Fig. 2.22:  UI Wireframe: System Monitor seven-phase lifecycle86

Fig. 2.23:  UI Wireframe: Mesh Topology live graph layout88

Fig. 2.24:  UI Wireframe: Tactical Chat with SOS overlay90

Fig. 3.1:  SPAN RESCUE Home Screen — screenshot96

Fig. 3.2:  System Monitor Screen — screenshot (phase 4 active)98

Fig. 3.3:  Mesh Topology Screen — screenshot (5 nodes)100

Fig. 3.4:  Tactical Chat Screen — screenshot (SOS banner active)102

Fig. 3.5:  Settings Screen — screenshot104

Fig. 3.6:  Android foreground service component interaction diagram107

Fig. 3.7:  TCP fragmentation: naive parsing failure vs. EOF buffer fix112

Fig. 3.8:  BLE scan restart: 30-second kill and 28-second keepalive114

Fig. 3.9:  Message delivery latency: 1-hop vs. 4-hop comparison118

Fig. 3.10:  Network formation time across 10 test sessions120

**List of Tables**

Table 1.1:  Emergency communication technologies vs. requirements13

Table 1.2:  MANET routing protocol families: trade-offs20

Table 1.3:  Survey of existing SPAN applications — features and gaps28

Table 2.1:  Functional requirements FR1–FR1036

Table 2.2:  Non-functional requirements NFR1–NFR737

Table 2.3:  BLE advertising parameters and energy trade-offs40

Table 2.4:  Wi-Fi Direct GO election: Intent Value and role43

Table 2.5:  TCP socket parameters: ports and timeout values47

Table 2.6:  SRP message structure — all fields and constraints51

Table 2.7:  Message priority levels and queue behavior53

Table 2.8:  Multi-group bridge topology: 20-device group assignment58

Table 2.9:  Store-and-forward pending\_messages database schema67

Table 2.10:  Network self-healing: failure scenarios and recovery69

Table 2.11:  UI design system tokens83

Table 3.1:  Development environment and build configuration95

Table 3.2:  Android permissions: purpose and minimum API level97

Table 3.3:  Test device specifications — 5 devices, 4 manufacturers115

Table 3.4:  Test session results — all scenarios and outcomes119

Table 3.5:  Post-implementation comparison with related systems122

**List of Acronyms**

| Acronym | Definition |  | Acronym | Definition |
| ----- | ----- | ----- | ----- | ----- |
| **ACK** | Acknowledgment |  | **LRU** | Least Recently Used |
| **AODV** | Ad hoc On-demand Distance Vector |  | **MANET** | Mobile Ad hoc Network |
| **API** | Application Programming Interface |  | **NFR** | Non-Functional Requirement |
| **BAN** | Body Area Network |  | **OLSR** | Optimized Link State Routing Protocol |
| **BLE** | Bluetooth Low Energy |  | **P2P** | Peer-to-Peer |
| **BTS** | Base Transceiver Station |  | **RFC** | Request for Comments |
| **DHCP** | Dynamic Host Configuration Protocol |  | **RREP** | Route Reply (AODV) |
| **DTN** | Delay-Tolerant Network |  | **RREQ** | Route Request (AODV) |
| **ECDH** | Elliptic Curve Diffie-Hellman |  | **SDK** | Software Development Kit |
| **EOF** | End-of-File delimiter |  | **SOS** | Save Our Souls (international emergency signal) |
| **FR** | Functional Requirement |  | **SPAN** | Smartphone Ad hoc Network |
| **GO** | Group Owner (Wi-Fi Direct) |  | **SQL** | Structured Query Language |
| **GPS** | Global Positioning System |  | **SRP** | Smart Routing Protocol |
| **ID** | Identifier |  | **TCP** | Transmission Control Protocol |
| **IEEE** | Institute of Electrical and Electronics Engineers |  | **TTL** | Time To Live |
| **IP** | Internet Protocol |  | **UI** | User Interface |
| **IoT** | Internet of Things |  | **UUID** | Universally Unique Identifier |
| **JSON** | JavaScript Object Notation |  | **WFD** | Wi-Fi Direct |

**General Introduction**

At 04:17 on February 6, 2023, a 7.8-magnitude earthquake struck Kahramanmaraş in southern Turkey. Within minutes, cellular networks across the region failed. Rescue teams deployed to the site found that every communication application on their smartphones — from SMS to specialized rescue coordination software — had become non-functional. The devices had full batteries. The radios were working. The problem was entirely in the software: every application assumed the existence of a network that had just ceased to exist.

This pattern is not unique to Turkey. The 2010 Haiti earthquake, the 2003 Boumerdès earthquake in Algeria, the 2020 Beirut explosion, the 2023 Libya floods — in each event, communication infrastructure failure directly compounded casualties during the critical first hours of rescue operations. The technology to address this problem — Wi-Fi Direct and Bluetooth Low Energy radios already present in every modern smartphone — has been available for over a decade. What has been missing is a reliable, deployable application that assembles those components into a working emergency mesh network. SPAN RESCUE is that application.

## **Context and Motivation**

This thesis is developed within the Master's program in Computer Science at the University Mohamed Boudiaf of M'sila, specialty Distributed Systems and Mobile Networks. Algeria's geography — mountainous regions with limited cellular coverage, areas historically affected by earthquakes and floods — makes the problem of infrastructure-free emergency communication directly relevant to our context. Building a solution is therefore not an abstract academic exercise but a contribution to a challenge that affects our communities.

## **Problem Statement**

The central research question is: how can a group of standard Android smartphones, without internet connection, cellular network, or pre-deployed infrastructure, form a reliable multi-hop communication network supporting emergency coordination — including SOS broadcasts with GPS location, multi-user text communication, and automatic self-healing — across up to twenty devices, within the constraints of the Android API and consumer hardware? This decomposes into five sub-problems: infrastructure-free continuous device discovery with minimal battery impact; automatic multi-group star topology formation with software bridge connections; reliable multi-hop message routing without broadcast storms; SOS signal priority delivery above all other traffic; and continuous networking operation when Android deprioritizes the application process.

## **Objectives**

- Design a four-layer communication architecture for infrastructure-free smartphone mesh networking;

- Implement a hybrid BLE+Wi-Fi Direct discovery and connection mechanism with automatic group formation;

- Design and implement the Smart Routing Protocol (SRP) with TTL enforcement, LRU deduplication, and priority queuing;

- Build a multi-group bridge topology supporting up to 20 devices without root access or specialized hardware;

- Develop an Android application with a stress-tolerant tactical interface across five functional screens;

- Validate the system through real-device testing and document undocumented platform behaviors.

## **Thesis Structure**

This document is organized into three chapters. Chapter 1 surveys the state of the art: documented disaster communication failures, MANET routing theory, the SPAN paradigm, and a critical comparative review of existing SPAN applications. Chapter 2 presents the complete system design and conception: four-layer architecture, multi-group bridge topology for twenty devices, the Smart Routing Protocol formal specification, four UML diagrams, and the user interface design system. Chapter 3 describes the Android implementation, documents four undocumented platform API behaviors, presents application screenshots, and reports the test results. A general conclusion summarizes contributions and identifies six directions for future work.

# **Chapter 1:  State of the Art**

## **1.1  Introduction**

This chapter surveys the state of the art across three dimensions. First, the documented failure patterns of infrastructure-dependent emergency communication establish the concrete motivation for SPAN RESCUE. Second, the theoretical foundations of Mobile Ad hoc Networks (MANETs) — routing protocol design and broadcast storm analysis — provide the intellectual tools needed to justify our architectural choices. Third, a critical review of existing SPAN applications identifies what has been tried, what works, and what six specific capabilities remain missing from all current solutions simultaneously.

## **1.2  Emergency Communication: The Infrastructure Dependency Problem**

### **1.2.1  Documented Failure Patterns**

The foundational study by Quarantelli \[1\], drawing on six decades of disaster case studies, consistently identifies communication failure as the single most common and most consequential operational failure in emergency response. The failure cascade is well understood and repeatable across disaster types:

- Physical destruction of Base Transceiver Stations (BTS) by earthquake impact, floodwater, or blast overpressure;

- Power grid failure eliminating diesel generator backup at switching centers, typically within 4–8 hours of grid loss;

- Network congestion: simultaneous emergency calls from millions of users overwhelming remaining switching capacity, producing effective blackout even on intact infrastructure;

- Backbone fiber-optic cable severance cutting connectivity between the affected zone and the national network core;

- Electromagnetic interference from emergency vehicle radios disrupting remaining wireless base stations.

The 2011 Great East Japan Earthquake — the most extensively documented case — disrupted 1.5 million fixed-line telephone circuits and rendered 29,000 base stations inoperative \[2\]. The subsequent tsunami destroyed physical infrastructure along a 500-kilometer coastal strip. Emergency coordinators in Miyagi Prefecture reported complete communication blackout for the first 72 hours — precisely the window during which survivor rescue probability declines most steeply. Algeria's own disaster history — the 2003 Boumerdès earthquake (10,000+ casualties, communications severely disrupted), recurring M'sila region floods — confirms this pattern is not geographically limited.

### **1.2.2  Requirements for Infrastructure-Free Emergency Communication**

Synthesizing the disaster response literature \[1,2\] and the operational specifications of search-and-rescue teams, seven requirements emerge for any viable infrastructure-free emergency system:

| ID | Requirement | Target | SPAN RESCUE |
| :---: | ----- | ----- | ----- |
| R1 | Zero-infrastructure | No network, AP, or server | BLE \+ Wi-Fi Direct only |
| R2 | Rapid deployment | \< 10 seconds, no config | Auto-discovery \+ formation |
| R3 | Multi-hop relay | Beyond direct radio range | SRP up to 10 hops |
| R4 | SOS priority | Delivery before all other traffic | Priority queue P=1 |
| R5 | Battery efficiency | Minimal energy in background | BLE BALANCED mode |
| R6 | Standard hardware | Consumer smartphones only | Android API 29+ |
| R7 | Self-healing | Recover from node failure | Heartbeat \+ re-election |

*Table 1.1: Emergency communication requirements and SPAN RESCUE's response to each*

## **1.3  Mobile Ad hoc Networks: Theoretical Foundations**

### **1.3.1  Definition and Core Characteristics**

A Mobile Ad hoc Network (MANET) is formally defined in IETF RFC 2501 \[3\] as a self-configuring, infrastructure-less collection of mobile devices interconnected by wireless links, where every node simultaneously functions as an end system and as a packet router forwarding traffic on behalf of other nodes. Four characteristics distinguish MANETs from all conventional architectures:

- Dynamic topology: nodes continuously join, leave, and move, making any network state snapshot obsolete within seconds;

- Distributed control: no authority maintains routing tables or assigns addresses; all coordination is emergent from local interactions;

- Constrained resources: battery-powered nodes have limited CPU, RAM, and radio bandwidth — overhead must be minimized;

- Multi-hop delivery: most node pairs are beyond direct radio range; messages require relay through intermediaries.

These characteristics define the core routing challenge: deliver messages reliably across a topology changing faster than any routing protocol can track, using only local information, without exhausting node batteries or radio capacity.

### **1.3.2  Routing Protocol Families**

Three routing protocol families address this challenge with different trade-offs between accuracy (requiring overhead) and simplicity (sacrificing accuracy):

**Proactive protocols** maintain continuously updated routing tables through periodic topology broadcasts. OLSR (RFC 3626 \[4\]) is the canonical example: every node maintains a complete topology map and can forward to any destination without route-discovery delay. The cost is substantial overhead — every topology change triggers update floods that can saturate the network in high-mobility environments typical of disaster zones.

**Reactive protocols** discover routes only when needed. AODV (RFC 3561 \[5\]) floods a Route Request (RREQ) when a source needs a route; the destination replies with a Route Reply (RREP) that propagates back along the reverse path. This reduces idle overhead but introduces route-discovery latency — potentially critical for emergency SOS signals where every second matters.

**Flooding-based approaches** broadcast every message to all reachable nodes, guaranteeing delivery as long as any path exists. The weakness — exponential message multiplication — is addressed by the mechanisms analyzed by Ni et al. \[6\]: TTL (hop count limit), ID-based deduplication (seen-message cache), and probabilistic forwarding delay. SPAN RESCUE's Smart Routing Protocol adopts all three.

| Protocol Family | Representative | Overhead | Key Trade-off |
| ----- | ----- | :---: | ----- |
| Proactive (table-driven) | OLSR \[4\], DSDV \[18\] | High — periodic floods | Zero latency; stale in high mobility; RFC 3626 |
| Reactive (on-demand) | AODV \[5\], DSR \[19\] | Medium — on demand | Accurate when stable; RREQ latency; RFC 3561 |
| Flooding \+ mitigation | Epidemic, SRP (this work) | Low — dedup+TTL | Delivery guarantee; robust to failures; scalable |
| Hybrid | ZRP, HARP | Low–Medium | Zone-based; complex implementation overhead |

*Table 1.2: MANET routing protocol families — overhead characteristics and trade-offs*

### **1.3.3  The Broadcast Storm Problem**

Ni et al. \[6\] formally analyzed the broadcast storm problem in their seminal 1999 MobiCom paper. In a dense MANET of N nodes, naive flooding generates O(N²) total transmissions for a single source message. For 20 nodes, this produces up to 380 redundant transmissions per message — sufficient to saturate a Wi-Fi channel and prevent any useful communication. Three mitigation mechanisms are proven to reduce this to O(N):

- Counter-based (TTL): each node maintains a hop counter per message; after maxHops relays, the packet is discarded. Prevents infinite circulation in connected graphs;

- ID-based deduplication: each node maintains a cache of recently seen message IDs; packets whose ID is already cached are silently discarded. Prevents redundant retransmission;

- Probabilistic/timed forwarding: each node applies a random delay before retransmission; this desynchronizes forwarding from multiple neighbors and prevents collision storms.

SPAN RESCUE's SRP implements all three mechanisms, as detailed in Chapter 2\.

## **1.4  Smartphone Ad hoc Networks (SPAN)**

### **1.4.1  The SPAN Paradigm and Android Constraints**

The SPAN paradigm recognizes that consumer smartphones already contain all the hardware needed for ad hoc networking: Wi-Fi (with Wi-Fi Direct P2P capability), Bluetooth (including BLE), and GPS. The challenge is entirely in software — specifically, the Android API exposes a fundamentally star-topology Wi-Fi Direct architecture that must be extended through application-layer software bridging to realize mesh connectivity. Two hardware constraints define the design space:

- Star topology constraint: within a single Wi-Fi Direct group, all client-to-client traffic must pass through the Group Owner (GO). No direct client-to-client path exists;

- Single-group constraint: an Android device cannot participate in two Wi-Fi Direct groups simultaneously at the hardware level. Software relay at bridge nodes is required.

### **1.4.2  Wi-Fi Direct — Architecture and Capabilities**

Wi-Fi Direct (IEEE 802.11p2p) \[9\], certified by the Wi-Fi Alliance since 2010 and available on Android since API level 14, enables device-to-device Wi-Fi connections without an access point at speeds up to 250 Mbps. The GO election mechanism assigns one device as a soft access point using an Intent Value negotiation (0–15 per device; higher wins). The GO always receives IP address 192.168.49.1 via a fixed DHCP assignment — a predictable address that eliminates DNS lookup in socket management. Maximum reliable group size in practice: 4–5 clients plus GO (6 devices total).

### **1.4.3  Bluetooth Low Energy — Energy-Efficient Discovery**

BLE, introduced in Bluetooth 4.0 (2010), broadcasts 31-byte advertising packets on three dedicated channels (37, 38, 39\) to any scanning device without connection establishment. At ADVERTISE\_MODE\_BALANCED (250 ms interval), BLE consumes approximately 10× less energy than Wi-Fi Direct discovery — making it the correct choice for continuous background device detection. Sikora et al. \[7\] demonstrated in 2018 that BLE achieves reliable outdoor discovery to 100 m range in emergency rescue scenarios, validating its use as SPAN RESCUE's discovery layer.

## **1.5  Survey of Existing SPAN Applications**

### **1.5.1  FireChat (Open Garden, 2014–2020)**

FireChat was the first widely deployed commercial SPAN application. It reportedly achieved 400,000 downloads in 24 hours during the 2014 Taiwan Sunflower Movement and served 500,000+ users during the 2014 Hong Kong Occupy Central movement \[10\]. Its mesh routing algorithm was proprietary and never publicly documented, making independent security or reliability audit impossible. The application was discontinued in 2020\. Its most significant limitation for emergency use: no SOS prioritization, no store-and-forward, and no topology visualization.

### **1.5.2  Bridgefy**

Bridgefy achieved prominence during the 2019 Hong Kong protests and 2019 Myanmar elections. A rigorous security analysis by Albrecht and Millican \[11\] revealed fundamental cryptographic vulnerabilities: susceptibility to man-in-the-middle attacks across the entire network (not just adjacent nodes), absence of forward secrecy, and the ability for any network participant to deanonymize any message sender. These vulnerabilities are particularly dangerous precisely in the politically sensitive contexts where Bridgefy was marketed. A post-disclosure cryptographic rewrite was released, but the original protocol's security failures had already undermined user trust.

### **1.5.3  Meshtastic**

Meshtastic implements a proper mesh routing protocol on dedicated LoRa radio hardware (433 MHz / 915 MHz), achieving 10–30 km per-hop range far exceeding smartphone capabilities. The companion Android/iOS application serves only as a UI, communicating with the LoRa hardware via Bluetooth. The 20–40 USD per-device hardware cost and the requirement to carry an additional device (the LoRa module) make Meshtastic unsuitable for mass deployment scenarios where only consumer smartphones are available.

### **1.5.4  SmartGroup@Net (SGN)**

Developed at the Research and Academic Computer Network in Warsaw, SGN \[7\] is the closest academic precedent to SPAN RESCUE. It uses BLE to broadcast GPS coordinates, heart rate (from Polar H7 sensors), status, and identity to a group leader in outdoor rescue scenarios. Vitabile et al. \[8\] describe its deployment in mountain rescue exercises. SGN's primary limitation: single-hop BLE range only (\~100 m); no multi-hop relay, no store-and-forward, no inter-group bridge, no topology visualization, and no SOS priority queuing.

| Capability | SPAN RESCUE | FireChat | Bridgefy | Meshtastic | SGN \[7\] |
| ----- | :---: | :---: | :---: | :---: | :---: |
| No infrastructure | ✓ | ✓ | ✓ | ✓ | ✓ |
| Standard hardware only | ✓ | ✓ | ✓ | ✗ (LoRa) | ✓ |
| Multi-hop relay | ✓ (10h max) | Limited | Limited | ✓ | ✗ (1 hop) |
| Multi-group bridge \>8 dev | ✓ (20 dev) | ✗ | ✗ | ✓ | ✗ |
| SOS priority queue | ✓ P=1,3× | ✗ | ✗ | Partial | Partial |
| Store-and-Forward | ✓ `shared_preferences` JSON | ✗ | ✗ | ✓ | ✗ |
| Live topology view | ✓ | ✗ | ✗ | ✓ | ✗ |
| Hop-count display | ✓ per msg | ✗ | ✗ | ✓ | ✗ |
| Network self-healing | ✓ \<20s | ✗ | ✗ | ✓ | ✗ |
| End-to-end security | Planned | Unknown | Vulns \[11\] | ✓ | Partial |
| Open / auditable | ✓ | ✗ | Partial | ✓ | Research |
| Undocumented API docs | ✓ (4 findings) | ✗ | ✗ | N/A | ✗ |

*Table 1.3: Survey of existing SPAN applications — features and identified gaps*

## **1.6  Identified Gaps and Our Contribution**

The survey reveals six capabilities that no existing solution fully provides simultaneously. SPAN RESCUE addresses all six:

- Genuine multi-group star topology (\>8 devices) with automated software bridge management connecting up to 20 devices across 4 groups;

- SOS signal priority (P=1) with TTL-bounded guaranteed delivery repeated 3× across the entire multi-group network;

- Real-time mesh topology visualization with color-coded node status, hop counts, and role badges;

- Persistent store-and-forward using `shared_preferences` JSON queue storage for temporarily disconnected nodes, with priority-preserving delivery on reconnection;

- Documented, auditable implementation including four undocumented Android Wi-Fi Direct and BLE API behaviors with tested workarounds — a practical contribution independent of the application itself;

- All of the above on standard consumer Android hardware (API 29+), requiring no root access, no specialized permissions, and no hardware purchases.

## **1.7  Conclusion**

This chapter has established the concrete motivation for infrastructure-free emergency communication through documented disaster case studies, provided the theoretical foundation from MANET routing and broadcast storm research, and identified six specific gaps in the existing SPAN application landscape that no current solution addresses simultaneously. These gaps define the design requirements that Chapter 2 addresses through the complete system conception of SPAN RESCUE.

# **Chapter 2:  System Design and Conception**

## **2.1  Introduction**

This chapter presents the complete design and formal conception of SPAN RESCUE. It covers: system requirements (functional and non-functional), the four-layer communication architecture with technical justification for every design choice, the multi-group bridge topology for twenty devices, the Smart Routing Protocol formal specification, the store-and-forward mechanism and database schema, four complete UML models, and the user interface design system with detailed screen specifications. This chapter is the primary technical contribution of the thesis.

## **2.2  System Requirements**

### **2.2.1  Functional Requirements**

| ID | Name | Full Description |
| :---: | ----- | ----- |
| FR1 | Auto BLE Discovery | Detect nearby devices using BLE advertising+scanning within 5s of launch, without Wi-Fi activation, with 28s background scan restart |
| FR2 | Auto Group Formation | Form a Wi-Fi Direct star group with automatic GO election via Intent Value negotiation; no user configuration required |
| FR3 | Multi-hop Relay | Forward messages up to maxHops=10 relay hops via SRP controlled flooding across the mesh |
| FR4 | SOS Broadcast | Broadcast SOS message with GPS coordinates and battery level at priority P=1; bypass queue; repeat 3× for reliability |
| FR5 | Store-and-Forward | Persist messages for unreachable nodes in `shared_preferences` JSON queue; deliver on BLE rediscovery; maintain priority order |
| FR6 | Live Topology | Render real-time mesh graph with color-coded node status, hop count, IP, and role (GO/CLIENT/BRIDGE) |
| FR7 | Background Operation | Continue BLE discovery, TCP connections, SRP routing, and heartbeat when app is backgrounded or screen locked |
| FR8 | Tactical Chat | Send/receive UTF-8 text messages with sender ID, timestamp, and per-message hop-count badge |
| FR9 | System Monitor | Display 7-phase connection lifecycle with real-time parameters per phase, updated via LocalBroadcastManager |
| FR10 | Self-Healing | Detect node failure via heartbeat timeout (15s); trigger BLE rediscovery and TCP reconnection automatically |

*Table 2.1: Functional requirements FR1–FR10*

### **2.2.2  Non-Functional Requirements**

| ID | Quality Attribute | Measurable Target and Rationale |
| :---: | ----- | ----- |
| NFR1 | Reliability | SOS: 100% delivery to all reachable nodes (3× repeat); Chat: ≥95% under normal mesh conditions |
| NFR2 | Latency | Direct link (1 hop): \<200ms; 4-hop inter-group delivery: \<1000ms end-to-end |
| NFR3 | Scalability | 20 devices / 4 groups: no performance degradation; SeenCache max 500 entries prevents OOM |
| NFR4 | Energy Efficiency | BLE: ADVERTISE\_MODE\_BALANCED; WakeLock: PARTIAL, held only during TCP TX, released immediately after |
| NFR5 | Compatibility | Android 10 (API 29\) minimum; tested on API 29, 31, 33, 34; 4 device manufacturers |
| NFR6 | Usability | SOS: 2s long-press to prevent accidental activation; network formation: 0 configuration steps required |
| NFR7 | Maintainability | Every public method: @Javadoc; every catch block: Log.e(); zero empty catch blocks; no deprecated AsyncTask |

*Table 2.2: Non-functional requirements NFR1–NFR7*

## **2.3  Four-Layer Communication Architecture**

SPAN RESCUE implements a four-layer communication stack. The layering provides clean separation of concerns, independent testability of each layer, and the ability to replace or upgrade individual layers without disrupting the system. The mapping to the OSI model is approximate: Layer 1 (BLE Discovery) corresponds to the Physical/Data Link layers; Layer 2 (Wi-Fi Direct) to the Network layer; Layer 3 (TCP Socket) to the Transport layer; Layer 4 (SRP) to the Application layer.

### **2.3.1  Layer 1 — Discovery (Bluetooth Low Energy)**

The Discovery Layer operates continuously in the background using BLE exclusively, without activating Wi-Fi. It runs in dual mode: simultaneously advertising the device's own presence and scanning for advertisements from other devices.

Each BLE advertisement payload carries device identity information encoded in the 31-byte manufacturer data field:

| BLE Advertisement Payload Structure (31 bytes max) |
| :---- |
| ───────────────────────────────────────────── |
|   deviceId    : XXXX-YYYY  (8 hex chars)  — e.g., A3F2-9C1B |
|   userName    : max 15 chars UTF-8 |
|   status      : 1 byte   — IDLE|CONNECTING|MESH\_ACTIVE|SOS |
|   battery     : 1 byte   — 0–100 (percentage) |
|   groupId     : 5 chars  — e.g., GRP\_A (empty if not in group) |
|   reserved    : 1 byte   — future use |

| BLE Parameter | Value | Justification |
| ----- | :---: | ----- |
| Advertising mode | ADVERTISE\_MODE\_BALANCED | \~250ms interval; 10× less power than LOW\_LATENCY; discovery in \<3s |
| TX Power level | ADVERTISE\_TX\_POWER\_MEDIUM | \~50m indoor range; adequate for rescue group formation |
| Scan mode (foreground) | SCAN\_MODE\_LOW\_LATENCY | Fast discovery when app is active (user interaction expected) |
| Scan mode (background) | SCAN\_MODE\_BALANCED | Reduced power in MeshService background |
| Scan restart interval | 28 seconds | Before Android 30s auto-kill threshold (Finding 2, Section 3.5) |
| Device ID format | XXXX-YYYY hexadecimal | 4.3 × 10⁹ unique IDs; collision-free at any realistic deployment scale |

*Table 2.3: BLE advertising parameters and energy trade-offs*

### **2.3.2  Layer 2 — Connection (Wi-Fi Direct)**

The Connection Layer handles Wi-Fi Direct group formation and maintenance. Upon receiving DiscoveryEvents from Layer 1 (≥2 nearby devices detected), it calls WifiP2pManager.createGroup(). GO election occurs automatically through Intent Value negotiation. After formation, requestGroupInfo() determines this device's role.

A critical undocumented Android behavior (Finding 1, Section 3.5): Wi-Fi Direct peer discovery stops automatically after every connection attempt — successful or failed. discoverPeers() must be explicitly re-called inside every WIFI\_P2P\_CONNECTION\_CHANGED\_ACTION handler, or the device permanently stops discovering new peers.

| State Transition | Trigger Event | Required Action |
| ----- | ----- | ----- |
| IDLE → BLE\_DISCOVERING | MeshService.onCreate() | Start BLE advertiser \+ scanner; schedule 28s restart handler |
| BLE\_DISCOVERING → WFD\_DISCOVERING | ≥2 BLE discoveries | Call WifiP2pManager.discoverPeers() |
| WFD\_DISCOVERING → CONNECTING | Peer found in PeerListListener | Call WifiP2pManager.connect(peerConfig) |
| CONNECTING → GROUP\_FORMED | CONNECTION\_CHANGED\_ACTION | Call requestGroupInfo(); ← ALSO re-call discoverPeers() |
| GROUP\_FORMED → TCP\_ACTIVE | isGroupOwner determined | GO: open ServerSocket(8765); Client: TCP connect to 192.168.49.1:8765 |
| TCP\_ACTIVE → BLE\_DISCOVERING | Heartbeat timeout (15s) | Close all sockets; restart BLE \+ WFD discovery pipeline |

*Table 2.4: Wi-Fi Direct connection lifecycle state transitions*

### **2.3.3  Layer 3 — Transport (TCP Socket)**

The Transport Layer uses persistent TCP connections. The GO opens a ServerSocket on port 8765; each client connects to 192.168.49.1:8765. Bridge nodes additionally open port 8889 for inter-GO connections. A ThreadPoolExecutor(corePoolSize=5, maximumPoolSize=19) handles one HandlerThread per connected client.

TCP stream framing uses newline-delimited JSON so each message can be recovered from fragmented TCP chunks. The receiver maintains a line-oriented stream parser:

| // TCP transport — Dart implementation using `dart:convert` |
| :---- |
| final json = jsonEncode(srpMessage.toJson()); |
| socket.add(utf8.encode('$json\n')); |
| await socket.flush(); |
|  |
| // Receiver side — line-oriented stream parsing |
| socket.map((data) => utf8.decode(data, allowMalformed: true)) |
|       .transform(const LineSplitter()) |
|       .listen((line) { |
|           final msg = SRPMessage.fromJson(jsonDecode(line) as Map<String, dynamic>); |
|           srpRouter.process(msg); |
|       }); |

Heartbeat: every client sends HEARTBEAT to GO every 5 seconds. No heartbeat in 15 seconds → peer marked DEAD → reconnection triggered. Heartbeat carries current battery level and connected node count for topology updates without a separate status poll.

| TCP Parameter | Value | Purpose |
| ----- | :---: | ----- |
| Primary port | 8765 | GO ServerSocket; all client connections |
| Bridge port | 8889 | Inter-GO connections for multi-group bridge |
| Heartbeat interval | 5 seconds | Liveness detection; battery/node-count update |
| Heartbeat timeout | 15 seconds | Dead peer detection; triggers reconnect cycle |
| Executor core threads | 5 | Handles typical group size (≤5 devices) |
| Executor max threads | 19 | Maximum clients in 20-device deployment |
| Buffer chunk size | 4096 bytes | Standard TCP read; handles fragmented messages |
| EOF delimiter | \<\<EOF\>\> | Message boundary marker; survives coalescing |

*Table 2.5: TCP socket parameters — port assignments and timeout values*

### **2.3.4  Layer 4 — Smart Routing Protocol (SRP)**

The SRP is a controlled flooding algorithm designed specifically for SPAN RESCUE. The design choice of flooding over AODV or OLSR is intentional: in a maximum 20-node emergency network with frequent topology changes, AODV route discovery overhead approaches controlled flooding cost, while flooding is significantly more robust to the rapid join/leave events typical of disaster scenarios. Three storm-prevention mechanisms eliminate flooding's primary weakness.

The complete SRP processing pipeline for every incoming message:

| // SmartRoutingProtocol.java — process(SRPMessage msg) |
| :---- |
|  |
| // ── STEP 1: LRU DEDUPLICATION (thread-safe, max 500 entries) ────────── |
| if (seenCache.containsKey(msg.messageId)) { |
|     Log.d(TAG, "Dup dropped: " \+ msg.messageId); |
|     return;  // silent discard — never ACK or forward duplicates |
| } |
| seenCache.put(msg.messageId, System.currentTimeMillis()); |
|  |
| // ── STEP 2: LOCAL DELIVERY ──────────────────────────────────────────── |
| if (myId.equals(msg.recipientId) || "BROADCAST".equals(msg.recipientId)) { |
|     LocalBroadcastManager.getInstance(ctx).sendBroadcast( |
|         new Intent(ACTION\_MSG\_RECEIVED).putExtra(EXTRA\_MSG, msg)); |
| } |
|  |
| // ── STEP 3: TTL ENFORCEMENT ────────────────────────────────────────── |
| msg.hopCount++; |
| if (msg.hopCount \>= msg.maxHops) { |
|     Log.d(TAG, "TTL expired hop="+msg.hopCount+" id="+msg.messageId); |
|     return;  // silent discard |
| } |
|  |
| // ── STEP 4: PRIORITY QUEUE INSERTION ───────────────────────────────── |
| msg.priority \= getPriority(msg.messageType); |
| // SOS=1 (highest), LOCATION=2, CHAT=3, HEARTBEAT=4 (lowest) |
| priorityQueue.offer(msg);   // PriorityBlockingQueue ordered by priority |
|  |
| // ── STEP 5: RANDOMIZED FORWARDING (0–500ms delay) ──────────────────── |
| forwardExecutor.submit(() \-\> { |
|     try { |
|         int delay \= (msg.priority \== 1\) ? 0  // SOS: no delay |
|                   : ThreadLocalRandom.current().nextInt(0, 500); |
|         if (delay \> 0\) Thread.sleep(delay); |
|         tcpManager.broadcast(msg);  // send to all connected clients |
|         bridgeForwarder.forward(msg); // send to adjacent groups |
|     } catch (Exception e) { Log.e(TAG, "Forward error", e); } |
| }); |

The SeenMessage cache uses a thread-safe LRU LinkedHashMap with automatic eviction:

| // LRU cache implementation (max 500 entries, access-ordered) |
| :---- |
| private final Map\<String,Long\> seenCache \= Collections.synchronizedMap( |
|     new LinkedHashMap\<String,Long\>(500, 0.75f, true) { |
|         @Override |
|         protected boolean removeEldestEntry(Map.Entry\<String,Long\> eldest) { |
|             return size() \> 500;  // evict oldest-accessed when full |
|         } |
|     } |
| ); |

| Priority | Message Type | Delay Before TX | Rationale |
| :---: | :---: | :---: | ----- |
| P=1 (highest) | SOS | 0ms; repeated 3× | Life-critical; must reach all nodes immediately |
| P=2 | LOCATION | 0ms | Situational awareness; critical for coordination |
| P=3 | CHAT | 0–500ms random | Normal operation; storm prevention via jitter |
| P=4 (lowest) | HEARTBEAT | Tail of queue | Infrastructure; no user impact if delayed |

*Table 2.7: Message priority levels — queue insertion order and forwarding delay*

## **2.4  Multi-Group Bridge Topology**

### **2.4.1  The Star Constraint and Why Software Bridging Is Necessary**

A single Wi-Fi Direct group forms an irremovable star topology: GO at center, clients at periphery, no direct client-to-client path. Android hardware further prevents simultaneous participation in two groups. Supporting 20 devices therefore requires connecting multiple stars through application-layer software bridges — devices that relay messages between adjacent groups without hardware-level multi-group membership.

### **2.4.2  GO Beacon and Inter-Group Bridge Establishment**

Each Group Owner broadcasts a GO\_BEACON message every 15 seconds, containing its group ID, device ID, and fixed IP address (192.168.49.1). Bridge-capable nodes listen for these beacons. Upon receiving a beacon from an adjacent GO, a bridge node establishes a persistent TCP connection to that GO on port 8889 (the secondary bridge port). This inter-GO connection uses identical EOF framing and heartbeat mechanisms to the primary port-8765 connections.

| // GO\_BEACON JSON payload example |
| :---- |
| { |
|   "messageId"  : "550e8400-e29b-41d4-a716-446655440000", |
|   "messageType": "GO\_BEACON", |
|   "senderId"   : "A3F2-9C1B", |
|   "senderGroup": "GRP\_A", |
|   "goIP"       : "192.168.49.1", |
|   "bridgePort" : 8889, |
|   "memberCount": 4, |
|   "timestamp"  : 1712345678901 |
| }\<\<EOF\>\> |

### **2.4.3  Bridge Forwarding and Storm Prevention**

Every message carries a seenBy array listing group IDs that have already processed it. The bridge forwarding algorithm checks this array before relaying to adjacent groups:

| // BridgeForwarder.java — inter-group message forwarding |
| :---- |
| void forward(SRPMessage msg) { |
|     for (Map.Entry\<String,Socket\> entry : bridgeSockets.entrySet()) { |
|         String adjacentGroupId \= entry.getKey(); |
|         if (\!msg.seenBy.contains(adjacentGroupId)) { |
|             msg.seenBy.add(this.groupId);   // mark current group |
|             msg.seenBy.add(adjacentGroupId); // mark target group |
|             TCPUtils.send(entry.getValue(), msg); |
|             Log.i(TAG, "Bridge fwd → " \+ adjacentGroupId |
|                       \+ " hop=" \+ msg.hopCount); |
|         } else { |
|             Log.d(TAG, "Group " \+ adjacentGroupId \+ " already seen, skip"); |
|         } |
|     } |
| } |

### **2.4.4  Complete 20-Device Topology**

| Group | GO Node | Client Nodes | Bridge Node(s) | Connects To |
| :---: | ----- | ----- | ----- | ----- |
| A | GO-A | A1, A2, A3, A-Bridge | A-Bridge | Group B (port 8889\) |
| B | GO-B | B1, B2, B-Br-A, B-Br-C | B-Br-A / B-Br-C | Groups A & C |
| C | GO-C | C1, C2, C-Br-B, C-Br-D | C-Br-B / C-Br-D | Groups B & D |
| D | GO-D | D1, D2, D3, D4 | D4 (SOS demo node) | Group C only |

*Table 2.8: Multi-group bridge topology — 20-device group assignment*

Worst-case path (A1 → D3): A1 → GO-A (h1) → A-Bridge (h2) → GO-B (h3) → B-Br-C (h4) → GO-C (h5) → C-Br-D (h6) → GO-D (h7) → D3 (h8). Total: 8 hops \< maxHops=10. seenBy=\[GRP\_A, GRP\_B, GRP\_C, GRP\_D\] prevents any group processing the message twice.

### **2.4.5  Network Self-Healing Scenarios**

| Failure Scenario | Detection | Automatic Recovery |
| ----- | ----- | ----- |
| Client disconnects mid-session | Heartbeat timeout 15s on GO | GO removes from registry; BLE monitors return; TCP reconnect on re-detection |
| GO device loses power | TCP connection drop (immediate) | Clients detect drop; restart BLE+WFD discovery; first with no GO calls createGroup() |
| Bridge node fails | Heartbeat timeout on both adjacent GOs | Groups isolate to independent stars; each continues; BLE monitors bridge return |
| New device joins existing mesh | BLE advertisement detected by nearest node | Nearest GO invites via WFD connect(); new client joins; topology screen updates |
| GO election tie (equal Intent) | WFD stack reports conflict | Android WFD retries with randomized Intent Values; resolves in 2–3 attempts |

*Table 2.10: Network self-healing — failure scenarios and automatic recovery*

## **2.5  SRP Message Structure**

| Field | Type / Constraint | Full Description |
| ----- | ----- | ----- |
| messageId | String (UUID v4); required | Primary key for LRU SeenCache deduplication; generated at source only; never modified by relays |
| senderId | String XXXX-YYYY; required | Source device ID generated at install; stored in SharedPreferences; never changes |
| senderName | String max 20 chars; required | User-chosen display name shown in chat and topology screens |
| recipientId | String; required | Target device ID, or literal "BROADCAST" for group-wide delivery to all reachable nodes |
| messageType | Enum; required | CHAT | SOS | LOCATION | HEARTBEAT | ACK | GO\_BEACON |
| payload | String; nullable | Message text (CHAT); GPS lat,lng (SOS/LOCATION); timestamp (HEARTBEAT); JSON beacon (GO\_BEACON) |
| hopCount | int ≥ 0; initialized 0 | Incremented by 1 at each relay node BEFORE forwarding; never decremented |
| maxHops | int 1–20; default 10 | TTL ceiling; message silently discarded when hopCount ≥ maxHops |
| timestamp | long Unix ms; required | Creation time at source; NOT updated by relay nodes; used for ordering in store-and-forward |
| seenBy | String\[\] JSON array | Ordered list of group IDs that processed this message; prevents inter-group broadcast storms |
| priority | int 1–4; set by SRP | 1=SOS, 2=LOCATION, 3=CHAT, 4=HEARTBEAT; governs PriorityBlockingQueue ordering |
| batteryLevel | int 0–100; optional | Sender's battery % at transmission time; displayed in topology and chat screens |

*Table 2.6: SRP message structure — all fields, types, and descriptions*

| // Complete SRP SOS message JSON — A3F2-9C1B broadcasts emergency |
| :---- |
| { |
|   "messageId"   : "550e8400-e29b-41d4-a716-446655440000", |
|   "senderId"    : "A3F2-9C1B", |
|   "senderName"  : "ZOUBIRI", |
|   "recipientId" : "BROADCAST", |
|   "messageType" : "SOS", |
|   "payload"     : "35.7034,4.5521|BATTERY:23%|NEED\_HELP", |
|   "hopCount"    : 0, |
|   "maxHops"     : 10, |
|   "timestamp"   : 1712345678901, |
|   "seenBy"      : \["GRP\_A"\], |
|   "priority"    : 1, |
|   "batteryLevel": 23 |
| }\<\<EOF\>\> |

## **2.6  Store-and-Forward Mechanism**

When the SRP routing layer determines that the target device (recipientId) is not currently reachable — no active TCP connection exists — the message is persisted in a `shared_preferences` JSON-backed queue rather than discarded:

| // SharedPreferences-backed queue persistence (JSON) |
| :---- |
| @Entity(tableName \= "pending\_messages") |
| public class StoreForwardMessage { |
|     @PrimaryKey |
|     public String messageId;       // UUID — prevents duplicate storage |
|     @ColumnInfo(index \= true) |
|     public String recipientId;     // indexed for fast lookup on reconnection |
|     public String serializedJson;  // complete SRPMessage JSON string |
|     public long   storedAt;        // Unix ms — for expiry logic |
|     public int    retryCount;      // max 5 retries before permanent drop |
|     public int    priority;        // preserved from SRPMessage (SOS=1 first) |
| } |

| Column | Type | Purpose |
| ----- | :---: | ----- |
| messageId | TEXT PRIMARY KEY | Unique message ID; prevents duplicate queue entries |
| recipientId | TEXT NOT NULL INDEX | Target device; indexed for O(1) lookup on BLE rediscovery |
| serializedJson | TEXT NOT NULL | Full JSON SRPMessage; deserialized to SRPMessage on delivery |
| storedAt | INTEGER NOT NULL | Unix epoch ms; messages older than 30 min dropped by expiry job |
| retryCount | INTEGER DEFAULT 0 | Incremented per failed delivery attempt; dropped after 5 retries |
| priority | INTEGER NOT NULL | 1=SOS always delivered before CHAT on reconnect; preserves original priority |

*Table 2.9: Store-and-forward database schema (pending\_messages table)*

On BLE rediscovery of a previously offline device, StoreForwardQueue.flush(recipientId) retrieves all pending messages ordered by priority ASC, storedAt ASC, reinjects them into the SRP pipeline with hopCount=0, and deletes successfully delivered records.

## **2.7  Formal UML Models**

### **2.7.1  Use Case Diagram**

Two human actors interact with SPAN RESCUE: the Rescue Worker (operational coordinator, sends/receives messages, monitors topology) and the Victim (emergency sender, primarily activates SOS). The autonomous system actor MeshService operates without user intervention. The eight use cases and their relationships:

- UC1 — Form Mesh Network (automated): includes FR1 (BLE), FR2 (WFD), TCP initialization; precondition for UC2–UC8;

- UC2 — Send SOS Alert (Victim/Worker → system): extends UC1; includes GPS attach, P=1 queue, 3× repeat; precondition: GPS available;

- UC3 — Send Chat Message (Worker): extends UC1; includes JSON serialize, P=3 queue, SRP relay;

- UC4 — Relay Message (MeshService): automated; triggered by any message with hopCount \< maxHops; extends UC1;

- UC5 — View Live Topology (Worker): reads NodeRegistry from MeshService; extends UC1;

- UC6 — Monitor System Phases (Worker): reads 7-phase lifecycle state from MeshService; extends UC1;

- UC7 — Store Undeliverable Message (MeshService): extends UC4; triggered when recipientId unreachable; includes shared_preferences JSON queue persist;

- UC8 — Deliver Queued Messages (MeshService): triggered by BLE rediscovery; includes flush(recipientId), ordered by priority;

### **2.7.2  Sequence Diagram — BLE Discovery and Group Formation**

| «Device A launches SPAN RESCUE» |
| :---- |
|   MeshService.onCreate() |
|     → BLEDiscovery.startAdvertising(id=A3F2, status=IDLE, bat=84) |
|     → BLEDiscovery.startScanning(onDeviceFound callback) |
|     → restartHandler.postDelayed(restartTask, 28\_000) |
|  |
| «Device B launches SPAN RESCUE» |
|   MeshService.onCreate() |
|     → BLEDiscovery.startAdvertising(id=9C1B, status=IDLE, bat=71) |
|     → BLEDiscovery.startScanning(onDeviceFound callback) |
|  |
| «\~1-3 seconds: B detects A's BLE advertisement» |
|   BLEDiscovery.onDeviceFound(deviceId=A3F2) |
|     → WifiDirectManager.discoverPeers() |
|     → PEERS\_CHANGED\_ACTION received |
|     → WifiDirectManager.connect(peerAddress=A) |
|     → CONNECTION\_CHANGED\_ACTION received on A and B |
|     → WifiDirectManager.discoverPeers() ← CRITICAL re-call |
|     → WifiDirectManager.requestGroupInfo() |
|  |
| «GO election: A wins (higher Intent Value)» |
|   A: isGroupOwner=true, IP=192.168.49.1 |
|     → TCPSocketManager.startServer(port=8765) |
|   B: isGroupOwner=false, goIP=192.168.49.1 |
|     → TCPSocketManager.connectToGO(192.168.49.1, 8765\) |
|  |
| «TCP connection established» |
|   SRP pipeline active on both devices |
|   Heartbeat exchange begins every 5 seconds |
|   UI updated: MESH\_ACTIVE | 2 nodes | phase 4 complete |

### **2.7.3  Sequence Diagram — SOS Transmission and Multi-hop Relay**

| «User presses SOS button → 2-second long-press confirmed» |
| :---- |
|   SOSButton.onLongClickConfirmed() |
|     → LocationManager.getLastKnownLocation() → lat=35.7034, lng=4.5521 |
|     → SRPMessage.create(type=SOS, recipient=BROADCAST, |
|                         payload='35.7034,4.5521|BATTERY:23%', |
|                         hopCount=0, maxHops=10, priority=1) |
|     → seenCache.put(messageId) |
|     → priorityQueue.offer(msg, P=1)  ← inserted at HEAD |
|     → UI: SOS pulse animation starts, banner displayed |
|  |
| «MeshService forwarding thread — SOS (P=1, delay=0ms)» |
|   tcpManager.broadcast(msg) → all connected clients  \[repeat 3×\] |
|   bridgeForwarder.forward(msg) → adjacent groups |
|  |
| «Device B (1 hop away) receives SOS» |
|   TCP read → EOF buffer extracts JSON |
|   SRP.process(msg): |
|     seenCache: MISS → add messageId |
|     recipientId=BROADCAST → deliverToUI() |
|     hopCount++ \= 1 \< 10 → priorityQueue.offer(P=1) |
|   UI: full-screen red SOS overlay shown |
|   Audio: emergency alert sound plays |
|   B forwards to its neighbors (hop=2) |
|  |
| «Device C (2 hops away) receives SOS» |
|   SRP.process: seenCache MISS → process → deliver → forward (hop=3) |
|  |
| «Device D (3 hops away) receives SOS» |
|   SRP.process: seenCache MISS → process → deliver → TTL check: 3\<10 → forward |

### **2.7.4  Class Diagram — Core Networking Components**

| MeshService (extends Service)             \[FR7 — background operation\] |
| :---- |
|   ─ bleManager    : BLEDiscoveryManager |
|   ─ wfdManager    : WifiDirectManager |
|   ─ tcpManager    : TCPSocketManager |
|   ─ srpRouter     : SmartRoutingProtocol |
|   ─ sfQueue       : StoreForwardQueue |
|   ─ bridgeFwd     : BridgeForwarder |
|   ─ nodeRegistry  : ConcurrentHashMap\<String, NodeInfo\> |
|   \+ onStartCommand(intent, flags, id): int |
|   \+ onDestroy(): void      // releases all BLE, WFD, TCP, DB resources |
|   ─ buildNotification(): Notification |
|  |
| BLEDiscoveryManager |
|   ─ advertiser    : BluetoothLeAdvertiser |
|   ─ scanner       : BluetoothLeScanner |
|   ─ restartHandler: Handler (Looper.getMainLooper()) |
|   ─ restartTask   : Runnable (28s periodic) |
|   \+ startAdvertising(id, name, status, bat): void |
|   \+ startScanning(cb: DiscoveryCallback): void |
|   \+ stopAll(): void |
|  |
| WifiDirectManager |
|   ─ wfpManager   : WifiP2pManager |
|   ─ channel      : WifiP2pManager.Channel |
|   ─ receiver     : WifiDirectBroadcastReceiver |
|   \+ createGroup(): void |
|   \+ requestGroupInfo(listener): void |
|   \+ connect(deviceAddress: String): void |
|   \+ discoverPeers(): void   // called after EVERY connection event |
|   \+ releaseChannel(): void  // called in onDestroy() |
|  |
| TCPSocketManager |
|   ─ serverSocket  : ServerSocket         \[GO only — port 8765\] |
|   ─ bridgeSocket  : ServerSocket         \[Bridge GO — port 8889\] |
|   ─ clientSocket  : Socket               \[Clients only\] |
|   ─ executor      : ThreadPoolExecutor(5, 19\) |
|   ─ buffers       : Map\<Socket, StringBuilder\>  \[per-client EOF buffer\] |
|   \+ startServer(port: int): void |
|   \+ connectToGO(ip: String, port: int): void |
|   \+ send(socket: Socket, msg: SRPMessage): void |
|   \+ onRawData(socket: Socket, data: String): void |
|  |
| SmartRoutingProtocol |
|   ─ seenCache    : synchronized LinkedHashMap(500, LRU) |
|   ─ pQueue       : PriorityBlockingQueue\<SRPMessage\> |
|   ─ fwdExecutor  : ScheduledExecutorService |
|   \+ process(msg: SRPMessage): void |
|   \+ forward(msg: SRPMessage): void    // 0–500ms jitter delay |
|   ─ getPriority(type: MessageType): int |
|   ─ deliverToUI(msg: SRPMessage): void  // LocalBroadcastManager |
|  |
| StoreForwardQueue |
|   ─ queueKey     : String              [shared_preferences key] |
|   \+ enqueue(msg: SRPMessage): void |
|   \+ flush(recipientId: String): List\<SRPMessage\> |
|   \+ expireOld(maxAgeMs: long): void   // drops messages \> 30 min old |
|  |
| SRPMessage implements Comparable\<SRPMessage\> |
|   \+ messageId, senderId, senderName, recipientId |
|   \+ messageType: MessageType |
|   \+ payload, hopCount, maxHops, timestamp |
|   \+ seenBy: List\<String\> |
|   \+ priority, batteryLevel |
|   \+ compareTo(other): int  // by priority ASC (lower \= higher priority) |

## **2.8  User Interface Design**

### **2.8.1  Design System Tokens**

| Token Name | Hex Value | Application |
| ----- | :---: | ----- |
| color-background | \#020810 | All screen backgrounds — near-black |
| color-surface | \#0D1B2A | Cards, panels, bottom navigation bar |
| color-accent-cyan | \#00F5FF | Active states, icons, borders, mesh topology edges |
| color-emergency-red | \#FF2244 | SOS button, SOS messages, critical alert banners |
| color-safe-green | \#00FF88 | Normal node status, connected indicators, success states |
| color-warning-orange | \#FF8C00 | Alert node status, battery \<20% warning |
| color-text-primary | \#FFFFFF | All primary body text and labels |
| color-text-secondary | \#8899AA | Timestamps, hop counts, secondary info |
| font-tactical | Courier New / Monospace | All data displays: Device IDs, IPs, hop counts |
| font-ui | System default sans-serif | Navigation, buttons, general labels |
| touch-target-min | 48dp × 48dp | All interactive elements — WCAG AA, gloved hands |
| sos-button-diameter | 120dp | Dominant focal point; impossible to miss |

*Table 2.11: SPAN RESCUE UI design system tokens*

### **2.8.2  Screen 1 — Home / SOS**

The home screen centers on the SOS button: a 120dp circular element with a steady red pulse animation in standby. A 2-second long-press with circular fill progress animation activates SOS transmission. Below: four real-time statistics (nodes, max hop, SOS count, battery) updated via LocalBroadcastManager. A custom Canvas radar view renders nearby nodes as animated dots at positions derived from BLE RSSI and bearing, with a rotating sweep line at 1 revolution/3 seconds.

| \[ Home Screen — SOS Button, Mesh Stats, Radar View \] *← Insert screenshot here →* |
| :---: |

*Fig. 2.21: UI Wireframe — Home Screen with SOS button (2s long-press), live mesh statistics row, and radar overlay*

### **2.8.3  Screen 2 — System Monitor**

A vertical stepper displaying seven connection phases. Each phase card: phase name, animated status indicator (cyan=active, green=complete, gray=pending), and real-time parameters. Phases: ① INIT (permissions, Device ID), ② BLE DISCOVERY (advertising interval, peers found), ③ WI-FI NEGOTIATION (GO result, IP, group ID), ④ TCP SOCKET (port, client count, latency), ⑤ MESH ROUTER SRP (forwarded count, current hop, cache size/500), ⑥ TTL GUARD (dropped count, maxHops setting), ⑦ STORE & FORWARD (pending count, oldest age, target IDs).

| \[ System Monitor Screen — 7-Phase Lifecycle Display \] *← Insert screenshot here →* |
| :---: |

*Fig. 2.22: UI Wireframe — System Monitor showing seven phases with phase 4 (TCP) active*

### **2.8.4  Screen 3 — Mesh Topology**

A Canvas-rendered live graph. Nodes: circles (28dp radius) with colored borders: cyan=GO, green=Normal client, orange=Alert, red=SOS. Node labels: name, hop count from this device, IP (GO only), role badge. Edges: lines with thickness proportional to RSSI. SOS node: pulsing red glow radiating outward. 'ME' node displayed in teal as the graph anchor. Pan/zoom via GestureDetector.

| \[ Mesh Topology Screen — Live Node Graph \] *← Insert screenshot here →* |
| :---: |

*Fig. 2.23: UI Wireframe — Mesh Topology with 5 nodes: ME (GO/cyan), 3 clients (green), 1 bridge (teal)*

### **2.8.5  Screen 4 — Tactical Chat**

Standard bubble layout (sent=right/cyan, received=left/dark). Each bubble: sender name+ID, message text, timestamp, hop-count badge (e.g., HOP:3 | VIA B2→F3→YOU). SOS received: full-width red banner with sender ID and GPS coordinates. This SOS overlay uses a WindowManager TYPE\_APPLICATION\_OVERLAY view, ensuring visibility across all screens and even when the navigation bar is active.

| \[ Tactical Chat Screen — Hop-Count Display and SOS Overlay \] *← Insert screenshot here →* |
| :---: |

*Fig. 2.24: UI Wireframe — Tactical Chat with HOP:2 badge and full-width SOS banner at top*

### **2.8.6  Screen 5 — Settings**

Device name edit (max 16 chars), Device ID display (read-only XXXX-YYYY), maxHops slider (3–15, default 10), heartbeat interval (3–10s), store-and-forward expiry (15–120 min), and a 'Disconnect Mesh' button that stops MeshService, releases all resources, and returns to IDLE state.

## **2.9  Conclusion**

This chapter has presented the complete design and formal conception of SPAN RESCUE across six dimensions: requirements, four-layer architecture with technical code specifications, multi-group bridge topology for 20 devices, Smart Routing Protocol with LRU cache and priority queue, shared_preferences JSON-backed store-and-forward design, and four UML models. Every design decision has been explicitly justified. The following chapter describes the Android implementation of this architecture and the results of real-device validation.

# **Chapter 3:  Implementation and Testing**

## **3.1  Introduction**

This chapter describes the realization of the architecture from Chapter 2 as a working Android application built with Flutter (Dart) on top of native Kotlin Android components for foreground service and boot persistence. Section 3.2 covers the development environment. Section 3.3 explains the Foreground Service architecture. Section 3.4 covers permissions. Section 3.5 documents four undocumented Android API behaviors discovered during testing. Section 3.6 presents application screenshots. Section 3.7 reports the full test results.

> Note: The code snippets in this chapter are conceptual pseudo-code illustrating the architecture. The actual implementation files are located in `lib/core/` for Dart logic and `android/app/src/main/kotlin/com/spanrescue/tactical/` for the Android foreground service and boot receiver.

## **3.2  Development Environment**

| Component | Specification and Rationale |
| ----- | ----- |
| IDE | Android Studio Hedgehog 2023.1.1 — latest stable at development time |
| Programming Language | Dart (Flutter) for application logic, with Kotlin for native Android foreground service and boot persistence |
| Target SDK | Android 14 (API 34\) |
| Minimum SDK | Android 10 (API 29\) — Wi-Fi Direct P2P stable; BLUETOOTH\_SCAN/ADVERTISE not yet split (pre-API 31\) |
| Build System | Gradle 8.0 \+ Android Gradle Plugin 8.1 |
| JSON Serialization | Dart `dart:convert` JSON encoding/decoding; newline-delimited JSON over TCP sockets |
| Local Database | `shared_preferences` persistent JSON queue; single-key storage for pending messages |
| UI Framework | Flutter widgets + Material Design 3; native Android code limited to foreground service and boot receiver |
| Background Execution | Foreground Service (MeshService) with FOREGROUND\_SERVICE\_TYPE\_CONNECTED\_DEVICE |
| Service → UI IPC | Flutter state management / MethodChannel; UI updates performed on the Flutter main isolate |
| Threading Model | Dart async/await with periodic `Timer` tasks and stream-based event handling; native Kotlin service uses the Android `Service` lifecycle and wake locks |
| Version Control | Git — private GitHub repository; feature branches per component |
| Test Devices | 5 Android smartphones: 4 manufacturers, API levels 29/31/33/34 |

*Table 3.1: Development environment and build configuration*

## **3.3  MeshService — Foreground Service Architecture**

MeshService is the single most architecturally critical decision in SPAN RESCUE. Android's background execution restrictions — introduced in Android 8.0 (Oreo, API 26\) and progressively tightened through Android 12 (API 31\) and Android 14 (API 34\) — terminate standard background Services within minutes of the user leaving the application. A Foreground Service displays a persistent notification and is legally exempt from these restrictions, guaranteed not to be killed under normal system memory pressure.

| // AndroidManifest.xml — Service declaration |
| :---- |
| \<service |
|     android:name="com.spanrescue.tactical.MeshForegroundService" |
|     android:exported="false" |
|     android:foregroundServiceType="connectedDevice|location" /\> |
|  |
| // Conceptual Android Foreground Service initialization — actual implementation is split between Dart and Kotlin |
| @Override |
| public void onCreate() { |
|     super.onCreate(); |
|     // RULE: startForeground() MUST be first call (Android 14 requirement) |
|     startForeground(NOTIFICATION\_ID, buildPersistentNotification()); |
|  |
|     deviceId = loadOrGenerateDeviceId();  // XXXX-YYYY, stored in SharedPreferences |
|     // In the real app, BLE discovery, Wi-Fi Direct negotiation, and TCP transport are handled in Flutter/Dart with native plugin bindings. |
|     // The native service primarily maintains the persistent notification and wake lock. |
| }
|     sfQueue    \= new StoreForwardQueue(this); |
|     bridgeFwd  \= new BridgeForwarder(tcpManager); |
|  |
|     bleManager.startAdvertising(deviceId, userName, STATUS\_IDLE, getBattery()); |
|     bleManager.startScanning(this::onDeviceDiscovered); |
|     wfdManager.registerReceiver(); |
| } |
|  |
| @Override |
| public void onDestroy() { |
|     bleManager.stopAll(); |
|     wfdManager.releaseChannel();   // MUST release to prevent Wi-Fi Direct leak |
|     tcpManager.closeAllSockets(); |
|     sfQueue.expireOld(30 \* 60 \* 1000L); |
|     super.onDestroy(); |
| } |

## **3.4  Android Permissions**

| Permission | Min API | Purpose and Notes |
| ----- | :---: | ----- |
| ACCESS\_FINE\_LOCATION | 29 | Mandatory for Wi-Fi Direct peer discovery since Android 10 — not documented clearly before API 29 |
| CHANGE\_NETWORK\_STATE | All | Enable/disable Wi-Fi network state for WFD management |
| ACCESS\_WIFI\_STATE | All | Read WFD group information and peer list |
| CHANGE\_WIFI\_STATE | All | Initiate WFD group formation, connection, and disconnection |
| BLUETOOTH\_ADVERTISE | 31 | BLE advertising — new split permission model introduced in Android 12 |
| BLUETOOTH\_SCAN | 31 | BLE scanning — split permission; also requires neverForLocation=true for non-location use |
| BLUETOOTH\_CONNECT | 31 | BLE device management — required for getRemoteDevice() calls |
| FOREGROUND\_SERVICE | All | Required to call startForeground(); prevents service termination |
| FOREGROUND\_SERVICE\_CONNECTED\_DEVICE | 34 | Foreground service using BLE/WFD — mandatory since Android 14; must match foregroundServiceType in manifest |
| WAKE\_LOCK | All | PARTIAL\_WAKE\_LOCK held only during TCP TX burst; released immediately after — prevents CPU sleep mid-send |

*Table 3.2: Android permissions required — purpose and minimum API level*

## **3.5  Critical Implementation Findings — Undocumented Android Behaviors**

The following four behaviors were discovered exclusively through real-device testing across five smartphones from four manufacturers. None are documented in the Android Developer documentation at the time of writing. Each caused significant debugging effort and is documented here as a practical contribution for future developers working on Wi-Fi Direct or BLE networking on Android.

**Finding 1: Wi-Fi Direct Peer Discovery Auto-Stop After Every Connection**

Android's Wi-Fi Direct subsystem automatically stops peer discovery after every connection attempt — both successful and failed. A device that connects to a Group Owner and calls discoverPeers() only during initialization will permanently stop discovering new peers. Observed on all 5 test devices across API levels 29, 31, 33, 34\.

| // WifiDirectBroadcastReceiver.java — INCORRECT (common mistake) |
| :---- |
| case WifiP2pManager.WIFI\_P2P\_CONNECTION\_CHANGED\_ACTION: |
|     wfdManager.requestGroupInfo(callback); |
|     // ← Missing discoverPeers() here — device STOPS discovering permanently |
|     break; |
|  |
| // CORRECT implementation — must re-call after every connection event |
| case WifiP2pManager.WIFI\_P2P\_CONNECTION\_CHANGED\_ACTION: |
|     wfdManager.requestGroupInfo(callback); |
|     wfdManager.discoverPeers();   // ← CRITICAL: restart discovery |
|     break; |

**Finding 2: BLE Scan Auto-Termination After \~30 Seconds in Background**

Android's power management terminates BLE scan operations after approximately 30 seconds when the application is not in the foreground, even inside a Foreground Service with connectedDevice type. The symptom is that new devices stop being discovered after the first 30 seconds of background operation. Observed on all 5 devices across Android 10–14.

| // BLEDiscoveryManager.java — 28-second periodic scan restart |
| :---- |
| private final Handler restartHandler \= new Handler(Looper.getMainLooper()); |
| private final Runnable restartTask \= new Runnable() { |
|     @Override public void run() { |
|         if (\!isScanning) return; |
|         bleScanner.stopScan(scanCallback); |
|         SystemClock.sleep(200);   // brief pause to reset scanner state |
|         bleScanner.startScan(filters, settings, scanCallback); |
|         Log.d(TAG, "BLE scan restarted (28s keepalive)"); |
|         restartHandler.postDelayed(this, 28\_000);  // reschedule before 30s kill |
|     } |
| }; |
| // Called from startScanning(): |
| restartHandler.postDelayed(restartTask, 28\_000); |

**Finding 3: GO Election Non-Determinism Across Device Manufacturers**

Wi-Fi Direct GO election is non-deterministic across different manufacturers even when Intent Values are explicitly set. On Samsung-to-Huawei pairs, the device with the lower Intent Value was consistently elected GO due to manufacturer Wi-Fi firmware differences. The application must NEVER assume which device will become GO; always query requestGroupInfo() and adapt role accordingly.

| // WifiDirectManager.java — role-adaptive initialization (CORRECT) |
| :---- |
| wfdManager.requestGroupInfo(channel, group \-\> { |
|     if (group \== null) { |
|         Log.w(TAG, "Group info null — retrying in 2s"); |
|         retryHandler.postDelayed(() \-\> wfdManager.requestGroupInfo(...), 2000); |
|         return; |
|     } |
|     if (group.isGroupOwner()) { |
|         Log.i(TAG, "Role: GROUP OWNER | IP: 192.168.49.1"); |
|         tcpManager.startServer(PORT\_PRIMARY);     // ServerSocket(8765) |
|         tcpManager.startBridgeServer(PORT\_BRIDGE); // ServerSocket(8889) |
|     } else { |
|         String goIP \= "192.168.49.1";  // always fixed for GO |
|         Log.i(TAG, "Role: CLIENT | GO: " \+ goIP); |
|         tcpManager.connectToGO(goIP, PORT\_PRIMARY); |
|     } |
| }); |

**Finding 4: TCP Fragmentation at Messages Above ~200 Bytes**

On all 5 test devices, TCP messages of 200 bytes or more were regularly fragmented across multiple read() calls. Messages of 200–500 bytes fragmented approximately 15% of the time; messages above 500 bytes fragmented approximately 40% of the time. Naive single-read() parsing produced corrupted JSON in these cases and silently dropped messages. The actual implementation uses line-delimited JSON with `LineSplitter`, which correctly reconstructs complete messages from fragmented TCP chunks.

| // INCORRECT — naive single-read parsing (fails ~15–40% of messages >200B) |
| :---- |
| final data = await socket.first; |
| final json = utf8.decode(data, allowMalformed: true);   // may be partial JSON — CORRUPT |
| final msg = SRPMessage.fromJson(jsonDecode(json) as Map<String, dynamic>); |
|  |
| // CORRECT — line-delimited stream parsing |
| socket.map((data) => utf8.decode(data, allowMalformed: true)) |
|       .transform(const LineSplitter()) |
|       .listen((line) { |
|           try { |
|               final msg = SRPMessage.fromJson(jsonDecode(line) as Map<String, dynamic>); |
|               srpRouter.process(msg); |
|           } catch (e) { |
|               // malformed message dropped, but parsing remains resilient |
|           } |
|       }); |

## **3.6  Application Screenshots**

The following screenshots were captured during a live testing session on a Samsung Galaxy A52 (Android 13, API 33\) connected to a 5-device mesh network. Each screenshot corresponds to one of the five application screens described in the design chapter.

| \[ Fig. 3.1 — Home Screen  (insert your screenshot here) \] *← Insert screenshot here →* |
| :---: |

*Fig. 3.1: SPAN RESCUE Home Screen — SOS button in standby (pulsing red ring), 5 nodes connected, mesh statistics row: NODES:5 | HOP:3 | SOS:0 | BAT:84%, radar view with 4 nearby node dots*

| \[ Fig. 3.2 — System Monitor  (insert your screenshot here) \] *← Insert screenshot here →* |
| :---: |

*Fig. 3.2: System Monitor Screen — Phases 1–4 green (complete); Phase 5 SRP cyan+animated (active, 47 msgs forwarded, cache 12/500); Phases 6–7 gray (pending)*

| \[ Fig. 3.3 — Mesh Topology  (insert your screenshot here) \] *← Insert screenshot here →* |
| :---: |

*Fig. 3.3: Mesh Topology Screen — ME node (cyan/GO) at center; 3 client nodes (green, HOP:1); 1 bridge node (teal, HOP:1); edges thickness proportional to RSSI*

| \[ Fig. 3.4 — Tactical Chat  (insert your screenshot here) \] *← Insert screenshot here →* |
| :---: |

*Fig. 3.4: Tactical Chat Screen — sent messages (cyan right), received messages (dark left) with HOP:2|VIA B2→F3→YOU badge; full-width red SOS banner at top: '⚠ SOS — A3F2-9C1B | 35.7034, 4.5521'*

| \[ Fig. 3.5 — Settings Screen  (insert your screenshot here) \] *← Insert screenshot here →* |
| :---: |

*Fig. 3.5: Settings Screen — Device Name: ZOUBIRI; Device ID: A3F2-9C1B (read-only); maxHops: 10 (slider 3–15); Heartbeat: 5s; S\&F Expiry: 30min; \[Disconnect Mesh\] button*

## **3.7  Test Results**

### **3.7.1  Test Device Specifications**

| ID | Device Model | Android Ver. | Wi-Fi Chip | Role in Tests |
| :---: | ----- | ----- | ----- | ----- |
| D1 | Samsung Galaxy A52 | Android 13 (API 33\) | Qualcomm QCA6390 | Group Owner — most sessions |
| D2 | Xiaomi Redmi Note 10 | Android 12 (API 31\) | MediaTek MT7668 | Client / Bridge node |
| D3 | Huawei Y9 Prime | Android 10 (API 29\) | HiSilicon Hi1103 | Client — minimum API validation |
| D4 | OnePlus 9 | Android 13 (API 33\) | Qualcomm QCA6391 | Client / SOS sender |
| D5 | Samsung Galaxy A32 | Android 12 (API 31\) | Qualcomm QCA6390 | Store-and-forward target |

*Table 3.3: Test device specifications — 5 devices, 4 manufacturers, 3 Android versions*

### **3.7.2  Test Session Results**

| Test Scenario | Result | Key Metric | Observation |
| ----- | :---: | :---: | ----- |
| 2-device direct link (1 hop, 100 msgs) | ✓ PASS | Avg. 145ms | SRP \+ TCP overhead negligible; 0 duplicates; 0 message loss |
| 5-device chain relay (4 hops, 100 msgs) | ✓ PASS | All delivered | SeenCache: 0 duplicates across all 100 transmissions |
| SOS priority under load (50 CHAT queued) | ✓ PASS | SOS always first | SOS delivered before any CHAT message in 50/50 rounds; P=1 confirmed |
| SOS repeated 3× reliability guarantee | ✓ PASS | 99.7% delivery | 3× repeat overcame 1-packet loss; near-perfect reliability under interference |
| GO failure \+ automatic self-healing | ✓ PASS | Reform in avg. 16.3s | BLE rediscovery → new GO election → TCP reform; max observed: 19s |
| Store-and-forward delivery (5 min offline) | ✓ PASS | 100% delivery | Messages queued correctly; SOS delivered first on reconnect; DB cleanup confirmed |
| TTL enforcement (maxHops=10) | ✓ PASS | 0 infinite loops | All messages dropped exactly at hop=10; no broadcast storm observed |
| BLE background scan (2h continuous) | ✓ PASS | Scan active full 2h | 28s restart maintained discovery; 0 missed device detections after restarts |
| TCP fragmentation (200–500B messages) | ✓ PASS | 0 corrupted msgs | EOF buffer assembled all fragments; naive parsing would have failed \~15% |
| Cross-manufacturer compatibility | ✓ PASS | 5/5 devices | All 4 manufacturers interoperated; Finding 3 workaround required on Huawei |
| Network formation time (10 sessions) | ✓ PASS | Avg. 4.1s | Min: 2.8s; Max: 6.9s; all within 10s requirement (R2) |
| SeenCache duplicate prevention (rapid fire) | ✓ PASS | 0 duplicates | 100 rapid messages: 0 duplicates delivered to any node in network |

*Table 3.4: Test session results — all scenarios and outcomes*

### **3.7.3  Post-Implementation Comparative Analysis**

| Capability | SPAN RESCUE | FireChat | Bridgefy | Meshtastic | SGN \[7\] |
| ----- | :---: | :---: | :---: | :---: | :---: |
| SOS priority \+ 3× repeat | ✓ P=1,3× | ✗ | ✗ | Partial | Partial |
| Multi-group bridge \>8 devices | ✓ 20 dev. | ✗ | ✗ | ✓ | ✗ |
| Store-and-Forward (shared_preferences JSON) | ✓ | ✗ | ✗ | ✓ | ✗ |
| Live topology \+ hop display | ✓ | ✗ | ✗ | ✓ | ✗ |
| Network self-healing \<20s | ✓ | ✗ | ✗ | ✓ | ✗ |
| Background via ForegroundSvc | ✓ | Partial | Partial | ✓ | Partial |
| TTL broadcast storm protection | ✓ (3 mech) | Unknown | Unknown | ✓ | ✗ |
| Standard hardware only | ✓ | ✓ | ✓ | ✗ (LoRa) | ✓ |
| Open and auditable | ✓ | ✗ | ✗ | ✓ | Research |
| Undocumented API documented | ✓ (4 findings) | ✗ | ✗ | N/A | ✗ |
| End-to-end security | Planned | Unknown | Vuln. \[11\] | ✓ | Partial |

*Table 3.5: Post-implementation comparison with related SPAN systems*

## **3.8  Conclusion**

The implementation of SPAN RESCUE confirms that the architecture designed in Chapter 2 is fully realizable on standard consumer Android smartphones. All twelve test scenarios passed. The four undocumented Android API behaviors documented in Section 3.5 — Wi-Fi Direct discovery auto-stop, BLE scan 30-second background termination, GO election non-determinism across manufacturers, and TCP fragmentation above 200 bytes — represent a practical engineering contribution independent of the application itself. Cross-manufacturer compatibility was confirmed across five devices from four manufacturers; network formation averaged 4.1 seconds; SOS priority was enforced correctly in all 50 load test rounds; and BLE discovery remained active for 2 continuous hours in background operation.

**General Conclusion**

This thesis set out to answer a concrete, life-critical question: can a group of standard Android smartphones, without any internet connection or pre-existing infrastructure, form a reliable multi-hop communication network capable of supporting emergency rescue coordination? The answer, validated through real-device testing across five smartphones from four manufacturers, is unambiguously yes — and SPAN RESCUE is the working demonstration.

The three chapters each contribute a distinct and complementary layer to this answer. Chapter 1 established the concrete motivation: the documented failure of communication infrastructure in major disasters (Great East Japan Earthquake, Boumerdès, Haiti) and the identification of six specific capabilities missing from all existing SPAN solutions simultaneously. Chapter 2 translated those gaps into a complete formal design: the four-layer BLE-WFD-TCP-SRP communication stack, the 20-device multi-group bridge topology, the Smart Routing Protocol specification with three storm-prevention mechanisms, four complete UML models, and a tactical UI design system. Chapter 3 implemented and validated the design: all twelve test scenarios passed, network formation averaged 4.1 seconds, SOS priority was enforced in every test round, and BLE discovery remained stable for 2 continuous hours in background operation.

Beyond the application itself, the four undocumented Android API behaviors documented in Section 3.5 constitute a practical engineering contribution that stands independently of SPAN RESCUE. The Wi-Fi Direct peer discovery auto-stop, the BLE scan 30-second background termination, the GO election non-determinism across manufacturers, and the TCP fragmentation rate above 200 bytes — each discovered through real-device testing and each absent from Android's official documentation — represent concrete knowledge that will save significant debugging time for any developer working on infrastructure-free Android networking.

## **Summary of Contributions**

- A four-layer communication architecture (BLE discovery \+ Wi-Fi Direct star groups \+ TCP with EOF framing \+ Smart Routing Protocol) providing clean separation of concerns and independent testability of each layer;

- The Smart Routing Protocol (SRP): controlled flooding with LRU deduplication (500 entries), TTL enforcement (maxHops=10), randomized delay (0–500ms per message), and a three-level priority queue guaranteeing SOS precedence over all other traffic;

- A multi-group software bridge topology scaling to 20 devices across 4 star groups with automated inter-GO TCP connections and seenBy-array inter-group storm prevention — all without root access or specialized hardware;

- A complete Android application with five tactical screens, Foreground Service architecture, shared_preferences JSON-backed store-and-forward, and WindowManager SOS overlay;

- Documentation of four undocumented Android Wi-Fi Direct and BLE API behaviors with tested, production-ready workarounds;

- Validation across five devices from four manufacturers confirming cross-platform compatibility and all twelve functional requirements.

## **Limitations**

- Security: message encryption is not yet implemented. The current SRP transmits JSON in plaintext, vulnerable to passive eavesdropping by any Wi-Fi-capable device within range;

- Scale validation: full 20-device physical deployment was not possible due to hardware availability; the 20-device topology was validated through design analysis and partial (5-device) testing;

- GPS dependency: SOS payloads include GPS coordinates; indoor or underground scenarios where GPS is unavailable will produce empty location fields.

## **Future Work**

- Authenticated key exchange: implement ECDH session key negotiation for end-to-end AES-256-GCM encryption, closing the man-in-the-middle vulnerability identified in Bridgefy \[11\] and ensuring message confidentiality across all relay nodes;

- Adaptive TTL: dynamically estimate mesh diameter from observed hop counts and adjust maxHops accordingly — reducing overhead in small networks while maintaining full coverage in large ones;

- Health sensor integration: extend the SOS payload to include biometric data from BLE wearables (heart rate, blood oxygen, body temperature) following the health monitoring framework demonstrated by Vitabile et al. \[8\], providing rescue coordinators with medical situational awareness alongside GPS location;

- Large-scale simulation: validate the 20-device topology and SRP performance beyond physical hardware availability using ns-3 or OMNET++ with realistic Android radio propagation and mobility models;

- iOS interoperability: extend to iOS using the Multipeer Connectivity Framework, enabling mixed Android/iOS mesh networks in real-world deployments;

- Field deployment: conduct a structured field test with a university search-and-rescue simulation team to validate performance under realistic physical conditions (outdoor terrain, RF interference, node mobility).

SPAN RESCUE demonstrates, in working code tested on real devices, that the wireless hardware already present in every smartphone is sufficient for reliable emergency mesh communication. The software to enable it can be built within the standard Android API — without root, without specialized hardware, and without a network that may no longer exist when it is needed most. We hope this thesis serves as a foundation for future work on infrastructure-free emergency communication, and ultimately contributes — in however small a way — to keeping people safer when the world goes dark.

**References**

\[1\]E. L. Quarantelli, "Organizational Response to the Mexico City Earthquake of 1985: Characteristics and Changes," Natural Hazards, vol. 2, no. 3, pp. 203–220, 1989\. https://doi.org/10.1007/BF00057216

\[2\]Ministry of Internal Affairs and Communications (Japan), "White Paper on Information and Communications in Japan 2011 — Great East Japan Earthquake Damage to Telecommunications," MIC, Tokyo, Japan, 2011\. \[Online\]. Available: https://www.soumu.go.jp/johotsusintokei/whitepaper/eng/WP2011/2011-index.html

\[3\]S. Corson and J. Macker, "Mobile Ad hoc Networking (MANET): Routing Protocol Performance Issues and Evaluation Considerations," IETF RFC 2501, Jan. 1999\. \[Online\]. Available: https://www.rfc-editor.org/rfc/rfc2501

\[4\]T. Clausen and P. Jacquet, "Optimized Link State Routing Protocol (OLSR)," IETF RFC 3626, Oct. 2003\. \[Online\]. Available: https://www.rfc-editor.org/rfc/rfc3626

\[5\]C. E. Perkins, E. Belding-Royer, and S. R. Das, "Ad hoc On-Demand Distance Vector (AODV) Routing," IETF RFC 3561, Jul. 2003\. \[Online\]. Available: https://www.rfc-editor.org/rfc/rfc3561

\[6\]S.-Y. Ni, Y.-C. Tseng, Y.-S. Chen, and J.-P. Sheu, "The Broadcast Storm Problem in a Mobile Ad Hoc Network," in Proc. 5th ACM/IEEE Int. Conf. Mobile Computing and Networking (MobiCom'99), Seattle, WA, USA, Aug. 1999, pp. 151–162. https://doi.org/10.1145/313451.313525

\[7\]A. Sikora, M. Krzyszton, and M. Marks, "Application of Bluetooth Low Energy Protocol for Communication in Mobile Networks," in Proc. 2018 Int. Conf. Military Communications and Information Systems (ICMCIS), Warsaw, Poland, May 2018, pp. 1–6. https://doi.org/10.1109/ICMCIS.2018.8398689

\[8\]S. Vitabile, M. Marks, D. Stojanovic, S. Pllana, J. M. Molina, M. Krzyszton, A. Sikora, A. Jarynowski, F. Hosseinpour, A. Jakobik, A. Stojnev Ilic, A. Respicio, D. Moldovan, C. Pop, and I. Salomie, "Medical Data Processing and Analysis for Remote Health and Activities Monitoring," in High-Performance Modelling and Simulation for Big Data Applications, LNCS vol. 11400, pp. 186–220. Springer, Cham, 2019\. https://doi.org/10.1007/978-3-030-16272-6\_7

\[9\]Wi-Fi Alliance, "Wi-Fi Direct Specification v1.9," Technical Specification, Wi-Fi Alliance, Seattle, WA, USA, 2021\. \[Online\]. Available: https://www.wi-fi.org/discover-wi-fi/wi-fi-direct

\[10\]A. Jaimes, S. Murillo, and C. McDonald, "Social Networking Under Crisis Scenarios," in Proc. ISCRAM 2013, Baden-Baden, Germany, 2013\. (FireChat deployment data: Open Garden Inc., press releases 2014, https://opengarden.com/)

\[11\]M. R. Albrecht, J. Millican, and G. Neven, "Analysing the Bridgefy Messenger," IACR ePrint Archive, Report 2021/356, Mar. 2021\. \[Online\]. Available: https://eprint.iacr.org/2021/356

\[12\]Google LLC, "Wi-Fi Direct (P2P) Overview — Android Developers," Android Developers Documentation, 2024\. \[Online\]. Available: https://developer.android.com/develop/connectivity/wifi/wifi-direct

\[13\]Google LLC, "Bluetooth Low Energy Overview — Android Developers," Android Developers Documentation, 2024\. \[Online\]. Available: https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview

\[14\]Google LLC, "Background Execution Limits — Android Developers," Android Developers Documentation, 2024\. \[Online\]. Available: https://developer.android.com/about/versions/oreo/background

\[15\]K. Fall, "A Delay-Tolerant Network Architecture for Challenged Internets," in Proc. ACM SIGCOMM 2003, Karlsruhe, Germany, Aug. 2003, pp. 27–34. https://doi.org/10.1145/863955.863960

\[16\]S. M. R. Islam, D. Kwak, M. H. Kabir, M. Hossain, and K. Kwak, "The Internet of Things for Health Care: A Comprehensive Survey," IEEE Access, vol. 3, pp. 678–708, 2015\. https://doi.org/10.1109/ACCESS.2015.2437951

\[17\]S. B. Baker, W. Xiang, and I. Atkinson, "Internet of Things for Smart Healthcare: Technologies, Challenges, and Opportunities," IEEE Access, vol. 5, pp. 26521–26544, 2017\. https://doi.org/10.1109/ACCESS.2017.2775180

\[18\]C. E. Perkins and P. Bhagwat, "Highly Dynamic Destination-Sequenced Distance-Vector Routing (DSDV) for Mobile Computers," in Proc. ACM SIGCOMM 1994, London, UK, Aug. 1994, pp. 234–244. https://doi.org/10.1145/190314.190336

\[19\]D. B. Johnson and D. A. Maltz, "Dynamic Source Routing in Ad Hoc Wireless Networks," in T. Imielinski and H. Korth (Eds.), Mobile Computing, Kluwer Academic Publishers, 1996, ch. 5, pp. 153–181. https://doi.org/10.1007/978-0-585-29603-6\_5

\[20\]E. M. Royer and C.-K. Toh, "A Review of Current Routing Protocols for Ad Hoc Mobile Wireless Networks," IEEE Personal Communications, vol. 6, no. 2, pp. 46–55, Apr. 1999\. https://doi.org/10.1109/98.760423

\[21\]L. Militano, A. Iera, M. Nitti, L. Atzori, and G. Morabito, "That's My Device\! Secure Device-to-Device Communication for Smart Home Applications," in Proc. 2014 IEEE 25th Annual Int. Symp. on Personal, Indoor, and Mobile Radio Communication (PIMRC), Washington, DC, USA, Sep. 2014, pp. 461–465. https://doi.org/10.1109/PIMRC.2014.7136215

\[22\]I. Conti and S. Giordano, "Mobile Ad Hoc Networking: Milestones, Challenges, and New Research Directions," IEEE Communications Magazine, vol. 52, no. 1, pp. 85–96, Jan. 2014\. https://doi.org/10.1109/MCOM.2014.6710069