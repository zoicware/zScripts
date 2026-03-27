function Edit-PolFile {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('HKLM', 'HKCU')]
        [string]$Hive,
        [Parameter(Mandatory)]
        [ValidateSet('Add', 'Delete')]
        [string]$Action,
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$ValueName,
        [ValidateSet('DWORD', 'SZ')]
        [string]$Type,
        [string]$Value
    )

    if ($Hive -eq 'HKLM') {
        $PolPath = "$env:SYSTEMROOT\System32\GroupPolicy\Machine\Registry.pol"
    }
    else {
        $PolPath = "$env:SYSTEMROOT\System32\GroupPolicy\User\Registry.pol"
    }

    #C# pol file reader/writer 
    if (-not ([System.Management.Automation.PSTypeName]'PolHandler').Type) {
        Add-Type -Language CSharp @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public class PolRec {
    public string Key;
    public string ValueName;
    public uint   Type;
    public byte[] Data;
}

public static class PolHandler {

    public static List<PolRec> Read(string f) {
        var l = new List<PolRec>();
        if (!File.Exists(f) || new FileInfo(f).Length < 8) return l;
        try {
            using (var br = new BinaryReader(File.OpenRead(f), Encoding.Unicode)) {
                if (br.ReadUInt32() != 0x67655250 || br.ReadUInt32() != 1) return l;
                while (br.BaseStream.Position < br.BaseStream.Length) {
                    if (br.ReadChar() != '[') continue;
                    var r = new PolRec { Key = RS(br) };
                    if (br.ReadChar() != ';') break;
                    r.ValueName = RS(br);
                    if (br.ReadChar() != ';') break;
                    r.Type = br.ReadUInt32();
                    if (br.ReadChar() != ';') break;
                    uint sz = br.ReadUInt32();
                    if (br.ReadChar() != ';') break;
                    if (br.BaseStream.Position + sz > br.BaseStream.Length) break;
                    r.Data = br.ReadBytes((int)sz);
                    if (br.ReadChar() != ']') break;
                    l.Add(r);
                }
            }
        } catch {}
        return l;
    }

    public static void Write(string f, ICollection<PolRec> d) {
        Directory.CreateDirectory(Path.GetDirectoryName(f));
        using (var bw = new BinaryWriter(File.Open(f, FileMode.Create), Encoding.Unicode)) {
            bw.Write((uint)0x67655250);
            bw.Write((uint)1);
            foreach (var r in d) {
                bw.Write('[');
                SS(bw, r.Key);       bw.Write(';');
                SS(bw, r.ValueName); bw.Write(';');
                bw.Write(r.Type);    bw.Write(';');
                bw.Write((uint)r.Data.Length); bw.Write(';');
                bw.Write(r.Data);
                bw.Write(']');
            }
        }
    }

    private static string RS(BinaryReader br) {
        var sb = new StringBuilder(); char c;
        while ((c = br.ReadChar()) != 0) sb.Append(c);
        return sb.ToString();
    }

    private static void SS(BinaryWriter bw, string v) {
        bw.Write(v.ToCharArray());
        bw.Write((char)0);
    }
}
'@
    }

    #Load existing records into a dictionary to edit 
    $policies = [System.Collections.Generic.Dictionary[string, PolRec]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    [PolHandler]::Read($PolPath) | ForEach-Object {
        $policies["$($_.Key);$($_.ValueName)"] = $_
    }

    $dictKey = "$Key;$ValueName"

    switch ($Action) {

        'Add' {
            if (-not $Type) { throw "'-Type' is required when Action is 'Add'" }
            if (-not $Value -and $Value -ne '0') { throw "'-Value' is required when Action is 'Add'" }

            $rec = [PolRec]::new()
            $rec.Key = $Key
            $rec.ValueName = $ValueName

            if ($Type -eq 'DWORD') {
                $rec.Type = 4
                $rec.Data = [BitConverter]::GetBytes([uint32]::Parse($Value))
            }
            else {
                $rec.Type = 1
                $rec.Data = [Text.Encoding]::Unicode.GetBytes($Value + [char]0)
            }

            $policies[$dictKey] = $rec
            Write-Verbose "Added/updated: $dictKey"
        }

        'Delete' {
            if ($policies.Remove($dictKey)) {
                Write-Verbose "Deleted: $dictKey"
            }
            else {
                Write-Warning "Entry not found in .pol file: $dictKey"
            }
        }
    }

    #add updated dictionary back to pol file
    $final = [System.Collections.Generic.List[PolRec]]::new($policies.Values)
    [PolHandler]::Write($PolPath, $final)
}



#example: updates group policy ui unlike just applying the reg key alone
$names = @(
    'TurnOffWindowsCopilot' 
    'DisableAIDataAnalysis' 
    'AllowRecallEnablement' 
    'DisableClickToDo' 
    'TurnOffSavingSnapshots' 
    'DisableSettingsAgent' 
    'DisableAgentConnectors' 
    'DisableAgentWorkspaces'
    'DisableRemoteAgentConnectors' 
)

#add all names 
foreach ($name in $names) {
    Edit-PolFile -Hive HKLM -Action Add -Key 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -ValueName $name -Type DWORD -Value 1 -Verbose
}

#delete all names (set to not configured)
foreach ($name in $names) {
    Edit-PolFile -Hive HKLM -Action Delete -Key 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -ValueName $name -Verbose
}
