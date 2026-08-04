# Read the TTF file and extract cmap table to see what glyphs are mapped
$bytes = [System.IO.File]::ReadAllBytes('C:\Users\User\OneDrive\Documents\My Flutter App\tvet system\frontend\assets\fonts\checkmark.ttf')

# Parse TTF header
$numTables = [BitConverter]::ToUInt16($bytes, 4)
Write-Output "Number of tables: $numTables"

# Find cmap table
for ($i = 0; $i -lt $numTables; $i++) {
    $offset = 12 + $i * 16
    $tag = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
    if ($tag -eq 'cmap') {
        $tableOffset = [BitConverter]::ToUInt32($bytes, $offset + 8)
        $tableLength = [BitConverter]::ToUInt32($bytes, $offset + 12)
        Write-Output "cmap table at offset $tableOffset, length $tableLength"
        
        # Parse cmap
        $version = [BitConverter]::ToUInt16($bytes, $tableOffset)
        $numSubtables = [BitConverter]::ToUInt16($bytes, $tableOffset + 2)
        Write-Output "cmap version: $version, subtables: $numSubtables"
        
        for ($j = 0; $j -lt $numSubtables; $j++) {
            $subOffset = $tableOffset + 4 + $j * 8
            $platformID = [BitConverter]::ToUInt16($bytes, $subOffset)
            $encodingID = [BitConverter]::ToUInt16($bytes, $subOffset + 2)
            $subtableStart = $tableOffset + [BitConverter]::ToUInt32($bytes, $subOffset + 4)
            
            $format = [BitConverter]::ToUInt16($bytes, $subtableStart)
            Write-Output "  Subtable ${j}: platform=${platformID} encoding=${encodingID} format=${format}"
            
            if ($format -eq 4) {
                $segCount = [BitConverter]::ToUInt16($bytes, $subtableStart + 6) / 2
                Write-Output "  Segment count: $segCount"
                
                $endCodesStart = $subtableStart + 14
                $startCodesStart = $endCodesStart + $segCount * 2 + 2  # +2 for reserved pad
                
                for ($k = 0; $k -lt $segCount; $k++) {
                    $endCode = [BitConverter]::ToUInt16($bytes, $endCodesStart + $k * 2)
                    $startCode = [BitConverter]::ToUInt16($bytes, $startCodesStart + $k * 2)
                    if ($startCode -ne 0xFFFF) {
                        $chars = @()
                        for ($c = $startCode; $c -le $endCode; $c++) {
                            $chars += [char]$c
                        }
                        Write-Output "    Range: 0x$($startCode.ToString('X4'))-0x$($endCode.ToString('X4')) = $($chars -join ', ')"
                    }
                }
            } elseif ($format -eq 0) {
                # Format 0 - byte encoding
                Write-Output "  Format 0 - simple byte mapping"
            } elseif ($format -eq 6) {
                # Format 6
                $firstCode = [BitConverter]::ToUInt16($bytes, $subtableStart + 6)
                $entryCount = [BitConverter]::ToUInt16($bytes, $subtableStart + 8)
                Write-Output "  First code: $firstCode, count: $entryCount"
            } elseif ($format -eq 12) {
                # Format 12 - segmented coverage
                $numGroups = [BitConverter]::ToUInt32($bytes, $subtableStart + 12)
                Write-Output "  Num groups: $numGroups"
                for ($k = 0; $k -lt $numGroups; $k++) {
                    $groupOffset = $subtableStart + 16 + $k * 12
                    $startCharCode = [BitConverter]::ToUInt32($bytes, $groupOffset)
                    $endCharCode = [BitConverter]::ToUInt32($bytes, $groupOffset + 4)
                    Write-Output "    Range: 0x$($startCharCode.ToString('X6'))-0x$($endCharCode.ToString('X6'))"
                }
            }
        }
        break
    }
}
