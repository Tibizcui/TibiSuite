-- ================================================================
-- TibiSuite v1.0.0
-- Auteur  : Tibiscui - Kirin Tor
-- Rôle    : Wrapper léger — barre d'onglets unifiée pour les
--           4 trackers (DailyTracker, DgnTracker, LegTracker,
--           RenTracker). Fonctionne avec 1, 2, 3 ou 4 modules
--           installés. Affiche un message CurseForge si un module
--           est absent.
-- ================================================================

local ADDON = "TibiSuite"

-- SavedVariables : persistance entre les sessions
TibiSuiteDB = TibiSuiteDB or {
  mmAngle = 200,                           -- angle du bouton sur la minimap
  barPos  = { point="CENTER", x=0, y=-300 }, -- position de la barre d'onglets
  barOpen = true,                          -- barre visible au login ?
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
    col         = { r=0.41, g=0.80, b=0.94 },  -- bleu Mage (#69CCF0)
    curseUrl    = "https://www.curseforge.com/wow/addons/dailytracker",
  },
  {
    key         = "Dgn",
    addonName   = "DgnTracker",
    label       = "Donjons",
    frameGlobal = "DGNMainFrame",
    mmBtnGlobal = "DGNMinimapBtn",
    toggleFn    = "DgnTracker_Toggle",
    col         = { r=0.00, g=0.44, b=0.87 },  -- bleu Shaman (#0070DE)
    curseUrl    = "https://www.curseforge.com/wow/addons/dgntracker",
  },
  {
    key         = "Leg",
    addonName   = "LegTracker",
    label       = "Legend.",
    frameGlobal = "LegTrackerMainFrame",
    mmBtnGlobal = "LegTrackerMinimapBtn",
    toggleFn    = "LegTracker_Toggle",
    col         = { r=1.00, g=0.50, b=0.00 },  -- orange légendaire (#FF8000)
    curseUrl    = "https://www.curseforge.com/wow/addons/legtracker",
  },
  {
    key         = "Rep",
    addonName   = "RenTracker",
    label       = "Reput.",
    frameGlobal = "RTMainFrame",
    mmBtnGlobal = "RTMinimapBtn",
    toggleFn    = "RenTracker_Toggle",
    col         = { r=1.00, g=0.82, b=0.00 },  -- or Quête (#FFD100)
    curseUrl    = "https://www.curseforge.com/wow/addons/tibirentracker",
  },
}

-- ================================================================
-- DIMENSIONS DE LA BARRE
-- ================================================================
local TAB_W      = 90    -- largeur d'un onglet
local TAB_H      = 30    -- hauteur d'un onglet
local TAB_GAP    = 3     -- espace entre onglets
local MARGIN     = 8     -- marge gauche/droite de la barre
local LOGO_W     = 108   -- largeur réservée pour icône + "TibiSuite" + séparateur
local CLOSE_W    = 22    -- largeur du bouton fermer
-- Largeur totale de la barre
local BAR_W = MARGIN + LOGO_W + (#MODULES * (TAB_W + TAB_GAP)) - TAB_GAP + CLOSE_W + MARGIN
local BAR_H = TAB_H + 14   -- espace vertical autour des onglets

-- ================================================================
-- VARIABLES LOCALES (initialisées dans BuildX)
-- ================================================================
local barFrame         -- la barre d'onglets principale
local tabButtons = {}  -- boutons d'onglets [1..4]
local minimapBtn       -- bouton sur la minimap
local placeholderFrame -- frame "addon absent"

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

  -- Appel de la fonction Toggle publique de l'addon
  -- (définie en fin de chaque addon lors de l'étape 2)
  local fn = _G[mod.toggleFn]
  if fn then
    fn()
  else
    -- Fallback de sécurité : manipulation directe de la frame
    local f = _G[mod.frameGlobal]
    if f then
      if f:IsShown() then f:Hide() else f:Show() end
    end
  end

  -- Mettre à jour les highlights après un court délai
  -- (le frame peut mettre 1 frame à changer d'état)
  C_Timer.After(0.05, UpdateTabHighlights)
end

-- ================================================================
-- CONSTRUCTION DE LA BARRE D'ONGLETS
-- ================================================================
local function BuildBar()
  if barFrame then return end  -- déjà construite

  -- ── Cadre principal de la barre ───────────────────────────────
  barFrame = CreateFrame("Frame", "TibiSuiteBar", UIParent, "BackdropTemplate")
  barFrame:SetSize(BAR_W, BAR_H)
  barFrame:SetFrameStrata("MEDIUM")
  barFrame:SetMovable(true)   -- requis pour StartMoving() depuis logoBtn
  barFrame:EnableMouse(true)
  barFrame:SetBackdrop(MakeBackdrop(5))
  barFrame:SetBackdropColor(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a)
  barFrame:SetBackdropBorderColor(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b)
  barFrame:Hide()

  -- Restauration de la position sauvegardée
  -- Fallback de sécurité : barPos peut être nil si la DB vient d'une version antérieure
  local pos = TibiSuiteDB.barPos or { point = "CENTER", x = 0, y = -300 }
  barFrame:ClearAllPoints()
  barFrame:SetPoint(
    pos.point or "CENTER",
    UIParent,
    pos.point or "CENTER",
    pos.x or 0,
    pos.y or -300)

  -- ── Zone logo : icône TibiSuite.tga + texte "TibiSuite" ─────────
  -- Conteneur cliquable (ferme la barre, comme le bouton ×)
  local logoBtn = CreateFrame("Button", nil, barFrame)
  logoBtn:SetSize(LOGO_W - 10, BAR_H - 6)
  logoBtn:SetPoint("LEFT", barFrame, "LEFT", MARGIN, 0)

  -- Icône TibiSuite.tga avec masque circulaire (même technique que la minimap)
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

  -- Texte "TibiSuite" en rouge #C41F3B
  local logoText = logoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  logoText:SetPoint("LEFT", logoIcon, "RIGHT", 6, 0)
  logoText:SetText("|cFFC41F3BTibiSuite|r")

  -- ── Drag : clic gauche maintenu sur la zone logo déplace la barre ──
  -- Un clic rapide = OnClick (masquer)
  -- Un clic maintenu + mouvement = OnDragStart (déplacer)
  logoBtn:RegisterForDrag("LeftButton")

  logoBtn:SetScript("OnDragStart", function()
    barFrame:StartMoving()
    GameTooltip:Hide()
  end)
  logoBtn:SetScript("OnDragStop", function()
    barFrame:StopMovingOrSizing()
    local point, _, _, x, y = barFrame:GetPoint()
    TibiSuiteDB.barPos = { point = point, x = x, y = y }
  end)

  -- Hover : surbrillance rouge de l'icône + tooltip avec les deux actions
  logoBtn:SetScript("OnEnter", function()
    logoIcon:SetVertexColor(1.1, 0.75, 0.75)   -- highlight rouge doux
    -- ANCHOR_NONE + SetPoint = contrôle précis, évite la superposition des onglets
    GameTooltip:SetOwner(logoBtn, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", logoBtn, "BOTTOMLEFT", 0, -6)
    GameTooltip:AddLine("|cFFC41F3BTibiSuite|r v1.0.0")
    GameTooltip:AddLine("|cFFFFD700Clic|r : masquer la barre",        0.80, 0.80, 0.85)
    GameTooltip:AddLine("|cFFFFD700Maintien + glisser|r : déplacer",  0.70, 0.70, 0.75)
    GameTooltip:Show()
  end)
  logoBtn:SetScript("OnLeave", function()
    logoIcon:SetVertexColor(1.0, 1.0, 1.0)
    GameTooltip:Hide()
  end)
  logoBtn:SetScript("OnClick", function()
    barFrame:Hide()
    TibiSuiteDB.barOpen = false
  end)

  -- Séparateur vertical or entre le logo et les onglets
  local sep = barFrame:CreateTexture(nil, "ARTWORK")
  sep:SetSize(1, BAR_H - 12)
  sep:SetPoint("LEFT", barFrame, "LEFT", MARGIN + LOGO_W - 8, 0)
  sep:SetColorTexture(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.45)

  -- ── Bouton fermer (×) à droite ────────────────────────────────
  local closeBtn = CreateFrame("Button", nil, barFrame, "BackdropTemplate")
  closeBtn:SetSize(CLOSE_W, CLOSE_W)
  closeBtn:SetPoint("RIGHT", barFrame, "RIGHT", -MARGIN + 2, 0)
  closeBtn:SetBackdrop(MakeBackdrop(3))
  closeBtn:SetBackdropColor(0.14, 0.05, 0.05, 0.90)
  closeBtn:SetBackdropBorderColor(0.55, 0.18, 0.18, 0.70)

  local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  closeX:SetAllPoints()
  closeX:SetText("|cFFFF5555×|r")

  closeBtn:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(1.0, 0.30, 0.30, 1.0)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
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
    TibiSuiteDB.barOpen = false
  end)

  -- ── Onglets des modules ───────────────────────────────────────
  -- Point de départ X des onglets (après le logo)
  local tabStartX = MARGIN + LOGO_W

  for i, mod in ipairs(MODULES) do
    local btn = CreateFrame("Button", nil, barFrame, "BackdropTemplate")
    btn:SetSize(TAB_W, TAB_H)
    btn:SetPoint("LEFT", barFrame, "LEFT",
      tabStartX + (i - 1) * (TAB_W + TAB_GAP), 0)
    btn:SetBackdrop(MakeBackdrop(4))
    -- Couleurs initiales (UpdateTabHighlights les affine au login)
    btn:SetBackdropColor(0.06, 0.03, 0.10, 0.88)
    btn:SetBackdropBorderColor(
      mod.col.r * 0.45, mod.col.g * 0.45, mod.col.b * 0.45, 0.65)

    -- Étiquette colorée
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints()
    lbl:SetText(ColorCode(mod.col.r, mod.col.g, mod.col.b) .. mod.label .. "|r")

    -- Capture de la variable de boucle (important en Lua !)
    local capturedMod = mod

    -- Tooltip au survol
    btn:SetScript("OnEnter", function(s)
      -- Bordure plus vive au survol
      s:SetBackdropBorderColor(capturedMod.col.r, capturedMod.col.g, capturedMod.col.b, 0.95)
      GameTooltip:SetOwner(s, "ANCHOR_NONE")
      GameTooltip:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -6)
      if C_AddOns.IsAddOnLoaded(capturedMod.addonName) then
        GameTooltip:AddLine(
          ColorCode(capturedMod.col.r, capturedMod.col.g, capturedMod.col.b) .. capturedMod.addonName .. "|r")
        GameTooltip:AddLine("Clic gauche : ouvrir / fermer", 0.80, 0.80, 0.90)
      else
        GameTooltip:AddLine(
          "|cFFFF5555" .. capturedMod.addonName .. "|r")
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

  -- ── Clic gauche : toggle de la barre ─────────────────────────
  minimapBtn:SetScript("OnClick", function(_, btn)
    if btn == "LeftButton" then
      if barFrame and barFrame:IsShown() then
        barFrame:Hide()
        TibiSuiteDB.barOpen = false
      else
        BuildBar()
        barFrame:Show()
        TibiSuiteDB.barOpen = true
        UpdateTabHighlights()
      end
    end
  end)

  -- ── Tooltip ───────────────────────────────────────────────────
  minimapBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF9480FFTibiSuite|r")
    GameTooltip:AddLine("Clic : afficher / masquer la barre", 0.80, 0.80, 0.90)
    GameTooltip:AddLine("|cFFFFD700Glisser|r pour repositionner",  0.65, 0.65, 0.65)
    GameTooltip:AddLine(" ")
    -- Statut de chaque module
    for _, mod in ipairs(MODULES) do
      local ok = C_AddOns.IsAddOnLoaded(mod.addonName)
      local status = ok and "|cFF44FF44●|r " or "|cFFFF5555●|r "
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
local function HideIndividualMinimapButtons()
  local btns = {
    "DTMinimapBtn",          -- DailyTracker
    "DGNMinimapBtn",         -- DgnTracker
    "LegTrackerMinimapBtn",  -- LegTracker
    "RTMinimapBtn",          -- RenTracker
  }
  for _, name in ipairs(btns) do
    local btn = _G[name]
    if btn and btn.Hide then btn:Hide() end
  end
end

-- ================================================================
-- ADDON COMPARTMENT (panneau addons Blizzard dans le header UI)
-- ================================================================
function TibiSuite_OnAddonCompartmentClick()
  if barFrame and barFrame:IsShown() then
    barFrame:Hide()
    TibiSuiteDB.barOpen = false
  else
    BuildBar()
    barFrame:Show()
    TibiSuiteDB.barOpen = true
    UpdateTabHighlights()
  end
end

function TibiSuite_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cFF9480FFTibiSuite|r")
  GameTooltip:AddLine("Suite de trackers — Tibiscui", 0.90, 0.90, 0.90)
  GameTooltip:AddLine(" ")
  for _, mod in ipairs(MODULES) do
    local ok     = C_AddOns.IsAddOnLoaded(mod.addonName)
    local status = ok and "|cFF44FF44✓|r" or "|cFFFF5555✗|r"
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
SlashCmdList["TIBISUITE"] = function()
  if barFrame and barFrame:IsShown() then
    barFrame:Hide()
    TibiSuiteDB.barOpen = false
  else
    BuildBar()
    barFrame:Show()
    TibiSuiteDB.barOpen = true
    UpdateTabHighlights()
  end
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

    -- Initialisation défensive de chaque champ DB (migration entre versions)
    -- Si TibiSuiteDB existait déjà vide ou incomplet, on comble les manques
    TibiSuiteDB.mmAngle = TibiSuiteDB.mmAngle or 200
    TibiSuiteDB.barPos  = TibiSuiteDB.barPos  or { point = "CENTER", x = 0, y = -300 }
    if TibiSuiteDB.barOpen == nil then TibiSuiteDB.barOpen = true end

    BuildMinimapButton()
    BuildBar()

  -- ── PLAYER_LOGIN : tous les addons sont chargés ───────────────
  elseif event == "PLAYER_LOGIN" then

    -- Masquer les boutons minimap individuels (ils sont créés à ce stade)
    C_Timer.After(0.5, HideIndividualMinimapButtons)

    -- Restaurer l'état de la barre (ouverte ou fermée au logout)
    if TibiSuiteDB.barOpen then
      if barFrame then
        barFrame:Show()
        UpdateTabHighlights()
      end
    end

    print("|cFF9480FFTibiSuite|r v1.0.0 chargé  —  "
      .. "|cFFFFD700/tibisuite|r ou |cFFFFD700/ts|r pour ouvrir la barre.")
  end
end)
