﻿XIncludeFile "module_debugger.pbi"

DeclareModule aes
  EnableExplicit
  
  Declare encrypt(*buffer, length)
  Declare decrypt(*buffer, length)
  
  Declare.s encryptString(string$)
  Declare.s decryptString(string$)
EndDeclareModule

Module aes
  UseModule debugger
  
  DataSection
    key_aes:  ; 256 bit aes key
    IncludeBinary "key.aes"
  EndDataSection
  
  Procedure encrypt(*buffer, length) ; AES encrpyt memory
    If Not *buffer Or Not length
      ProcedureReturn #False
    EndIf
    
    Protected *out
    
    *out = AllocateMemory(length)
    If Not AESEncoder(*buffer, *out, length, ?key_aes, 256, #Null, #PB_Cipher_ECB)
      deb("aes:: failed to encode memory")
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    CopyMemory(*out, *buffer, length)
    FreeMemory(*out)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure decrypt(*buffer, length) ; decrypt memory
    If Not *buffer Or Not length
      ProcedureReturn #False
    EndIf
    
    Protected *out
    
    *out = AllocateMemory(length)
    If Not AESDecoder(*buffer, *out, length, ?key_aes, 256, #Null, #PB_Cipher_ECB)
      deb("aes:: failed to decode memory")
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    CopyMemory(*out, *buffer, length)
    FreeMemory(*out)
    
    ProcedureReturn #True
  EndProcedure
  
  
  Procedure.s encryptString(string$) ; convert plain text o AES (Base64 encoded)
    Protected *buffer, len, *out, out$
    
    len = StringByteLength(string$)
    If len = 0
      ProcedureReturn ""
    ElseIf len < 16
      len = 16
    EndIf
    *buffer = AllocateMemory(len+1)
    If *buffer
      PokeS(*buffer, string$)
      If encrypt(*buffer, len)
        *out = AllocateMemory(len*2+1)
        If *out
          If Base64EncoderBuffer(*buffer, len, *out, len*2)
            out$ = PeekS(*out, len*2, #PB_Ascii)
            FreeMemory(*out)
          Else
            deb("aes:: failed to allocate base64 encode memory")
          EndIf
        Else
          deb("aes:: failed to allocate output memory")
        EndIf
      Else
        deb("aes:: failed to encrypt string")
      EndIf
      FreeMemory(*buffer)
    Else
      deb("aes:: failed to allocate input memory")
    EndIf
    ProcedureReturn out$
  EndProcedure
  
  Procedure.s decryptString(string$) ; convert an Base64 encoded AES string to plain text
    Protected *buffer, len, *out, out$
    
    len = StringByteLength(string$)
    If len = 0
      ProcedureReturn ""
    ElseIf len < 16
      len = 16
    EndIf
    *buffer = AllocateMemory(len+1)
    If *buffer
      ; write ASCII coded Base64 string to *buffer
      len = PokeS(*buffer, string$, StringByteLength(string$, #PB_Ascii), #PB_Ascii|#PB_String_NoZero)
      *out = AllocateMemory(len+1)
      If *out
        ; *buffer contains Base64 (ASCII)
        len = Base64DecoderBuffer(*buffer, len, *out, len)
        ; *out points to memory area with AES encrypted data
        If decrypt(*out, len)
          out$ = PeekS(*out, len)
        Else
          deb("aes:: failed to decrypt string")
        EndIf
        FreeMemory(*out)
      Else
        deb("aes:: failed to allocate memory")
      EndIf
      FreeMemory(*buffer)
    Else
      deb("aes:: failed to allocate memory")
    EndIf
    ProcedureReturn out$
  EndProcedure
  
EndModule