﻿
DeclareModule settings
  EnableExplicit
  
  Declare setFilename(filename$)
  
  Declare setInteger(group$, key$, value)
  Declare setString(group$, key$, value$)
  Declare getInteger(group$, key$)
  Declare.s getString(group$, key$)
  
EndDeclareModule

Module settings
  Global accessMutex = CreateMutex()
  Global settingsFile$
  Global NewMap defaultValues$()
  
  ; define all default values..
  defaultValues$("/locale") = "en"
  defaultValues$("/compareVersion") = "1"
  defaultValues$("backup/after_install") = "0"
  defaultValues$("backup/before_update") = "1"
  defaultValues$("backup/before_uninstall") = "0"
  defaultValues$("proxy/enabled") = "0"
  defaultValues$("proxy/server") = ""
  defaultValues$("proxy/user") = ""
  defaultValues$("proxy/password") = ""
  defaultValues$("integration/register_protocol") = "1"
  defaultValues$("integration/register_context_menu") = "1"
  defaultValues$("window/x") = "-1"
  defaultValues$("window/y") = "-1"
  defaultValues$("window/width") = "-1"
  defaultValues$("window/height") = "-1"
  
  
  Procedure setFilename(filename$)
    settingsFile$ = filename$
  EndProcedure
  
  Procedure setInteger(group$, key$, value)
    LockMutex(accessMutex)
    OpenPreferences(settingsFile$, #PB_Preference_GroupSeparator)
    PreferenceGroup(group$)
    WritePreferenceInteger(key$, value)
    ClosePreferences()
    UnlockMutex(accessMutex)
  EndProcedure
  
  Procedure setString(group$, key$, value$)
    LockMutex(accessMutex)
    OpenPreferences(settingsFile$, #PB_Preference_GroupSeparator)
    PreferenceGroup(group$)
    WritePreferenceString(key$, value$)
    ClosePreferences()
    UnlockMutex(accessMutex)
  EndProcedure
  
  Procedure getInteger(group$, key$)
    Protected value
    LockMutex(accessMutex)
    OpenPreferences(settingsFile$, #PB_Preference_GroupSeparator)
    PreferenceGroup(group$)
    value = ReadPreferenceInteger(key$, Val(defaultValues$(group$+"/"+key$)))
    ClosePreferences()
    UnlockMutex(accessMutex)
    ProcedureReturn value
  EndProcedure
  
  Procedure.s getString(group$, key$)
    Protected value$
    LockMutex(accessMutex)
    OpenPreferences(settingsFile$, #PB_Preference_GroupSeparator)
    PreferenceGroup(group$)
    value$ = ReadPreferenceString(key$, defaultValues$(group$+"/"+key$))
    ClosePreferences()
    UnlockMutex(accessMutex)
    ProcedureReturn value$
  EndProcedure
  
  
  
EndModule
