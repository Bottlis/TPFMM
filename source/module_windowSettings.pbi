DeclareModule windowSettings
  EnableExplicit
  
  Global window
  
  Declare create(parentWindow)
  Declare show()
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_repository.h.pbi"
XIncludeFile "module_aes.pbi"


Module windowSettings
  
  Global _parentW, _dialog
  Global NewMap gadget()
  
  Declare updateGadgets()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure resize()
    ; nothing to do
  EndProcedure
  
  Procedure GadgetCloseSettings() ; close settings window and apply settings
    HideWindow(window, #True)
    DisableWindow(_parentW, #False)
    SetActiveWindow(_parentW)
    
    If misc::checkGameDirectory(main::gameDirectory$) <> 0
      debugger::add("windowSettings() - gameDirectory not correct or not set - exit TPFMM now")
      main::exit()
    EndIf
    
  EndProcedure
  
  Procedure GadgetButtonAutodetect()
    debugger::add("windowSettings::GadgetButtonAutodetect()")
    Protected path$
    
    CompilerSelect #PB_Compiler_OS
      
      CompilerCase #PB_OS_Windows 
        ; try to get Steam install location                         SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800
        path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        EndIf
        ; try to get GOG install location
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\GOG.com\Games\1720767912", "PATH")
        EndIf
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\WOW6432Node\GOG.com\Games\1720767912", "PATH")
        EndIf
        
      CompilerCase #PB_OS_Linux
        path$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/steamapps/common/Transport Fever/")
        
      CompilerCase #PB_OS_MacOS
        path$ = misc::Path(GetHomeDirectory() + "/Library/Application Support/Steam/SteamApps/common/Transport Fever/")
    CompilerEndSelect
    
    If path$ And FileSize(path$) = -2
      debugger::add("windowSettings::GadgetButtonAutodetect() - found {"+path$+"}")
      SetGadgetText(gadget("installationPath"), path$)
      updateGadgets()
      ProcedureReturn #True
    EndIf
    
    debugger::add("windowSettings::GadgetButtonAutodetect() - did not found any TF installation")
    ProcedureReturn #False
  EndProcedure
  
  Procedure GadgetButtonBrowse()
    Protected Dir$
    Dir$ = GetGadgetText(gadget("installationPath"))
    Dir$ = PathRequester("Transport Fever Installation Path", Dir$)
    If Dir$
      SetGadgetText(gadget("installationPath"), Dir$)
    EndIf
    updateGadgets()
  EndProcedure
  
  Procedure GadgetButtonOpenPath()
    misc::openLink(GetGadgetText(gadget("installationPath")))
  EndProcedure
  
  Procedure GadgetSaveSettings()
    Protected Dir$, locale$, restart.i = #False
    dir$ = GetGadgetText(gadget("installationPath"))
    dir$ = misc::Path(dir$)
    
    locale$ = StringField(StringField(GetGadgetText(gadget("languageSelection")), 1, ">"), 2, "<") ; extract string between < and >
    If locale$ = ""
      locale$ = "en"
    EndIf
    
    OpenPreferences(main::settingsFile$, #PB_Preference_GroupSeparator)
    WritePreferenceString("path", dir$)
    WritePreferenceInteger("autobackup", GetGadgetState(gadget("miscAutoBackup")))
    If locale$ <> ReadPreferenceString("locale", "en")
      restart = #True
    EndIf
    WritePreferenceString("locale", locale$)
    WritePreferenceInteger("compareVersion", GetGadgetState(gadget("miscVersionCheck")))
    
    PreferenceGroup("proxy")
    WritePreferenceInteger("enabled", GetGadgetState(gadget("proxyEnabled")))
    WritePreferenceString("server", GetGadgetText(gadget("proxyServer")))
    WritePreferenceString("user", GetGadgetText(gadget("proxyUser")))
    WritePreferenceString("password", aes::encryptString(GetGadgetText(gadget("proxyPassword"))))
    
    ClosePreferences()
    
    main::initProxy()
    
    If restart
      MessageRequester("Restart TPFMM", "TPFMM will now restart to display the selected locale")
      misc::openLink(ProgramFilename())
      End
    EndIf
    
    
;     If misc::checkGameDirectory(Dir$) = 0
;       ; 0   = path okay, executable found and writing possible
;       ; 1   = path okay, executable found but cannot write
;       ; 2   = path not okay
;     EndIf
    
    If main::gameDirectory$ <> dir$
      ; gameDir changed
      main::gameDirectory$ = Dir$
      mods::freeAll()
      mods::load()
    EndIf
    
    repository::init()
    
    GadgetCloseSettings()
  EndProcedure
  
  Procedure updateGadgets()
    ; check gadgets etc
    Protected ret
    Static LastDir$ = "-"
    
    If #True Or LastDir$ <> GetGadgetText(gadget("installationPath"))
      LastDir$ = GetGadgetText(gadget("installationPath"))
      
      If FileSize(LastDir$) = -2
        ; DisableGadget(, #False)
      Else
        ; DisableGadget(, #True)
      EndIf
      
      ret = misc::checkGameDirectory(LastDir$)
      ; 0   = path okay, executable found and writing possible
      ; 1   = path okay, executable found but cannot write
      ; 2   = path not okay
      If ret = 0
        SetGadgetText(gadget("installationTextStatus"), locale::l("settings","success"))
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(0,100,0))
        DisableGadget(gadget("save"), #False)
      Else
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(255,0,0))
        DisableGadget(gadget("save"), #True)
        If ret = 1
          SetGadgetText(gadget("installationTextStatus"), locale::l("settings","failed"))
        Else
          SetGadgetText(gadget("installationTextStatus"), locale::l("settings","not_found"))
        EndIf
      EndIf
    EndIf
    
    If GetGadgetState(gadget("proxyEnabled"))
      DisableGadget(gadget("proxyServer"), #False)
      DisableGadget(gadget("proxyUser"), #False)
      DisableGadget(gadget("proxyPassword"), #False)
    Else
      DisableGadget(gadget("proxyServer"), #True)
      DisableGadget(gadget("proxyUser"), #True)
      DisableGadget(gadget("proxyPassword"), #True)
    EndIf
    
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(parentWindow)
    _parentW = parentWindow
    
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    DataSection
      dataDialogXML:
      IncludeBinary "dialogs/settings.xml"
      dataDialogXMLend:
    EndDataSection
    
    ; open dialog
    Protected xml 
    xml = CatchXML(#PB_Any, ?dataDialogXML, ?dataDialogXMLend - ?dataDialogXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      MessageRequester("Critical Error", "Could not read window definition!", #PB_MessageRequester_Error)
      End
    EndIf
    
    _dialog = CreateDialog(#PB_Any)
     
    If Not OpenXMLDialog(_dialog, xml, "settings", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(parentWindow))
      MessageRequester("Critical Error", "Could not open settings window!", #PB_MessageRequester_Error)
      End
    EndIf
    FreeXML(xml)
    
    window = DialogWindow(_dialog)
    
    
    ; get gadgets
    Macro getGadget(name)
      gadget(name) = DialogGadget(_dialog, name)
      If Not IsGadget(gadget(name))
        MessageRequester("Critical Error", "Could not create gadget "+name+"!", #PB_MessageRequester_Error)
        End
      EndIf
    EndMacro
    
    
    getGadget("panelSettings")
    
    getGadget("save")
    getGadget("cancel")
    
    getGadget("installationFrame")
    getGadget("installationTextSelect")
    getGadget("installationAutodetect")
    getGadget("installationPath")
    getGadget("installationBrowse")
    getGadget("installationTextStatus")
    
    getGadget("miscFrame")
    getGadget("miscAutoBackup")
    getGadget("miscVersionCheck")
    
    getGadget("languageFrame")
    getGadget("languageSelection")
    
    
    getGadget("proxyEnabled")
    getGadget("proxyFrame")
    getGadget("proxyServerLabel")
    getGadget("proxyServer")
    getGadget("proxyUserLabel")
    getGadget("proxyUser")
    getGadget("proxyPasswordLabel")
    getGadget("proxyPassword")
    
    
;     getGadget("repositoryList")
;     getGadget("repositoryAdd")
;     getGadget("repositoryRemove")
;     getGadget("repositoryNameLabel")
;     getGadget("repositoryName")
;     getGadget("repositoryCuratorLabel")
;     getGadget("repositoryCurator")
;     getGadget("repositoryDescriptionLabel")
;     getGadget("repositoryDescription")
    
    
    ; set texts
    SetWindowTitle(window, l("settings","title"))
    
    SetGadgetItemText(gadget("panelSettings"), 0,   l("settings", "general"))
    SetGadgetItemText(gadget("panelSettings"), 1,   l("settings", "proxy"))
;     SetGadgetItemText(gadget("panelSettings"), 2,   l("settings", "repository"))
    
    SetGadgetText(gadget("save"),                   l("settings","save"))
    GadgetToolTip(gadget("save"),                   l("settings","save_tip"))
    SetGadgetText(gadget("cancel"),                 l("settings","cancel"))
    GadgetToolTip(gadget("cancel"),                 l("settings","cancel_tip"))
    
    SetGadgetText(gadget("installationFrame"),      l("settings","path"))
    SetGadgetText(gadget("installationTextSelect"), l("settings","text"))
    SetGadgetText(gadget("installationAutodetect"), l("settings","autodetect"))
    GadgetToolTip(gadget("installationAutodetect"), l("settings","autodetect_tip"))
    SetGadgetText(gadget("installationPath"),       "")
    SetGadgetText(gadget("installationBrowse"),     l("settings","browse"))
    GadgetToolTip(gadget("installationBrowse"),     l("settings","browse_tip"))
    SetGadgetText(gadget("installationTextStatus"), "")
               
    SetGadgetText(gadget("miscFrame"),              l("settings","other"))
    SetGadgetText(gadget("miscAutoBackup"),         l("settings","backup"))
    GadgetToolTip(gadget("miscAutoBackup"),         l("settings","backup_tip"))
    SetGadgetText(gadget("miscVersionCheck"),       l("settings","versioncheck"))
    GadgetToolTip(gadget("miscVersionCheck"),       l("settings","versioncheck_tip"))
    
    SetGadgetText(gadget("languageFrame"),          l("settings","locale"))
    SetGadgetText(gadget("languageSelection"),      "")
    
    
    SetGadgetText(gadget("proxyEnabled"),           l("settings","proxy_enabled"))
    SetGadgetText(gadget("proxyFrame"),             l("settings","proxy_frame"))
    SetGadgetText(gadget("proxyServerLabel"),       l("settings","proxy_server"))
    SetGadgetText(gadget("proxyUserLabel"),         l("settings","proxy_user"))
    SetGadgetText(gadget("proxyPasswordLabel"),     l("settings","proxy_password"))
    
    
;     SetGadgetText(gadget("repositoryList"),         "")
;     SetGadgetText(gadget("repositoryAdd"),          l("settings", "repository_add"))
;     SetGadgetText(gadget("repositoryAdd"),          l("settings", "repository_add"))
;     SetGadgetText(gadget("repositoryRemove"),       l("settings", "repository_remove"))
;     SetGadgetText(gadget("repositoryNameLabel"),        l("settings", "repository_name"))
;     SetGadgetText(gadget("repositoryCuratorLabel"),     l("settings", "repository_curator"))
;     SetGadgetText(gadget("repositoryDescriptionLabel"), l("settings", "repository_description"))
    
    
    ; bind events
    BindEvent(#PB_Event_CloseWindow, @GadgetCloseSettings(), window)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    
    ; bind gadget events
    BindGadgetEvent(gadget("installationAutodetect"), @GadgetButtonAutodetect())
    BindGadgetEvent(gadget("installationBrowse"), @GadgetButtonBrowse())
    ;BindGadgetEvent(, @GadgetButtonOpenPath())
    BindGadgetEvent(gadget("save"), @GadgetSaveSettings())
    BindGadgetEvent(gadget("cancel"), @GadgetCloseSettings())
    BindGadgetEvent(gadget("installationPath"), @updateGadgets(), #PB_EventType_Change)
    BindGadgetEvent(gadget("proxyEnabled"), @updateGadgets())
    
    RefreshDialog(_dialog)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure show()
    Protected locale$
    
    debugger::add("windowSettings::show()")
    
    OpenPreferences(main::settingsFile$)
    ; main
    SetGadgetText(gadget("installationPath"), ReadPreferenceString("path", main::gameDirectory$))
    SetGadgetState(gadget("miscAutoBackup"), ReadPreferenceInteger("autobackup", 1))
    locale$ = ReadPreferenceString("locale", "en")
    SetGadgetState(gadget("miscVersionCheck"), ReadPreferenceInteger("compareVersion", #False))
    
    ; proxy
    PreferenceGroup("proxy")
    SetGadgetState(gadget("proxyEnabled"), ReadPreferenceInteger("enabled", 0))
    SetGadgetText(gadget("proxyServer"), ReadPreferenceString("server", ""))
    SetGadgetText(gadget("proxyUser"), ReadPreferenceString("user", ""))
    SetGadgetText(gadget("proxyPassword"), aes::decryptString(ReadPreferenceString("password", "")))
    
    ClosePreferences()
    
    
    If GetGadgetText(gadget("installationPath")) = ""
      GadgetButtonAutodetect()
    EndIf
    
    ; locale
    locale::listAvailable(gadget("languageSelection"), locale$)
    
;     repository::listRepositories(gadget())
    
    updateGadgets()
    
    ; show window
    RefreshDialog(_dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    DisableWindow(_parentW, #True)
    SetActiveWindow(window)
  EndProcedure
  
EndModule
