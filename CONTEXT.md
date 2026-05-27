# Nook

A macOS utility that lets users assign custom names to virtual desktops (Spaces) and displays those names in Mission Control and in a persistent on-screen widget.

## Language

**Space**:
A macOS virtual desktop, identified internally by a stable UUID.
_Avoid_: Desktop (ambiguous with the Finder home screen), Workspace, Window

**Name**:
A user-assigned string that identifies a Space by purpose rather than position.
_Avoid_: Label, alias, title, tag

**Nook Bar**:
The persistent on-screen display showing the active Space's name. Appears in the notch on notch-equipped displays and as a floating pill on all others.
_Avoid_: Widget (WidgetKit connotation), indicator, badge

**Label**:
The name displayed over a Space's thumbnail when Mission Control is open. Named Spaces show their Name; unnamed Spaces show the macOS default ("Desktop N").
_Avoid_: Overlay (implementation term), badge, tag

**Active Space**:
The Space currently displayed on a given screen.
_Avoid_: Current space, focused space, selected space

**Collision**:
The state where two or more Spaces share the same Name.
_Avoid_: Conflict, duplicate

**Indexed Name**:
The display string shown in the Nook Bar during a Collision — the Name followed by a sequential number (e.g. "Coding 1", "Coding 2"). Used only when a Collision exists; otherwise the plain Name is shown.
_Avoid_: Qualified name, disambiguated name, labeled name

## Relationships

- A **Space** has zero or one **Name**
- A **Collision** occurs when two or more **Spaces** share the same **Name**
- During a **Collision**, the **Nook Bar** shows an **Indexed Name** instead of the plain **Name**

## Example dialogue

> **Dev:** "When does the Nook Bar show an Indexed Name?"
> **Domain expert:** "Only during a Collision — if two Spaces are both named 'Coding', they become 'Coding 1' and 'Coding 2'. A Space with a unique Name always shows just the Name."

## Flagged ambiguities

- "Coding 1/4" format (ratio) was initially proposed but superseded: the correct Indexed Name format is "Coding 1", "Coding 2" — sequential index only, no total count.
