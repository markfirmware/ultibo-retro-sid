unit uQemuDiagnostics;
interface

type
 TTarget = (Rpi, Rpi2, Rpi3, QemuArm7a);

procedure StartLogging;
procedure SaveFrameBuffer;
procedure ProgramStop;

implementation
uses Console,FrameBuffer,GlobalConfig,GlobalConst,Logging,Platform,Serial,SysUtils;

var
 SavedFrameBuffer:Pointer;
 Target:TTarget;

function TargetToString(Target:TTarget):String;
begin
 case Target of
  Rpi: TargetToString:='Rpi';
  Rpi2: TargetToString:='Rpi2';
  Rpi3: TargetToString:='Rpi3';
  QemuArm7a: TargetToString:='QemuArm7a';
 end;
end;

procedure DetermineEntryState;
begin
 Target:={$ifdef TARGET_RPI_INCLUDING_RPI0}  Rpi       {$endif}
         {$ifdef TARGET_RPI2_INCLUDING_RPI3} Rpi2      {$endif}
         {$ifdef TARGET_RPI3}                Rpi3      {$endif}
         {$ifdef TARGET_QEMUARM7A}           QemuArm7a {$endif};
end;

// Save frame buffer in memory and write signal to log
procedure SaveFrameBuffer;
const
 ColorFormat=COLOR_FORMAT_RGB24;
 BytesPerPixel=3;
var
 FrameBufferProperties:TFrameBufferProperties;
 Width:Integer;
 Height:Integer;
begin
 FrameBufferDeviceGetProperties(FrameBufferDeviceGetDefault,@FrameBufferProperties);
 Width:=FrameBufferProperties.PhysicalWidth;
 Height:=FrameBufferProperties.PhysicalHeight;
 if Assigned(SavedFrameBuffer) then
  begin
   FreeMem(SavedFrameBuffer);
   SavedFrameBuffer:=nil;
  end;
 if not Assigned(SavedFrameBuffer) then
  SavedFrameBuffer:=GetMem(Width * Height * BytesPerPixel);
 ConsoleDeviceGetImage(ConsoleDeviceGetDefault,0,0,SavedFrameBuffer,
                       Width,Height,ColorFormat,0);
 LoggingOutput(Format('frame buffer at 0x%x size %dx%dx%d',
                      [LongWord(SavedFrameBuffer),Width,Height,BytesPerPixel]));
end;

procedure ProgramStop;
begin
 LoggingOutput('program stop');
end;

procedure StartLogging;
begin
 if (Target = QemuArm7a) then
  begin
   SERIAL_REGISTER_LOGGING:=True;
   SerialLoggingDeviceAdd(SerialDeviceGetDefault);
   LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_SERIAL));
  end
 else
  begin
   LoggingDeviceSetTarget(LoggingDeviceFindByType(LOGGING_TYPE_FILE),'c:\ultibo-retro.sid.log');
   LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_FILE));
  end;
end;

initialization
DetermineEntryState;
SavedFrameBuffer:=nil;
end.
