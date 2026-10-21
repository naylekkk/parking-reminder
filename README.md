# Parking Reminder — app iOS

Te notifie quand tu arrives à une adresse pour payer le parking, puis toutes les 2 h tant que tu restes sur place. Les rappels s'arrêtent tout seuls quand tu quittes la zone.

## Construire l'app sans Mac (GitHub Actions)

1. Crée un dépôt sur GitHub (ex : `parking-reminder`, il peut être privé).
2. Envoie-y le contenu de ce dossier (bouton **Add file > Upload files** sur la page du dépôt, en gardant le dossier `.github` — voir plus bas).
3. Onglet **Actions** : le build « Build iOS app » se lance tout seul (~5 min). Tu peux aussi le relancer avec **Run workflow**.
4. Quand il est vert ✅, ouvre-le et télécharge l'artefact **ParkingReminder-ipa** (un zip contenant `ParkingReminder.ipa`).

> Le dossier `.github` est caché sous Windows et le glisser-déposer peut l'ignorer. Si l'onglet Actions reste vide, crée le fichier à la main sur GitHub : **Add file > Create new file**, nom `.github/workflows/build.yml`, et colle le contenu du fichier.

## Installer sur l'iPhone depuis Windows (Sideloadly, gratuit)

1. Installe **iTunes** (version du site d'Apple, pas celle du Microsoft Store) et **Sideloadly** (sideloadly.io).
2. Branche l'iPhone en USB, déverrouille-le et appuie sur « Faire confiance ».
3. Dans Sideloadly : glisse `ParkingReminder.ipa`, entre ton identifiant Apple, clique **Start**.
4. Sur l'iPhone : **Réglages > Général > VPN et gestion de l'appareil** → fais confiance à ton identifiant Apple.
5. Active le **Mode développeur** si iOS le demande (Réglages > Confidentialité et sécurité).

Avec un identifiant Apple gratuit, l'app expire au bout de 7 jours : il suffit de refaire l'étape Sideloadly.

## Au premier lancement

- Accepte les notifications.
- Localisation : accepte, puis choisis **« Toujours autoriser »** (sinon : Réglages > Parking > Position > Toujours).
- Laisse « Position exacte » activée.

## Limites à connaître

- La détection d'arrivée/sortie peut prendre 1 à 5 minutes (c'est iOS qui décide, pour économiser la batterie).
- Il faut s'éloigner d'environ 100 à 200 m au-delà du rayon pour que la sortie soit détectée.
- 20 adresses maximum surveillées en même temps (limite iOS).
