# TibiSuite

> **A unified tracker suite for World of Warcraft — Midnight & The War Within**
> *Suite de trackers unifiée pour World of Warcraft — Midnight & The War Within*

![Version](https://img.shields.io/badge/version-1.0.0-9480FF)
![WoW](https://img.shields.io/badge/WoW-Midnight%20%7C%20TWW-red)
![Author](https://img.shields.io/badge/author-Tibiscui%20%E2%80%94%20Kirin%20Tor-gold)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 🇬🇧 English

### What is TibiSuite?

TibiSuite is a lightweight **wrapper addon** that unifies four independent trackers under a single minimap button and a clean tab bar. Instead of cluttering your minimap with four separate icons, you get one button to rule them all.

Each tracker can also be installed and used **independently** — TibiSuite is fully optional.

### Modules

| Addon | Description | Version |
|---|---|---|
| **DailyTracker** | Daily & weekly quest tracker — Midnight & The War Within. Auto-detection via `C_QuestLog`. | 1.0 |
| **DgnTracker** | Dungeon, Raid, Delve & Torghast entrance tracker. All expansions from Vanilla to Midnight. | 1.3 |
| **LegTracker** | Legendary item tracker by expansion. Full account-wide tracking across all your characters. | 2.0 |
| **RepTracker** | Reputation tracker for all expansions — Vanilla to Midnight. 13 expansions, collapsible groups, auto-track by zone. | 2.0 |

### Installation

#### Option A — Full Suite (recommended)

Install all five folders in your `Interface/AddOns/` directory:

```
Interface/AddOns/
├── TibiSuite/
├── DailyTracker/
├── DgnTracker/
├── LegTracker/
└── RepTracker/
```

TibiSuite will automatically detect which trackers are installed and show a CurseForge download link for any missing ones.

#### Option B — Individual Addon

Install only the tracker(s) you want. Each addon works completely standalone with its own minimap button.

```
Interface/AddOns/
└── RepTracker/   ← works perfectly on its own
```

### Usage

| Action | Result |
|---|---|
| **Left-click** the TibiSuite minimap button | Show / hide the tab bar |
| **Drag** the minimap button | Reposition it around the minimap |
| **Click a tab** in the bar | Open / close that tracker |
| **Drag** the tab bar | Move it anywhere on screen |
| `/tibisuite` or `/ts` | Toggle the tab bar via chat command |

> If a tracker is not installed, clicking its tab displays a message with the CurseForge download link.

### Compatibility

- **Interface**: 12.0.7 (Midnight), 12.0.5
- **Compatible with**: ElvUI, Dominos, Bartender4 (dynamic minimap radius)
- **Optional dependency**: TomTom (DgnTracker waypoints)

### Configuration

All settings are saved automatically per character via `SavedVariables`:

- Tab bar position
- Minimap button angle
- Last open/closed state of each tracker window

---

## 🇫🇷 Français

### Qu'est-ce que TibiSuite ?

TibiSuite est un **addon wrapper léger** qui regroupe quatre trackers indépendants sous un seul bouton minimap et une barre d'onglets. Au lieu d'encombrer votre minimap avec quatre icônes séparées, vous n'en avez plus qu'une.

Chaque tracker peut également être installé et utilisé **de manière indépendante** — TibiSuite est entièrement optionnel.

### Modules

| Addon | Description | Version |
|---|---|---|
| **DailyTracker** | Suivi des quêtes quotidiennes et hebdomadaires — Midnight & The War Within. Détection automatique via `C_QuestLog`. | 1.0 |
| **DgnTracker** | Tracker des entrées d'instances (Donjons, Raids, Gouffres, Torghast) pour toutes les extensions. Vanilla → Midnight. | 1.3 |
| **LegTracker** | Suivi des objets légendaires par extension. Suivi de compte complet sur tous vos personnages. | 2.0 |
| **RepTracker** | Suivi des réputations multi-extensions — Vanilla → Midnight. 13 extensions, groupes repliables, suivi auto par zone. | 2.0 |

### Installation

#### Option A — Suite complète (recommandé)

Installez les cinq dossiers dans votre répertoire `Interface/AddOns/` :

```
Interface/AddOns/
├── TibiSuite/
├── DailyTracker/
├── DgnTracker/
├── LegTracker/
└── RepTracker/
```

TibiSuite détecte automatiquement les trackers installés et affiche un lien CurseForge pour les modules manquants.

#### Option B — Addon individuel

Installez uniquement le ou les trackers souhaités. Chaque addon fonctionne parfaitement seul avec son propre bouton minimap.

### Utilisation

| Action | Résultat |
|---|---|
| **Clic gauche** sur le bouton minimap TibiSuite | Afficher / masquer la barre d'onglets |
| **Glisser** le bouton minimap | Le repositionner autour de la minimap |
| **Clic sur un onglet** | Ouvrir / fermer ce tracker |
| **Glisser** la barre d'onglets | La déplacer sur l'écran |
| `/tibisuite` ou `/ts` | Basculer la barre via commande chat |

> Si un tracker n'est pas installé, cliquer sur son onglet affiche un message avec le lien CurseForge de téléchargement.

### Compatibilité

- **Interface** : 12.0.7 (Midnight), 12.0.5
- **Compatible avec** : ElvUI, Dominos, Bartender4 (rayon minimap dynamique)
- **Dépendance optionnelle** : TomTom (waypoints DgnTracker)

### Configuration

Tous les paramètres sont sauvegardés automatiquement par personnage via `SavedVariables` :

- Position de la barre d'onglets
- Angle du bouton minimap
- Dernier état ouvert/fermé de chaque fenêtre de tracker

---

## File Structure / Structure des fichiers

```
TibiSuite/
├── TibiSuite.toc         — Addon manifest / Manifeste de l'addon
├── TibiSuite.lua         — Core wrapper logic / Logique du wrapper
└── medias/
    └── TibiSuite.tga     — Minimap icon (64×64, TGA 32-bit RGBA)

DailyTracker/
├── DailyTracker.toc
├── DailyTracker.lua
├── data/
│   ├── Midnight.lua
│   └── TheWarWithin.lua
└── medias/

DgnTracker/
├── DgnTracker.toc
├── DgnTracker.lua
├── data/           — 12 expansions (Vanilla → Midnight)
└── medias/

LegTracker/
├── LegTracker.toc
├── LegTracker.lua
├── data/
│   └── LegendaryItems.lua
├── locales/
│   └── frFR.lua
└── medias/

RepTracker/
├── RepTracker.toc
├── RepTracker.lua
├── data/           — 13 expansions (Vanilla → Midnight)
└── medias/
```

---

## Author / Auteur

**Tibiscui** — Kirin Tor (EU)

*Joueur depuis la fin de The Burning Crusade. Ces addons sont nés d'un besoin personnel de suivre les réputations, légendaires, donjons et quêtes quotidiennes sans dépendre d'addons lourds.*

---

## License

MIT — Free to use, modify and redistribute with attribution.
Libre d'utilisation, modification et redistribution avec attribution.
