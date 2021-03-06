﻿
DeclareModule modInformation
  EnableExplicit
  
  Declare modInfoShow(*mod, parentWindowID=0)
  
EndDeclareModule

XIncludeFile "module_modSettings.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "threads.pb"

Module modInformation
  UseModule debugger
  UseModule locale
  
  ;{ Stucts
  Structure modInfoGadget
    id.i
    name$
  EndStructure
  Structure modInfoAuthor
    gadgetContainer.modInfoGadget
    gadgetImage.modInfoGadget
    gadgetAuthor.modInfoGadget
    gadgetRole.modInfoGadget
    name$
    role$
    url$
    tfnetId.i
    steamId.i
    image.i
    thread.i
  EndStructure
  Structure modInfoSource Extends modInfoGadget
    url$
  EndStructure
  Structure modInfoTag Extends modInfoGadget
    tag$
  EndStructure
  Structure modInfoWindow
    dialog.i
    window.i
    parentWindowID.i
    Map gadgets.i() ; standard gadgets
    ; dynamic gadgets:
    List authors.modInfoAuthor()
    List sources.modInfoSource()
    List tags.modInfoTag()
    ; other data
    mod.i
    modFolder$
  EndStructure
  ;}
  
  ; load default XML
  Global xml
  misc::IncludeAndLoadXML(xml, "dialogs/modInfo.xml")
  
  
  Procedure modInfoClose()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      HideWindow(*data\window, #True)
      ForEach *data\authors()
        If *data\authors()\image And IsImage(*data\authors()\image)
          ; FreeImage(*data\authors()\image)
          ; reuse image (do not free)
        EndIf
        If *data\authors()\thread
          ; TODO: killing the author image thread might cause locked mutex and other weird stuff.
          ; must make an interactive download that can be aborted and everything cleared!
          ; or download in any case but make sure to not apply image to a deleted gadget (more complex)
          DebuggerWarning("todo fix authors download thread kill")
          threads::WaitStop(*data\authors()\thread, 10, #True) ; TODO CHANGE THIS!
        EndIf
      Next
      CloseWindow(*data\window)
      FreeDialog(*data\dialog)
      FreeStructure(*data)
    EndIf
  EndProcedure
  
  Procedure modInfoAuthor()
    
  EndProcedure
  
  Procedure modInfoFolder()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      misc::openLink(*data\modFolder$)
    EndIf
  EndProcedure
  
  Procedure modInfoShowSettings()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    modSettings::show(*data\mod, *data\parentWindowID)
    modInfoClose()
  EndProcedure
  
  Procedure modInfoSource()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      ForEach *data\sources()
        If EventGadget() = *data\sources()\id
          If *data\sources()\url$
            misc::openLink(*data\sources()\url$)
            ProcedureReturn #True
          EndIf
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure modInfoAuthorImage(*author.modInfoAuthor)
    ; download avatar and set in imagegadget
    Protected gadget = *author\gadgetImage\id
    Protected url$
    Protected *buffer, image
    Protected scale.d
    Static mutex, avatarDefault
    Static NewMap images()
    
    If Not gadget Or Not IsGadget(gadget)
      ProcedureReturn #False
    EndIf
    
    If Not mutex
      mutex = CreateMutex()
    EndIf
    
    LockMutex(mutex)
    ; init default avatar
    If Not avatarDefault Or Not IsImage(avatarDefault)
      avatarDefault = CopyImage(images::Images("avatar"), #PB_Any)
      ResizeImage(avatarDefault, GadgetWidth(gadget), GadgetHeight(gadget), #PB_Image_Smooth)
    EndIf
    UnlockMutex(mutex)
    
    SetGadgetState(gadget, ImageID(avatarDefault))
    
      ; if author has an avatar
    If *author\tfnetId Or *author\steamId
      url$ = URLEncoder("https://www.transportfevermods.com/repository/avatar/?tfnetId="+*author\tfnetId+"&steamId="+*author\steamId)
      
      If FindMapElement(images(), url$)
        ; reuse image
        image = images(url$)
      Else
        ; get avatar from transportfever.net
        *buffer = ReceiveHTTPMemory(url$, #Null, main::VERSION_FULL$)
        If *buffer
          image = CatchImage(#PB_Any, *buffer, MemorySize(*buffer))
          FreeMemory(*buffer)
          images(url$) = image
        Else
          ProcedureReturn #False
        EndIf
      EndIf
    EndIf
    
      
    If image And IsImage(image)
      scale = 1
      If ImageWidth(image) > GadgetWidth(gadget)
        scale = GadgetWidth(gadget) / ImageWidth(image)
      EndIf
      If ImageHeight(image)*scale > GadgetHeight(gadget)
        scale = GadgetHeight(gadget) / ImageHeight(image)
      EndIf
      If scale <> 1
        ResizeImage(image, ImageWidth(image)*scale, ImageHeight(image)*scale)
      EndIf
      SetGadgetState(gadget, ImageID(image))
      *author\image = image ; save for freeImage() when closing window
    EndIf
    
  EndProcedure
  
  Procedure modInfoShow(*mod.mods::LocalMod, parentWindowID=0)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    Protected *data.modInfoWindow
    *data = AllocateStructure(modInfoWindow)
    
    *data\modFolder$ = mods::getModFolder(*mod\getID())
    
    ; manipulate xml before opening dialog
    Protected *nodeBase, *node, *nodeBox
    If IsXML(xml)
      ; fill authors
      Protected count, i, *author.mods::author
      *nodeBase = XMLNodeFromID(xml, "infoBoxAuthors")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        count = mods::modCountAuthors(*mod)
        For i = 0 To count-1
          *author = mods::modGetAuthor(*mod, i)
          If Not *author
            Continue
          EndIf
          AddElement(*data\authors())
          *data\authors()\name$ = *author\name$
          *data\authors()\role$ = *author\role$
          *data\authors()\tfnetId = *author\tfnetId
          *data\authors()\steamId = *author\steamId
          
          *node = *nodeBase
          ; new container
;           *node = CreateXMLNode(*node, "container", -1)
;           *data\authors()\gadgetContainer\name$ = Str(*node)
;           SetXMLAttribute(*node, "name", Str(*node))
;           SetXMLAttribute(*node, "width", "300")
;           SetXMLAttribute(*node, "flags", "#PB_Container_Single")
          
          *nodeBox = CreateXMLNode(*node, "hbox", -1)
          SetXMLAttribute(*nodeBox, "expand", "item:2")
          SetXMLAttribute(*nodeBox, "spacing", "10")
          SetXMLAttribute(*nodeBox, "width", "200")
          
          *node = CreateXMLNode(*nodeBox, "image", -1)
          *data\authors()\gadgetImage\name$ = "image-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "image-"+Str(*data\authors()))
          SetXMLAttribute(*node, "width", "60")
          SetXMLAttribute(*node, "height", "60")
          
          *nodeBox = CreateXMLNode(*nodeBox, "vbox", -1)
          SetXMLAttribute(*nodeBox, "expand", "no")
          SetXMLAttribute(*nodeBox, "align", "center,left")
          
          *node = CreateXMLNode(*nodeBox, "text", -1)
          *data\authors()\gadgetAuthor\name$ = "author-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "author-"+Str(*data\authors()))
          SetXMLAttribute(*node, "text", *author\name$)
          
          *node = CreateXMLNode(*nodeBox, "text", -1)
          *data\authors()\gadgetRole\name$ = "role-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "role-"+Str(*data\authors()))
          SetXMLAttribute(*node, "text", *author\role$)
          
          
          If *author\tfnetId
            *data\authors()\url$      = "https://www.transportfever.net/index.php/User/"+Str(*author\tfnetId)+"/"
          ElseIf *author\steamId
            *data\authors()\url$      = "http://steamcommunity.com/profiles/"+Str(*author\steamId)+"/"
          EndIf
        Next
      EndIf
      
      ; tags
      
      ; sources
      *nodeBase = XMLNodeFromID(xml, "infoBoxSources")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        ; TODO use foldername and repository information
;         If *mod\getTfnetID()
;           *node = CreateXMLNode(*nodeBase, "hyperlink", -1)
;           SetXMLAttribute(*node, "name", "source-tpfnet")
;           SetXMLAttribute(*node, "text", "TransportFever.net")
;           AddElement(*data\sources())
;           *data\sources()\name$ = "source-tpfnet"
;           *data\sources()\url$  = "https://www.transportfever.net/filebase/index.php/Entry/"+*mod\getTfnetID()+"/"
;         EndIf
;         If *mod\getWorkshopID()
;           *node = CreateXMLNode(*nodeBase, "hyperlink", -1)
;           SetXMLAttribute(*node, "name", "source-workshop")
;           SetXMLAttribute(*node, "text", "Workshop")
;           AddElement(*data\sources())
;           *data\sources()\name$ = "source-workshop"
;           *data\sources()\url$  = "http://steamcommunity.com/sharedfiles/filedetails/?id="+*mod\getWorkshopID()
;         EndIf
      EndIf
      
      ; check if image is available
      Protected image
      image = *mod\getPreviewImage()
      *node = XMLNodeFromID(xml, "image")
      If image
        SetXMLAttribute(*node, "invisible", "no")
        SetXMLAttribute(*node, "width", Str(ImageWidth(image)))
        SetXMLAttribute(*node, "height", Str(ImageHeight(image)))
      Else
        SetXMLAttribute(*node, "invisible", "yes")
        SetXMLAttribute(*node, "height", "0")
      EndIf
      
      
      ; show window
      *data\dialog = CreateDialog(#PB_Any)
      If *data\dialog And OpenXMLDialog(*data\dialog, xml, "modInfo", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, parentWindowID)
        *data\window = DialogWindow(*data\dialog)
        *data\parentWindowID = parentWindowID
        *data\mod = *mod
        
        ; get gadgets
        Macro getGadget(gadget)
          *data\gadgets(gadget) = DialogGadget(*data\dialog, gadget)
          If *data\gadgets(gadget) = -1
            deb("modInformation:: could not get gadget '"+gadget+"'")
          EndIf
        EndMacro
        
        getGadget("top")
        getGadget("bar")
        getGadget("descriptionLabel")
        getGadget("description")
        getGadget("info")
        getGadget("idLabel")
        getGadget("id")
        getGadget("folderLabel")
        getGadget("folder")
        getGadget("tagsLabel")
        getGadget("tags")
        getGadget("dependenciesLabel")
;         getGadget("filesLabel")
;         getGadget("files")
        getGadget("sizeLabel")
        getGadget("size")
        getGadget("modSettings")
        getGadget("sourcesLabel")
        getGadget("image")
        
        UndefineMacro getGadget
        
        ; set text
        SetWindowTitle(*data\window, _("info_title"))
        SetGadgetText(*data\gadgets("descriptionLabel"),  _("info_description"))
        SetGadgetText(*data\gadgets("info"),              _("info_info"))
        SetGadgetText(*data\gadgets("idLabel"),           _("info_id"))
        SetGadgetText(*data\gadgets("folderLabel"),       _("info_folder"))
        SetGadgetText(*data\gadgets("tagsLabel"),         _("info_tags"))
        SetGadgetText(*data\gadgets("dependenciesLabel"), _("info_dependencies"))
;         SetGadgetText(*data\gadgets("filesLabel"),        _("info_files"))
        SetGadgetText(*data\gadgets("sizeLabel"),         _("info_size"))
        SetGadgetText(*data\gadgets("modSettings"),       _("info_mod_settings"))
        SetGadgetText(*data\gadgets("sourcesLabel"),      _("info_sources"))
        
        
;         SetGadgetText(*data\gadgets("name"),              *mod\name$+" (v"+*mod\version$+")")
        SetGadgetText(*data\gadgets("description"),       *mod\getDescription())
        SetGadgetText(*data\gadgets("id"),                *mod\getID())
        SetGadgetText(*data\gadgets("folder"),            *mod\getFoldername())
        SetGadgetText(*data\gadgets("tags"),              *mod\getTags())
        SetGadgetText(*data\gadgets("size"),              misc::printSize(*mod\getSize(#True)))
        
        If image
          SetGadgetState(*data\gadgets("image"), ImageID(image))
        EndIf
        
        SetWindowTitle(*data\window, *mod\getName()+" (v"+*mod\getVersion()+")")
        
        
        Static fontHeader, fontBigger
        If Not fontHeader
          fontHeader = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.8, #PB_Round_Nearest), #PB_Font_Bold)
        EndIf
        If Not fontBigger
          fontBigger = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.4, #PB_Round_Nearest), #PB_Font_Bold)
        EndIf
        
        ; bind events
        BindEvent(#PB_Event_CloseWindow, @ModInfoClose(), *data\window)
        AddKeyboardShortcut(*data\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
        BindEvent(#PB_Event_Menu, @ModInfoClose(), *data\window, #PB_Event_CloseWindow)
        BindGadgetEvent(*data\gadgets("folder"), @modInfoFolder(), #PB_EventType_LeftClick)
        
        ; get dynamic gadgets for event binding...
        ForEach *data\authors()
;           *data\authors()\gadgetContainer\id  = DialogGadget(*data\dialog, *data\authors()\gadgetContainer\name$)
          *data\authors()\gadgetImage\id      = DialogGadget(*data\dialog, *data\authors()\gadgetImage\name$)
          *data\authors()\gadgetAuthor\id     = DialogGadget(*data\dialog, *data\authors()\gadgetAuthor\name$)
          *data\authors()\gadgetRole\id       = DialogGadget(*data\dialog, *data\authors()\gadgetRole\name$)
;           SetGadgetData(*data\authors()\gadgetContainer\id, *data\authors())
          SetGadgetFont(*data\authors()\gadgetAuthor\id, FontID(fontBigger))
          ;BindGadgetEvent(, @modInfoAuthor())
          *data\authors()\thread = threads::NewThread(@modInfoAuthorImage(), *data\authors(), "modInformation::modInfoAuthorImage/"+*data\authors()\name$)
        Next
        
        If *mod\hasSettings()
          DisableGadget(*data\gadgets("modSettings"), #False)
          BindGadgetEvent(*data\gadgets("modSettings"), @modInfoShowSettings())
        EndIf
        
        ForEach *data\sources()
          *data\sources()\id = DialogGadget(*data\dialog, *data\sources()\name$)
          BindGadgetEvent(*data\sources()\id, @modInfoSource())
        Next
        
        
        ; store all information attached to the window:
        ; todo create structure for modInfoWindow
        SetWindowData(*data\window, *data)
        
        
        ;show
        ; DisableWindow(window, #True)
        RefreshDialog(*data\dialog)
        
        If StartDrawing(CanvasOutput(*data\gadgets("top")))
          FillArea(1, 1, -1, RGB(47, 71, 99))
          StopDrawing()
        EndIf
        If StartDrawing(CanvasOutput(*data\gadgets("bar")))
          FillArea(1, 1, -1, RGB(47, 71, 99))
          Box(0, GadgetHeight(*data\gadgets("bar"))-3, GadgetWidth(*data\gadgets("bar")), 3, RGB(130, 155, 175))
          StopDrawing()
        EndIf
        
        HideWindow(*data\window, #False, #PB_Window_WindowCentered)
        
        ProcedureReturn #True
      Else
        deb("modInformation:: "+DialogError(*data\dialog))
      EndIf
    EndIf
    ; failed to open window -> free data
    FreeStructure(*data)
  EndProcedure
  
  
EndModule
