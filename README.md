# Treasure <img width="60" height="60" alt="cofre" src="https://github.com/user-attachments/assets/397760bf-2181-40d5-b9db-a3e67a5f5c11" />

**Version:** 1.0.9  
**Author:** Waky  
**License:** GNU General Public License v3  
**Link:** <https://github.com/XavierRobles/treasure>

---

> ### 📢 Notice
>
> Treasure is completely transparent in its operation: it acts only on the client, processing information that is already displayed in the game chat.  
> It does **not** modify any game files, **does not** send data to the server, and consumes minimal resources, operating solely with the local data available.
>
> ---
>
> Treasure es completamente transparente en su funcionamiento: actúa solo en el cliente, procesando la información que ya aparece en el chat del juego.  
> **No** modifica archivos del juego, **no** envía datos al servidor y consume recursos mínimos, operando únicamente con los datos locales disponibles.

---

## 📌 Changelog
### v1.0.9 (English)

- Added a new **Weekly** section to track weekly/twice-weekly content alongside Dynamis and Limbus.
- Added a third **Weekly** chip in compact mode next to **Dynamis** and **Limbus**.
- Added **Eco-Warrior** tracker:
  - Auto-detects accepted/active/completed quests for **San d'Oria / Windurst / Bastok** from in-game dialogue.
  - Detects phases automatically (accepted, field NPC started, NM ready, key item obtained, reward ready, completed, blocked).
  - Detects Eeko-Weeko cycle sync messages to keep the weekly cycle in line with the server state.
  - Weekly reset is computed on **Sunday 00:00 JST**; cycle progress is preserved across weekly resets.
  - Shows the **city start NPC** for each nation (Norejaie / Lumomo / Raifa) in the status table.
- Added **Highwind** weekly NM tracker:
  - Detects kills via the in-game defeat message combined with the local player's own XP gain within 5 seconds (double check, so spectating the kill from outside does not count).
  - Shows a live **alive / dead** icon next to the status panel.
  - Per-character weekly state with reset at **Sunday 00:00 JST**.
- Added a dedicated **Options** tab inside Weekly with all manual overrides (mark/undo, reset week/cycle/all, clear trigger log).
- Added new commands:
  - `/tr ew [show|set|done|undo|phase|reset week|reset cycle|reset all]` for Eco-Warrior.
  - `/tr hw [show|mark|undo|reset week|reset all]` for Highwind.
- Added a parallel **weekly router** and per-character storage under `weekly\ecowar.lua` and `weekly\highwind.lua`.
- Added a new **Quests** weekly tracker with auto-detection for **Spice Gals**, **Uninvited Guests** and **Secrets of Ovens Lost**:
  - Per-character state machine: *available → started → has key item → reward blocked (inventory full) → completed this week*.
  - Random-reward quests (Uninvited Guests) are confirmed by the NPC reward dialogue itself, not by a fixed obtained item.
  - Shared rewards like **Page from Miratete's Memoirs** are routed to the correct quest via a pending hand-in window, avoiding cross-quest false positives.
  - `Achievement Unlocked` is only used as a secondary trigger, never as the primary confirmation.
  - Weekly reset aligned with the rest of the Weekly trackers (**Sunday 00:00 JST**).
  - New **Quests** tab in full mode plus a `N/3 done` line in compact mode, with manual mark/undo/reset controls in the Options tab.
  - Per-character storage at `weekly\quests.lua`; the in-file catalog is open so adding new quests/missions/ENM requires no UI or router changes.
- Fixed **Eco-Warrior** reward detection: the tracker no longer marks a nation as completed when the NPC offers the reward but the player has full inventory or already owns the item. Completion now requires the real **Page from the Dragon Chronicles** + **Tale of the Wandering Heroes** drops to land.
- Fixed an ImGui tab-state issue where opening Limbus from compact and going back could leave the live treasure pool blank.

### v1.0.9 (Español)

- Añadida una nueva sección **Weekly** para llevar contenido semanal/dos veces por semana junto a Dynamis y Limbus.
- Añadido un tercer chip **Weekly** en modo compacto, junto a **Dynamis** y **Limbus**.
- Añadido tracker de **Eco-Warrior**:
  - Detecta automáticamente quest aceptada/activa/completada para **San d'Oria / Windurst / Bastok** a partir de los diálogos del juego.
  - Detecta fases automáticamente (aceptada, NPC de campo iniciado, NM listo, key item obtenido, recompensa lista, completada, bloqueada).
  - Detecta mensajes de Eeko-Weeko para sincronizar el ciclo semanal con el estado del servidor.
  - El reset semanal se calcula con **Domingo 00:00 JST**; el progreso del ciclo se mantiene entre resets.
  - Muestra en la tabla de estado el **NPC de ciudad** donde se inicia la misión (Norejaie / Lumomo / Raifa).
- Añadido tracker semanal de NM **Highwind**:
  - Detecta los kills combinando el mensaje de derrota del juego con la propia ganancia de XP del jugador local en menos de 5 segundos (doble check, para que verlo morir sin participar no cuente).
  - Muestra un icono **vivo / muerto** en vivo al lado del panel de estado.
  - Estado semanal por personaje con reset en **Domingo 00:00 JST**.
- Añadida una pestaña **Options** dentro de Weekly con todos los manual overrides (mark/undo, reset week/cycle/all, limpiar log de triggers).
- Añadidos nuevos comandos:
  - `/tr ew [show|set|done|undo|phase|reset week|reset cycle|reset all]` para Eco-Warrior.
  - `/tr hw [show|mark|undo|reset week|reset all]` para Highwind.
- Añadido un **weekly router** paralelo y almacenamiento por personaje en `weekly\ecowar.lua` y `weekly\highwind.lua`.
- Añadido un nuevo tracker semanal de **Quests** con detección automática para **Spice Gals**, **Uninvited Guests** y **Secrets of Ovens Lost**:
  - Máquina de estados por personaje: *available → started → has key item → reward blocked (inventario lleno) → completed this week*.
  - Las quests con recompensa aleatoria (Uninvited Guests) se confirman por el propio diálogo de entrega del NPC, no por un drop fijo.
  - Las recompensas compartidas como **Page from Miratete's Memoirs** se asignan a la quest correcta mediante una ventana de hand-in pendiente, evitando falsos positivos entre quests.
  - `Achievement Unlocked` solo se usa como trigger secundario, nunca como confirmación principal.
  - Reset semanal alineado con el resto de Weekly trackers (**Domingo 00:00 JST**).
  - Nueva pestaña **Quests** en modo full y resumen `N/3 done` en modo compacto, con controles manuales de mark/undo/reset en la pestaña Options.
  - Almacenamiento por personaje en `weekly\quests.lua`; el catálogo del propio archivo es abierto, por lo que añadir nuevas quests/misiones/ENM no requiere cambios en UI ni router.
- Corregida la detección de cierre de **Eco-Warrior**: ya no se marca una nación como completada cuando el NPC ofrece la recompensa pero el inventario está lleno o ya posees el ítem. La completación ahora exige que lleguen de verdad los drops **Page from the Dragon Chronicles** + **Tale of the Wandering Heroes**.
- Corregido un problema de estado de pestañas ImGui por el que entrar a Limbus desde compacto y volver podía dejar el pool en vivo en blanco.

---
### v1.0.8 (English)

- Fixed Limbus route detection so **NW / NE / SW / SE** are matched reliably from entry lines.
- Temenos route detection remains separated as **West / East / North** plus **Central 1-4**.
- Fixed route carry-over issues where the previous path could leak into a new run header/floor cap.
- Updated Limbus run lifecycle: after the run starts, it stays active until you leave **Apollyon/Temenos**.
- Limbus no longer auto-closes just because timer reached 0 while you are still inside Limbus.
- Improved Limbus reconnect behavior so a run can resume cleanly after a disconnect while still in-zone.
- Updated session naming:
  - **Dynamis** now saves without **Run 1** (one run per day/zone policy).
  - **Limbus** keeps **Run N** and includes route tags like **Apollyon-SW** / **Temenos-Central2**.
- Fixed live treasure-pool filtering outside events: opening Limbus view no longer hides normal pool items when returning.

### v1.0.8 (Español)

- Corregida la detección de rutas en Limbus para **NW / NE / SW / SE** al entrar.
- En Temenos la deteccion se mantiene separada como **West / East / North** y **Central 1-4**.
- Corregido el arrastre de ruta anterior que podía mostrar cabecera o tope de pisos equivocados.
- Ajustado el ciclo de run en Limbus: una vez empieza, se mantiene activo hasta salir de **Apollyon/Temenos**.
- Limbus ya no se cierra automáticamente solo porque el tiempo llegue a 0 si sigues dentro de la zona.
- Mejorada la reanudación tras desconexión en Limbus mientras sigas dentro del evento.
- Actualizado el nombre de sesiones:
  - **Dynamis** ahora guarda sin **Run 1** (política de una run por día/zona).
  - **Limbus** mantiene **Run N** y añade etiqueta de ruta como **Apollyon-SW** / **Temenos-Central2**.
- Corregido el filtro del pool vivo fuera de evento: entrar en la vista de Limbus ya no oculta ítems normales al volver.

### v1.0.7 (English)

- Added a new event: **Limbus**.
- Added a dedicated event router so Dynamis and Limbus keep separate runtime and UI logic.
- Added full **Limbus** support with its own session flow and zone detection (ID and zone-name fallback).
- Added Limbus timer parsing for start, extension, time-left sync, and end-of-run message handling.
- Added Limbus full tabs: **Coins**, **Items**, **Players**, **Key Items**, **Treasure**, **Management**, and **Settings**.
- Added **Key Items** status view in Limbus (Cosmo-Cleanse, Red Card, Black Card, White Card).
- Added Limbus **Management** split for coins with include/delivered tracking.
- Limbus split participants are now locked from the run start snapshot, so late joins do not count by default.
- Improved Limbus end behavior: run can stay active after timer end while pool items remain; it closes once pool is done or on zone out.
- Improved reconnect handling so active sessions are saved before character state reset and can resume cleanly.
- Updated compact header flow: **Dynamis** and **Limbus** buttons open full mode for that event, and **Back** always returns to compact mode.
- Improved compact header compatibility across different clients.
- Added a new **All** tab in Limbus to show merged totals (coins + items) and lost values in one table.
- Limbus run files are now created only when the run actually starts (run-start message), not when entering Apollyon/Temenos lobby.
- Added automatic **Run N** session naming for same-day repeats (Run 1, Run 2, ...), and event-filtered History lists.
- Added floor-transition tracking with packet confirmation, plus gate/vortex ready state updates tied to transitions.
- Added **Gate/Vortex** open detection for messages like **"The gate opens..."** and **"A vortex materializes..."**.
- Added default **Limbus chip colors** aligned with each chip type, used consistently in compact and full views.
- Added a Limbus **Gate/Vortex state icon** (open/closed) in the top status area.
- Refined compact Limbus status to focus on time, floor, and gate/vortex state while the run is active.
- Updated the interface style with rounded event buttons, improved compact header behavior, and refreshed event tabs for Limbus/Dynamis.
- Added separate selected-border settings for **Dynamis** and **Limbus** buttons.
- Event Buttons reset now affects only the current event settings.
- Fixed session-history scrolling so the list no longer jumps back to the top while browsing.
- Fixed full-view mouse-wheel scrolling so content keeps scrolling smoothly with a fixed **Back / X** header.
- Added Apollyon route profiles (**West / East / South West / South East / Central**) with floor caps per route and final objective tracking.
- Added Central Apollyon **Gunpod** tracking with live spawn count and active add HP status.
- Gunpod spawn detection now uses boss message parsing (**Pod Ejection**) plus entity fallback, with anti-duplicate protection.
- Gunpod cap is now dynamic, so if an extra add appears the tracker expands automatically (for example **6/6**).
- Added Gunpod HP percent display and configurable HP bar colors in Limbus settings.
- Improved compact auto-resize when the active Limbus header appears/disappears, keeping all content visible.
- Added boss-drop tooltips in Limbus live pool for Omega/Ultima items, showing the exact Homam/Nashira piece.
- Added icon support inside Limbus tooltips (job icons for AF items and gear icons for Omega/Ultima drops).
- Reorganized the icon library into a cleaner, scalable structure (`chips` and `elementals`) while preserving backward compatibility.
- Improved event separation: each event tab now shows only its own drops across Treasure, All, Coins, Items, Players, Lost, and Management.
- When opening the opposite event while inside another zone, the selected tab stays clean (no mixed drops).
- Back behavior improved: returning from full to compact now follows the active zone event again.
- Added new Global auto-hide settings so users can choose when Treasure hides:
  - Hide when game UI is hidden.
  - Hide on selected game menu groups (with per-group checkboxes).
- Refined currency classification so **Ancient Beastcoin** stays in Limbus currency, while **Gold Beastcoin** is treated as a regular item in Dynamis.
- Improved opposite-event behavior: while inside Dynamis/Limbus, your own event keeps showing the real live pool, and the opposite event stays clean.
- Reinforced event color isolation so each event always uses its own configured loot colors.
- Tightened Limbus coin detection to only Ancient Beastcoin variants (**Ancient / Anc. / Anct.**).

### v1.0.7 (Español)

- Añadido un nuevo evento: **Limbus**.
- Añadido un router de eventos para separar por completo la lógica y UI de Dynamis y Limbus.
- Añadido soporte completo para **Limbus** con flujo de sesión propio y detección de zona por ID y por nombre.
- Añadido parser de tiempo de Limbus para inicio, extensiones, sincronización por minutos restantes y fin real de run.
- Añadidas pestañas completas en Limbus: **Coins**, **Items**, **Players**, **Key Items**, **Treasure**, **Management** y **Settings**.
- Añadida vista de **Key Items** en Limbus (Cosmo-Cleanse, Red Card, Black Card y White Card).
- Añadida pestaña **Management** de Limbus para el split de coins con control de include/entregado.
- Los participantes del split de Limbus ahora se bloquean al inicio de run, para que las entradas tardías no cuenten por defecto.
- Mejorado el cierre de Limbus: tras terminar el tiempo, la sesión sigue viva mientras quede pool; se cierra al vaciar pool o salir de zona.
- Mejorado el manejo de reconexión guardando la sesión activa antes de resetear estado del personaje.
- Ajustado el flujo de cabecera en compacto: botones **Dynamis** y **Limbus** abren su menú en full, y **Back** siempre vuelve a compacto.
- Mejorada la compatibilidad de la cabecera compacta en distintos clientes.
- Añadida una nueva pestaña **All** en Limbus para ver en una sola tabla los totales combinados (coins + items) y perdidos.
- Los archivos de run de Limbus ahora se crean solo cuando la run empieza de verdad (mensaje de inicio), no al entrar al lobby de Apollyon/Temenos.
- Añadido nombrado automático de sesiones con **Run N** para repeticiones el mismo día (Run 1, Run 2, ...), y filtrado por evento en el historial.
- Añadido seguimiento de cambio de piso con confirmación por paquetes, junto al estado de gate/vortex ligado a esas transiciones.
- Añadida detección de apertura de **Gate/Vortex** para mensajes como **"The gate opens..."** y **"A vortex materializes..."**.
- Añadidos **colores por defecto de chips en Limbus** según su tipo, aplicados en modo compacto y full.
- Añadido un **icono de estado Gate/Vortex** (abierto/cerrado) en la zona de estado superior de Limbus.
- Ajustado el estado compacto de Limbus para centrarse en tiempo, piso y estado de gate/vortex mientras la run está activa.
- Actualizado el estilo de interfaz con botones de evento más redondeados, mejor cabecera en compacto y pestañas renovadas para Limbus/Dynamis.
- Añadidos ajustes separados de borde seleccionado para los botones de **Dynamis** y **Limbus**.
- El reset de Event Buttons ahora solo afecta a los ajustes del evento activo.
- Corregido el scroll del historial para que no vuelva arriba mientras recorres la lista.
- Corregido el scroll con rueda en vista full para que el contenido baje fluido y la cabecera **Back / X** quede fija.
- Añadidos perfiles de ruta de Apollyon (**West / East / South West / South East / Central**) con tope de pisos por ruta y objetivo final.
- Añadido seguimiento de **Gunpod** en Central Apollyon con contador de apariciones en vivo y estado de vida del add activo.
- La detección de aparición de Gunpod ahora usa mensaje del boss (**Pod Ejection**) más fallback por entidad, con protección anti-duplicado.
- El límite de Gunpod ahora es dinámico: si aparece un add extra, el contador se amplía automáticamente (por ejemplo **6/6**).
- Añadido porcentaje de vida en Gunpod y ajuste de colores de su barra en Settings de Limbus.
- Mejorado el autoajuste en compacto cuando aparece/desaparece la cabecera activa de Limbus para que no se corte el contenido.
- Añadidos tooltips de boss en el pool vivo de Limbus para drops de Omega/Ultima, mostrando la pieza exacta de Homam/Nashira.
- Añadido soporte de iconos dentro de los tooltips de Limbus (icono de job para AF e icono de equipo para drops de Omega/Ultima).
- Reestructurada la libreria de iconos con una estructura mas limpia y escalable (`chips` y `elementals`), manteniendo compatibilidad con versiones anteriores.
- Mejorada la separación por evento: cada pestaña ahora muestra solo drops de su propio evento en Treasure, All, Coins, Items, Players, Lost y Management.
- Al abrir el evento contrario dentro de otra zona, la vista se mantiene limpia y sin mezclar drops.
- Mejorado el comportamiento de Back: al volver de full a compacto, se recupera de nuevo el evento activo de la zona.
- Añadidas nuevas opciones globales de auto-ocultación para que el usuario decida cuándo esconder Treasure:
  - Ocultar cuando la UI del juego esta oculta.
  - Ocultar en grupos de menus seleccionados (con check por grupo).
- Ajustada la clasificacion de moneda para que **Ancient Beastcoin** siga como currency de Limbus y **Gold Beastcoin** se trate como item normal en Dynamis.
- Mejorado el comportamiento con evento opuesto: estando dentro de Dynamis/Limbus, tu propio evento sigue mostrando el pool real en vivo y el evento contrario queda limpio.
- Reforzada la separación de colores por evento para que cada uno use siempre sus ajustes propios.
- Ajustada la detección de moneda en Limbus para contar solo variantes de Ancient Beastcoin (**Ancient / Anc. / Anct.**).

---
### v1.0.6 (English)

- Fixed compact/full resizing so the window no longer grows for no reason when the pool is empty.
- Window size and column widths now stay exactly as the user left them.
- Improved per-character settings loading to keep layouts stable between characters.
- Added a **Personal Steal (THF)** block in the **Currency** tab, showing only your own steals.
- Personal Steal now shows attempts, success, failed, and success rate.
- Stolen currency now tracks single currency only (**Tukuku / Ordelle / Byne**).
- Improved live pool ordering to avoid items swapping positions while the timer updates.

- Fixed an issue where a false **"continues..."** message could appear when leaving Dynamis.
- Improved timer stability for the treasure-pool countdown, party report queue, and periodic updates.
- Improved saving behavior to reduce unnecessary disk writes while keeping critical saves on zone-out and timeout.
- Improved History list responsiveness by reducing repeated folder scans.
- Restored `/tr` fallback behavior so unknown subcommands toggle the UI.

### v1.0.6 (Español)

- Corregido el redimensionado entre modo compacto/completo para que la ventana no crezca sin motivo cuando el pool está vacío.
- El tamaño de ventana y los anchos de columna ahora se guardan exactamente como los deja el usuario.
- Mejorada la carga de ajustes por personaje para mantener el layout estable entre chars.
- Añadido el bloque **Personal Steal (THF)** en la pestaña **Currency**, mostrando solo los steals del jugador.
- Personal Steal muestra intentos, aciertos, fallos y porcentaje de éxito.
- La moneda robada solo cuenta moneda simple (**Tukuku / Ordelle / Byne**).
- Mejorado el orden del pool en vivo para evitar que los ítems cambien de posición mientras actualiza el tiempo.

- Corregido un problema por el que podia aparecer un mensaje falso de **"continues..."** al salir de Dynamis.
- Mejorada la estabilidad de los temporizadores del treasure-pool, la cola de reportes de party y las actualizaciones periodicas.
- Mejorado el sistema de guardado para reducir escrituras innecesarias a disco, manteniendo guardados criticos al salir de zona y en timeout.
- Mejorada la fluidez del historial evitando escaneos repetidos de la carpeta de sesiones.
- Restaurado el fallback de `/tr` para que los subcomandos desconocidos vuelvan a alternar la UI.

---

### v1.0.5 (English)

- Fixed an issue where the **Glass price** button could be hidden when the scrollbar appeared.
- Fixed an issue where lost items were assigned to a ghost user (**"To"**), incorrectly counting as an extra player.
- Fixed the **"All"** tab label duplication when an item was lost.
- Added an option to manually assign **extra currencies**, to compensate losses caused by re-entry or disconnects.
- Updated default event durations to match Dynamis formats:
  - **3h** (Cities)
  - **4h** (North)
  - **2h** (Dreams)
- Added an **event countdown timer** to show the remaining time.

### v1.0.5 (Español)

- Corregido un problema por el que el botón del **precio del Glass** podía quedar oculto al aparecer la barra de desplazamiento.
- Corregido un error por el que, al perderse un ítem, se asignaba a un usuario fantasma (**"To"**), contándose además como un jugador adicional.
- Corregida la duplicación del nombre de la pestaña **"All"** cuando se perdía un ítem.
- Añadida una opción para asignar **moneda extra** manualmente, para compensar pérdidas por reentrada o desconexión.
- Ajustadas las duraciones por defecto según Dynamis:
  - **3h** (Cities)
  - **4h** (North)
  - **2h** (Dreams)
- Añadida una **cuenta atrás** del evento para mostrar el tiempo restante.

---

### v1.0.4 (English)

- Introduced a **new time-based split system** for Dynamis currency distribution.
- Added **Start / End time controls** for the event, with automatic duration calculation.
- Split duration is now calculated in **minutes** and used as the base for all distributions.
- Added a configurable **Glass price field** (default: 1,000,000) that affects all split calculations.
- Each player can now have a **custom participation time**, allowing partial attendance.
- Currency and glass cost are **distributed proportionally to time played**.
- Added per-player management flags:
  - **Participated** (exclude helpers or late joins).
  - **Glass paid**.
  - **Currency delivered**.
- Added performance improvements:
  - Reduced redundant UI recalculations in compact mode.
  - Avoided unnecessary renders / table headers when a player has no relevant data.
  - Smoothed window resizing to prevent micro-jitter.
- Added advanced **currency reporting system** via `/tr` commands:
  - `/tr c`, `/tr cur`, `/tr currency` → report **total currency** to party chat.
  - `/tr who` → report **currency obtained per player**.
- Currency values are **automatically normalized**, converting all 100-value items into base units.
- Party chat output is **rate-limited and queued** to prevent failed messages or spam.
- Party chat reports now use **in-game icon tokens and visual separators** instead of plain text.
- Improved chat formatting for totals and per-player reports.
- Fixed UI behavior so **compact and full modes** maintain independent layouts.
- The names of **all Dynamis Dreamlands zones** are now displayed correctly.
- Improved participant detection to ensure **only players actually involved in the Dynamis run** are tracked for event management and splits.
- Historical session files are now shown **sorted by date**, newest first.
- **Backwards compatible** with session files created before this update.

---

### v1.0.4 (Español)

- Introducido un **nuevo sistema de reparto (split) basado en tiempo** para la moneda de Dynamis.
- Añadidos controles de **hora de inicio y fin** del evento, con cálculo automático de duración.
- La duración del evento se calcula en **minutos** y se usa como base para todos los repartos.
- Añadido un campo configurable de **precio del Glass** (por defecto: 1.000.000).
- Cada jugador puede tener ahora un **tiempo de participación personalizado**, permitiendo asistencias parciales.
- La moneda y el coste del glass se **reparten de forma proporcional al tiempo jugado**.
- Añadidas opciones de gestión por jugador:
  - **Participó** (para excluir helpers o gente que no cuenta).
  - **Glass pagado**.
  - **Moneda entregada**.
- Mejoras de rendimiento:
  - Menos recalculados redundantes del UI en modo compacto.
  - Se evitan renders/cabeceras/tablas innecesarias cuando un jugador no tiene datos relevantes.
  - Ajuste de altura más suave para evitar micro-“temblores” al redimensionar.
- Añadido un **sistema avanzado de reporte de moneda** mediante comandos `/tr`:
  - `/tr c`, `/tr cur`, `/tr currency` → muestra el **total de moneda** en party.
  - `/tr who` → muestra la **moneda obtenida por cada jugador**.
- Las monedas de valor 100 se **normalizan automáticamente** a su moneda base.
- El envío de mensajes al chat de party está **limitado y encolado** para evitar errores o spam.
- Los mensajes de moneda usan ahora **iconos y separadores gráficos del propio juego**.
- Formato del chat mejorado para totales y reportes por jugador.
- Corregido el comportamiento del UI para que los modos **compacto y completo** mantengan layouts independientes.
- El nombre de **todas las Dynamis Dreamlands** ahora se muestra correctamente.
- Detección de participantes reforzada para asegurar que **solo los jugadores realmente implicados en la run** se gestionan para el evento y el split.
- Los archivos históricos ahora se muestran **ordenados por fecha**, del más reciente al más antiguo.
- **Compatible con archivos de sesión anteriores** a esta actualización.


### v1.0.3 (English)

- Items in the treasure‑pool table are now sorted by **time left** (earliest → latest).  
  If two items have the same remaining time, they are ordered by slot number.  
- **Members are no longer added to the event when viewing past runs outside Dynamis.**

### v1.0.3 (Español)

- Los objetos de la tabla del treasure‑pool ahora se ordenan por **tiempo restante** (del que antes expira al que más dura).  
  Si dos ítems tienen el mismo tiempo, se ordenan por número de slot.  
- **Ya no se añaden miembros al evento al revisar runs pasadas fuera de Dynamis.**

### v1.0.2 (English)

- Fix: The addon now properly hides when any in‑game menu is opened (inventory, map, full‑log, etc.).

### v1.0.2 (Español)

- Corrección: El addon vuelve a ocultarse correctamente al abrir cualquier menú del juego (inventario, mapa, full‑log, etc.).

### v1.0.1 (English)

- Fixed a bug that prevented per‑character profiles from saving/loading correctly.  
- Default compact‑mode position adjusted to fit 1920 × 1080 screens.  
- Added early character‑change detection to reload the correct settings without relogging.

### v1.0.1 (Español)

- Corregido un bug que impedía guardar/cargar los perfiles por personaje.  
- Posición por defecto del modo compacto ajustada para resoluciones 1920 × 1080.  
- Se añadió detección temprana de cambio de personaje para recargar la configuración sin reloguear.

### v1.0.0 (English)

- Real‑time tracking of every drop in the Dynamis Treasure Pool.  
- Persistent sessions per zone/day: leave Dynamis, come back later, and your history is seamlessly restored.  
- Two UI modes (full and compact) rendered with ImGui.  
- Management tab to mark **glass paid**, **currency delivered**, and **member participation**.  
- Automatic party and alliance detection; names offered in drop‑down lists.  
- Slash command `/tr` to toggle the interface.  
- Customisable themes, colours, and column widths that persist between sessions.  
- Correct log messages when restoring or starting runs.  
- Safe cleanup on zone change, timeouts, and Ashita shutdown.

### v1.0.0 (Español)

- Registro en tiempo real de cada objeto que cae en el Treasure Pool de Dynamis.  
- Sesiones persistentes por zona y día: puedes salir, volver más tarde y seguir donde lo dejaste.  
- Dos modos de interfaz (completo y compacto) mediante ImGui.  
- Pestaña **Management** para marcar *glass paid*, *currency delivered* y la participación de cada jugador.  
- Detección automática de party y alianza; los nombres aparecen en listas desplegables.  
- Comando `/tr` para alternar la interfaz.  
- Temas, colores y anchos de columna personalizables que se guardan entre sesiones.  
- Mensajes de log correctos al restaurar o iniciar run.  
- Limpieza segura al cambiar de zona, superar timeouts o cerrar Ashita.

---

### Description (English)

**Treasure** is a lightweight Ashita addon for Final Fantasy XI that turns Dynamis loot tracking into a one‑window task.

During a run the addon:

- Monitors treasure‑pool packets and chat lines in real time.  
- Shows a sortable table with **Item**, **Winner**, **Lot**, and **Time Left**.  

The **Management** tab lets the run leader quickly record:

- Which players paid their glass fee.  
- Who has already received currency.  
- How long each member stayed in the run.

Everything is stored in a single session file per zone and date, ready for review in the built‑in history viewer.

---

#### Installation

1. **Copy the folder**

   Place the `Treasure` directory inside your Ashita `addons` folder, for example:


2. **Load the addon**

- **Automatic**  
  Add the line below to `scripts\default.txt` so Treasure loads on every launch:

  ```
  /addon load treasure
  ```

- **Manual**  
  Or type the same command in the Ashita chat box once you are in‑game:

  ```
  /addon load treasure
  ```
### Descripción (Español)

**Treasure** es un addon ligero para Ashita que simplifica la gestión del loot en Dynamis a una sola ventana.

Durante la run, el addon:

- Escucha en tiempo real los paquetes del Treasure‑Pool y las líneas del chat.  
- Muestra una tabla ordenable con **Objeto**, **Ganador**, **Lot** y **Tiempo restante**.  

La pestaña **Management** permite al líder de la run apuntar rápidamente:

- Qué jugadores pagaron su *glass*.  
- Quién recibió moneda.  
- Cuánto tiempo permaneció cada miembro en la run.

Todo se almacena en un único archivo de sesión por zona y fecha, listo para revisarse desde el visor de historial integrado.

---

#### Instalación

1. **Copia la carpeta**

   Coloca el directorio `Treasure` dentro de tu carpeta `addons` de Ashita, por ejemplo:


2. **Carga el addon**

- **Automático**  
  Añade la siguiente línea a `scripts\default.txt` para que Treasure se cargue cada vez que arranques el juego:

  ```
  /addon load treasure
  ```

- **Manual**  
  También puedes escribir el mismo comando en el chat de Ashita cuando estés dentro del juego:

  ```
  /addon load treasure
  ```
<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/66bbff76-e547-4087-9adb-5eb6decc296c"  width="320" alt="Treasure compact"/></td>
    <td><img src="https://github.com/user-attachments/assets/24d38183-3daa-452f-8161-91b7b9fb1176"  width="320" alt="Treasure full 1"/></td>
    <td><img src="https://github.com/user-attachments/assets/00c1ca7a-7ce9-4b7c-b170-299f50c1941b"  width="320" alt="Treasure full 2"/></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/1e2077d3-7c33-4504-b39d-2df503fd45e9"  width="320" alt="Management tab"/></td>
    <td><img src="https://github.com/user-attachments/assets/27d2c94f-a166-49d6-bcb2-2dbaa4f0efe0" width="320" alt="Treasure example"/></td>
</td>
    <td><img src="https://github.com/user-attachments/assets/0d0781e6-dc2a-45ca-9680-a28bf3f9c143"  width="320" alt="History viewer"/></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/d10998b6-964d-4bf7-9afa-ce5f4b2448e8"  width="320" alt="Session banner"/></td>
    <td><img src="https://github.com/user-attachments/assets/4466ad0a-3dcd-48d1-873c-8197da9352b2"  width="320" alt="Glass paid check"/></td>
    <td><img src="https://github.com/user-attachments/assets/b815ae27-6f85-4026-a0b8-29a9f7b06ae8"  width="320" alt="Currency delivered check"/></td>
  </tr>
</table>
