{
   Double Commander
   -------------------------------------------------------------------------
   Interface to GVolumeMonitor

   Copyright (C) 2014-2016 Alexander Koblov (alexx2000@mail.ru)

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit uGVolume;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uDrive, uUDisks;

type
  TGVolumeNotify = procedure(Event: TUDisksMethod; Drive: PDrive) of object;

function Initialize: Boolean;
procedure Finalize;

procedure AddObserver(Func: TGVolumeNotify);
procedure RemoveObserver(Func: TGVolumeNotify);

function EnumerateVolumes(DrivesList: TDrivesList): Boolean;

implementation

uses
  typinfo, fgl, uGLib2, uGio2, uGObject2;

type
  TGVolumeObserverList = specialize TFPGList<TGVolumeNotify>;

var
  VolumeMonitor: PGVolumeMonitor = nil;
  Observers: TGVolumeObserverList = nil;

procedure Print(const Message: String);
begin
  WriteLn('GVolumeMonitor: ', Message);
end;

function ReadString(Volume: PGVolume; const Kind: Pgchar): UTF8String;
var
  Value: PAnsiChar;
begin
  Value:= g_volume_get_identifier(Volume, Kind);
  if Value = nil then
    Result:= EmptyStr
  else begin
    Result:= StrPas(Value);
    g_free(Value);
  end;
end;

function VolumeToDrive(Volume: PGVolume): PDrive;
var
  GFile: PGFile;
  Name, Path: Pgchar;
begin
  Result:= nil;
  GFile:= g_volume_get_activation_root(Volume);
  if Assigned(GFile) then
  begin
    Path:= g_file_get_uri(GFile);
    if Assigned(Path) then
    begin
      New(Result);
      Result^.IsMounted:= True;
      Result^.Path:= StrPas(Path);
      Result^.DriveType:= dtSpecial;
      Result^.IsMediaEjectable:= g_volume_can_eject(Volume);
      Result^.DeviceId:= ReadString(Volume, VOLUME_IDENTIFIER_KIND_UNIX_DEVICE);
      Result^.DriveLabel:= ReadString(Volume, VOLUME_IDENTIFIER_KIND_LABEL);
      Name:= g_volume_get_name(Volume);
      if (Name = nil) then
        Result^.DisplayName:= ExtractFileName(Result^.DeviceId)
      else
      begin
        Result^.DisplayName := StrPas(Name);
        g_free(Name);
      end;
      g_free(Path);
    end;
    g_object_unref(PGObject(GFile));
  end;
end;

procedure VolumeEvent(volume_monitor: PGVolumeMonitor; volume: PGVolume; user_data: gpointer); cdecl;
var
  Drive: PDrive;
  Index: Integer;
  VolumeEvent: TUDisksMethod absolute user_data;
begin
  Drive:= VolumeToDrive(volume);
  if Assigned(Drive) then
  begin
    Print(GetEnumName(TypeInfo(TUDisksMethod), PtrInt(VolumeEvent)) + ': ' + Drive^.Path);
    for Index:= 0 to Observers.Count - 1 do
      Observers[Index](VolumeEvent, Drive);
  end;
end;

procedure AddObserver(Func: TGVolumeNotify);
begin
  if Observers.IndexOf(Func) < 0 then
    Observers.Add(Func);
end;

procedure RemoveObserver(Func: TGVolumeNotify);
begin
  Observers.Remove(Func);
end;

function Initialize: Boolean;
begin
  VolumeMonitor:= g_volume_monitor_get();
  Result:= Assigned(VolumeMonitor);
  if Result then
  begin
    Observers:= TGVolumeObserverList.Create;
    g_signal_connect_data(VolumeMonitor, 'volume-added', TGCallback(@VolumeEvent),
                          gpointer(PtrInt(UDisks_DeviceAdded)), nil, G_CONNECT_AFTER);
    g_signal_connect_data(VolumeMonitor, 'volume-changed', TGCallback(@VolumeEvent),
                          gpointer(PtrInt(UDisks_DeviceChanged)), nil, G_CONNECT_AFTER);
    g_signal_connect_data(VolumeMonitor, 'volume-removed', TGCallback(@VolumeEvent),
                          gpointer(PtrInt(UDisks_DeviceRemoved)), nil, G_CONNECT_AFTER);
  end;
end;

procedure Finalize;
begin
  if Assigned(VolumeMonitor) then
  begin
    FreeAndNil(Observers);
    g_object_unref(VolumeMonitor);
    VolumeMonitor:= nil;
  end;
end;

function EnumerateVolumes(DrivesList: TDrivesList): Boolean;
var
  Drive: PDrive;
  GVolume: PGVolume;
  VolumeList: PGList;
  VolumeTemp: PGList;
begin
  VolumeList:= g_volume_monitor_get_volumes(VolumeMonitor);
  Result:= Assigned(VolumeList);
  if Result then
  begin
    VolumeTemp:= VolumeList;
    while Assigned(VolumeTemp) do
    begin
      GVolume:= VolumeTemp^.data;
      Drive:= VolumeToDrive(GVolume);

      if (Assigned(Drive)) then
        DrivesList.Add(Drive);

      g_object_unref(PGObject(GVolume));
      VolumeTemp:= VolumeTemp^.next;
    end;
    g_list_free(VolumeList);
  end;
end;

end.
