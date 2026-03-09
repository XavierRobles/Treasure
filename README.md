# Treasure <img width="60" height="60" alt="cofre" src="https://github.com/user-attachments/assets/397760bf-2181-40d5-b9db-a3e67a5f5c11" />

**Version:** 1.0.7  
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
### v1.0.7 (English)

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

### v1.0.7 (Español)

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
