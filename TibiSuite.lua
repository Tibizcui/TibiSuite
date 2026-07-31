-- ================================================================
-- TibiSuite v3.0
-- Auteur  : Tibiscui - Kirin Tor
-- Rôle    : Wrapper léger, barre d'onglets unifiée pour les
--           trackers de la suite (DailyTracker, DgnTracker,
--           LegTracker, RenTracker, LvlHistory, WeeklyCompass).
--           Fonctionne avec n'importe quel sous-ensemble de modules
--           installés. Affiche un message CurseForge si un module
--           est absent.
-- ================================================================

local ADDON   = "TibiSuite"
local VERSION = "3.0"

-- SavedVariables (compte) : réglages partagés par tous les personnages
--   mmAngle  : angle du bouton minimap
--   scale    : échelle de la barre d'onglets
--   locked   : barre verrouillée (non déplaçable) ?
--   vertical : orientation verticale ?
TibiSuiteDB = TibiSuiteDB or {}

-- SavedVariablesPerCharacter : état propre à CHAQUE personnage
--   barPos  : position de la barre pour ce perso
--   barOpen : barre visible au login pour ce perso ?
TibiSuiteCharDB = TibiSuiteCharDB or {}

-- Valeurs par défaut des réglages compte (comblées au chargement)
local DEFAULTS = {
  mmAngle  = 200,
  scale    = 1.00,
  locked   = false,
  vertical = false,
}

-- ================================================================
-- HELPERS VISUELS
-- ================================================================

-- Couleurs standards (identiques aux 4 trackers)
local COL_BG     = { r=0.04, g=0.02, b=0.06, a=0.97 }
local COL_BORDER = { r=0.72, g=0.60, b=0.28, a=1.00 }

-- Convertit r,g,b [0-1] en code couleur WoW "|cFFRRGGBB"
local function ColorCode(r, g, b)
  return string.format("|cFF%02X%02X%02X",
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5))
end

-- Icônes de statut natives WoW (rendu garanti, contrairement à ✓/✗ absents
-- de la police par défaut, qui s'affichaient en carrés vides).
local ICON_OK   = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local ICON_MISS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"

-- Backdrop standard réutilisé partout
local function MakeBackdrop(insets)
  insets = insets or 4
  return {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false, tileSize = 16, edgeSize = 14,
    insets   = { left=insets, right=insets, top=insets, bottom=insets },
  }
end

-- ================================================================
-- DÉFINITION DES MODULES
-- ================================================================
-- Chaque module correspond à un addon tracker.
--   addonName   : nom exact de l'addon (doit correspondre au .toc)
--   label       : texte affiché dans l'onglet
--   frameGlobal : nom global de la frame principale de l'addon
--   mmBtnGlobal : nom global du bouton minimap de l'addon
--   toggleFn    : nom de la fonction publique Toggle de l'addon
--   col         : couleur identitaire r/g/b [0-1]
--   curseUrl    : URL CurseForge à afficher si l'addon est absent
-- ================================================================
local MODULES = {
  {
    key         = "Daily",
    addonName   = "DailyTracker",
    label       = "Daily",
    frameGlobal = "DTMainFrame",
    mmBtnGlobal = "DTMinimapBtn",
    toggleFn    = "DailyTracker_Toggle",
    col         = { r=0.25, g=0.78, b=0.92 },  -- cyan Midnight
    curseUrl    = "https://www.curseforge.com/wow/addons/dailytracker",
  },
  {
    key         = "Dgn",
    addonName   = "DgnTracker",
    label       = "Donjons",
    frameGlobal = "DGNMainFrame",
    mmBtnGlobal = "DGNMinimapBtn",
    toggleFn    = "DgnTracker_Toggle",
    col         = { r=0.00, g=0.44, b=0.87 },  -- bleu instances
    curseUrl    = "https://www.curseforge.com/wow/addons/dgntracker",
  },
  {
    key         = "Leg",
    addonName   = "LegTracker",
    label       = "LegTracker",
    frameGlobal = "LegTrackerMainFrame",
    mmBtnGlobal = "LegTrackerMinimapBtn",
    toggleFn    = "LegTracker_Toggle",
    col         = { r=1.00, g=0.50, b=0.00 },  -- or légendaires
    curseUrl    = "https://www.curseforge.com/wow/addons/legtracker",
  },
  {
    key         = "Rep",
    addonName   = "RenTracker",
    label       = "Reput.",
    frameGlobal = "RNTMainFrame",
    mmBtnGlobal = "RNTMinimapBtn",
    toggleFn    = "RenTracker_Toggle",
    col         = { r=0.8, g=0.6, b=0.20 },  -- or réputations
    curseUrl    = "https://www.curseforge.com/wow/addons/rentracker",
  },
  {
    key         = "Lvl",
    addonName   = "LvlHistory",
    label       = "Lvl Hist",
    frameGlobal = "LvlHistoryMainFrame",
    mmBtnGlobal = "LvlHistoryMinimapButton",
    toggleFn    = "LvlHistory_Toggle",
    col         = { r=0.235, g=0.882, b=0.247 },  -- vert level-up #3CE13F
    curseUrl    = "https://www.curseforge.com/wow/addons/lvlhistory",
  },
  {
    key         = "Weekly",
    addonName   = "WeeklyCompass",
    label       = "Weekly",
    frameGlobal = "WeeklyCompassFrame",
    mmBtnGlobal = "WeeklyCompassMinimapButton",
    toggleFn    = "WeeklyCompass_Toggle",
    slashList   = "WEEKLYCOMPASS",  -- secours : /wc si la fonction Toggle est absente
    col         = { r=0.20, g=0.80, b=0.70 },  -- turquoise boussole
    curseUrl    = "https://www.curseforge.com/wow/addons/weeklycompass",
  },
}

-- ================================================================
-- DIMENSIONS DE LA BARRE
-- ================================================================
local TAB_W      = 90    -- largeur d'un onglet
local TAB_H      = 30    -- hauteur d'un onglet
local TAB_GAP    = 3     -- espace entre onglets
local MARGIN     = 8     -- marge autour de la barre
local LOGO_W     = 108   -- largeur réservée pour icône + "TibiSuite" + séparateur
local CLOSE_W    = 22    -- taille du bouton fermer (×)
local ALL_W      = 22    -- taille des boutons "tout ouvrir/fermer"
local ALL_GAP    = 3     -- espace entre les boutons du cluster droit
local VCOL_W     = 100   -- largeur d'une colonne en mode vertical

-- ================================================================
-- VARIABLES LOCALES (initialisées dans BuildX)
-- ================================================================
local barFrame         -- la barre d'onglets principale
local tabButtons = {}  -- boutons d'onglets [1..N]
local minimapBtn       -- bouton sur la minimap
local placeholderFrame -- frame "addon absent"
local optionsFrame     -- panneau d'options /ts config

-- Fonctions déclarées ici, définies plus bas (dépendances croisées)
local LayoutBar, SetAllModules, OpenOptions, RefreshOptions

-- ================================================================
-- MISE À JOUR DU HIGHLIGHT DES ONGLETS
-- Appelée après chaque clic et à l'ouverture de la barre.
-- Un onglet est "actif" si la frame de son module est visible.
-- ================================================================
local function UpdateTabHighlights()
  for i, mod in ipairs(MODULES) do
    local btn = tabButtons[i]
    if not btn then break end

    local loaded = C_AddOns.IsAddOnLoaded(mod.addonName)
    local frame  = loaded and _G[mod.frameGlobal]
    local active = frame and frame:IsShown()

    if active then
      -- Onglet actif : fond coloré, bordure vive
      btn:SetBackdropColor(
        mod.col.r * 0.22, mod.col.g * 0.22, mod.col.b * 0.22, 0.95)
      btn:SetBackdropBorderColor(
        mod.col.r, mod.col.g, mod.col.b, 1.0)
    elseif not loaded then
      -- Module absent : grisé
      btn:SetBackdropColor(0.05, 0.04, 0.06, 0.80)
      btn:SetBackdropBorderColor(0.35, 0.30, 0.35, 0.5)
    else
      -- Inactif mais installé : fond sombre, bordure atténuée
      btn:SetBackdropColor(0.06, 0.03, 0.10, 0.88)
      btn:SetBackdropBorderColor(
        mod.col.r * 0.45, mod.col.g * 0.45, mod.col.b * 0.45, 0.65)
    end
  end
end

-- ================================================================
-- OUVRIR / FERMER TOUS LES MODULES INSTALLÉS
-- show=true  : affiche les fenêtres encore masquées
-- show=false : masque les fenêtres encore visibles
-- On passe par la fonction Toggle de chaque module (build paresseux),
-- et on ne bascule que si l'état diffère de la cible.
-- ================================================================
function SetAllModules(show)
  for _, mod in ipairs(MODULES) do
    if C_AddOns.IsAddOnLoaded(mod.addonName) then
      local f  = _G[mod.frameGlobal]
      local fn = _G[mod.toggleFn]
      local shown = f and f:IsShown()
      if show and not shown then
        if fn then fn() elseif f then f:Show() end
      elseif (not show) and shown then
        if fn then fn() else f:Hide() end
      end
    end
  end
  C_Timer.After(0.05, UpdateTabHighlights)
end

-- ================================================================
-- PLACEHOLDER : affiché quand un module n'est pas installé
-- ================================================================
local function BuildPlaceholder()
  if placeholderFrame then return end

  placeholderFrame = CreateFrame("Frame", "TibiSuitePlaceholder", UIParent, "BackdropTemplate")
  placeholderFrame:SetSize(440, 185)
  placeholderFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  placeholderFrame:SetFrameStrata("HIGH")
  placeholderFrame:SetMovable(true)
  placeholderFrame:EnableMouse(true)
  placeholderFrame:RegisterForDrag("LeftButton")
  placeholderFrame:SetScript("OnDragStart", placeholderFrame.StartMoving)
  placeholderFrame:SetScript("OnDragStop",  placeholderFrame.StopMovingOrSizing)
  placeholderFrame:SetBackdrop(MakeBackdrop(6))
  placeholderFrame:SetBackdropColor(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a)
  placeholderFrame:SetBackdropBorderColor(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b)
  placeholderFrame:Hide()

  -- ── Titre (nom de l'addon manquant) ───────────────────────────
  local title = placeholderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", placeholderFrame, "TOP", 0, -16)
  placeholderFrame._title = title

  -- ── Message principal ─────────────────────────────────────────
  local msg = placeholderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  msg:SetPoint("TOP", title, "BOTTOM", 0, -10)
  msg:SetText("Cet addon n'est pas installé.")
  msg:SetTextColor(0.90, 0.90, 0.90)

  -- ── Label URL ─────────────────────────────────────────────────
  local urlLabel = placeholderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  urlLabel:SetPoint("TOP", msg, "BOTTOM", 0, -10)
  urlLabel:SetText("Téléchargez-le gratuitement sur CurseForge :")
  urlLabel:SetTextColor(0.70, 0.70, 0.70)

  -- ── URL affichée (non cliquable dans WoW, mais copiable) ──────
  local urlText = placeholderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  urlText:SetPoint("TOP", urlLabel, "BOTTOM", 0, -4)
  urlText:SetTextColor(0.45, 0.75, 1.00)
  placeholderFrame._urlText = urlText

  -- ── Bouton "Copier le lien" ───────────────────────────────────
  -- Ouvre une EditBox pré-remplie pour que le joueur puisse Ctrl+C
  local copyBtn = CreateFrame("Button", nil, placeholderFrame, "BackdropTemplate")
  copyBtn:SetSize(130, 26)
  copyBtn:SetPoint("TOP", urlText, "BOTTOM", 0, -12)
  copyBtn:SetBackdrop(MakeBackdrop(3))
  copyBtn:SetBackdropColor(0.12, 0.08, 0.18, 0.95)
  copyBtn:SetBackdropBorderColor(0.55, 0.45, 0.18, 0.80)

  local copyLabel = copyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  copyLabel:SetAllPoints()
  copyLabel:SetText("|cFFFFD700Copier le lien|r")

  copyBtn:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(0.85, 0.72, 0.30, 1.0)
  end)
  copyBtn:SetScript("OnLeave", function(s)
    s:SetBackdropBorderColor(0.55, 0.45, 0.18, 0.80)
  end)
  copyBtn:SetScript("OnClick", function()
    -- Crée (ou réutilise) une EditBox pour copier l'URL
    local eb = _G["TibiSuiteCopyBox"]
    if not eb then
      eb = CreateFrame("EditBox", "TibiSuiteCopyBox", UIParent, "InputBoxTemplate")
      eb:SetSize(420, 30)
      eb:SetPoint("TOP", placeholderFrame, "BOTTOM", 0, -8)
      eb:SetAutoFocus(true)
      eb:SetScript("OnEscapePressed", function(s) s:Hide() end)
      eb:SetScript("OnEnterPressed",  function(s) s:Hide() end)
    end
    eb:SetText(placeholderFrame._curUrl or "")
    eb:HighlightText()
    eb:Show()
    eb:SetFocus()
  end)

  -- ── Bouton fermer ─────────────────────────────────────────────
  local closeBtn = CreateFrame("Button", nil, placeholderFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", placeholderFrame, "TOPRIGHT", 2, 2)
  closeBtn:SetScript("OnClick", function()
    placeholderFrame:Hide()
    if _G["TibiSuiteCopyBox"] then _G["TibiSuiteCopyBox"]:Hide() end
  end)
end

-- Met à jour et affiche le placeholder pour un module donné
local function ShowPlaceholder(mod)
  BuildPlaceholder()
  placeholderFrame._title:SetText(
    ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.addonName .. "|r")
  placeholderFrame._urlText:SetText(mod.curseUrl)
  placeholderFrame._curUrl = mod.curseUrl
  if _G["TibiSuiteCopyBox"] then _G["TibiSuiteCopyBox"]:Hide() end
  placeholderFrame:Show()
end

-- ================================================================
-- LOGIQUE D'ACTIVATION D'UN ONGLET
-- ================================================================
local function OnTabClick(mod)
  -- Fermer le placeholder si ouvert pour un autre module
  if placeholderFrame and placeholderFrame:IsShown() then
    placeholderFrame:Hide()
    if _G["TibiSuiteCopyBox"] then _G["TibiSuiteCopyBox"]:Hide() end
  end

  -- Module absent → placeholder CurseForge
  if not C_AddOns.IsAddOnLoaded(mod.addonName) then
    ShowPlaceholder(mod)
    UpdateTabHighlights()
    return
  end

  -- 1) Fonction Toggle publique de l'addon (voie normale)
  local fn = _G[mod.toggleFn]
  local f  = _G[mod.frameGlobal]
  if type(fn) == "function" then
    fn()
  elseif f then
    -- 2) Fallback : la frame existe déjà, on la bascule directement
    if f:IsShown() then f:Hide() else f:Show() end
  elseif mod.slashList and SlashCmdList[mod.slashList] then
    -- 3) Dernier recours : commande slash du module (frame construite à la volée)
    SlashCmdList[mod.slashList]("")
  end

  -- Mettre à jour les highlights après un court délai
  -- (le frame peut mettre 1 frame à changer d'état)
  C_Timer.After(0.05, UpdateTabHighlights)
end

-- ================================================================
-- CONSTRUCTION DE LA BARRE D'ONGLETS
-- ================================================================
-- Sauvegarde la position courante de la barre (par personnage)
local function SaveBarPos()
  if not barFrame then return end
  local point, _, _, x, y = barFrame:GetPoint()
  TibiSuiteCharDB.barPos = { point = point, x = x, y = y }
end

-- Restaure la position sauvegardée (par personnage), avec valeurs de secours
local function RestoreBarPos()
  local pos = TibiSuiteCharDB.barPos or { point = "CENTER", x = 0, y = -300 }
  barFrame:ClearAllPoints()
  barFrame:SetPoint(
    pos.point or "CENTER", UIParent, pos.point or "CENTER",
    pos.x or 0, pos.y or -300)
end

local function BuildBar()
  if barFrame then return end  -- déjà construite

  -- ── Cadre principal de la barre ───────────────────────────────
  barFrame = CreateFrame("Frame", "TibiSuiteBar", UIParent, "BackdropTemplate")
  barFrame:SetFrameStrata("MEDIUM")
  barFrame:SetMovable(true)   -- requis pour StartMoving() depuis logoBtn
  barFrame:EnableMouse(true)
  barFrame:SetClampedToScreen(true)  -- ne jamais laisser la barre hors écran
  barFrame:SetBackdrop(MakeBackdrop(5))
  barFrame:SetBackdropColor(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a)
  barFrame:SetBackdropBorderColor(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b)
  barFrame:Hide()

  RestoreBarPos()

  -- ── Zone logo : icône TibiSuite.tga + texte "TibiSuite" ─────────
  local logoBtn = CreateFrame("Button", nil, barFrame)
  logoBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  barFrame._logo = logoBtn

  local logoIcon = logoBtn:CreateTexture(nil, "ARTWORK")
  logoIcon:SetSize(22, 22)
  logoIcon:SetPoint("LEFT", logoBtn, "LEFT", 0, 0)
  logoIcon:SetTexture("Interface\\AddOns\\TibiSuite\\medias\\TibiSuite")
  local logoMask = logoBtn:CreateMaskTexture()
  logoMask:SetAllPoints(logoIcon)
  logoMask:SetTexture(
    "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  logoIcon:AddMaskTexture(logoMask)
  barFrame._logoIcon = logoIcon

  local logoText = logoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  logoText:SetPoint("LEFT", logoIcon, "RIGHT", 6, 0)
  logoText:SetText("|cFFC41F3BTibiSuite|r")

  -- ── Drag : maintien clic gauche déplace la barre (sauf si verrouillée) ──
  logoBtn:RegisterForDrag("LeftButton")
  logoBtn:SetScript("OnDragStart", function()
    if TibiSuiteDB.locked then return end
    barFrame:StartMoving()
    GameTooltip:Hide()
  end)
  logoBtn:SetScript("OnDragStop", function()
    barFrame:StopMovingOrSizing()
    SaveBarPos()
  end)

  logoBtn:SetScript("OnEnter", function()
    logoIcon:SetVertexColor(1.1, 0.75, 0.75)
    GameTooltip:SetOwner(logoBtn, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", logoBtn, "BOTTOMLEFT", 0, -6)
    GameTooltip:AddLine("|cFFC41F3BTibiSuite|r v" .. VERSION)
    GameTooltip:AddLine("|cFFFFD700Maj + clic gauche|r : masquer la barre", 0.80, 0.80, 0.85)
    GameTooltip:AddLine("|cFFFFD700Clic droit|r : options", 0.80, 0.80, 0.85)
    if not TibiSuiteDB.locked then
      GameTooltip:AddLine("|cFFFFD700Maintien + glisser|r : déplacer", 0.70, 0.70, 0.75)
    else
      GameTooltip:AddLine("Barre verrouillée", 0.60, 0.60, 0.65)
    end
    GameTooltip:Show()
  end)
  logoBtn:SetScript("OnLeave", function()
    logoIcon:SetVertexColor(1.0, 1.0, 1.0)
    GameTooltip:Hide()
  end)
  logoBtn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      OpenOptions()
    elseif button == "LeftButton" and IsShiftKeyDown() then
      -- Maj + clic gauche : masquer la barre (évite les fermetures accidentelles)
      barFrame:Hide()
      TibiSuiteCharDB.barOpen = false
    end
    -- Clic gauche simple : rien (le logo sert de poignée de déplacement)
  end)

  -- Séparateur or entre le logo et les onglets (orienté par LayoutBar)
  local sep = barFrame:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.45)
  barFrame._sep = sep

  -- ── Petit bouton générique du cluster droit (fabrique interne) ──
  local function MakeMiniButton(glyph, borderCol)
    local b = CreateFrame("Button", nil, barFrame, "BackdropTemplate")
    b:SetSize(ALL_W, ALL_W)
    b:SetBackdrop(MakeBackdrop(3))
    b:SetBackdropColor(0.10, 0.08, 0.14, 0.92)
    b:SetBackdropBorderColor(borderCol[1], borderCol[2], borderCol[3], 0.70)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetText(glyph)
    b._border = borderCol
    b:SetScript("OnLeave", function(s)
      s:SetBackdropBorderColor(s._border[1], s._border[2], s._border[3], 0.70)
      GameTooltip:Hide()
    end)
    return b
  end

  -- Tout ouvrir (+ vert)
  local openAll = MakeMiniButton("|cFF66FF66+|r", { 0.30, 0.70, 0.30 })
  barFrame._openAll = openAll
  openAll:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(0.45, 0.95, 0.45, 1.0)
    GameTooltip:SetOwner(s, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -6)
    GameTooltip:AddLine("Tout ouvrir", 0.6, 1.0, 0.6)
    GameTooltip:Show()
  end)
  openAll:SetScript("OnClick", function() SetAllModules(true) end)

  -- Tout fermer (- orange)
  local closeAll = MakeMiniButton("|cFFFFAA55-|r", { 0.70, 0.45, 0.20 })
  barFrame._closeAll = closeAll
  closeAll:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(0.95, 0.65, 0.30, 1.0)
    GameTooltip:SetOwner(s, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -6)
    GameTooltip:AddLine("Tout fermer", 1.0, 0.75, 0.4)
    GameTooltip:Show()
  end)
  closeAll:SetScript("OnClick", function() SetAllModules(false) end)

  -- ── Bouton fermer (×) ─────────────────────────────────────────
  local closeBtn = CreateFrame("Button", nil, barFrame, "BackdropTemplate")
  closeBtn:SetSize(CLOSE_W, CLOSE_W)
  closeBtn:SetBackdrop(MakeBackdrop(3))
  closeBtn:SetBackdropColor(0.14, 0.05, 0.05, 0.90)
  closeBtn:SetBackdropBorderColor(0.55, 0.18, 0.18, 0.70)
  barFrame._close = closeBtn

  local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  closeX:SetAllPoints()
  closeX:SetText("|cFFFF5555×|r")

  closeBtn:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(1.0, 0.30, 0.30, 1.0)
    GameTooltip:SetOwner(s, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -6)
    GameTooltip:AddLine("Masquer la barre TibiSuite", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("(icône minimap pour rouvrir)", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  closeBtn:SetScript("OnLeave", function(s)
    s:SetBackdropBorderColor(0.55, 0.18, 0.18, 0.70)
    GameTooltip:Hide()
  end)
  closeBtn:SetScript("OnClick", function()
    barFrame:Hide()
    TibiSuiteCharDB.barOpen = false
  end)

  -- ── Onglets des modules (positionnés par LayoutBar) ───────────
  for i, mod in ipairs(MODULES) do
    local btn = CreateFrame("Button", nil, barFrame, "BackdropTemplate")
    btn:SetBackdrop(MakeBackdrop(4))
    btn:SetBackdropColor(0.06, 0.03, 0.10, 0.88)
    btn:SetBackdropBorderColor(
      mod.col.r * 0.45, mod.col.g * 0.45, mod.col.b * 0.45, 0.65)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints()
    lbl:SetText(ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.label .. "|r")

    local capturedMod = mod

    btn:SetScript("OnEnter", function(s)
      s:SetBackdropBorderColor(capturedMod.col.r, capturedMod.col.g, capturedMod.col.b, 0.95)
      GameTooltip:SetOwner(s, "ANCHOR_NONE")
      GameTooltip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -6)
      if C_AddOns.IsAddOnLoaded(capturedMod.addonName) then
        GameTooltip:AddLine("|cFFFFD700" .. capturedMod.addonName .. "|r")
        GameTooltip:AddLine("Clic gauche : ouvrir / fermer", 0.80, 0.80, 0.90)
      else
        GameTooltip:AddLine("|cFFFF5555" .. capturedMod.addonName .. "|r")
        GameTooltip:AddLine("Non installé", 0.90, 0.40, 0.40)
        GameTooltip:AddLine("Clic : voir le lien de téléchargement", 0.65, 0.65, 0.65)
      end
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
      UpdateTabHighlights()
      GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
      OnTabClick(capturedMod)
    end)

    tabButtons[i] = btn
  end

  -- Positionne tout selon l'orientation + applique l'échelle
  LayoutBar()
end

-- ================================================================
-- MISE EN PAGE DE LA BARRE (horizontale ou verticale) + ÉCHELLE
-- Repositionne logo, séparateur, onglets et cluster droit.
-- Appelée à la construction et à chaque changement de réglage.
-- ================================================================
-- Un module est-il visible dans la barre ? (réglage utilisateur, défaut oui)
local function IsModuleVisible(mod)
  return not (TibiSuiteDB.hidden and TibiSuiteDB.hidden[mod.key])
end

function LayoutBar()
  if not barFrame then return end
  TibiSuiteDB.hidden = TibiSuiteDB.hidden or {}
  local logo     = barFrame._logo
  local sep      = barFrame._sep
  local closeBtn = barFrame._close
  local openAll  = barFrame._openAll
  local closeAll = barFrame._closeAll

  barFrame:SetScale(TibiSuiteDB.scale or 1.0)

  -- helper : réinitialise l'ancrage
  local function anchor(f, ...) f:ClearAllPoints() f:SetPoint(...) end

  -- Onglets à afficher (filtre utilisateur) : on masque les autres
  local vis = {}
  for i, mod in ipairs(MODULES) do
    local btn = tabButtons[i]
    if btn then
      if IsModuleVisible(mod) then
        btn:Show()
        vis[#vis + 1] = btn
      else
        btn:Hide()
      end
    end
  end
  local m = #vis

  if not TibiSuiteDB.vertical then
    -- ---------------- MODE HORIZONTAL ----------------
    local clusterW = ALL_W + ALL_GAP + ALL_W + ALL_GAP + CLOSE_W
    local tabsW = (m > 0) and (m * (TAB_W + TAB_GAP) - TAB_GAP) or 0
    local barH = TAB_H + 14
    local barW = MARGIN + LOGO_W + tabsW + ALL_GAP + clusterW + MARGIN
    barFrame:SetSize(barW, barH)

    logo:SetSize(LOGO_W - 10, barH - 6)
    anchor(logo, "LEFT", barFrame, "LEFT", MARGIN, 0)

    sep:SetSize(1, barH - 12)
    anchor(sep, "LEFT", barFrame, "LEFT", MARGIN + LOGO_W - 8, 0)

    local tabStartX = MARGIN + LOGO_W
    for j, btn in ipairs(vis) do
      btn:SetSize(TAB_W, TAB_H)
      anchor(btn, "LEFT", barFrame, "LEFT",
        tabStartX + (j - 1) * (TAB_W + TAB_GAP), 0)
    end

    -- Tailles fixes (au cas où l'on revient du mode vertical)
    openAll:SetSize(ALL_W, ALL_W)
    closeAll:SetSize(ALL_W, ALL_W)
    closeBtn:SetSize(CLOSE_W, CLOSE_W)

    anchor(closeBtn, "RIGHT", barFrame, "RIGHT", -MARGIN + 2, 0)
    anchor(closeAll, "RIGHT", closeBtn, "LEFT", -ALL_GAP, 0)
    anchor(openAll,  "RIGHT", closeAll, "LEFT", -ALL_GAP, 0)
  else
    -- ---------------- MODE VERTICAL ------------------
    local logoH = 26
    local tabsH = (m > 0) and (m * (TAB_H + TAB_GAP) - TAB_GAP) or 0
    local barW  = MARGIN + VCOL_W + MARGIN
    local barH  = MARGIN + logoH + 6 + tabsH + 8 + ALL_W + 6 + CLOSE_W + MARGIN
    barFrame:SetSize(barW, barH)

    logo:SetSize(VCOL_W, logoH)
    anchor(logo, "TOP", barFrame, "TOP", 0, -MARGIN)

    sep:SetSize(VCOL_W, 1)
    anchor(sep, "TOP", logo, "BOTTOM", 0, -3)

    local prev = sep
    for j, btn in ipairs(vis) do
      btn:SetSize(VCOL_W, TAB_H)
      if j == 1 then
        anchor(btn, "TOP", sep, "BOTTOM", 0, -6)
      else
        anchor(btn, "TOP", prev, "BOTTOM", 0, -TAB_GAP)
      end
      prev = btn
    end

    -- Point d'ancrage du cluster : dernier onglet visible, sinon séparateur
    local lastAnchor = (m > 0) and vis[m] or sep
    local topOff     = (m > 0) and -8 or -6

    local halfW = (VCOL_W - ALL_GAP) / 2
    openAll:SetSize(halfW, ALL_W)
    closeAll:SetSize(halfW, ALL_W)
    anchor(openAll,  "TOPLEFT",  lastAnchor, "BOTTOMLEFT",  0, topOff)
    anchor(closeAll, "TOPRIGHT", lastAnchor, "BOTTOMRIGHT", 0, topOff)

    closeBtn:SetSize(VCOL_W, CLOSE_W)
    anchor(closeBtn, "TOPLEFT", openAll, "BOTTOMLEFT", 0, -6)
  end
end

-- ================================================================
-- PANNEAU D'OPTIONS  (/ts config, ou clic droit sur le logo)
-- Contrôles faits main, aucune dépendance aux templates Blizzard.
-- ================================================================
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.70, 1.50, 0.05

-- Petit bouton texte réutilisable (avec surbrillance de bordure au survol)
local function MakeTextButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop(MakeBackdrop(3))
  b:SetBackdropColor(0.12, 0.09, 0.16, 0.95)
  b:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.75)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetAllPoints()
  fs:SetText(text)
  b._label = fs
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(0.85, 0.72, 0.30, 1.0) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.75) end)
  return b
end

-- Met à jour l'affichage des contrôles selon la DB
function RefreshOptions()
  local f = optionsFrame
  if not f then return end
  f._scaleVal:SetText(string.format("%d%%",
    math.floor((TibiSuiteDB.scale or 1) * 100 + 0.5)))
  f._lockBtn._label:SetText("Barre verrouillée : " ..
    (TibiSuiteDB.locked and "|cFF66FF66Oui|r" or "|cFFFF7777Non|r"))
  f._vertBtn._label:SetText("Barre verticale : " ..
    (TibiSuiteDB.vertical and "|cFF66FF66Oui|r" or "|cFFFF7777Non|r"))

  -- Bascules par module (statut d'installation + affiché/masqué)
  if f._moduleRows then
    TibiSuiteDB.hidden = TibiSuiteDB.hidden or {}
    for _, row in ipairs(f._moduleRows) do
      local mod     = row.mod
      local loaded  = C_AddOns.IsAddOnLoaded(mod.addonName)
      local dot     = loaded and (ICON_OK .. " ") or (ICON_MISS .. " ")
      local visible = not TibiSuiteDB.hidden[mod.key]
      local state   = visible and "|cFF66FF66affiché|r" or "|cFFFF7777masqué|r"
      row.btn._label:SetText(dot ..
        ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.label .. "|r   " .. state)
      row.btn._label:SetJustifyH("CENTER")
    end
  end
end

local function BuildOptions()
  if optionsFrame then return end
  local f = CreateFrame("Frame", "TibiSuiteOptions", UIParent, "BackdropTemplate")
  optionsFrame = f
  f:SetSize(300, 470)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop(MakeBackdrop(6))
  f:SetBackdropColor(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a)
  f:SetBackdropBorderColor(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("|cFFC41F3BTibiSuite|r  Options")

  local xBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  xBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  xBtn:SetScript("OnClick", function() f:Hide() end)

  -- ── Échelle : label + [-] valeur [+] ──
  local scaleLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scaleLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
  scaleLbl:SetText("Échelle")

  local minus = MakeTextButton(f, 26, 22, "|cFFFFD700-|r")
  minus:SetPoint("LEFT", scaleLbl, "RIGHT", 26, 0)
  local scaleVal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  scaleVal:SetPoint("LEFT", minus, "RIGHT", 8, 0)
  scaleVal:SetWidth(48)
  scaleVal:SetJustifyH("CENTER")
  f._scaleVal = scaleVal
  local plus = MakeTextButton(f, 26, 22, "|cFFFFD700+|r")
  plus:SetPoint("LEFT", scaleVal, "RIGHT", 8, 0)

  local function stepScale(d)
    local v = (TibiSuiteDB.scale or 1) + d
    if v < SCALE_MIN then v = SCALE_MIN elseif v > SCALE_MAX then v = SCALE_MAX end
    TibiSuiteDB.scale = v
    LayoutBar()
    RefreshOptions()
  end
  minus:SetScript("OnClick", function() stepScale(-SCALE_STEP) end)
  plus:SetScript("OnClick",  function() stepScale( SCALE_STEP) end)

  -- ── Verrou ──
  local lockBtn = MakeTextButton(f, 260, 24, "")
  lockBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -84)
  f._lockBtn = lockBtn
  lockBtn:SetScript("OnClick", function()
    TibiSuiteDB.locked = not TibiSuiteDB.locked
    RefreshOptions()
  end)

  -- ── Orientation verticale ──
  local vertBtn = MakeTextButton(f, 260, 24, "")
  vertBtn:SetPoint("TOPLEFT", lockBtn, "BOTTOMLEFT", 0, -8)
  f._vertBtn = vertBtn
  vertBtn:SetScript("OnClick", function()
    TibiSuiteDB.vertical = not TibiSuiteDB.vertical
    LayoutBar()
    RefreshOptions()
  end)

  -- ── Actions : Tout ouvrir / Tout fermer / Recentrer ──
  local openA = MakeTextButton(f, 80, 24, "|cFF66FF66Tout ouvrir|r")
  openA:SetPoint("TOPLEFT", vertBtn, "BOTTOMLEFT", 0, -14)
  openA:SetScript("OnClick", function() SetAllModules(true) end)

  local closeA = MakeTextButton(f, 80, 24, "|cFFFFAA55Tout fermer|r")
  closeA:SetPoint("LEFT", openA, "RIGHT", 8, 0)
  closeA:SetScript("OnClick", function() SetAllModules(false) end)

  local recenter = MakeTextButton(f, 80, 24, "|cFFAAD4FFRecentrer|r")
  recenter:SetPoint("LEFT", closeA, "RIGHT", 8, 0)
  recenter:SetScript("OnClick", function()
    TibiSuiteCharDB.barPos = { point = "CENTER", x = 0, y = -300 }
    if barFrame then
      RestoreBarPos()
      barFrame:Show()
      TibiSuiteCharDB.barOpen = true
      UpdateTabHighlights()
    end
  end)

  -- ── Séparateur + section "Onglets affichés" ──
  local div = f:CreateTexture(nil, "ARTWORK")
  div:SetSize(260, 1)
  div:SetPoint("TOPLEFT", openA, "BOTTOMLEFT", 0, -12)
  div:SetColorTexture(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.40)

  local secLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  secLbl:SetPoint("TOPLEFT", div, "BOTTOMLEFT", 0, -8)
  secLbl:SetText("Onglets affichés dans la barre")

  -- Une bascule par module (masque / affiche l'onglet)
  f._moduleRows = {}
  local prev = secLbl
  for _, mod in ipairs(MODULES) do
    local capturedMod = mod
    local row = MakeTextButton(f, 260, 22, "")
    if prev == secLbl then
      row:SetPoint("TOPLEFT", secLbl, "BOTTOMLEFT", 0, -6)
    else
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
    end
    row:SetScript("OnClick", function()
      TibiSuiteDB.hidden = TibiSuiteDB.hidden or {}
      TibiSuiteDB.hidden[capturedMod.key] = not TibiSuiteDB.hidden[capturedMod.key]
      LayoutBar()
      RefreshOptions()
    end)
    f._moduleRows[#f._moduleRows + 1] = { btn = row, mod = mod }
    prev = row
  end

  -- Raccourci : masquer tous les modules non installés
  local hideMissing = MakeTextButton(f, 260, 24, "|cFFAAD4FFMasquer les non-installés|r")
  hideMissing:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
  hideMissing:SetScript("OnClick", function()
    TibiSuiteDB.hidden = TibiSuiteDB.hidden or {}
    for _, mod in ipairs(MODULES) do
      if not C_AddOns.IsAddOnLoaded(mod.addonName) then
        TibiSuiteDB.hidden[mod.key] = true
      end
    end
    LayoutBar()
    RefreshOptions()
  end)
end

function OpenOptions()
  BuildOptions()
  RefreshOptions()
  optionsFrame:Show()
end

-- ================================================================
-- BOUTON MINIMAP
-- ================================================================
local function GetMinimapRadius()
  return (Minimap:GetWidth() / 2) + 10
end

local function SetMinimapPos(angle)
  TibiSuiteDB.mmAngle = angle
  local rad    = math.rad(angle)
  local radius = GetMinimapRadius()
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(rad) * radius,
    math.sin(rad) * radius)
end

local function BuildMinimapButton()
  if minimapBtn then return end

  minimapBtn = CreateFrame("Button", "TibiSuiteMinimapBtn", Minimap)
  minimapBtn:SetSize(32, 32)
  minimapBtn:SetFrameStrata("MEDIUM")
  minimapBtn:SetFrameLevel(8)
  minimapBtn:SetMovable(false)
  minimapBtn:EnableMouse(true)
  minimapBtn:SetClampedToScreen(true)
  minimapBtn:SetToplevel(true)

  -- ── Icône (avec mask circulaire Blizzard) ─────────────────────
  local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
  icon:SetSize(24, 24)
  icon:SetTexture("Interface\\AddOns\\TibiSuite\\medias\\TibiSuite")

  local mask = minimapBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture(
    "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  -- ── Ring doré Blizzard ────────────────────────────────────────
  local ring = minimapBtn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(52, 52)
  ring:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  -- ── Position initiale ─────────────────────────────────────────
  SetMinimapPos(TibiSuiteDB.mmAngle or 200)

  -- ── Drag orbital ─────────────────────────────────────────────
  minimapBtn:RegisterForDrag("LeftButton")
  -- Nécessaire pour que OnClick reste actif même avec RegisterForDrag
  minimapBtn:RegisterForClicks("AnyUp")

  minimapBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my  = Minimap:GetCenter()
      local uiScale = UIParent:GetEffectiveScale()
      local cx, cy  = GetCursorPosition()
      local angle   = math.deg(math.atan2(
        (cy / uiScale) - my,
        (cx / uiScale) - mx))
      SetMinimapPos(angle)
    end)
  end)
  minimapBtn:SetScript("OnDragStop", function(s)
    s:SetScript("OnUpdate", nil)
  end)

  -- ── Recalcul si la minimap change de taille (ElvUI / Dominos) ─
  local resizeWatcher = CreateFrame("Frame")
  resizeWatcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  resizeWatcher:SetScript("OnEvent", function()
    SetMinimapPos(TibiSuiteDB.mmAngle or 200)
  end)

  -- ── Clic gauche : toggle de la barre ; clic droit : options ──
  minimapBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      OpenOptions()
    else
      if barFrame and barFrame:IsShown() then
        barFrame:Hide()
        TibiSuiteCharDB.barOpen = false
      else
        BuildBar()
        barFrame:Show()
        TibiSuiteCharDB.barOpen = true
        UpdateTabHighlights()
      end
    end
  end)

  -- ── Tooltip ───────────────────────────────────────────────────
  minimapBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF9480FFTibiSuite|r")
    GameTooltip:AddLine("Clic gauche : afficher / masquer la barre", 0.80, 0.80, 0.90)
    GameTooltip:AddLine("Clic droit : options", 0.80, 0.80, 0.90)
    GameTooltip:AddLine("|cFFFFD700Glisser|r pour repositionner",  0.65, 0.65, 0.65)
    GameTooltip:AddLine(" ")
    -- Statut de chaque module
    for _, mod in ipairs(MODULES) do
      local ok = C_AddOns.IsAddOnLoaded(mod.addonName)
      local status = ok and (ICON_OK .. " ") or (ICON_MISS .. " ")
      GameTooltip:AddLine(status .. ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.addonName .. "|r")
    end
    GameTooltip:Show()
  end)
  minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ================================================================
-- SUPPRESSION DES BOUTONS MINIMAP INDIVIDUELS
-- Cachés dès que TibiSuite est actif pour éviter les doublons.
-- ================================================================
local INDIVIDUAL_MM_BTNS = {
  "DTMinimapBtn",            -- DailyTracker
  "DGNMinimapBtn",           -- DgnTracker
  "LegTrackerMinimapBtn",    -- LegTracker
  "RNTMinimapBtn",           -- RenTracker
  "LvlHistoryMinimapButton", -- LvlHistory
  "WeeklyCompassMinimapButton", -- WeeklyCompass
}

local function HideIndividualMinimapButtons()
  for _, name in ipairs(INDIVIDUAL_MM_BTNS) do
    local btn = _G[name]
    if btn and btn.Hide then
      btn:Hide()
      -- Robustesse : certains modules (ou LibDBIcon) re-affichent leur bouton
      -- après notre passage. On pose un hook OnShow unique qui le re-masque,
      -- pour éviter les doublons de boutons minimap tant que TibiSuite est actif.
      if not btn.__tibiSuiteHooked then
        btn.__tibiSuiteHooked = true
        btn:HookScript("OnShow", function(self) self:Hide() end)
      end
    end
  end
end

-- ================================================================
-- ADDON COMPARTMENT (panneau addons Blizzard dans le header UI)
-- ================================================================
-- Bascule l'affichage de la barre (fabrique la barre au besoin)
local function ToggleBar()
  if barFrame and barFrame:IsShown() then
    barFrame:Hide()
    TibiSuiteCharDB.barOpen = false
  else
    BuildBar()
    barFrame:Show()
    TibiSuiteCharDB.barOpen = true
    UpdateTabHighlights()
  end
end

function TibiSuite_OnAddonCompartmentClick()
  ToggleBar()
end

function TibiSuite_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cFF9480FFTibiSuite|r")
  GameTooltip:AddLine("Suite de trackers, par Tibiscui", 0.90, 0.90, 0.90)
  GameTooltip:AddLine(" ")
  for _, mod in ipairs(MODULES) do
    local ok     = C_AddOns.IsAddOnLoaded(mod.addonName)
    local status = ok and ICON_OK or ICON_MISS
    GameTooltip:AddLine(
      status .. " " .. ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.addonName .. "|r",
      0.80, 0.80, 0.80)
  end
  GameTooltip:Show()
end

function TibiSuite_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ================================================================
-- COMMANDE SLASH  /tibisuite
-- ================================================================
SLASH_TIBISUITE1 = "/tibisuite"
SLASH_TIBISUITE2 = "/ts"
SlashCmdList["TIBISUITE"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "config" or msg == "options" then
    OpenOptions()

  elseif msg == "reset" then
    -- Recentre la barre (secours si elle a été perdue hors écran)
    TibiSuiteCharDB.barPos = { point = "CENTER", x = 0, y = -300 }
    if barFrame then
      RestoreBarPos()
      barFrame:Show()
      TibiSuiteCharDB.barOpen = true
      UpdateTabHighlights()
    end
    print("|cFF9480FFTibiSuite|r barre recentrée.")

  elseif msg == "openall" then
    SetAllModules(true)

  elseif msg == "closeall" then
    SetAllModules(false)

  elseif msg == "lock" then
    TibiSuiteDB.locked = not TibiSuiteDB.locked
    RefreshOptions()
    print("|cFF9480FFTibiSuite|r barre " ..
      (TibiSuiteDB.locked and "|cFF66FF66verrouillée|r" or "|cFFFF7777déverrouillée|r") .. ".")

  elseif msg == "vertical" then
    TibiSuiteDB.vertical = not TibiSuiteDB.vertical
    BuildBar()
    LayoutBar()
    RefreshOptions()
    print("|cFF9480FFTibiSuite|r orientation " ..
      (TibiSuiteDB.vertical and "verticale" or "horizontale") .. ".")

  elseif msg == "help" or msg == "?" then
    print("|cFF9480FFTibiSuite|r v" .. VERSION .. " - commandes :")
    print("  |cFFFFD700/ts|r : afficher / masquer la barre")
    print("  |cFFFFD700/ts config|r : panneau d'options")
    print("  |cFFFFD700/ts openall|r / |cFFFFD700closeall|r : tout ouvrir / fermer")
    print("  |cFFFFD700/ts lock|r : verrouiller / déverrouiller")
    print("  |cFFFFD700/ts vertical|r : basculer horizontale / verticale")
    print("  |cFFFFD700/ts reset|r : recentrer la barre")

  else
    ToggleBar()
  end
end

-- ================================================================
-- SUPPORT LibDataBroker (optionnel)
-- Si LibDataBroker-1.1 est présent (Titan Panel, ElvUI, Bazooka...),
-- on expose un objet "launcher" pour brancher TibiSuite dans une
-- barre de données. Le bouton minimap fait maison reste actif :
-- LDB ne crée pas d'icône minimap, donc aucun doublon.
-- ================================================================
local function SetupLDB()
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  if not LDB then return end
  if LDB:GetDataObjectByName("TibiSuite") then return end  -- déjà enregistré

  LDB:NewDataObject("TibiSuite", {
    type  = "launcher",
    icon  = "Interface\\AddOns\\TibiSuite\\medias\\TibiSuite",
    label = "TibiSuite",
    OnClick = function(_, button)
      if button == "RightButton" then
        OpenOptions()
      else
        ToggleBar()
      end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("|cFF9480FFTibiSuite|r v" .. VERSION)
      tt:AddLine("Clic gauche : afficher / masquer la barre", 0.80, 0.80, 0.90)
      tt:AddLine("Clic droit : options", 0.80, 0.80, 0.90)
      tt:AddLine(" ")
      for _, mod in ipairs(MODULES) do
        local ok = C_AddOns.IsAddOnLoaded(mod.addonName)
        local status = ok and (ICON_OK .. " ") or (ICON_MISS .. " ")
        tt:AddLine(status .. ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.addonName .. "|r")
      end
    end,
  })
end

-- ================================================================
-- INITIALISATION
-- ================================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")

evFrame:SetScript("OnEvent", function(_, event, arg1)

  -- ── ADDON_LOADED : TibiSuite vient d'être chargé ──────────────
  if event == "ADDON_LOADED" and arg1 == ADDON then

    -- Réglages compte : on comble les champs manquants avec les défauts
    for k, v in pairs(DEFAULTS) do
      if TibiSuiteDB[k] == nil then TibiSuiteDB[k] = v end
    end
    -- Visibilité des onglets (table set : hidden[key]=true si masqué)
    if type(TibiSuiteDB.hidden) ~= "table" then TibiSuiteDB.hidden = {} end

    -- Migration : dans les versions antérieures, position et état d'ouverture
    -- étaient stockés au niveau COMPTE. On les rapatrie une fois vers la DB
    -- par personnage, puis on nettoie les anciens champs.
    if TibiSuiteCharDB.barPos == nil and type(TibiSuiteDB.barPos) == "table" then
      TibiSuiteCharDB.barPos = TibiSuiteDB.barPos
    end
    TibiSuiteDB.barPos  = nil
    TibiSuiteDB.barOpen = nil

    -- État par personnage : ouverte par défaut au premier login du perso
    if TibiSuiteCharDB.barOpen == nil then TibiSuiteCharDB.barOpen = true end

    BuildMinimapButton()
    BuildBar()
    SetupLDB()

  -- ── PLAYER_LOGIN : tous les addons sont chargés ───────────────
  elseif event == "PLAYER_LOGIN" then

    -- Masquer les boutons minimap individuels (ils sont créés à ce stade)
    C_Timer.After(0.5, HideIndividualMinimapButtons)

    -- Restaurer l'état de la barre propre à ce personnage
    if barFrame then
      if TibiSuiteCharDB.barOpen then
        barFrame:Show()
        UpdateTabHighlights()
      else
        barFrame:Hide()
      end
    end

    print("|cFF9480FFTibiSuite|r v" .. VERSION .. " chargé  -  "
      .. "|cFFFFD700/ts|r pour la barre, |cFFFFD700/ts config|r pour les options, "
      .. "|cFFFFD700/ts help|r pour l'aide.")
  end
end)
