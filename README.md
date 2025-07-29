# Treasure <img width="60" height="60" alt="cofre" src="https://github.com/user-attachments/assets/397760bf-2181-40d5-b9db-a3e67a5f5c11" />

**Version:** 1.0.3  
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

## 📌 Changelog
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




