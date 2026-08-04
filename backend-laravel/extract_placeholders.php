<?php
$zip = new ZipArchive();
$zip->open('C:/Users/User/Downloads/TVET & DTC/RAP.docx');
$xml = $zip->getFromName('word/document.xml');
$zip->close();

// Extract all text content
preg_match_all('/<w:t[^>]*>([^<]*)<\/w:t>/', $xml, $texts);
$allText = $texts[1];
echo "=== All text content (line by line) ===\n";
foreach ($allText as $i => $t) {
    if (trim($t) !== '') echo "[$i] $t\n";
}
