﻿
XIncludeFile "module_locale.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_mods.h.pbi"

DeclareModule modSettings
  EnableExplicit
  
  Declare show(*mod.mods::mod, parentWindowID=0)
  
EndDeclareModule


Module modSettings
  
  UseModule locale
  
  ;- Structures
  
  Structure modSettingsWindow
    xml.i
    dialog.i
    window.i
    
    *mod.mods::mod
  EndStructure
  
  ;- Macros
  
  Macro gadget(name)
    DialogGadget(*data\dialog, name)
  EndMacro
  
  
  ;- variables
  Global xml
 
  
  ;- init
  
  DataSection
    dialogModSettingsXML:
    IncludeBinary "dialogs/modSettings.xml"
    dialogModSettingsXMLend:
  EndDataSection
  
  Global fontHeader, fontBigger
  fontHeader = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.8, #PB_Round_Nearest), #PB_Font_Bold)
  fontBigger = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.4, #PB_Round_Nearest), #PB_Font_Bold)
  
  ;- Procedures
  
  Procedure _handleNumber(gadget, force=#False)
    Protected *setting.mods::settings
    Protected text$, number.d
    
    *setting  = GetGadgetData(gadget)
    number = ValD(GetGadgetText(gadget))
    
    If number > *setting\max
      number = *setting\max
    ElseIf number < *setting\min
      number = *setting\min
    EndIf
    
    text$ = StrD(number)
;     If text$ <> GetGadgetText(gadget) And ; allow also typing "e" As following numbers may result in valid number
;        text$+"e" <> LCase(GetGadgetText(gadget)) And 
;        text$+"e-" <> LCase(GetGadgetText(gadget)) And
;        text$+"e+" <> LCase(GetGadgetText(gadget))
    If force Or ValD(text$) <> ValD(GetGadgetText(gadget))
      SetGadgetText(gadget, text$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
;         SendMessage_(GadgetID(gadget), #EM_SETSEL, 0, -1); select all
        SendMessage_(GadgetID(gadget), #EM_SETSEL, Len(text$), Len(text$)); curser at end
      CompilerEndIf
    EndIf
  EndProcedure
  
  Procedure checkNumber()
    _handleNumber(EventGadget(), #False)
  EndProcedure
  
  Procedure setDefault()
    Protected *data.modSettingsWindow
    Protected *setting.mods::settings
    *data     = GetWindowData(EventWindow())
    *setting  = GetGadgetData(EventGadget())
    
    Select *setting\type$
      Case "boolean"
        SetGadgetState(gadget("value-"+*setting\name$), Val(*setting\Default$))
      Case "string"
        SetGadgetText(gadget("value-"+*setting\name$), *setting\Default$)
      Case "number"
        SetGadgetText(gadget("value-"+*setting\name$), *setting\Default$)
    EndSelect
    
  EndProcedure
  
  Procedure enter()
    ; enter button was pressed
    Protected gadget
    Protected *setting.mods::settings
    
    gadget = GetActiveGadget()
    If gadget = -1
      ; no gadget selected
      ProcedureReturn #False
    EndIf
    
    If IsGadget(gadget)
      If GadgetType(gadget) = #PB_GadgetType_String
        *setting = GetGadgetData(gadget)
        If *setting And *setting\type$ = "number"
          _handleNumber(gadget, #True)
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure close()
    Protected *data.modSettingsWindow
    *data = GetWindowData(EventWindow())
    If *data
      HideWindow(*data\window, #True)
      CloseWindow(*data\window)
      FreeDialog(*data\dialog)
      
      ForEach *data\mod\settings()
        With *data\mod\settings()
          If \im And IsImage(\im)
            FreeImage(\im)
          EndIf
        EndWith
      Next
      
      FreeStructure(*data)
    EndIf
  EndProcedure
  
  Procedure save()
    ; write settings.lua
    Protected *data.modSettingsWindow
    *data = GetWindowData(EventWindow())
    
    Protected modFolder$ = mods::getModFolder(*data\mod\tpf_id$, *data\mod\aux\type$)
    Protected file, gadget
    Protected val$
    
    file = CreateFile(#PB_Any, modFolder$+"settings.lua")
    
    If file
      WriteStringN(file, "return {")
      ForEach *data\mod\settings()
        With *data\mod\settings()
          gadget = gadget("value-"+\name$)
          
          Select \type$
            Case "boolean"
              If GetGadgetState(gadget)
                val$ = "true"
              Else
                val$ = "false"
              EndIf
            Case "string"
              val$ = GetGadgetText(gadget)
              val$ = ReplaceString(val$, "\", "\\")
              val$ = ReplaceString(val$, #DQUOTE$, "\"+#DQUOTE$)
              val$ = #DQUOTE$+val$+#DQUOTE$
            Case "number"
              _handleNumber(gadget, #True)
              val$ = GetGadgetText(gadget)
          EndSelect
          
          WriteStringN(file, "  "+MapKey(*data\mod\settings())+" = "+val$+",")
        EndWith
      Next
      WriteStringN(file, "}")
      CloseFile(file)
;       misc::openLink(modFolder$+"settings.lua")
    Else
      debugger::add("modSettings::save() - ERROR: could not create "+modFolder$+"settings.lua")
    EndIf
  
    
    ; close window
    close()
  EndProcedure
  
  Procedure show(*mod.mods::mod, parentWindowID=0)
    debugger::add("modSettings::modSettingsShow()")
    
    If Not *mod
      ProcedureReturn #False
    EndIf
    If MapSize(*mod\settings()) = 0
      ProcedureReturn #False
    EndIf
    
    Protected *data.modSettingsWindow
    *data = AllocateStructure(modSettingsWindow)
    *data\mod = *mod
    
    Protected modFolder$
    modFolder$ = mods::getModFolder(*mod\tpf_id$, *mod\aux\type$)
    
    ; load default XML
    Protected xml
    xml = CatchXML(#PB_Any, ?dialogModSettingsXML, ?dialogModSettingsXMLend - ?dialogModSettingsXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      debugger::add("modSettings::modSettingsShow() - ERROR (XML): could not read window definition")
      ProcedureReturn #False
    EndIf
    
    ; manipulate xml before opening dialog
    Protected *nodeBase, *node, *nodeBox
    Protected factor.d
    #WIDTH  = 55
    #HEIGHT = 20
    If IsXML(xml)
      
      *nodeBase = XMLNodeFromID(xml, "settings")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        
        ForEach *data\mod\settings()
          With *data\mod\settings()
            ; preview image
            If \image$ And FileSize(modFolder$ + \image$) > 0
              \im = LoadImage(#PB_Any, modFolder$ + \image$)
              factor = 1
              ; If ImageWidth(\im) > #WIDTH
                factor = #WIDTH / ImageWidth(\im)
              ; EndIf
              If ImageHeight(\im) * factor > #HEIGHT
                factor = #HEIGHT / ImageHeight(\im)
              EndIf
              ResizeImage(\im, ImageWidth(\im) * factor, ImageHeight(\im) * factor)
            EndIf
            
            If \im And IsImage(\im)
              *node = CreateXMLNode(*nodeBase, "image", -1)
              SetXMLAttribute(*node, "name", "image-"+\name$)
              SetXMLAttribute(*node, "width", Str(ImageWidth(\im)))
              SetXMLAttribute(*node, "height", Str(ImageHeight(\im)))
            Else
              *node = CreateXMLNode(*nodeBase, "empty", -1)
            EndIf
            
            
            ; name of parameter
            *node = CreateXMLNode(*nodeBase, "text", -1)
            SetXMLAttribute(*node, "name", "name-"+\name$)
            SetXMLAttribute(*node, "text", \name$+":")
            ; SetXMLAttribute(*node, "flags", "#PB_String_ReadOnly | #PB_String_BorderLess")
            SetXMLAttribute(*node, "flags", "#PB_Text_Right")
            If \type$ = "boolean"
              SetXMLAttribute(*node, "text", "")
              SetXMLAttribute(*node, "invisible", "yes")
            EndIf
            
            
            ; input of parameter
            Select \type$
              Case "boolean"
                *node = CreateXMLNode(*nodeBase, "checkbox", -1)
                SetXMLAttribute(*node, "name", "value-"+\name$)
                SetXMLAttribute(*node, "text", \name$)
              Case "string"
                *node = CreateXMLNode(*nodeBase, "string", -1)
                SetXMLAttribute(*node, "name", "value-"+\name$)
                SetXMLAttribute(*node, "text", "")
              Case "number"
                 ; spin cannot handle float...
                *node = CreateXMLNode(*nodeBase, "string", -1)
                SetXMLAttribute(*node, "name", "value-"+\name$)
                SetXMLAttribute(*node, "text", "0")
                
;                 *nodeBox = CreateXMLNode(*nodeBase, "hbox", -1)
;                 SetXMLAttribute(*nodeBox, "expand", "item:1")
;                 *node = CreateXMLNode(*nodeBox, "string", -1)
;                 SetXMLAttribute(*node, "name", "value-"+\name$)
;                 SetXMLAttribute(*node, "text", "0")
;                 *nodeBox = CreateXMLNode(*nodeBox, "vbox", -1)
;                 SetXMLAttribute(*nodeBox, "expand", "equal")
;                 *node = CreateXMLNode(*nodeBox, "button", -1)
;                 SetXMLAttribute(*node, "name", "inc-"+\name$)
;                 SetXMLAttribute(*node, "text", "^")
;                 *node = CreateXMLNode(*nodeBox, "button", -1)
;                 SetXMLAttribute(*node, "name", "dec-"+\name$)
;                 SetXMLAttribute(*node, "text", "v")
            EndSelect
            
            
            ; reset to default
            *node = CreateXMLNode(*nodeBase, "button", -1)
            SetXMLAttribute(*node, "name", "default-"+\name$)
            SetXMLAttribute(*node, "text", l("mod_settings", "default"))
          EndWith
        Next
      EndIf
      
      ; show window
      debugger::add("modInformation::modInfoShow() - open window...")
      *data\dialog = CreateDialog(#PB_Any)
      If *data\dialog And OpenXMLDialog(*data\dialog, xml, "modSettings", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, parentWindowID)
        *data\window = DialogWindow(*data\dialog)
        FreeXML(xml)
        
        ; set texts
        SetWindowTitle(*data\window, locale::l("mod_settings","title")+": "+*data\mod\name$)
        SetGadgetText(gadget("name"), *data\mod\name$)
        
        ForEach *data\mod\settings()
          With *data\mod\settings()
            If \im And IsImage(\im)
              SetGadgetState(gadget("image-"+\name$), ImageID(\im))
            EndIf
            
            BindGadgetEvent(gadget("default-"+\name$), @setDefault())
            SetGadgetData(gadget("default-"+\name$), *data\mod\settings())
            
            GadgetToolTip(gadget("name-"+\name$), \description$)
            GadgetToolTip(gadget("value-"+\name$), \description$)
            
            BindGadgetEvent(gadget("value-"+\name$), @checkNumber(), #PB_EventType_Change)
            SetGadgetData(gadget("value-"+\name$), *data\mod\settings())
          EndWith
        Next
        
        ; load current settings
        Protected NewMap settings$()
        luaParser::parseModSettings(modFolder$, settings$())
        
        ; apply current setting or default 
        Protected val$
        ForEach *data\mod\settings()
          With *data\mod\settings()
            
            If FindMapElement(settings$(), MapKey(*data\mod\settings()))
              ; apply value read from settings.lua
              val$ = settings$()
            Else
              ; use default value
              val$ = \Default$
            EndIf
            
            Select \type$ 
              Case "boolean"
                SetGadgetState(gadget("value-"+\name$), Val(val$))
              Case "string"
                SetGadgetText(gadget("value-"+\name$), val$)
              Case "number"
                If ValD(val$) > \max
                  val$ = StrD(\max)
                ElseIf ValD(val$) < \min
                  val$ = StrD(\min)
                EndIf
                SetGadgetText(gadget("value-"+\name$), val$)
;                 SetGadgetAttribute(gadget("value-"+\name$), #PB_Spin_Minimum, \min)
;                 SetGadgetAttribute(gadget("value-"+\name$), #PB_Spin_Maximum, \max)
;                 SetGadgetState(gadget("value-"+\name$), Val(val$))
            EndSelect
            
          EndWith
        Next
        
        SetGadgetFont(gadget("name"), FontID(fontBigger))
;         SetGadgetColor(*data\gadgets("name"), #PB_Gadget_FrontColor, RGB($FF, $FF, $FF))
;         SetGadgetColor(*data\gadgets("name"), #PB_Gadget_BackColor, RGB(47, 71, 99))
        
        BindEvent(#PB_Event_CloseWindow, @close(), *data\window)
        AddKeyboardShortcut(*data\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
        BindEvent(#PB_Event_Menu, @close(), *data\window, #PB_Event_CloseWindow)
        AddKeyboardShortcut(*data\window, #PB_Shortcut_Return, 1)
        BindEvent(#PB_Event_Menu, @enter(), *data\window, 1)
        
        SetGadgetText(gadget("settings"), l("mod_settings", "settings"))
        SetGadgetText(gadget("save"), l("mod_settings", "save"))
        SetGadgetText(gadget("cancel"), l("mod_settings", "cancel"))
        BindGadgetEvent(gadget("save"), @save())
        BindGadgetEvent(gadget("cancel"), @close())
        
        ; DisableWindow(window, #True)
        RefreshDialog(*data\dialog)
        SetWindowData(*data\window, *data)
        HideWindow(*data\window, #False, #PB_Window_WindowCentered)
        ProcedureReturn #True
      Else
        debugger::add("modInformation::modInfoShow() - Error: "+DialogError(*data\dialog))
      EndIf
    EndIf
    ; failed to open window -> free data
    FreeXML(xml)
    FreeStructure(*data)
  EndProcedure
  
EndModule