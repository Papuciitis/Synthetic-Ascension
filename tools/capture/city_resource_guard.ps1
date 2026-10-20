# Capture/test process protection only; never changes game or Windows settings.
if (-not ('CityCaptureMemory' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CityCaptureMemory {
    [StructLayout(LayoutKind.Sequential)] public struct Status {
        public uint Length; public uint Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile;
        public ulong TotalVirtual, AvailableVirtual, AvailableExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GlobalMemoryStatusEx(ref Status status);
    public static Status Read() {
        var status = new Status(); status.Length = (uint)Marshal.SizeOf(typeof(Status));
        if (!GlobalMemoryStatusEx(ref status)) throw new InvalidOperationException("Memory status unavailable");
        return status;
    }
}
'@
}

function Assert-CityCaptureMemory {
    param([int]$MinimumAvailableMB=1024,[int]$MinimumCommitMB=1536)
    $cityMemory=[CityCaptureMemory]::Read()
    if ($cityMemory.AvailablePhysical -lt $MinimumAvailableMB*1MB -or $cityMemory.AvailablePageFile -lt $MinimumCommitMB*1MB) {
        throw ('Capture not started: available RAM {0} MB, commit headroom {1} MB.' -f [math]::Round($cityMemory.AvailablePhysical/1MB),[math]::Round($cityMemory.AvailablePageFile/1MB))
    }
}

function Wait-CityCaptureProcess {
    # Only accepts the exact Process object returned by this caller's Start-Process.
    param([System.Diagnostics.Process]$Process,[int]$TimeoutSeconds,[int]$MaximumPrivateMB=1200)
    $cityTimer=[Diagnostics.Stopwatch]::StartNew()
    $cityPeak=0L
    $cityLowest=([CityCaptureMemory]::Read()).AvailablePhysical
    $cityLowestCommit=([CityCaptureMemory]::Read()).AvailablePageFile
    $cityStopReason=''
    try { $Process.PriorityClass=[Diagnostics.ProcessPriorityClass]::BelowNormal } catch { }
    while (-not $Process.WaitForExit(500)) {
        $Process.Refresh()
        if ($Process.HasExited) {break}
        $cityMemory=[CityCaptureMemory]::Read()
        $cityPeak=[math]::Max($cityPeak,$Process.PrivateMemorySize64)
        $cityLowest=[math]::Min($cityLowest,$cityMemory.AvailablePhysical)
        $cityLowestCommit=[math]::Min($cityLowestCommit,$cityMemory.AvailablePageFile)
        if ($cityTimer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {$cityStopReason='timeout'}
        elseif ($Process.PrivateMemorySize64 -gt $MaximumPrivateMB*1MB) {$cityStopReason='engine_private_memory_limit'}
        elseif ($cityMemory.AvailablePhysical -lt 384MB) {$cityStopReason='system_memory_headroom'}
        elseif ($cityMemory.AvailablePageFile -lt 768MB) {$cityStopReason='system_commit_headroom'}
        if ($cityStopReason) {
            if (-not $Process.HasExited) {$Process.Kill()}
            $Process.WaitForExit()
            break
        }
    }
    return [ordered]@{stop_reason=$cityStopReason;peak_private_mb=[math]::Round($cityPeak/1MB);minimum_available_mb=[math]::Round($cityLowest/1MB);minimum_commit_headroom_mb=[math]::Round($cityLowestCommit/1MB);elapsed_seconds=[math]::Round($cityTimer.Elapsed.TotalSeconds,2)}
}
