Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\Users\User\OneDrive\Documents\My Flutter App\tvet system\pei_temp.docx')
$entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
$reader = New-Object System.IO.StreamReader($entry.Open())
$content = $reader.ReadToEnd()
$reader.Close()
$zip.Dispose()

$xml = [xml]$content
$nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$nsmgr.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

# Get all tables - focus on table 2 and 4 (FOR TESDA USE ONLY)
$tables = $xml.SelectNodes('//w:tbl', $nsmgr)
$tableNum = 0
foreach ($tbl in $tables) {
    $tableNum++
    if ($tableNum -ne 2 -and $tableNum -ne 4) { continue }
    Write-Output "=== TABLE $tableNum (FOR TESDA USE ONLY) ==="
    
    # Get tblGrid
    $grid = $tbl.SelectSingleNode('.//w:tblGrid', $nsmgr)
    if ($grid) {
        $gridCols = $grid.SelectNodes('.//w:gridCol', $nsmgr)
        $colWidths = @()
        foreach ($col in $gridCols) {
            $w = $col.GetAttribute('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
            $colWidths += $w
        }
        Write-Output "  Grid columns (twips): $($colWidths -join ', ')"
        # Convert twips to points (1 twip = 1/20 pt)
        $colPts = $colWidths | ForEach-Object { [math]::Round($_ / 20, 2) }
        Write-Output "  Grid columns (pt): $($colPts -join ', ')"
    }
    
    $rows = $tbl.SelectNodes('.//w:tr', $nsmgr)
    $rowNum = 0
    foreach ($row in $rows) {
        $rowNum++
        Write-Output "  --- Row $rowNum ---"
        
        # Get row height
        $trPr = $row.SelectSingleNode('.//w:trPr', $nsmgr)
        if ($trPr) {
            $trHeight = $trPr.SelectSingleNode('.//w:trHeight', $nsmgr)
            if ($trHeight) {
                $h = $trHeight.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                $hRule = $trHeight.GetAttribute('hRule', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                Write-Output "    Height: $h twips ($([math]::Round($h/20, 2)) pt), rule=$hRule"
            }
        }
        
        $cells = $row.SelectNodes('.//w:tc', $nsmgr)
        $cellNum = 0
        foreach ($cell in $cells) {
            $cellNum++
            
            # Get gridSpan
            $tcPr = $cell.SelectSingleNode('.//w:tcPr', $nsmgr)
            $span = 1
            $tcW = ''
            if ($tcPr) {
                $gridSpan = $tcPr.SelectSingleNode('.//w:gridSpan', $nsmgr)
                if ($gridSpan) {
                    $span = $gridSpan.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                }
                $tcWidth = $tcPr.SelectSingleNode('.//w:tcW', $nsmgr)
                if ($tcWidth) {
                    $tcW = $tcWidth.GetAttribute('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                }
                
                # Get borders
                $tcBorders = $tcPr.SelectSingleNode('.//w:tcBorders', $nsmgr)
                $borderInfo = ''
                if ($tcBorders) {
                    foreach ($side in @('top','left','bottom','right')) {
                        $b = $tcBorders.SelectSingleNode(".//w:$side", $nsmgr)
                        if ($b) {
                            $bVal = $b.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                            $bSz = $b.GetAttribute('sz', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                            if ($bVal -ne 'nil' -and $bVal -ne 'none') {
                                $borderInfo += "$side=$bVal(sz$bSz) "
                            }
                        }
                    }
                }
            }
            
            # Get text
            $texts = $cell.SelectNodes('.//w:t', $nsmgr)
            $cellText = ($texts | ForEach-Object { $_.InnerText }) -join ''
            
            Write-Output "    Cell ${cellNum}: span=${span} w=${tcW} twips borders=[${borderInfo}] text=[${cellText}]"
        }
    }
    Write-Output ""
}
