# Asfalto Uno

Básquet callejero 3D, local y sin conexión. Cada duelo usa exactamente dos jugadores: dos personas en el mismo teclado o una persona contra la CPU. El vestuario guarda dos fichas independientes.

## Abrir en macOS

1. Descomprime **Asfalto-Uno-macOS.zip**.
2. Arrastra **Asfalto Uno.app** a **Aplicaciones** y ábrela. El paquete es universal (Apple Silicon e Intel) y declara macOS 14.8 como mínimo.
3. Si macOS bloquea la apertura, esta compilación tiene firma local (ad hoc) y no está notarizada por Apple. Si confías en el origen del archivo, sigue la guía oficial de Apple para [abrir una app de un desarrollador no identificado](https://support.apple.com/es-cl/102445). No hace falta desactivar Gatekeeper.

La aplicación se exportó desde Linux con las plantillas oficiales de Godot 4.5.1. Se comprobó el juego en Linux; todavía no se ha ejecutado el binario en macOS 14.8 ni en el macOS más reciente.

## Jugar

Elige Santiago, Ciudad de México o Nueva York. En **VS CPU** puedes elegir **Fácil**, **Normal** o **Difícil**. En Fácil, la CPU se mueve más despacio, marca con más distancia e intenta robar con menos frecuencia; también tienes más tiempo para acertar en el medidor. La elección se guarda.

Abre **Vestuario → Aptitudes** para repartir hasta **400 puntos por jugador** entre altura, peso, musculatura, lanzamiento, defensa y dribbling. Cada aptitud admite de 0 a 100 puntos. Si el contador marca cero libres, baja una aptitud antes de subir otra. Los repartos se guardan por separado y las fichas anteriores que superen el límite se ajustan proporcionalmente.

En **Vestuario** también puedes cambiar el nombre y el aspecto. En **Animaciones**, prueba los estilos de tiro, dribbling y celebración antes de jugar. Arrastra sobre la vista 3D para rotar al jugador.

| Acción | Jugador 1 | Jugador 2 |
| --- | --- | --- |
| Mover | W A S D | Flechas |
| Tiro / robo | F | O |
| Sprint / postura defensiva | G | P |
| Saltar para taponar | H | I |
| Cambio de mano y dirección | Punto (.) | Punto (.) |
| Clavada cerca del aro | Espacio | Espacio |

Mantén la tecla de tiro y suéltala cuando el medidor alcance el verde. Punto y Espacio solo actúan sobre quien tiene el balón. La clavada vale un punto.

En defensa, pulsa **H** (J1) o **I** (J2) para saltar. Acércate al atacante y salta al inicio del tiro o antes de que el balón llegue al aro en una clavada. Si alcanzas el balón, lo desvías y ganas la siguiente posesión. Un salto a destiempo deja una breve recuperación. Mantén **G** o **P** para marcar sin saltar. **Esc** pausa el partido.

Una canasta vale un punto dentro del arco y dos fuera. El turno cambia después de un lanzamiento o cuando se agotan los 15 segundos; también puedes quitarle el balón al rival con un robo. Gana quien llegue a 11 con al menos dos de ventaja.

Los jugadores reaccionan con voces en español. La música de tensión entra cuando cualquiera alcanza 9 puntos y se corta al decidirse la victoria. En la premiación, el rival entrega el anillo al ganador. Desde ahí puedes pedir la revancha o volver al circuito.

Durante el duelo, el público animado, que incluye espectadoras adultas en bikini, aplaude canastas y tapones. Los raperos interpretan pistas originales: boom bap con quena en Santiago, hip hop con cumbia en Ciudad de México y boom bap de la Costa Este en inglés en Nueva York. La pista local baja de volumen en el tramo final. Un perro cruza la cancha de vez en cuando sin interferir con los jugadores ni con el balón.

## Abrir el proyecto y exportar

- Abre el proyecto en **Godot 4.5.1 estándar** (no requiere .NET ni dependencias adicionales).
- Presiona **F6** si abriste la escena principal, o **F5** para ejecutar el proyecto.
- En **Proyecto → Exportar**, instala las plantillas oficiales de esa versión y elige el preset **macOS**. Para una distribución pública sin advertencias, usa un certificado Developer ID y notariza la aplicación.

Desde la raíz del proyecto con `godot` disponible:

```sh
godot --headless --editor --import
godot --headless --path . --script tests/smoke.gd
mkdir -p build
godot --headless --path . --export-release macOS build/Asfalto-Uno-macOS.zip
```

El juego usa personajes y escenarios 3D procedurales estilizados. No utiliza activos de GTA V ni pretende reproducir su nivel de fotorrealismo. No incluye juego en red.

## Créditos

Godot Engine (MIT) y Barlow Condensed (SIL Open Font License). Los avisos completos están en la carpeta `art/`. Las voces fueron sintetizadas con Piper; sus créditos y la procedencia de los modelos están en `art/audio/CREDITOS.txt`.
