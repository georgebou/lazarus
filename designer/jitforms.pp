{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
 
  Author: Mattias Gaertner

  Abstract:
    This unit defines a list of forms descendents. The forms are normal TForm
    descendents with one exception: Every form has its own class. These classes
    are changeable at runtime, so that IDEs can add, remove or rename methods
    and such stuff. Also these forms can be loaded from streams and missing
    components and methods are added just-in-time to the class definition.
    Hence the name for the class: TJITForms.
    Subcomponents are looked up in the list of registered components
    (TJITForms.RegCompList).

  ToDo:
    -Add recursion needed for frames.
}
unit JITForms;

{$mode objfpc}{$H+}

{$I ide.inc}

interface

uses
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, Forms, Controls, LCLLinux, Dialogs, JITForm, ComponentReg,
  IDEProcs;

type
  //----------------------------------------------------------------------------
  TJITFormError = (
      jfeNone,
      jfeUnknown,
      jfeUnknownProperty,
      jfeUnknownComponentClass,
      jfeReaderError
    );
  TJITFormErrors = set of TJITFormError;
  
  TJITReaderErrorEvent = procedure(Sender: TObject; ErrorType: TJITFormError;
    var Action: TModalResult) of object;


  { TJITComponentList }

  TJITComponentList = class(TPersistentWithTemplates)
  private
    FComponentPrefix: string;
    procedure SetComponentPrefix(const AValue: string);
  protected
    FCurReadErrorMsg: string;
    FCurReadJITComponent:TComponent;
    FCurReadClass:TClass;
    FCurReadChild: TComponent;
    FCurReadChildClass: TComponentClass;
    FOnReaderError: TJITReaderErrorEvent;
    FJITComponents: TList;
    // jit procedures
    function CreateVMTCopy(SourceClass: TClass;
                           const NewClassName: ShortString):Pointer;
    procedure FreevmtCopy(vmtCopy: Pointer);
    procedure DoAddNewMethod(JITClass:TClass;
                             const AName:ShortString; ACode:Pointer);
      // AddNewMethod does not check if method already exists
    procedure DoRemoveMethod(JITClass:TClass; AName:ShortString;
                             var OldCode:Pointer);
      // RemoveMethod does not free code memory
    procedure DoRenameMethod(JITClass:TClass; OldName,NewName:ShortString);
    procedure DoRenameClass(JITClass:TClass; const NewName:ShortString);
    // TReader events
    procedure ReaderFindMethod(Reader: TReader; const FindMethodName: Ansistring;
      var Address: Pointer; var Error: Boolean);
    procedure ReaderSetName(Reader: TReader; Component: TComponent;
      var NewName: Ansistring);
    procedure ReaderReferenceName(Reader: TReader; var RefName: Ansistring);
    procedure ReaderAncestorNotFound(Reader: TReader;
      const ComponentName: Ansistring; ComponentClass: TPersistentClass;
      var Component: TComponent);
    procedure ReaderError(Reader: TReader; const ErrorMsg: Ansistring;
      var Handled: Boolean);
    procedure ReaderFindComponentClass(Reader: TReader;
      const FindClassName: Ansistring; var ComponentClass: TComponentClass);
    procedure ReaderCreateComponent(Reader: TReader;
      ComponentClass: TComponentClass; var Component: TComponent);
    // some useful functions
    function GetItem(Index:integer):TComponent;
    function GetClassNameFromStream(s:TStream):shortstring;
    function OnFindGlobalComponent(const AName:AnsiString):TComponent;
    procedure InitReading;
    function DoCreateJITComponent(NewComponentName,NewClassName:shortstring
                                  ):integer;
    procedure DoFinishReading; virtual;
    function CreateDefaultVMTCopy: Pointer; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    property Items[Index:integer]: TComponent read GetItem; default;
    function Count:integer;
    function AddNewJITComponent:integer;
    function AddJITComponentFromStream(BinStream:TStream):integer;
    procedure DestroyJITComponent(JITComponent:TComponent);
    procedure DestroyJITComponent(Index:integer);
    function IndexOf(JITComponent:TComponent):integer;
    function FindComponentByClassName(const AClassName:shortstring):integer;
    function FindComponentByName(const AName:shortstring):integer;
    procedure GetUnusedNames(var ComponentName, ComponentClassName: shortstring);
    procedure AddNewMethod(JITComponent: TComponent; const AName: ShortString);
    function CreateNewMethod(JITComponent:TComponent;
                             const AName:ShortString): TMethod;
    procedure RemoveMethod(JITComponent:TComponent; const AName:ShortString);
    procedure RenameMethod(JITComponent:TComponent;
                           const OldName,NewName:ShortString);
    procedure RenameComponentClass(JITComponent:TComponent;
                                   const NewName:ShortString);
  public
    property OnReaderError: TJITReaderErrorEvent
                                       read FOnReaderError write FOnReaderError;
    property CurReadJITComponent:TComponent read FCurReadJITComponent;
    property CurReadClass:TClass read FCurReadClass;
    property CurReadChild: TComponent read FCurReadChild;
    property CurReadChildClass: TComponentClass read FCurReadChildClass;
    property CurReadErrorMsg: string read FCurReadErrorMsg;
    property ComponentPrefix: string read FComponentPrefix
                                     write SetComponentPrefix;
  end;


  { TJITForms }
  
  TJITForms = class(TJITComponentList)
  private
    function GetItem(Index: integer): TForm;
  protected
    procedure DoFinishReading; override;
    function CreateDefaultVMTCopy: Pointer; override;
  public
    constructor Create;
    function IsJITForm(AComponent: TComponent): boolean;
    property Items[Index:integer]: TForm read GetItem; default;
  end;
  
  
  { TJITDataModules }
  
  TJITDataModules = class(TJITComponentList)
  private
    function GetItem(Index: integer): TDataModule;
  protected
    function CreateDefaultVMTCopy: Pointer; override;
  public
    constructor Create;
    function IsJITDataModule(AComponent: TComponent): boolean;
    property Items[Index:integer]: TDataModule read GetItem; default;
  end;

implementation

var
  MyFindGlobalComponentProc:function(const AName:AnsiString):TComponent of object;

function MyFindGlobalComponent(const AName:AnsiString):TComponent;
begin
  Result:=MyFindGlobalComponentProc(AName);
end;

  //----------------------------------------------------------------------------


{ TJITComponentList }

constructor TJITComponentList.Create;
begin
  inherited Create;
  FComponentPrefix:='Form';
  FJITComponents:=TList.Create;
end;

destructor TJITComponentList.Destroy;
begin
  while FJITComponents.Count>0 do DestroyJITComponent(FJITComponents.Count-1);
  FJITComponents.Free;
  inherited Destroy;
end;

function TJITComponentList.GetItem(Index:integer):TComponent;
begin
  Result:=TComponent(FJITComponents[Index]);
end;

function TJITComponentList.Count:integer;
begin
  Result:=FJITComponents.Count;
end;

function TJITComponentList.IndexOf(JITComponent:TComponent):integer;
begin
  Result:=Count-1;
  while (Result>=0) and (Items[Result]<>JITComponent) do dec(Result);
end;

procedure TJITComponentList.DestroyJITComponent(JITComponent:TComponent);
var a:integer;
begin
  if JITComponent=nil then
    RaiseException('TJITComponentList.DestroyJITForm JITComponent=nil');
  a:=IndexOf(JITComponent);
  if a<0 then
    RaiseException('TJITComponentList.DestroyJITForm JITComponent.ClassName='+
      JITComponent.ClassName);
  if a>=0 then DestroyJITComponent(a);
end;

procedure TJITComponentList.DestroyJITComponent(Index:integer);
var OldClass:TClass;
begin
  OldClass:=Items[Index].ClassType;
  Items[Index].Free;
  FreevmtCopy(OldClass);
  FJITComponents.Delete(Index);
end;

function TJITComponentList.FindComponentByClassName(
  const AClassName:shortstring):integer;
begin
  Result:=FJITComponents.Count-1;
  while (Result>=0)
  and (AnsiCompareText(Items[Result].ClassName,AClassName)<>0) do
    dec(Result);
end;

function TJITComponentList.FindComponentByName(const AName:shortstring):integer;
begin
  Result:=FJITComponents.Count-1;
  while (Result>=0)
  and (AnsiCompareText(Items[Result].Name,AName)<>0) do
    dec(Result);
end;

procedure TJITComponentList.GetUnusedNames(
  var ComponentName,ComponentClassName:shortstring);
var a:integer;
begin
  a:=1;
  repeat
    ComponentName:=ComponentPrefix+IntToStr(a);
    ComponentClassName:='T'+ComponentPrefix+IntToStr(a);
    inc(a);
  until (FindComponentByName(ComponentName)<0)
        and (FindComponentByClassName(ComponentClassName)<0);
end;

function TJITComponentList.GetClassNameFromStream(s:TStream):shortstring;
var Signature:shortstring;
  NameLen:byte;
begin
  Result:='';
  // read signature
  Signature:='1234';
  s.Read(Signature[1],length(Signature));
  if Signature<>'TPF0' then exit;
  // read classname length
  NameLen:=0;
  s.Read(NameLen,1);
  // read classname
  if NameLen>0 then begin
    SetLength(Result,NameLen);
    s.Read(Result[1],NameLen);
  end;
  s.Position:=0;
end;

function TJITComponentList.AddNewJITComponent:integer;
var NewComponentName,NewClassName:shortstring;
begin
  {$IFDEF IDE_VERBOSE}
  Writeln('[TJITComponentList] AddNewJITComponent');
  {$ENDIF}
  GetUnusedNames(NewComponentName,NewClassName);
  {$IFDEF IDE_VERBOSE}
  Writeln('NewComponentName is ',NewComponentName,', NewClassName is ',NewClassName);
  {$ENDIF}
  Result:=DoCreateJITComponent(NewComponentName,NewClassName);
end;

function TJITComponentList.AddJITComponentFromStream(BinStream:TStream):integer;
//  returns new index
// -1 = invalid stream
var
  Reader:TReader;
  NewClassName:shortstring;
  NewName: string;
begin
  Result:=-1;
  NewClassName:=GetClassNameFromStream(BinStream);
  if NewClassName='' then begin

    // Application.MessageBox('No classname in form stream found.','',mb_OK);
    MessageDlg('No classname in stream found.',mterror,[mbOK],0);

    exit;
  end;
  {$IFDEF IDE_VERBOSE}
  writeln('[TJITComponentList.AddJITFormFromStream] 1');
  {$ENDIF}
  try
    Result:=DoCreateJITComponent('',NewClassName);
    {$IFDEF IDE_VERBOSE}
    writeln('[TJITComponentList.AddJITFormFromStream] 2');
    {$ENDIF}

    Reader:=TReader.Create(BinStream,4096);
    MyFindGlobalComponentProc:=@OnFindGlobalComponent;
    FindGlobalComponent:=@MyFindGlobalComponent;

    {$IFDEF IDE_VERBOSE}
    writeln('[TJITComponentList.AddJITFormFromStream] 3');
    {$ENDIF}
    try
      // connect TReader events
      Reader.OnError:=@ReaderError;
      Reader.OnFindMethod:=@ReaderFindMethod;
      Reader.OnSetName:=@ReaderSetName;
      Reader.OnReferenceName:=@ReaderReferenceName;
      Reader.OnAncestorNotFound:=@ReaderAncestorNotFound;
      Reader.OnCreateComponent:=@ReaderCreateComponent;
      Reader.OnFindComponentClass:=@ReaderFindComponentClass;

      {$IFDEF IDE_VERBOSE}
      writeln('[TJITComponentList.AddJITFormFromStream] 4');
      {$ENDIF}
      InitReading;

      Reader.ReadRootComponent(FCurReadJITComponent);
      if FCurReadJITComponent.Name='' then begin
        NewName:=FCurReadJITComponent.ClassName;
        if NewName[1] in ['T','t'] then
          System.Delete(NewName,1,1);
        FCurReadJITComponent.Name:=NewName;
      end;

      {$IFDEF IDE_VERBOSE}
      writeln('[TJITComponentList.AddJITFormFromStream] 5');
      {$ENDIF}
      DoFinishReading;
    finally
      FindGlobalComponent:=nil;
      Reader.Free;
    end;
  except
    writeln('[TJITComponentList.AddJITFormFromStream] ERROR reading form stream'
       +' of Class ''',NewClassName,'''');
    Result:=-1;
  end;
end;

function TJITComponentList.OnFindGlobalComponent(const AName:AnsiString):TComponent;
begin
  Result:=Application.FindComponent(AName);
end;

procedure TJITComponentList.InitReading;
begin
  FCurReadChildClass:=nil;
  FCurReadChild:=nil;
  FCurReadErrorMsg:='';
end;

function TJITComponentList.DoCreateJITComponent(
  NewComponentName,NewClassName:shortstring):integer;
var
  Instance:TComponent;
  ok: boolean;
begin
  Result:=-1;
  // create new class and an instance
  //writeln('[TJITForms.DoCreateJITComponent] Creating new JIT class '''+NewClassName+''' ...');
  Pointer(FCurReadClass):=CreateDefaultVMTCopy;
  //writeln('[TJITForms.DoCreateJITComponent] Creating an instance of JIT class '''+NewClassName+''' ...');
  Instance:=TComponent(FCurReadClass.NewInstance);
  //writeln('[TJITForms.DoCreateJITComponent] Initializing new instance ...');
  TComponent(FCurReadJITComponent):=Instance;
  ok:=false;
  try
    Instance.Create(nil);
    if NewComponentName<>'' then
      Instance.Name:=NewComponentName;
    DoRenameClass(FCurReadClass,NewClassName);
    ok:=true;
  //writeln('[TJITForms.DoCreateJITComponent] Initialization was successful! FormName="',NewFormName,'"');
  finally
    if not ok then begin
      TComponent(FCurReadJITComponent):=nil;
      writeln('[TJITForms.DoCreateJITComponent] Error while creating instance');
    end;
  end;
  Result:=FJITComponents.Add(FCurReadJITComponent);
end;

procedure TJITComponentList.DoFinishReading;
begin

end;

procedure TJITComponentList.AddNewMethod(JITComponent:TComponent;
  const AName:ShortString);
begin
  CreateNewmethod(JITComponent,AName);
end;

procedure TJITComponentList.RemoveMethod(JITComponent:TComponent;
  const AName:ShortString);
var OldCode:Pointer;
begin
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RemoveMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RemoveMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if (AName='') or (not IsValidIdent(AName)) then
    raise Exception.Create('TJITComponentList.RemoveMethod invalid name: "'+AName+'"');
  OldCode:=nil;
  DoRemoveMethod(JITComponent.ClassType,AName,OldCode);
  FreeMem(OldCode);
end;

procedure TJITComponentList.RenameMethod(JITComponent:TComponent;
  const OldName,NewName:ShortString);
begin
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RenameMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RenameMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if (NewName='') or (not IsValidIdent(NewName)) then
    raise Exception.Create('TJITComponentList.RenameMethod invalid name: "'+NewName+'"');
  DoRenameMethod(JITComponent.ClassType,OldName,NewName);
end;

procedure TJITComponentList.RenameComponentClass(JITComponent:TComponent;
  const NewName:ShortString);
begin
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RenameComponentClass JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RenameComponentClass JITComponent.ClassName='+
      JITComponent.ClassName);
  if (NewName='') or (not IsValidIdent(NewName)) then
    raise Exception.Create('TJITComponentList.RenameComponentClass invalid name: "'+NewName+'"');
  DoRenameClass(JITComponent.ClassType,NewName);
end;

function TJITComponentList.CreateNewMethod(JITComponent: TComponent;
  const AName: ShortString): TMethod;
var CodeTemplate,NewCode:Pointer;
  CodeSize:integer;
  OldCode: Pointer;
begin
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.CreateNewMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.CreateNewMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if (AName='') or (not IsValidIdent(AName)) then
    raise Exception.Create('TJITComponentList.CreateNewMethod invalid name: "'+AName+'"');
  OldCode:=JITComponent.MethodAddress(AName);
  if OldCode<>nil then begin
    Result.Data:=JITComponent;
    Result.Code:=OldCode;
    exit;
  end;
  CodeTemplate:=MethodAddress('DoNothing');
  CodeSize:=100; // !!! what is the real codesize of DoNothing? !!!
  GetMem(NewCode,CodeSize);
  Move(CodeTemplate^,NewCode^,CodeSize);
  DoAddNewMethod(JITComponent.ClassType,AName,NewCode);
  Result.Data:=JITComponent;
  Result.Code:=NewCode;
end;

//------------------------------------------------------------------------------
// adding, removing and renaming of classes and methods at runtime

type
  // these definitions are copied from objpas.inc

  TMethodNameRec = packed record
    Name : PShortString;
    Addr : Pointer;
  end;

  TMethodNameTable = packed record
    Count : DWord;
    Entries : packed array[0..0] of TMethodNameRec;
  end;

  PMethodNameTable =  ^TMethodNameTable;

procedure TJITComponentList.SetComponentPrefix(const AValue: string);
begin
  if FComponentPrefix=AValue then exit;
  FComponentPrefix:=AValue;
end;

function TJITComponentList.CreateVMTCopy(SourceClass:TClass;
  const NewClassName:ShortString):Pointer;
const
  vmtSize:integer=2000; //XXX how big is the vmt of class TJITForm ?
var MethodTable, NewMethodTable : PMethodNameTable;
  MethodTableSize: integer;
  ClassNamePtr, ClassNamePShortString: Pointer;
begin
//writeln('[TJITComponentList.CreatevmtCopy] SourceClass='''+SourceClass.ClassName+''''
// +' NewClassName='''+NewClassName+'''');
  // create copy of vmt
  GetMem(Result,vmtSize);
  // type of self is class of TJITForm => it points to the vmt
  Move(Pointer(SourceClass)^,Result^,vmtSize);
  // create copy of methodtable
  MethodTable:=PMethodNameTable((Pointer(SourceClass)+vmtMethodTable)^);
  if Assigned(MethodTable) then begin
    MethodTableSize:=SizeOf(DWord)+
                     MethodTable^.Count*SizeOf(TMethodNameRec);
    GetMem(NewMethodTable,MethodTableSize);
    Move(MethodTable^,NewMethodTable^,MethodTableSize);
    PPointer(Result+vmtMethodTable)^:=NewMethodTable;
  end;
  // create pointer to classname
  // set ClassNamePtr to point to the PShortString of ClassName 
  ClassNamePtr:=Pointer(Result)+vmtClassName;
  GetMem(ClassNamePShortString,SizeOf(ShortString));
  Pointer(ClassNamePtr^):=ClassNamePShortString;
  Move(NewClassName[0],ClassNamePShortString^,SizeOf(ShortString));
end;

procedure TJITComponentList.FreevmtCopy(vmtCopy:Pointer);

  procedure FreeNewMethods(MethodTable: PMethodNameTable);
  var
    CurCount, BaseCount, i: integer;
    BaseMethodTable: PMethodNameTable;
    CurMethod: TMethodNameRec;
  begin
    if MethodTable=nil then exit;
    BaseMethodTable:=PMethodNameTable((Pointer(TJITForm)+vmtMethodTable)^);
    if Assigned(BaseMethodTable) then
      BaseCount:=BaseMethodTable^.Count
    else
      BaseCount:=0;
    CurCount:=MethodTable^.Count;
    if CurCount=BaseCount then exit;
    i:=CurCount;
    while i>BaseCount do begin
      CurMethod:=MethodTable^.Entries[i-1];
      if CurMethod.Name<>nil then
        FreeMem(CurMethod.Name);
      if CurMethod.Addr<>nil then
        FreeMem(CurMethod.Addr);
      dec(i);
    end;
  end;

var
  MethodTable : PMethodNameTable;
  ClassNamePtr: Pointer;
begin
  //writeln('[TJITComponentList.FreevmtCopy] ClassName='''+TClass(vmtCopy).ClassName+'''');
  if vmtCopy=nil then exit;
  // free copy of methodtable
  MethodTable:=PMethodNameTable((Pointer(vmtCopy)+vmtMethodTable)^);
  if (Assigned(MethodTable)) then begin
    FreeNewMethods(MethodTable);
    FreeMem(MethodTable);
  end;
  // free pointer to classname
  ClassNamePtr:=Pointer(vmtCopy)+vmtClassName;
  FreeMem(Pointer(ClassNamePtr^));
  // free copy of VMT
  FreeMem(vmtCopy);
end;

procedure TJITComponentList.DoAddNewMethod(JITClass:TClass;
  const AName:ShortString;  ACode:Pointer);
var OldMethodTable, NewMethodTable: PMethodNameTable;
  NewMethodTableSize:integer;
begin
  //writeln('[TJITComponentList.AddNewMethod] '''+JITClass.ClassName+'.'+AName+'''');
  OldMethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  if Assigned(OldMethodTable) then begin
    NewMethodTableSize:=SizeOf(DWord)+
                     (OldMethodTable^.Count + 1)*SizeOf(TMethodNameRec);
  end else begin
    NewMethodTableSize:=SizeOf(DWord)+SizeOf(TMethodNameRec);
  end;
  GetMem(NewMethodTable,NewMethodTableSize);
  if Assigned(OldMethodTable) then begin
    Move(OldMethodTable^,NewMethodTable^,
      NewMethodTableSize-SizeOf(TMethodNameRec));
    NewMethodTable^.Count:=NewMethodTable^.Count+1;
  end else begin
    NewMethodTable^.Count:=1;
  end;
  {$R-}
  //for a:=0 to NewMethodTable^.Count-2 do
  //  writeln(a,'=',NewMethodTable^.Entries[a].Name^,' $'
  //    ,HexStr(Integer(NewMethodTable^.Entries[a].Name),8));
  with NewMethodTable^.Entries[NewMethodTable^.Count-1] do begin
    GetMem(Name,256);
    Name^:=AName;
    Addr:=ACode;
  end;
  //for a:=0 to NewMethodTable^.Count-1 do
  //  writeln(a,'=',NewMethodTable^.Entries[a].Name^,' $'
  //    ,HexStr(Integer(NewMethodTable^.Entries[a].Name),8));
  {$R+}
  PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^):=NewMethodTable;
  if Assigned(OldMethodTable) then
    FreeMem(OldMethodTable);
end;

procedure TJITComponentList.DoRemoveMethod(JITClass:TClass;
  AName:ShortString; var OldCode:Pointer);
var OldMethodTable, NewMethodTable: PMethodNameTable;
  NewMethodTableSize:integer;
  a:cardinal;
begin
  {$IFDEF IDE_VERBOSE}
  writeln('[TJITComponentList.DoRemoveMethod] '''+JITClass.ClassName+'.'+AName+'''');
  {$ENDIF}
  AName:=uppercase(AName);
  OldMethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  OldCode:=nil;
  if Assigned(OldMethodTable) then begin
    a:=0;
    while a<OldMethodTable^.Count do begin
      {$R-}
      if uppercase(OldMethodTable^.Entries[a].Name^)=AName then begin
        OldCode:=OldMethodTable^.Entries[a].Addr;
        FreeMem(OldMethodTable^.Entries[a].Name);
        if OldMethodTable^.Count>0 then begin
          NewMethodTableSize:=SizeOf(DWord)+
                     OldMethodTable^.Count*SizeOf(TMethodNameRec);
          GetMem(NewMethodTable,NewMethodTableSize);
          NewMethodTable^.Count:=OldMethodTable^.Count-1;
          Move(OldMethodTable^,NewMethodTable^,SizeOf(DWord)+
                                                     a*SizeOf(TMethodNameRec));
          Move(OldMethodTable^.Entries[a],NewMethodTable^.Entries[a+1],
                 SizeOf(DWord)+a*SizeOf(TMethodNameRec));
        end else begin
          NewMethodTable:=nil;
        end;
        PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^):=NewMethodTable;
        FreeMem(OldMethodTable);
        break;
      end;
      {$R+}
      inc(a);
    end;
  end;
end;

procedure TJITComponentList.DoRenameMethod(JITClass:TClass;
  OldName,NewName:ShortString);
var MethodTable: PMethodNameTable;
  a:integer;
begin
  {$IFDEF IDE_VERBOSE}
  writeln('[TJITComponentList.DoRenameMethod] ClassName='''+JITClass.ClassName+''''
    +' OldName='''+OldName+''' NewName='''+OldName+'''');
  {$ENDIF}
  OldName:=uppercase(OldName);
  MethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  if Assigned(MethodTable) then begin
    for a:=0 to MethodTable^.Count-1 do begin
      if uppercase(MethodTable^.Entries[a].Name^)=OldName then
        MethodTable^.Entries[a].Name^:=NewName;
    end;
  end;
end;

procedure TJITComponentList.DoRenameClass(JITClass:TClass;
  const NewName:ShortString);
begin
  {$IFDEF IDE_VERBOSE}
  writeln('[TJITComponentList.DoRenameClass] OldName='''+JITClass.ClassName
    +''' NewName='''+NewName+''' ');
  {$ENDIF}
  PShortString((Pointer(JITClass)+vmtClassName)^)^:=NewName;
end;

//------------------------------------------------------------------------------

{
  TReader events.
  If a LFM is streamed back into the corresponfing TForm descendent, all methods
  and components are published members and TReader can set these values.
  But at design time we do not have the corresponding TForm descendent. And
  there is no compiled code, thus it must be produced it at runtime
  (just-in-time).
}

procedure TJITComponentList.ReaderFindMethod(Reader: TReader;
  const FindMethodName: Ansistring;  var Address: Pointer; var Error: Boolean);
var NewMethod: TMethod;
begin
  {$IFDEF IDE_DEBUG}
  writeln('[TJITComponentList.ReaderFindMethod] A "'+FindMethodName+'" Address=',HexStr(Cardinal(Address),8));
  {$ENDIF}
  if Address=nil then begin
    // there is no method in the ancestor class with this name
    // => add a JIT method with this name to the JITForm
    NewMethod:=CreateNewMethod(FCurReadJITComponent,FindMethodName);
    Address:=NewMethod.Code;
    Error:=false;
  end;
end;

procedure TJITComponentList.ReaderSetName(Reader: TReader; Component: TComponent;
  var NewName: Ansistring);
begin
//  writeln('[TJITComponentList.ReaderSetName] OldName="'+Component.Name+'" NewName="'+NewName+'"');
end;

procedure TJITComponentList.ReaderReferenceName(Reader: TReader; var RefName: Ansistring);
begin
//  writeln('[TJITComponentList.ReaderReferenceName] Name='''+RefName+'''');
end;

procedure TJITComponentList.ReaderAncestorNotFound(Reader: TReader;
  const ComponentName: Ansistring;  ComponentClass: TPersistentClass;
  var Component: TComponent);
begin
// ToDo: this is for custom form templates
//  writeln('[TJITComponentList.ReaderAncestorNotFound] ComponentName='''+ComponentName
//    +''' Component='''+Component.Name+'''');
end;

procedure TJITComponentList.ReaderError(Reader: TReader;
  const ErrorMsg: Ansistring; var Handled: Boolean);
// ToDo: use SUnknownProperty when it is published by the fpc team
const
  SUnknownProperty = 'Unknown property';
var
  ErrorType: TJITFormError;
  Action: TModalResult;
begin
  ErrorType:=jfeReaderError;
  Action:=mrCancel;
  FCurReadErrorMsg:=ErrorMsg;
  // find out, what error occured
  if RightStr(ErrorMsg,length(SUnknownProperty))=SUnknownProperty then begin
    ErrorType:=jfeUnknownProperty;
    Action:=mrIgnore;
  end;
  if Assigned(OnReaderError) then
    OnReaderError(Self,ErrorType,Action);
  Handled:=Action in [mrIgnore];
  writeln('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
  writeln('[TJITComponentList.ReaderError] "'+ErrorMsg+'" ignoring=',Handled);
  writeln('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<');
end;

procedure TJITComponentList.ReaderFindComponentClass(Reader: TReader;
  const FindClassName: Ansistring;  var ComponentClass: TComponentClass);
var
  RegComp: TRegisteredComponent;
  Action: TModalResult;
  ErrorType: TJITFormError;
begin
  fCurReadChild:=nil;
  fCurReadChildClass:=ComponentClass;
  if ComponentClass=nil then begin
    {$IFDEF DisablePkgs}
    RegComp:=FRegCompList.FindComponentClassByName(FindClassName);
    {$ELSE}
    RegComp:=IDEComponentPalette.FindComponent(FindClassName);
    {$ENDIF}
    if RegComp<>nil then begin
      //writeln('[TJITComponentList.ReaderFindComponentClass] '''+FindClassName
      //   +''' is registered');
      ComponentClass:=RegComp.ComponentClass;
    end else begin
      writeln('[TJITComponentList.ReaderFindComponentClass] '''+FindClassName
         +''' is unregistered');
      Action:=mrCancel;
      ErrorType:=jfeUnknownComponentClass;
      if Assigned(OnReaderError) then
        OnReaderError(Self,ErrorType,Action);
    end;
  end;
end;

procedure TJITComponentList.ReaderCreateComponent(Reader: TReader;
  ComponentClass: TComponentClass; var Component: TComponent);
begin
  fCurReadChild:=Component;
  fCurReadChildClass:=ComponentClass;
//  writeln('[TJITComponentList.ReaderCreateComponent] Class='''+ComponentClass.ClassName+'''');
end;

//==============================================================================


{ TJITForms }

constructor TJITForms.Create;
begin
  inherited Create;
  FComponentPrefix:='Form';
end;

function TJITForms.IsJITForm(AComponent: TComponent): boolean;
begin
  Result:=(AComponent<>nil) and (AComponent is TForm)
      and (TForm(AComponent).Parent=nil) and (IndexOf(AComponent)>=0);
end;

function TJITForms.GetItem(Index: integer): TForm;
begin
  Result:=TForm(inherited Items[Index]);
end;

function TJITForms.CreateDefaultVMTCopy: Pointer;
begin
  Result:=CreateVMTCopy(TJITForm,'TJITForm');
end;

procedure TJITForms.DoFinishReading;

  procedure ApplyVisible;
  var
    i: integer;
    AControl: TControl;
  begin
    // The LCL has as default Visible=false. But for Delphi compatbility
    // loading control defaults to true.
    for i:=0 to FCurReadJITComponent.ComponentCount-1 do begin
      AControl:=TControl(FCurReadJITComponent.Components[i]);
      if (AControl is TControl) then begin
        if (not (csVisibleSetInLoading in AControl.ControlState)) then
          AControl.Visible:=true
        else
          AControl.ControlState:=
            AControl.ControlState-[csVisibleSetInLoading];
      end;
    end;
  end;

begin
  inherited DoFinishReading;
  ApplyVisible;
  TJITForm(FCurReadJITComponent).Show;
end;


{ TJITDataModules }

function TJITDataModules.GetItem(Index: integer): TDataModule;
begin
  Result:=TDataModule(inherited Items[Index]);
end;

function TJITDataModules.CreateDefaultVMTCopy: Pointer;
begin
  Result:=CreateVMTCopy(TJITDataModule,'TJITDataModule');
end;

constructor TJITDataModules.Create;
begin
  inherited Create;
  FComponentPrefix:='DataModule';
end;

function TJITDataModules.IsJITDataModule(AComponent: TComponent): boolean;
begin
  Result:=(AComponent<>nil) and (AComponent is TDataModule)
          and (IndexOf(AComponent)>=0);
end;

end.

