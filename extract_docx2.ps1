Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\Users\User\OneDrive\Documents\My Flutter App\tvet system\pei_temp.docx')
$entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
$reader = New-Object System.IO.StreamReader($entry.Open())
$content = $reader.ReadToEnd()
$reader.Close()
$zip.Dispose()
# Extract table structure with cell text
$xml = [xml]$content
$nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$nsmgr.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

# Get all tables
$tables = $xml.SelectNodes('//w:tbl', $nsmgr)
$tableNum = 0
foreach ($tbl in $tables) {
    $tableNum++
    Write-Output "=== TABLE $tableNum ==="
    $rows = $tbl.SelectNodes('.//w:tr', $nsmgr)
    $rowNum = 0
    foreach ($row in $rows) {
        $rowNum++
        $cells = $row.SelectNodes('.//w:tc', $nsmgr)
        $cellTexts = @()
        foreach ($cell in $cells) {
            $texts = $cell.SelectNodes('.//w:t', $nsmgr)
            $cellText = ($texts | ForEach-Object { $_.InnerText }) -join ''
            $cellTexts += $cellText
        }
        Write-Output "  Row ${rowNum}: $($cellTexts -join ' | ')"
    }
    Write-Output ""
}
