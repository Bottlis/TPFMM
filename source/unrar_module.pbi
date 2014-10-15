﻿; http://www.purebasic.fr/english/viewtopic.php?f=40&t=56876

DeclareModule unrar
  #ERAR_SUCCESS             = 0
  #ERAR_END_ARCHIVE         = 10
  #ERAR_NO_MEMORY           = 11
  #ERAR_BAD_DATA            = 12
  #ERAR_BAD_ARCHIVE         = 13
  #ERAR_UNKNOWN_FORMAT      = 14
  #ERAR_EOPEN               = 15
  #ERAR_ECREATE             = 16
  #ERAR_ECLOSE              = 17
  #ERAR_EREAD               = 18
  #ERAR_EWRITE              = 19
  #ERAR_SMALL_BUF           = 20
  #ERAR_UNKNOWN             = 21
  #ERAR_MISSING_PASSWORD    = 22
  
  #RAR_OM_LIST              = 0
  #RAR_OM_EXTRACT           = 1
  #RAR_OM_LIST_INCSPLIT     = 2
  
  #RAR_SKIP                 = 0
  #RAR_TEST                 = 1
  #RAR_EXTRACT              = 2
  
  #RAR_VOL_ASK              = 0
  #RAR_VOL_NOTIFY           = 1
  
  #RAR_DLL_VERSION          = 6
  
  #RAR_HASH_NONE            = 0
  #RAR_HASH_CRC32           = 1
  #RAR_HASH_BLAKE2          = 2
  
  #RHDF_SPLITBEFORE         = $01
  #RHDF_SPLITAFTER          = $02
  #RHDF_ENCRYPTED           = $04
  #RHDF_SOLID               = $10
  #RHDF_DIRECTORY           = $20

  Enumeration
    #UCM_CHANGEVOLUME
    #UCM_PROCESSDATA
    #UCM_NEEDPASSWORD
    #UCM_CHANGEVOLUMEW
    #UCM_NEEDPASSWORDW
  EndEnumeration
  
  Structure RARHeaderDataEx
    ArcName.b[1024]
    ArcNameW.w[1024]
    FileName.b[1024]
    FileNameW.w[1024]
    Flags.l
    PackSize.q
    UnpSize.q
    HostOS.l
    FileCRC.l
    FileTime.l
    UnpVer.l
    Method.l
    FileAttr.l
    *CmtBuf
    CmtBufSize.l
    CmtSize.l
    CmtState.l
    DictSize.l
    HashType.l
    Hash.b[32]
    Reserved.l[1014]
  EndStructure
  
  Structure RAROpenArchiveDataEx
    *ArcName
    *ArcNameW
    OpenMode.l
    OpenResult.l
    *CmtBuf
    CmtBufSize.l
    CmtSize.l
    CmtState.l
    Flags.l
    *Callback
    UserData.i
    Reserved.l[28]
  EndStructure

  Prototype UNRARCALLBACK(msg, UserData, P1, P2)
  Prototype CHANGEVOLPROC(ArcName.s, Mode)
  Prototype PROCESSDATAPROC(*Addr, Size)
  Prototype RAROpenArchive(*ArchiveData.RAROpenArchiveDataEx)
  Prototype RARCloseArchive(hArcData)
  Prototype RARReadHeader(hArcData, *HeaderData.RARHeaderDataEx)
  Prototype RARProcessFile(hArcData, Operation, DestPath.s, DestName.s)
  Prototype RARSetCallback(hArcData, *Callback.UNRARCALLBACK, UserData)
  Prototype RARSetChangeVolProc(hArcData, *ChangeVolProc.CHANGEVOLPROC)
  Prototype RARSetProcessDataProc(hArcData, *ProcessDataProc.PROCESSDATAPROC)
  Prototype RARSetPassword(hArcData, Password.p-ascii)
  Prototype RARGetDllVersion()
  
  Global RAROpenArchive.RAROpenArchive
  Global RARProcessFile.RARProcessFile
  Global RAROpenArchive.RAROpenArchive
  Global RARProcessFile.RARProcessFile
  Global RARReadHeader.RARReadHeader
  Global RARCloseArchive.RARCloseArchive
  Global RARSetCallback.RARSetCallback
  Global RARSetChangeVolProc.RARSetChangeVolProc
  Global RARSetProcessDataProc.RARSetProcessDataProc
  Global RARSetPassword.RARSetPassword
  Global RARGetDllVersion.RARGetDllVersion
  
  Declare RARUnpackArchiv(FileName.s, DestPath.s = "", Password.s = "", *Callback = 0)
EndDeclareModule

Module unrar
  EnableExplicit

  Define DLL
  
  CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
    DLL = OpenLibrary(#PB_Any, "unrar64.dll")
  CompilerElse
    DLL = OpenLibrary(#PB_Any, "unrar.dll")
  CompilerEndIf
  
  If DLL
    RAROpenArchive        = GetFunction(DLL, "RAROpenArchiveEx")
    CompilerIf #PB_Compiler_Unicode
    RARProcessFile        = GetFunction(DLL, "RARProcessFileW")
    CompilerElse
    RARProcessFile        = GetFunction(DLL, "RARProcessFile")
    CompilerEndIf
    RARReadHeader         = GetFunction(DLL, "RARReadHeaderEx")
    RARCloseArchive       = GetFunction(DLL, "RARCloseArchive")
    RARSetCallback        = GetFunction(DLL, "RARSetCallback")
    RARSetChangeVolProc   = GetFunction(DLL, "RARSetChangeVolProc")
    RARSetProcessDataProc = GetFunction(DLL, "RARSetProcessDataProc")
    RARSetPassword        = GetFunction(DLL, "RARSetPassword")
    RARGetDllVersion      = GetFunction(DLL, "RARGetDllVersion")
  EndIf
  
  Procedure Callback(msg, UserData, P1, P2)
    Protected PWD.s
    
    If UserData
      PWD = PeekS(UserData)
    EndIf
    Select msg
      Case #UCM_NEEDPASSWORD
        If PWD = ""
          PWD = InputRequester("Password", "Password required:", "", #PB_InputRequester_Password)
        EndIf
        If PWD
          PokeS(P1, PWD, P2, #PB_Ascii)
          ProcedureReturn #True
        EndIf
      Case #UCM_NEEDPASSWORDW
        If PWD = ""
          PWD = InputRequester("Password", "Password required:", "", #PB_InputRequester_Password)
        EndIf
        If PWD
          PokeS(P1, PWD, P2, #PB_Unicode)
          ProcedureReturn #True
        EndIf
    EndSelect
  EndProcedure
  
  Procedure RARUnpackArchiv(FileName.s, DestPath.s = "", Password.s = "", *Callback = 0)
    Protected raropen.RAROpenArchiveDataEx
    Protected rarheader.RARHeaderDataEx
    Protected hRAR, NoError = #True
    
    CompilerIf #PB_Compiler_Unicode
      raropen\ArcNameW = @Filename
    CompilerElse
      raropen\ArcName = @Filename
      If DestPath
        CharToOem_(DestPath, DestPath)
      EndIf
    CompilerEndIf
    raropen\OpenMode = #RAR_OM_EXTRACT
    If Password
      raropen\UserData = @Password
    EndIf
    If *Callback
      raropen\Callback = *Callback
    Else
      raropen\Callback = @Callback()
    EndIf
    
    
    hRAR = RAROpenArchive(raropen)
    
    If hRAR
      While RARReadHeader(hRAR, rarheader) = #ERAR_SUCCESS
        Debug "---- rarheader ----"
        Debug PeekS(@rarheader\ArcName,1024,#PB_Ascii)
        Debug PeekS(@rarheader\ArcNameW,1024,#PB_Unicode)
        Debug PeekS(@rarheader\FileName,#PB_Ascii)
        Debug PeekS(@rarheader\FileNameW)
        Debug "Destination: "+DestPath
        If RARProcessFile(hRAR, #RAR_EXTRACT, DestPath, #NULL$) <> #ERAR_SUCCESS
          NoError = #False
        EndIf
      Wend
      RARCloseArchive(hRAR)
    EndIf
    ProcedureReturn NoError
  EndProcedure
  
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 203
; FirstLine = 163
; Folding = --
; EnableUnicode
; EnableXP