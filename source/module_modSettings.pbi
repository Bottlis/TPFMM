
XIncludeFile "module_locale.pbi"
XIncludeFile "module_luaParser.pbi"
XIncludeFile "module_mods.h.pbi"

DeclareModule modSettings
  EnableExplicit
  
  Declare show(*mod.mods::LocalMod, parentWindowID=0)
  
EndDeclareModule


Module modSettings
  UseModule locale
  UseModule debugger
  
  ;- Structures
  
  
  Structure modSettingsWindow
    xml.i
    dialog.i
    window.i
    
    *mod.mods::LocalMod
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
    Protected *setting.mods::modLuaSetting
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
    Protected *setting.mods::modLuaSetting
    Protected *tableValue.mods::tableValue
    Protected gadget, item
    *data     = GetWindowData(EventWindow())
    *setting  = GetGadgetData(EventGadget())
    
    gadget = gadget("value-"+*setting\name$)
    
    Select *setting\type$
      Case "boolean"
        SetGadgetState(gadget, Val(*setting\Default$))
      Case "string"
        SetGadgetText(gadget, *setting\Default$)
      Case "number"
        SetGadgetText(gadget, StrD(ValD(*setting\Default$)))
      Case "table"
        For item = 0 To CountGadgetItems(gadget) - 1
          *tableValue = GetGadgetItemData(gadget, item)
          
          SetGadgetItemState(gadget, item, 0)
          
          ForEach *setting\tableDefaults$()
            If *setting\tableDefaults$() = *tableValue\value$
              If *setting\multiSelect 
                SetGadgetItemState(gadget, item, 1)
                Break ; break ForEach, but no For-Loop
              Else
                SetGadgetState(gadget, item)
                Break 2 ; finished, only one can be selected
              EndIf
            EndIf
          Next
        Next
        
    EndSelect
    
  EndProcedure
  
  Procedure enter()
    ; enter button was pressed
    Protected gadget
    Protected *setting.mods::modLuaSetting
    
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
      
      Protected NewList *settings.mods::ModLuaSetting()
      *data\mod\getSettings(*settings())
      
      ForEach *settings()
        With *settings()
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
    
    Protected modFolder$ = mods::getModFolder(*data\mod\getID())
    Protected file, gadget, item
    Protected val$
    Protected *tableValue.mods::tableValue
    
    file = CreateFile(#PB_Any, modFolder$+"settings.lua")
    
    Protected NewList *settings.mods::ModLuaSetting()
    *data\mod\getSettings(*settings())
      
    If file
      WriteStringN(file, "return {")
      ForEach *settings()
        With *settings()
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
            Case "table"
              val$ = "{"
              If \multiSelect
                For item = 0 To CountGadgetItems(gadget) - 1
                  If GetGadgetItemState(gadget, item) ; if selected
                    *tableValue = GetGadgetItemData(gadget, item)
                    If *tableValue
                      ; \value$ is already correctly formated during LUAparsing :)
                      val$ + *tableValue\value$ + ", "
                    EndIf
                  EndIf
                Next
              Else
                item = GetGadgetState(gadget)
                *tableValue = GetGadgetItemData(gadget, item)
                If *tableValue
                  ; \value$ is already correctly formated during LUAparsing :)
                  val$ + *tableValue\value$
                EndIf
              EndIf
              val$ + "}"
              
          EndSelect
          
          WriteStringN(file, "  "+\key$+" = "+val$+",")
        EndWith
      Next
      WriteStringN(file, "}")
      CloseFile(file)
;       misc::openLink(modFolder$+"settings.lua")
    Else
      deb("modSettings:: could not create "+modFolder$+" settings.lua")
    EndIf
  
    
    ; close window
    close()
  EndProcedure
  
  Procedure show(*mod.mods::LocalMod, parentWindowID=0)
    If Not *mod
      ProcedureReturn #False
    EndIf
    If Not *mod\hasSettings()
      ProcedureReturn #False
    EndIf
    
    Protected *data.modSettingsWindow
    *data = AllocateStructure(modSettingsWindow)
    *data\mod = *mod
    
    Protected modFolder$
    modFolder$ = mods::getModFolder(*mod\getID())
    
    ; load default XML
    Protected xml
    xml = CatchXML(#PB_Any, ?dialogModSettingsXML, ?dialogModSettingsXMLend - ?dialogModSettingsXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      deb("modSettings:: could not read window definition")
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
        
        Protected NewList *settings.mods::ModLuaSetting()
        *data\mod\getSettings(*settings())
    
        ForEach *settings()
          With *settings()
            ; preview image
            
            If \image$ And FileSize(modFolder$ + \image$) > 0
              \im = LoadImage(#PB_Any, modFolder$ + \image$)
              If \im
                factor = 1
                ; If ImageWidth(\im) > #WIDTH
                  factor = #WIDTH / ImageWidth(\im)
                ; EndIf
                If ImageHeight(\im) * factor > #HEIGHT
                  factor = #HEIGHT / ImageHeight(\im)
                EndIf
                ResizeImage(\im, ImageWidth(\im) * factor, ImageHeight(\im) * factor)
              Else ; not \im
                deb("modSettings:: could not load image "+modFolder$+\image$)
              EndIf
            ElseIf \image$ ; and not filesize(...)
              deb("modSettings:: could not find image file "+modFolder$+\image$)
            EndIf
            
            If \im
              *node = CreateXMLNode(*nodeBase, "image", -1)
              SetXMLAttribute(*node, "name", "image-"+\name$)
              SetXMLAttribute(*node, "width", Str(ImageWidth(\im)))
              SetXMLAttribute(*node, "height", Str(ImageHeight(\im)))
              If \type$ = "boolean"
                ; no text for boolean type, only image (text is right of checkbox)
                SetXMLAttribute(*node, "colspan", "2")
              EndIf
            EndIf
            
            
            ; name of parameter
            If \type$ <> "boolean"
              *node = CreateXMLNode(*nodeBase, "text", -1)
              SetXMLAttribute(*node, "name", "name-"+\name$)
              SetXMLAttribute(*node, "text", \name$+":")
              ; SetXMLAttribute(*node, "flags", "#PB_String_ReadOnly | #PB_String_BorderLess")
              SetXMLAttribute(*node, "flags", "#PB_Text_Right")
              If Not \im
                ; no image, only text
                SetXMLAttribute(*node, "colspan", "2")
              EndIf
            Else
              If Not \im
                ; no image, no text
                *node = CreateXMLNode(*nodeBase, "empty", -1)
                SetXMLAttribute(*node, "colspan", "2")
              EndIf
            EndIf
            
            
            ; input gadget (string/checkbox/listview/...)
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
              Case "table"
                If \multiSelect ; allow multiple selections
                  *node = CreateXMLNode(*nodeBase, "listview", -1)
                  SetXMLAttribute(*node, "name", "value-"+\name$)
                  SetXMLAttribute(*node, "flags", "#PB_ListView_ClickSelect")
                  If ListSize(\tableValues()) > 6
                    SetXMLAttribute(*node, "height", Str(misc::getDefaultRowHeight(#PB_GadgetType_ListView) * 6))
                  Else
                    SetXMLAttribute(*node, "height", Str(misc::getDefaultRowHeight(#PB_GadgetType_ListView) * ListSize(\tableValues())))
                  EndIf
                Else ; only exactly one entry may be selected
                  *node = CreateXMLNode(*nodeBase, "combobox", -1)
                  SetXMLAttribute(*node, "name", "value-"+\name$)
                EndIf
                
            EndSelect
            
            
            ; reset to default button
            *node = CreateXMLNode(*nodeBase, "button", -1)
            SetXMLAttribute(*node, "name", "default-"+\name$)
            SetXMLAttribute(*node, "text", _("mod_settings_default"))
            
          EndWith
        Next
      EndIf
      
      ; show window
      *data\dialog = CreateDialog(#PB_Any)
      If *data\dialog And OpenXMLDialog(*data\dialog, xml, "modSettings", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, parentWindowID)
        *data\window = DialogWindow(*data\dialog)
        FreeXML(xml)
        
        ; set texts
        SetWindowTitle(*data\window, _("mod_settings_title")+": "+*data\mod\getName())
        SetGadgetText(gadget("name"), *data\mod\getName())
        
        ; load current settings
        Protected NewMap currentSettings.mods::modSetting()
        luaParser::parseSettingsLua(modFolder$, currentSettings())
        
        ; apply current setting or default 
        
        Protected NewList *settings.mods::ModLuaSetting()
        *data\mod\getSettings(*settings())
        
        Protected val$, option$
        ForEach *settings()
          With *settings()
            option$ = \key$
            
            
            
            ; set image
            If \im
              SetGadgetState(gadget("image-"+\name$), ImageID(\im))
            EndIf
            
            ; handle table related stuff: fill entries and select items...
            Protected item
            If \type$ = "table"
              item = 0
              ForEach \tableValues()
                AddGadgetItem(gadget("value-"+\name$), item, \tableValues()\text$)
                SetGadgetItemData(gadget("value-"+\name$), item, \tableValues())
                
                ; select if currently selected or default
                If FindMapElement(currentSettings(), option$)
                  ForEach currentSettings()\values$()
                    If currentSettings()\values$() = \tableValues()\value$
                      ; select this table value
                      If \multiSelect
                        SetGadgetItemState(gadget("value-"+\name$), item, 1)
                      Else
                        SetGadgetState(gadget("value-"+\name$), item)
                      EndIf
                      Break
                    EndIf
                  Next
                Else ; use default values
                  ForEach \tableDefaults$()
                    If \tableDefaults$() = \tableValues()\value$
                      ; select this table value
                      If \multiSelect
                        SetGadgetItemState(gadget("value-"+\name$), item, 1)
                      Else
                        SetGadgetState(gadget("value-"+\name$), item)
                      EndIf
                      Break
                    EndIf
                  Next
                EndIf
                
                item + 1
              Next
            EndIf
            
            ; number check
            If \type$ = "number"
              BindGadgetEvent(gadget("value-"+\name$), @checkNumber(), #PB_EventType_Change)
            EndIf
            
            ; standard bindings
            BindGadgetEvent(gadget("default-"+\name$), @setDefault())
            SetGadgetData(gadget("default-"+\name$), *settings())
            SetGadgetData(gadget("value-"+\name$), *settings())
            GadgetToolTip(gadget("value-"+\name$), \description$)
            
            
            ; fill in values (not for table, this is already done)
            ; select current setting for this setting option
            If FindMapElement(currentSettings(), option$)
              ; apply value read from settings.lua
              val$ = currentSettings()\value$
              ; table-related values are handled independently
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
              Case "table"
                ; nothing to do here
                
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
        
        SetGadgetText(gadget("settings"), _("mod_settings_settings"))
        SetGadgetText(gadget("save"), _("mod_settings_save"))
        SetGadgetText(gadget("cancel"), _("mod_settings_cancel"))
        BindGadgetEvent(gadget("save"), @save())
        BindGadgetEvent(gadget("cancel"), @close())
        
        ; DisableWindow(window, #True)
        RefreshDialog(*data\dialog)
        SetWindowData(*data\window, *data)
        HideWindow(*data\window, #False, #PB_Window_WindowCentered)
        ProcedureReturn #True
      Else
        deb("modInformation:: "+DialogError(*data\dialog))
      EndIf
    EndIf
    ; failed to open window -> free data
    FreeXML(xml)
    FreeStructure(*data)
  EndProcedure
  
EndModule
