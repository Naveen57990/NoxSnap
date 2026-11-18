# 📝 10_NoxSnap — Personal Notes

1) **Project Concept**:
   - Hardware-level physical magnetic handoff between Android (Realme P1 5G) and Apple Silicon MacBook.
   - MacBook lid bezel lo unde natural neodymium magnets ni phone magnetometer tho detect chesi, phone lo open unna browser tab ni Mac Chrome front window loki sub-second speed lo beam chesthundi.
   - Zero cloud, zero accounts, pure local Wi-Fi / Hotspot HTTP handshake (port 53320).

2) **Physical Magnetic Trigger Mechanics**:
   - Phone top corner ni MacBook display lid magnet daggara touch cheyagane:
     - Magnetometer flux spike detect avthundi ($\ge 80\,\mu\text{T}$, $\Delta \ge 25\,\mu\text{T}$).
     - Hysteresis state machine ventane `LOCKED_IN_CONTACT` mode loki velthundi (phone magnet meeda unnantha varaku malli malli trigger avvadu, no duplicate loops).
     - Phone lifted away ($< 52\,\mu\text{T}$) ayyaka $800\,\text{ms}$ cooldown lo re-arm avthundi.

3) **Pure Direction (Phone ➔ Mac Chrome)**:
   - Mac to phone pulling logic motham scrub chesam.
   - Left bezel magnet aina, right bezel magnet aina, top magnet aina — ekkada touch chesina 100% phone's active Chrome tab direct ga Mac Chrome front window loki beam avthundi.
   - In-app Accessibility Service browser URL ni automatically capture chesthundi, copy-paste or manual sharing avasaram ledu.

4) **Apple-Grade Water Shockwave Visual Effect**:
   - Gaudy neon boxes, emoji pills, colored HUDs motham delete chesam.
   - Tab handoff ayinappudu touched bezel corner nunchi pure crystalline liquid water ripple wavefronts screen meeda spread ayyi fade out avthayi.
   - Dual-layer refraction: razor-sharp specular crest + soft fluid swell, viscous deceleration physics.

5) **Launchers & Quick Commands**:
   - Start Mac receiver daemon: `START_NOXSNAP_MAC.command` (or `DARK_LAUNCHER.command` lo option `[s]`).
   - Stop daemon: `STOP_NOXSNAP_MAC.command`.
   - Install APK on phone: `INSTALL_PHONE_APK.command` (flashes `NoxSnap.apk`).
   - GitHub Repo: `https://github.com/Naveen57990/NoxSnap`
