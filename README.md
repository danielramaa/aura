<!-- Template file for README.md for LEIC-ES-2025-26 -->

# _Aura_ Development Report

Welcome to the documentation of _Aura_!

This Software Development Report, tailored for LEIC-ES-2025-26, provides comprehensive details about _Aura_, starting from an high-level vision and going into low-level implementation decisions. 

It is organised by the following activities: 

* [Business modeling](#Business-Modelling) 
  * [Product Vision](#Product-Vision)
  * [Features and Assumptions](#Features-and-Assumptions)
* [Requirements](#Requirements)
  * [Domain model](#Domain-model)
  * [User interfaces](#User-interfaces)
* [Architecture and Design](#Architecture-And-Design)
  * [Logical architecture](#Logical-Architecture)
  * [Physical architecture](#Physical-Architecture)
  * [Functional prototype](#Functional-Prototype)
* [Project management](#Project-Management)
  * [Sprint 0](#Sprint-0)
  * [Sprint 1](#Sprint-1)
  * [Sprint 2](#Sprint-2)
  * [Sprint 3](#Sprint-3)
  * [Final Release](#Final-Release)

Contributions are expected to be made exclusively by the initial team, but we may open them to the community, after the course, in all areas and topics: requirements, technologies, development, experimentation, testing, etc.

Please contact us!

Thank you!

* Bruno da Fonseca Nicolau Costa Dias - up202405613@up.pt
* Carolina Oliveira Dias - up202406310@up.pt
* Daniel Morais Rama - up202409357@up.pt
* Francisco Almeida Henriques dos Santos Poeira - up202406330@up.pt
* Pedro Oliveira Soares Lopes - up202405618@up.pt

---
## Business Modelling

Business modeling in software development involves defining the product's vision, understanding market needs, aligning features with user expectations, and setting the groundwork for strategic planning and execution.

### Product Vision

<!-- 
Start by defining a clear and concise product vision for your app, to help members of the team, contributors, and users into focusing their often disparate views into a concise, visual, and short textual form. 

The vision should provide a "high concept" of the product for marketers, developers, and managers.

A product vision describes the essential of the product and sets the direction to where a product is headed, and what the product will deliver in the future. 

**We favor a catchy and concise statement, ideally one sentence.**

We suggest you use the product vision template described in the following link:
* [How To Create A Convincing Product Vision To Guide Your Team, by uxstudioteam.com](https://uxstudioteam.com/ux-blog/product-vision/)

To learn more about how to write a good product vision, please read:
* [Vision, by scrumbook.org](http://scrumbook.org/value-stream/vision.html)
* [Product Management: Product Vision, by ProductPlan](https://www.productplan.com/glossary/product-vision/)
* [20 Inspiring Vision Statement Examples (2019 Updated), by lifehack.org](https://www.lifehack.org/articles/work/20-sample-vision-statement-for-the-new-startup.html)
-->
| | |
|---|---|
| **Vision** | Empower people living with chronic or rare health conditions to find their community anonymously — sharing experiences, insights, and support with others who truly understand. |
| **Target group** | People diagnosed with chronic or rare health conditions (e.g. diabetes, fibromyalgia, MS) who feel isolated and lack a safe space to talk openly about their experiences. |
| **Needs** | A stigma-free space to connect with peers who share the same condition — without fear of judgment, loss of privacy, or exposure of personal identity. |
| **Product** | Anonymous mobile app with condition-specific communities, real-time group chat, peer wellbeing sharing (with medical disclaimers), message reactions, and content moderation. |
| **Business goals** | Demonstrate viability of an anonymous peer-support platform as a university project. Validate demand, gather user feedback, and build a working MVP with a real Firebase backend. |


### Features and Assumptions
<!-- 
Indicate an  initial/tentative list of high-level features - high-level capabilities or desired services of the system that are necessary to deliver benefits to the users.
 - Feature XPTO - a few words to briefly describe the feature
 - Feature ABCD - ...
...

Optionally, indicate an initial/tentative list of assumptions that you are doing about the app and dependencies of the app to other systems.
-->

### Features:

#### 1. Authentication and account management
- Registration with e-mail and password
- Password recovery
- Private profile editing (name, date of birth, e-mail)
- Account privacy settings
- Notification management (push and e-mail)
- Account deletion and data export (GDPR)
- Terms of service and privacy policy (acceptance)

#### 2. Onboarding and health selection
- Initial health/interests questionnaire
- Health condition search and selection (catalogue)
- Suggest new conditions (form)
- Manage list of followed conditions
- Define experience level with the condition (patient/doctor)

#### 3. Anonymity system
- Automatic anonymous avatar generation
- Random anonymous nickname generation (e.g. *CalmWolf*)
- Option to generate a new anonymous identity (reset)
- Identity isolation (a different nickname per room/condition)
- User metadata concealment (registration date, location, IP)

#### 4. Directory and navigation
- Main list of subscribed rooms/conditions
- Explore new rooms by category (mental health, autoimmune, chronic, etc.)
- Sub-rooms or specific topics (e.g. Diabetes > Insulin Pumps)
- Global search bar (rooms, conditions, topics)
- Online user count per room

#### 5. Chat and interaction
- Real-time text chat (public within rooms)
- Reply to specific messages (threads)
- Anonymous user mentions (@nickname)
- Typing indicator
- Empathetic emoji reactions (hug, I understand, stay strong, etc.)
- Link sharing with preview (and automatic medical disclaimer warning)
- Anonymous polls within rooms
- Save messages (bookmarks/favourites) in a private area
- Message history search within a room
- Pinned messages at the top of the chat

#### 6. Safety and moderation
- Mandatory medical disclaimer acceptance on room entry
- Global SOS button (link to local support and emergency lines)
- Report message (spam, misinformation, bullying, risk to life)
- Report anonymous user
- Block/mute anonymous user (hide their messages)
- Automatic profanity and hate speech filter
- Automatic personal data sharing filter (phone numbers, e-mails)
- Detection and blocking of prescription medication names (illegal sales)
- Shadowban system for offending users
- Moderator status (verified medical professionals only)

#### 7. Engagement and community
- Karma/thanks system (give anonymous kudos for good advice)
- Welcome bot in rooms

#### 8. Notifications and accessibility
- Push notifications for replies and mentions
- Activity notifications for saved topics
- Do not disturb mode / silence schedules
- Font size adjustment (accessibility)
- Screen reader support (VoiceOver/TalkBack)

#### 9. Future features
- Live Q&A sessions with invited doctors/specialists (they are real, users remain anonymous)
- Temporary private rooms created by users
- In-app donations to keep the project running

### Assumptions

- Users have an Android device running Android 8.0 or above with a stable internet connection
- Users are willing to register with a real e-mail and password for account recovery purposes
- Firebase Authentication (e-mail/password) is sufficient for account management in the MVP
- Auto-generated anonymous nicknames and avatars are accepted by users as their in-room identity
- A single anonymous identity per room is enough — users do not need cross-room identity persistence
- Medical disclaimers displayed at room entry are sufficient to mitigate liability around shared health content
- The health condition catalogue is manually curated by the team for the MVP — no external medical database integration
- Content moderation in the MVP is semi-manual (automated filters + user reports reviewed by the team)
- Push notifications are delivered via Firebase Cloud Messaging (FCM) and require user permission on device
- GDPR compliance is limited to account deletion and basic data export in the MVP — full compliance is a post-MVP concern
- The SOS button links to static, pre-defined crisis lines — no dynamic geolocation-based lookup in the MVP
- Live Q&A sessions, private rooms, and donations are out of scope for the MVP and treated as future features
- The app targets Android only — iOS support is deferred

## Requirements


### User Stories

The user stories for this project are managed and tracked in our [GitHub Projects board](https://github.com/orgs/LEIC-ES-2025-26-2LEIC14/projects/3/views/1).

### User Interface:


### Domain model

<!-- 
To better understand the context of the software system, it is useful to have a simple UML class diagram with all and only the key concepts (names, attributes) and relationships involved of the problem domain addressed by your app. 
Also provide a short textual description of each concept (domain class). 

Example:
 <p align="center" justify="center">
  <img src="https://github.com/FEUP-LEIC-ES-2022-23/templates/blob/main/images/DomainModel.png"/>
</p>
-->


## Architecture and Design
<!--
The architecture of a software system encompasses the set of key decisions about its organization. 

A well written architecture document is brief and reduces the amount of time it takes new programmers to a project to understand the code to feel able to make modifications and enhancements.

To document the architecture requires describing the decomposition of the system in their parts (high-level components) and the key behaviors and collaborations between them. 

In this section you should start by briefly describing the components of the project and their interrelations. You should describe how you solved typical problems you may have encountered, pointing to well-known architectural and design patterns, if applicable.
-->


### Logical architecture
<!--
The purpose of this subsection is to document the high-level logical structure of the code (Logical View), using a UML diagram with logical packages, without the worry of allocating to components, processes or machines.

It can be beneficial to present the system in a horizontal decomposition, defining layers and implementation concepts, such as the user interface, business logic and concepts.

Example of _UML package diagram_ showing a _logical view_ of the Eletronic Ticketing System (to be accompanied by a short description of each package):

![LogicalView](https://user-images.githubusercontent.com/9655877/160585416-b1278ad7-18d7-463c-b8c6-afa4f7ac7639.png)
-->


### Physical architecture
<!--
The goal of this subsection is to document the high-level physical structure of the software system (machines, connections, software components installed, and their dependencies) using UML deployment diagrams (Deployment View) or component diagrams (Implementation View), separate or integrated, showing the physical structure of the system.

It should describe also the technologies considered and justify the selections made. Examples of technologies relevant for ESOF are, for example, frameworks for mobile applications (such as Flutter).

Example of _UML deployment diagram_ showing a _deployment view_ of the Eletronic Ticketing System (please notice that, instead of software components, one should represent their physical/executable manifestations for deployment, called artifacts in UML; the diagram should be accompanied by a short description of each node and artifact):

![DeploymentView](https://user-images.githubusercontent.com/9655877/160592491-20e85af9-0758-4e1e-a704-0db1be3ee65d.png)
-->


### Functional prototype
<!--
To help on validating all the architectural, design and technological decisions made, we usually implement a functional prototype, a thin vertical slice of the system integrating as much technologies as we can.

In this subsection please describe which feature, or part of it, you have implemented, and how, together with a snapshot of the user interface, if applicable.

At this phase, instead of a complete user story, you can simply implement a small part of a feature that demonstrates thay you can use the technology, for example, show a screen with the app credits (name and authors).
-->

## Project management
<!--
Software project management is the art and science of planning and leading software projects, in which they are planned, implemented, monitored and controlled.

In the context of ESOF, we recommend each team to adopt a set of project management practices and tools capable of registering tasks, assigning tasks to team members, adding estimations to tasks, monitor tasks progress, and therefore being able to track their projects.

Common practices of managing agile software development with Scrum are: backlog management, release management, estimation, Sprint planning, Sprint development, acceptance tests, and Sprint retrospectives.

You can find below information and references related with the project management: 

* Backlog management: Product backlog and Sprint backlog in a [Github Projects board](https://github.com/orgs/FEUP-LEIC-ES-2023-24/projects/64);
* Release management: [v0](#), v1, v2, v3, ...;
* Sprint planning and retrospectives: 
  * plans: screenshots of Github Projects board at begin and end of each Sprint;
  * retrospectives: meeting notes in a document in the repository, addressing the following questions:
    * Did well: things we did well and should continue;
    * Do differently: things we should do differently and how;
    * Puzzles: things we don’t know yet if they are right or wrong;
    * list of a few improvements to implement next Sprint;

-->

### Sprint 0

### Sprint 1

### Sprint 2

### Sprint 3

### Sprint 4

### Final Release
