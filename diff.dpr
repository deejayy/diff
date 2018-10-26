{$APPTYPE Console}
program Diff;

uses Crt;

var F, G: File;
    A, B, Bytes: Array of Byte;
    F_: Array[False..True] of LongInt;
    I, J: Integer;
    Ps, S: String;
    Ds, BitDiff: Boolean;
    SFrom, STo: LongWord;
    Exc: Set of Byte;
//  ----------------------------------
    BC: LongWord;
    Offs: Array of LongWord;


// ==============
//   SysUtils
// ==============

function StrToInt(const S: string): Integer;
var
  E: Integer;
begin
  Val(S, Result, E);
  if E <> 0 then Write('Integer convert error!');
end;

function StrToIntDef(const S: string; Default: Integer): Integer;
var
  E: Integer;
begin
  Val(S, Result, E);
  if E <> 0 then Result := Default;
end;

function TryStrToInt(const S: string; out Value: Integer): Boolean;
var
  E: Integer;
begin
  Val(S, Value, E);
  Result := E = 0;
end;

function IntToStr(Value: Integer): String;
var E: String;
begin
  Str(Value, E);
  Result := E;
end;

function IntToHex(Number, MinLen: integer): string;
const HexNums: string[16] = '0123456789ABCDEF';
begin
  Result := '';
  repeat
     Result := HexNums[(Number and $0f) + 1] + Result;
     Number := Number shr 4;
  until Number = 0;
  while length(Result) < MinLen do Result := '0' + Result;
end;

// ==============
//  Error, Help
// ==============

procedure CError(S: String);
begin
  WriteLn(S);
  Halt;
end;

procedure AdvHelp;
Begin
  WriteLn('RÇszletes seg°tsÇg:');
  WriteLn('  o Ez a program tulajdonkÇppen kÇt f†jlt, b†jtonkÇnt îsszehasonl°t.');
  WriteLn('    Az îsszehasonl°t†s proced£r†ja:');
  WriteLn('    A kÇt f†jl megnyit†sa ut†n mindkettãt beolvassa ês b†jtr¢l ');
  WriteLn('    b†jtra vÇgignÇzi, hogy melyik p†r kÅlînbîzik. Ezt pedig ki°rja.');
  WriteLn('  o A program az ÇrvÇnytelen kapcsol¢kat (tîbbnyire amelyek nincsenek a');
  WriteLn('    programban) figyelmen k°vÅl hagyja');
  WriteLn('  o A program max 4GB nagys†g£ f†jlt tud kezelni "csak"');
  WriteLn('  o A gener†lt k¢d az elsã paramÇterben megadott f†jlra csin†l egy');
  WriteLn('    programot, ami a m†sodik f†jlt¢l val¢ kÅlînbsÇgeket °rja felÅl,');
  WriteLn('    Teh†t ha a gener†lt k¢dot leford°tva lefuttatod, akkor az elsã');
  WriteLn('    f†jl ut†na egyezni fog a m†sodikkal.');
  WriteLn('  ');
  WriteLn('Tippek, trÅkkîk:');
  WriteLn('  o Ha a /F kapcsol¢t £gy haszn†ljuk, hogy nem adunk meg vÇgÇrtÇket, akkor');
  WriteLn('    automatikusan a f†jl vÇge lesz az.');
  WriteLn;
End;

procedure Examples;
Begin
  WriteLn('  PÇlda: diff.exe file1.ext file2.ext /D1');
  WriteLn('           Ez a pÇlda îsszehasonl°tja a file1.ext Çs file2.ext f†jlokat, Çs');
  WriteLn('           csak azokat a kÅlînbsÇgeket °rja ki, mint a 01 & 02 vagy 57 & 56 ');
  WriteLn('         diff.exe file1.ext file2.ext /F1-500');
  WriteLn('           Ez a pÇlda îsszehasonl°tja a file1.ext Çs file2.ext f†jlokat az');
  WriteLn('           elsãtãl az îtsz†zadik b†jtig');
  WriteLn('         diff.exe file1.ext file2.ext /E[1;31;255]');
  WriteLn('           Ez a pÇlda îsszehasonl°tja a file1.ext Çs file2.ext f†jlokat, de');
  WriteLn('           ha a kÅlînbsÇgek kîzÅl b†rmelyik 1 vagy 31 vagy 255 akkor azokat');
  WriteLn('           nem °rja ki');
  WriteLn;
End;

procedure NoParam;
Begin
  WriteLn('Haszn†lat: diff.exe file1.kit file2.kit [/kapcsol¢k ... ]');
  WriteLn('  /Dxxx           Csak azokat a kÅlînbsÇgeket °rd ki, amelyek');
  WriteLn('                  kÅlînbsÇge xxx (decim†lis sz†m)');
  WriteLn('  /Fxxxx-yyyy     A f†jlt csak xxxx-tãl yyyy-ig nÇzi meg');
  WriteLn('  /E[xx;yy;aa]    Kihagyja azokaz a sz†mokat a keresÇsbãl, amelyek a [] kîzîtt');
  WriteLn('                  vannak, Çs pontosvesszãvel vannak elv†lasztva');
  WriteLn('  /B              BiteltÇrÇs, ha a kÇt kÅlînbsÇg csak egy bitben tÇr el');
  WriteLn('  /H              RÇszletesebb seg°tsÇg');
  WriteLn('  /G              Gener†ljon k¢dot:');
  WriteLn('     /Gp          Pascal nyelven');
  WriteLn('     /Gd          Delphi nyelven');
  WriteLn('     /Ga          Assembly nyelven (kÇszÅlãben)');
  WriteLn('     /Gc          C/C++ nyelven');
  WriteLn('  /X              PÇld†k');
  WriteLn('  /C              A kÇt f†jlb¢l egy rÇszletet ki°r, +5 -5 b†jtos kîrzetben');
  WriteLn('  /A              A kÅlînbsÇgeket ASCII karakterkÇnt °rja ki');
  WriteLn('');
End;

// ====================
//   Needed functions
// ====================

procedure ProcessFromTo(S: String; var _From, _To: LongWord);
Var K: String;
begin
  K := S;
  Delete(K, 1, Pos('/F', K) + 1);
  Delete(K, Pos(' ', K), Length(K));
  _From := StrToIntDef(Copy(K, 1, Pos('-', K) - 1), _From);
  _To := StrToIntDef(Copy(K, Pos('-', K) + 1, 8), _To);
end;

procedure SetExc(S: String);
var K, V: String;
    I, J, L: Integer;
begin
  K := S;
  J := 1;
  While Pos(';', K) <> 0 Do
  Begin
    Inc(J);
    Delete(K, Pos(';', K), 1);
  End;
  K := S;
  For I := 1 To J Do
  Begin
    If Pos(';', K) <> 0 Then V := Copy(K, 1, Pos(';', K) - 1)
    Else V := Copy(K, 1, Length(K) - 1);
    If TryStrToInt(V, L) Then Include(Exc, StrToInt(V));
    Delete(K, 1, Pos(';', K));
  End;
end;

// ====================
//   Source Generator
// ====================

procedure Generate(C: Byte; Po: LongInt);
begin
  Inc(BC);
  SetLength(Offs, BC);
  Offs[BC - 1] := Po;
  SetLength(Bytes, BC);
  Bytes[BC - 1] := C;
end;

procedure GenPascalFinal(Filename: String);
const ibc: array[false..true] of string = (', ', '');
      imod: array[false..true] of string = ('', #10'      ');
var I: LongWord;
begin
  WriteLn('Program Patch;');
  WriteLn('');
  WriteLn('Const Count = ', BC, ';');
  WriteLn('      FileName = ''', Filename ,''';');
  Write  ('      PatchArray: Array[1..Count] of Byte = ('#10'      ');

  For I := 0 To BC - 1 Do Write('$', IntToHex(Bytes[I], 2), ibc[I = BC - 1], imod[ ((I mod 13) = 0) and (I <> 0)]);

  WriteLn('); ');
  Write  ('      Offsets: Array[1..Count] of LongInt = ('#10'      ');

  For I := 0 To BC - 1 Do Write('$', IntToHex(Offs[I], 8), ibc[I = BC - 1], imod[ ((I mod 5) = 0) and (I <> 0)]);

  WriteLn(');');
  WriteLn('');
  WriteLn('Var F: File;');
  WriteLn('    I: LongInt;');
  WriteLn('');
  WriteLn('Begin');
  WriteLn('  Assign(F, Filename);');
  WriteLn('  Reset(F, 1);');
  WriteLn('  For I := 1 To Count Do');
  WriteLn('  Begin');
  WriteLn('    Seek(F, Offsets[I]);');
  WriteLn('    BlockWrite(F, PatchArray[I], 1);');
  WriteLn('  End;');
  WriteLn('  Close(F);');
  WriteLn('End.');
end;

procedure GenDelphiFinal(Filename: String);
const ibc: array[false..true] of string = (', ', '');
      imod: array[false..true] of string = ('', #10'      ');
var I: LongWord;
begin
  WriteLn('Const Count = ', BC, ';');
  WriteLn('      FileName = ''', Filename ,''';');
  Write  ('      PatchArray: Array[1..Count] of Byte = ('#10'      ');

  For I := 0 To BC - 1 Do Write('$', IntToHex(Bytes[I], 2), ibc[I = BC - 1], imod[ ((I mod 14) = 0) and (I <> 0)]);

  WriteLn('); ');
  Write  ('      Offsets: Array[1..Count] of LongWord = ('#10'      ');

  For I := 0 To BC - 1 Do Write('$', IntToHex(Offs[I], 8), ibc[I = BC - 1], imod[ ((I mod 5) = 0) and (I <> 0)]);

  WriteLn(');');
  WriteLn('');
  WriteLn('Var F: File;');
  WriteLn('    I: LongWord;');
  WriteLn('');
  WriteLn('Begin');
  WriteLn('  AssignFile(F, Filename);');
  WriteLn('  Reset(F, 1);');
  WriteLn('  For I := 1 To Count Do');
  WriteLn('  Begin');
  WriteLn('    Seek(F, Offsets[I]);');
  WriteLn('    BlockWrite(F, PatchArray[I], 1);');
  WriteLn('  End;');
  WriteLn('  CloseFile(F);');
  WriteLn('End.');
end;

procedure GenAsmFinal(Filename: String);
begin
end;

procedure GenCppFinal(Filename: String);
const ibc: array[false..true] of string = (', ', '');
      imod: array[false..true] of string = ('', #10'    ');
var I: LongWord;
begin
  Writeln('#include <stdio.h>');
  Writeln('');
  Writeln('void main(void)');
  Writeln('{');
  Writeln('  int count = ', BC, ';');
  Writeln('  char fileName[] = "', Filename ,'";');
  Write  ('  unsigned char patchArray[] = {'#10'    ');

  For I := 0 To BC - 1 Do
    Write('0x', IntToHex(Bytes[I], 2), ibc[I = BC - 1], imod[(((I - 1) mod 12) = 0) and (I <> 0)]);

  Writeln('  }');
  Write  ('  long offsets[] = {'#10'    ');

  For I := 0 To BC - 1 Do
    Write('0x', IntToHex(Offs[I], 8), ibc[I = BC - 1], imod[(((I - 1) mod 6) = 0) and (I <> 0)]);

  Writeln('  }');
  Writeln('  FILE *f;');
  Writeln('');
  Writeln('  f = fopen(fileName, "r+b";');
  Writeln('  for(long i = 0; i < count; i ++)');
  Writeln('  {');
  Writeln('    fseek(f, offsets[i], SEEK_SET');
  Writeln('    fwrite(patchArray + i, 1, 1, f);');
  Writeln('  }');
  Writeln('  fclose(f);');
  Writeln('');
  Writeln('}');
end;

// =============
//   Write Out
// =============

procedure WriteOut(I: LongWord);
var J: Integer;
    K, L: String;
begin
  Generate(B[I], I);
  If Pos('/G', Ps) = 0 Then
   Begin
    If Pos('/C', Ps) = 0 Then
     Begin
      If Pos('/A', Ps) = 0 Then
         WriteLn(IntToHex(A[I], 2) + ' & ' + IntToHex(B[I], 2) + ' @ ' + IntToHex(I, 8))
      Else
       Begin
        If (A[I] in [32..255]) And (B[I] in [32..255]) Then WriteLn(Char(A[I]) + ' & ' + Char(B[I]) + ' @ ' + IntToHex(I, 8))
        Else WriteLn('  &   @ ' + IntToHex(I, 8))
       End
     End
    Else
     Begin
      Write(IntToHex(A[I], 2) + ' & ' + IntToHex(B[I], 2) + ' @ ' + IntToHex(I, 8) + ' | ');
      For J := 1 To 10 Do Begin If (A[I + J - 5] in [32..255]) And (I + J - 5 >= 0) And (I + J - 5 <= STo) Then K := K + Char(A[I + J - 5]) Else K := K + ' '; End;
      For J := 1 To 10 Do Begin If (B[I + J - 5] in [32..255]) And (I + J - 5 >= 0) And (I + J - 5 <= STo) Then L := L + Char(B[I + J - 5]) Else L := L + ' '; End;
      WriteLn(K + ' & ' + L);
     End;
   End;
end;

// ================
//   MAIN PROGRAM
// ================

begin
  Ps := '';
  J := 0; BC := 0;
  For I := 1 To ParamCount Do
    Ps := Ps + ParamStr(I) + ' ';

  WriteLn('(* ---===<   Difference bytes v0.63 (by DeeJayy)   >===--- *)');
  WriteLn('  ');
  If ParamCount < 2 Then NoParam;

  If Pos('/H ', Ps) <> 0 Then AdvHelp;

  If Pos('/X ', Ps) <> 0 Then Examples;

  If ParamCount < 2 Then Halt;

                                  { TODO :
                                    gen asm full }


  S := Ps;
  Delete(S, 1, Pos('/E[', Ps) - 1);
  Delete(S, Pos('] ', S) + 1, Length(S));
  SetExc(Copy(S, 4, Length(S)));
  AssignFile(F, ParamStr(1));
  AssignFile(G, ParamStr(2));
  {$I-}
  Reset(F, 1);
  {$I+}
  If IOResult <> 0 Then CError('F†jl hiba (1)');
  {$I-}
  Reset(G, 1);
  {$I+}
  If IOResult <> 0 Then CError('F†jl hiba (2)');

  F_[False] := FileSize(F);
  F_[True] := FileSize(G);

  If (F_[False] = 0) Or (F_[True] = 0) Then CError('Az egyik f†jl Åres!');

  SFrom := 0;
  STo := F_[(F_[False] < F_[True])] - 1;

  SetLength(A, STo);
  SetLength(B, STo);

  If Pos('/F', Ps) <> 0 Then ProcessFromTo(Ps, SFrom, STo);

  Seek(F, SFrom);
  Seek(G, SFrom);
  If STo - SFrom < F_[False] Then BlockRead(F, A[0], STo - SFrom)
  Else BlockRead(F, A[0], F_[False] - SFrom);
  If STo - SFrom < F_[True]  Then BlockRead(G, B[0], STo - SFrom)
  Else BlockRead(G, B[0], F_[True] - SFrom);

  BitDiff := False; Ds := False;
  If Pos('/D', Ps) <> 0 Then
  Begin
    J := 2; S := '';
    While Copy(Ps, Pos('/D', Ps) + J, 1) <> ' ' Do
    Begin
      S := S + Copy(Ps, Pos('/D', Ps) + J, 1);
      Inc(J);
    End;
    If TryStrToInt(S, J) Then J := StrToInt(S)
    Else CError('/D kapcsol¢ hiba');
    Ds := True;
  End;
  If Pos('/B ', Ps) <> 0 Then BitDiff := True;

  For I := SFrom To STo Do
  If (A[I] <> B[I]) Then
  Begin
    If Not ((A[I] in Exc) Or (B[I] in Exc)) Then
    If Not BitDiff Then Begin
    If Ds Then Begin
    If (Abs(A[I] - B[I]) = J) Then
         WriteOut(I) End
    Else WriteOut(I) End
    Else
    If ((A[I] xor B[I]) And ((A[I] xor B[I]) - 1)) = 0 Then
         WriteOut(I)
  End;

  If BC = 0 Then WriteLn('A kÇt f†jl egyezik!');

  If Pos('/G', Ps) <> 0 Then
  Case Ps[Pos('/G', Ps) + 2] of
    'p': GenPascalFinal(ParamStr(1));
    'a': GenAsmFinal(ParamStr(1));
    'c': GenCppFinal(ParamStr(1));
    'd': GenDelphiFinal(ParamStr(1));
  End;

  CloseFile(F);
  CloseFile(G);
end.
