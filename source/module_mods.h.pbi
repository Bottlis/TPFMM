﻿DeclareModule mods
  EnableExplicit
  
  #SCANNER_VERSION = #pb_editor_buildcount
  
  Structure backup  ;-- information about last backup if available
    date.i
    filename$
  EndStructure
  
  Structure aux     ;-- additional information about mod
    type$             ; "mod", "map", "dlc", ...
    isVanilla.b       ; pre-installed mods should not be uninstalled
    luaDate.i         ; date of info.lua (reload info when newer version available)
    luaLanguage$      ; language of currently loaded info from mod.lua -> reload mod.lua when language changes
    installDate.i     ; date of first encounter of this file (added to TPFMM)
    repoTimeChanged.i ; timechanged value from repository if installed from repo (if timechanged in repo > timechanged in mod: update available
    tfnetID.i         ; entry ID in transportfever.net download section
    workshopID.i      ; fileID in Steam Workshop
    *repo_mod         ; (temp) link to mod in repository
    sv.i              ; scanner version, rescan if newer scanner version is used
    hidden.b          ; hidden from overview ("visible" in mod.lua)
    backup.backup     ; backup information (local)
  EndStructure
  
  
  Structure author  ;-- information about author
    name$             ; name of author
    role$             ; CREATOR, CO_CREATOR, TESTER, BASED_ON, OTHER
    text$             ; optional, additional text to display
    tfnetId.i         ; user ID on transportfever.net
    steamId.i         ; SteamID
    steamProfile$     ; Steam profile link
  EndStructure
  
  Structure dependency ;-- dependency information
    mod$            ; folder name
    version.i       ; minorVersion
    steamId.i       ; steam workshop ID
    tfnetId.i       ; transportfever.net ID
    exactMatch.b    ; is only exact version match allowed?
  EndStructure
  
  Structure mod           ;-- information about mod/dlc
    tpf_id$                 ; folder name in game: author_name_version or steam workshop ID
    name$                   ; name of mod
    majorVersion.i          ; first part of version number, identical to version in ID string
    minorVersion.i          ; latter part of version number
    version$
    severityAdd$            ; potential impact to game when adding mod
    severityRemove$         ; potential impact to game when removeing mod
    description$            ; optional description
    List authors.author()   ; information about author(s)
    List tags$()            ; list of tags
    List tagsLocalized$()   ; 
    minGameVersion.i        ; minimum required build number of game
    List dependencies.dependency()    ; list of required mods (folder name of required mod)
    url$                    ; website with further information
    
    aux.aux                 ; auxiliary information
  EndStructure
  
  Declare register(window, gadgetModList, gadgetFilterString, gadgetFilterHidden, gadgetFilterVanilla, gadgetFilterFolder)
  
  Declare init()    ; allocate new mod structure, return *mod
  Declare free(*mod.mod) ; free *mod structure
  Declare freeAll() ; free all mods in map
  Declare loadList(*data) ; load up programm (read mods from different locations)
  Declare saveList()
  
  Declare generateID(*mod.mod, id$ = "")
  
  Declare.s getModFolder(id$ = "", type$ = "mod")
  
  ; required interfaces:
  ; install(*data) - extract an archive to the game folder
  ; uninstall(*data) - remove a mod folder from the game
  ; 
  ; download(*data) - provided by repository module! -> dowloads file to temp dir and calls install procedure
  
  ; check mod functions:
  
  Declare canUninstall(*mod.mod)
  Declare canBackup(*mod.mod)
  Declare isInstalled(source$, id)
  
  ; queue callbacks:
  Declare install(*data)    ; check and extract archive to game folder
  Declare uninstall(*data)  ; remove mod folder from game, maybe create a security backup by zipping content
  Declare backup(*data)     ; backup mod
  
  ; export
  Declare exportList(all=#False)
  
  ; display callbacks
  Declare displayMods()
  Declare displayDLCs()
  
  Declare getPreviewImage(*mod.mod, original=#False)
EndDeclareModule
