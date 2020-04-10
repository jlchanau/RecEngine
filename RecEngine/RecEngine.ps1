Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
[System.Windows.Forms.Application]::EnableVisualStyles()

$SaveAsFileName = [string]::Empty

# Create Icon Extractor Assembly
$code = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace System
{
	public class IconExtractor
	{

	 public static Icon Extract(string file, int number, bool largeIcon)
	 {
	  IntPtr large;
	  IntPtr small;
	  ExtractIconEx(file, number, out large, out small, 1);
	  try
	  {
	   return Icon.FromHandle(largeIcon ? large : small);
	  }
	  catch
	  {
	   return null;
	  }

	 }
	 [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
	 private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

	}
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

#DEFAULT VALUES
##RecEngine Values
$instanceName                    = "AMPECRDMSASP01"
$recDatabaseName                 = "RecEngine"
$recSchemaName                   = "rec"

$Form                            = New-Object system.Windows.Forms.Form
$Form.Size                       = New-Object System.Drawing.Size(800,600)
$Form.text                       = "RecEngine v1.0"
$Form.TopMost                    = $false
$Form.MaximizeBox                = $false
$Form.FormBorderStyle            = 'FixedDialog'
$Form.StartPosition              = "CenterScreen"
$Form.Topmost                    = $True
$Form.AutoScaleMode              = 'Font'

############################################################################
#FUNCTIONS
############################################################################
#Browse file function
Function Select-FileDialog
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null     

    $objForm = New-Object System.Windows.Forms.OpenFileDialog -Property @{Filter = 'SQL files (*.sql)|*.sql'}
    $objForm.ShowHelp = $True
    $objForm.OverwritePrompt = $True
    $objForm.CreatePrompt = $True
    $objForm.ShowDialog() | out-null
    Return $objForm.FileName
}

Function Open-FileDialog
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null     

    $objForm = New-Object System.Windows.Forms.OpenFileDialog -Property @{Filter = 'JSON files (*.json)|*.json'}
    $objForm.ShowHelp = $True
    $objForm.OverwritePrompt = $True
    $objForm.CreatePrompt = $True
    $objForm.ShowDialog() | out-null
    Return $objForm.FileName
}

Function SaveAs {
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog -Property @{Filter = 'JSON files|*.json'} 
    $SaveFileDialog.title = "Save File to Disk"   
    $SaveFileDialog.ShowHelp = $True
    $SaveFileDialog.OverwritePrompt = $True
    $SaveFileDialog.CreatePrompt = $True
    $SaveFileDialog.ShowDialog() | out-null
    Return $SaveFileDialog.FileName
}


Function validateTextBoxes {
    IF($tbREServer.text -ne '' -and $tbRESchema.text -ne '' -and $tbREDatabase.text -ne '' -and $tbREName.text -ne '' -and $tbColumns.text -ne ''`
                                       -and $tbSourceDatabase.text -ne '' -and $tbSourceTableName.text -ne '' -and $tbSourcePK.text -ne '' -and $tbSourceSQLFile.text -ne '' `
                                       -and $tbTargetDatabase.text -ne '' -and $tbTargetTableName.text -ne '' -and $tbTargetPK.text -ne '' -and $tbTargetSQLFile.text -ne '')
                                    {
                                        $btnStart.Enabled = $true
                                    }
                                    ELSE 
                                    {
                                        $btnStart.Enabled = $false
                                    }
}


Function recExecution {
$instanceName           = $tbServer.Text
$delimiter              = "|"

$recDatabaseName        = $tbREDatabase.Text
$recSchemaName          = $tbRESchema.Text
$recName                = $tbREName.Text

$sourceDatabaseName     = $tbSourceDatabase.Text
$sourceTableName        = $tbSourceTableName.Text
$sourcePK               = $tbSourcePK.Text
$SQL_sourceQueryPath    = $tbSourceSQLFile.Text 

$targetDatabaseName     = $tbTargetDatabase.Text
$targetTableName        = $tbTargetTableName.Text
$targetPK               = $tbTargetPK.Text
$SQL_targetQueryPath    = $tbTargetSQLFile.Text 

$columnArray            = $tbColumns.Text.Split(",").trim() -replace "`r`n", ""

#########################################################################
# SETTINGS VALIDATION
#########################################################################
$validSettings = 1
$errorMessage = [string]::Empty
$invalidTableNameRec = [string]::Empty
$invalidTableNameTarget = [string]::Empty
$invalidColumnsRec = [string]::Empty
$invalidColumnsTarget = [string]::Empty
$SQL_sourceQueryPathExists = [string]::Empty
$columns = [string]::Empty

#Check SQL_sourceQueryPath is valid
IF($validSettings -eq 1) {

    IF(![System.IO.File]::Exists($SQL_sourceQueryPath)){
        $validSettings = 0
        $SQL_sourceQueryPathExists = "false"
        #write-host $SQL_sourceQueryPathExists
    }
    #if valid execute the query
    ELSE{ 
        #Drop source table if exists
        $SQL_dropRecTable = "IF OBJECT_ID('$recSchemaName.$sourceTableName', 'U') IS NOT NULL 
        DROP TABLE $recSchemaName.$sourceTableName;"
        Invoke-SqlCmd $SQL_dropRecTable  -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0

        #Run source query and create PK and Hashbyte index
        Invoke-SqlCmd -inputfile $SQL_sourceQueryPath -ServerInstance $instanceName -Database $SourceDatabaseName -QueryTimeout 0
        #Write-Host "Source table created"
        IF($tbStatus.Text -ne ""){$tbStatus.TextAppend("")}

        $tbStatus.AppendText("Source table created.")
    }
}
IF($validSettings -eq 1) {
    IF(![System.IO.File]::Exists($SQL_targetQueryPath)){
        $validSettings = 0
        $SQL_targetQueryPathExists = "false"
    }
    #if valid execute the query
    ELSE{ 
        #Drop rec table if exists
        $SQL_dropTargetTable = "IF OBJECT_ID('$recSchemaName.$targetTableName', 'U') IS NOT NULL 
        DROP TABLE $recSchemaName.$targetTableName;"
        Invoke-SqlCmd $SQL_dropTargetTable  -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0

        #Run Rec Query and Create PK and Hashbyte index
        Invoke-SqlCmd -inputfile $SQL_targetQueryPath -ServerInstance $instanceName -Database $TargetDatabaseName -QueryTimeout 0
        #Write-Host "Target table created"
        $tbStatus.AppendText("`r`nTarget table created.")
    }
}

IF($validSettings -eq 1) {
    #Check rec table name exists
    $queryResultTableNameRec = Invoke-Sqlcmd -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0 `
    -Query "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '$sourceTableName' AND TABLE_SCHEMA = '$recSchemaName'"
    $tableNameExistsRec = $queryResultTableNameRec.TABLE_NAME
    IF($tableNameExistsRec.length -eq 0) {
        $validSettings = 0
        $invalidTableNameRec = $sourceTableName
    }

    #Check target table schema and name combination exists
    $queryResultTableNameTarget = Invoke-Sqlcmd -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0 `
    -Query "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '$targetTableName' AND TABLE_SCHEMA = '$recSchemaName'" 
    $tableNameExistsTarget = $queryResultTableNameTarget.TABLE_NAME
    IF($tableNameExistsTarget.length -eq 0) {
        $validSettings = 0
        $invalidTableNameTarget = $targetTableName
    }
}

#Check columns listed are valid
IF($validSettings -eq 1){
    #Check columns exist in Rec table
    FOREACH ($column IN $columnArray) {
        $queryResultRec = Invoke-Sqlcmd -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0 `
        -Query "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$sourceTableName' AND COLUMN_NAME = '$column'" 
        $columnExistsRec = $queryResultRec.COLUMN_NAME   
        IF($columnExistsRec.length -eq 0) {
            $validSettings = 0

            IF($invalidColumnsRec.length -eq 0) {
                $invalidColumnsRec = $column
            } 
            ELSE{
                $invalidColumnsRec = "$invalidColumnsRec, $column"
            }
        }
    }

    #Check columns exist in Target table
    FOREACH ($column IN $columnArray) {
        $queryResultTarget = Invoke-Sqlcmd -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0 `
        -Query "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$($targetTableName)' AND COLUMN_NAME = '$column'" 
        $columnExistsTarget = $queryResultTarget.COLUMN_NAME   
        IF($columnExistsTarget.length -eq 0) {
            $validSettings = 0
            IF($invalidColumnsTarget.length -eq 0) {
                $invalidColumnsTarget = $column
            } 
            ELSE{
                $invalidColumnsTarget = "$invalidColumnsTarget, $column"
            }
        }
    }
}

#Display invalid settings message if applicable
IF($validSettings -eq 0){
    $btnStart.Enabled = $true
    IF($SQL_sourceQueryPathExists -eq "false"){
        $errorMessage = "INVALID REC QUERY PATH: $SQL_sourceQueryPath does not exist."    
    }
    IF($SQL_targetQueryPathExists -eq "false" -and $errorMessage.length -gt 0) {
        $errorMessage = "$errorMessage`n`nINVALID REC QUERY PATH: $SQL_targetQueryPath does not exist."   
    }
    ELSEIF($invalidTableNameRec.length -gt 0 -and $errorMessage.length -eq 0) {
        $errorMessage = "INVALID REC QUERY PATH: $SQL_targetQueryPath does not exist."   
    }
    IF($invalidTableNameTarget.length -gt 0) {
        $errorMessage = "INVALID TARGET TABLE SCHEMA & NAME: $recSchemaName.$invalidTableNameTarget does not exist in $recDatabaseName."
    }
    IF($invalidTableNameRec.length -gt 0 -and $errorMessage.length -gt 0) {
        $errorMessage = "$errorMessage`n`nINVALID REC TABLE NAME: $recSchemaName.$invalidTableNameRec does not exist in $recDatabaseName."
    }
    ELSEIF($invalidTableNameRec.length -gt 0 -and $errorMessage.length -eq 0) {
        $errorMessage = "INVALID REC TABLE NAME: $recSchemaName.$invalidTableNameRec does not exist in $recDatabaseName."
    }
    IF($invalidColumnsRec.length -gt 0 -and $errorMessage.length -gt 0){
        $errorMessage = "$errorMessage`n`n$invalidColumnsRec do(es) not exist in $recDatabaseName.$recSchemaName.$sourceTableName."
    }
    ELSEIF($invalidColumnsRec.length -gt 0 -and $errorMessage.length -eq 0) {
        $errorMessage = "$invalidColumnsRec do(es) not exist in $recDatabaseName.$recSchemaName.$sourceTableName."
    }
    IF($invalidColumnstarget.length -gt 0 -and $errorMessage.length -gt 0){
        $errorMessage = "$errorMessage`n`n$invalidColumnsTarget do(es) not exist in $recDatabaseName.$recSchemaName.$targetTableName."
    }
    ELSEIF($invalidColumnstarget.length -gt 0 -and $errorMessage.length -eq 0) {
        $errorMessage = "$invalidColumnstarget do(es) not exist in $recDatabaseName.$recSchemaName.$targetTableName."
    }

    #Output Error Message
    $MessageboxTitle = "ERROR! Invalid Settings"
    $ButtonType = [System.Windows.MessageBoxButton]::OK
    $MessageIcon = [System.Windows.MessageBoxImage]::Error
    $MessageBoxResult = [System.Windows.MessageBoxResult]:: OK
    $MessageBoxOptions = [System.Windows.MessageBoxOptions]:: None
    [System.Windows.MessageBox]::Show($errorMessage,$MessageboxTitle,$ButtonType,$messageicon,$MessageBoxResult,$MessageBoxOptions) 

}
#write-host $validSettings

ELSE {
    #########################################################################
    # REC EXECUTION
    #########################################################################
    #Start Date
    $startDateTime = get-date -uFormat "%Y-%m-%d %T"
    #write-host "Rec execution started"
    $tbStatus.AppendText("`r`nReconciliation execution started.")

    #Set Columns
    FOREACH ($column IN $columnArray){
        IF ($column -eq $columnArray[0]){
            $columns = "ISNULL(CAST($($column) AS NVARCHAR(MAX)),'a') + '$delimiter'"
        }
        ELSE {$columns = "$($columns) + ISNULL(CAST($($column) AS NVARCHAR(MAX)),'a') + '$delimiter'"
        }
        
    }
    #write-host $columns

    #Add Hashbyte column to target table
    $SQL_AddHashbyteColumnTarget = "
    IF COL_LENGTH('$recSchemaName.$targetTableName', 'Hashbyte') IS NOT NULL
    BEGIN
    ALTER TABLE $recSchemaName.$targetTableName DROP COLUMN Hashbyte;
    END
    ALTER TABLE $recSchemaName.$targetTableName ADD Hashbyte VARBINARY(255) NULL;
    "
    Invoke-SqlCmd $SQL_AddHashbyteColumnTarget  -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0
    #write-host $SQL_AddHashbyteColumnTarget

    #Add match columns to Rec table

    $SQL_MakePKNotNull = "
    ALTER TABLE $recSchemaName.$sourceTableName ALTER COLUMN $sourcePK NVARCHAR(255) NOT NULL;"
    Invoke-SqlCmd $SQL_MakePKNotNull -ServerInstance $instanceName -Database $recDatabaseName -querytimeout 0  

    $SQL_recAlterTable = "
    ALTER TABLE $recSchemaName.$sourceTableName ADD CONSTRAINT PK_$($recSchemaName)_$($sourceTableName)_$($sourcePK) PRIMARY KEY CLUSTERED ($($sourcePK));
    ALTER TABLE $recSchemaName.$sourceTableName ADD HashByte VARBINARY(255) NULL
        ,Matched BIT NOT NULL DEFAULT 1
        ,NotExist NVARCHAR(10)
    "
    FOREACH ($column IN $columnArray)
    {
        $SQL_recAlterTable = "$SQL_recAlterTable 
        ,$($column)_Match BIT NOT NULL DEFAULT 1"
    }
    #write-host $SQL_recAlterTable
    Invoke-SqlCmd $SQL_recAlterTable -ServerInstance $instanceName -Database $recDatabaseName -querytimeout 0       

    #Update target table Hashbyte
    $SQL_updateTargetHashbyte = "
    UPDATE $recSchemaName.$targetTableName
    SET [Hashbyte] = RecEngine.dbo.GetHashHybrid('SHA2_256',CONVERT(VARBINARY(MAX),$columns));
    "
    Invoke-SqlCmd $SQL_updateTargetHashbyte  -ServerInstance $instanceName -Database $recDatabaseName -QueryTimeout 0

    #Update match columns
    $SQL_UpdateRecTable = "
    UPDATE $recSchemaName.$sourceTableName
    SET [Hashbyte] = RecEngine.dbo.GetHashHybrid('SHA2_256',CONVERT(VARBINARY(MAX),$columns));

    CREATE NONCLUSTERED INDEX [ucidx_$($sourceTableName)_srcId] ON $recSchemaName.$sourceTableName
    (
    	$sourcePK ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
    ;

    UPDATE A
    SET
        A.Matched = 0"

    FOREACH ($column IN $columnArray){
        $SQL_UpdateRecTable = "$SQL_UpdateRecTable 
        ,A.$($column)_Match = CASE WHEN ISNULL(CAST(A.$column AS NVARCHAR(MAX)),'a') = ISNULL(CAST(B.$column AS NVARCHAR(MAX)),'a') THEN 1 ELSE 0 END"
    }
    $SQL_UpdateRecTable = 
    "
    $SQL_UpdateRecTable
    FROM
        $recSchemaName.$sourceTableName A
    INNER JOIN
        $recDatabaseName.$recSchemaName.$targetTableName B
        ON A.$sourcePK = B.$targetPK
        AND A.HashByte <> B.HashByte
    "
    #write-host $SQL_UpdateRecTable
    Invoke-SqlCmd $SQL_UpdateRecTable -ServerInstance $instanceName -Database $recDatabaseName -querytimeout 0

    #Rows not existing in target table
    $SQL_notExistInTarget = "
    UPDATE A
    SET
        A.Matched = 0
        ,A.NotExist = 'Target'"
    FOREACH ($column IN $columnArray){
        $SQL_notExistInTarget = "$SQL_notExistInTarget 
        ,A.$($column)_Match = 0"
    }
    $SQL_notExistInTarget = 
    "$SQL_notExistInTarget
    FROM
        $recSchemaName.$sourceTableName A 
    LEFT JOIN
        $recDatabaseName.$recSchemaName.$targetTableName B
        ON A.$sourcePK = B.$targetPK
    WHERE
        B.$targetPK IS NULL
    "
    write-host $SQL_notExistInTarget
    Invoke-SqlCmd $SQL_notExistInTarget -ServerInstance $instanceName -Database $recDatabaseName -querytimeout 0

    #Rows not existing in reconcile table
    $SQL_notExistInReconcile = "
    INSERT INTO $recSchemaName.$sourceTableName (
        $sourcePK
        ,Matched
        ,NotExist"
    FOREACH ($column IN $columnArray){
        $SQL_notExistInReconcile = "$SQL_notExistInReconcile 
        ,$column"
    }
    $SQL_notExistInReconcile = "$SQL_notExistInReconcile
    )
    SELECT
        A.$targetPK
        ,0
        ,'Source'"
    FOREACH ($column IN $columnArray){
        $SQL_notExistInReconcile = "$SQL_notExistInReconcile 
        ,A.$column"
    }
    $SQL_notExistInReconcile = "$SQL_notExistInReconcile
    FROM
        $recDatabaseName.$recSchemaName.$targetTableName A 
    LEFT JOIN
        $recSchemaName.$sourceTableName  B
        ON A.$targetPK = B.$sourcePK
    WHERE
        B.$sourcePK IS NULL"

    write-host $SQL_notExistInReconcile
    Invoke-SqlCmd $SQL_notExistInReconcile -ServerInstance $instanceName -Database $recDatabaseName -querytimeout 0


    #########################################################################
    # 1.Rec Detail Mistmatches Report
    #########################################################################
    #Clear RecDetailMistmatches of existing recName records
    $SQL_recDetailMistmatchesDelete = "DELETE FROM [Report].[RecDetailsMismatches] WHERE [RecName] = '$recName'"
    Invoke-SqlCmd -Query $SQL_recDetailMistmatchesDelete -Server $instanceName -Database $recDatabaseName -querytimeout 0     

    $SQL_RecDetailMistmatches = "
    WITH CTE AS (
        SELECT 
            $sourcePK                           AS [PrimaryKey]
            ,REPLACE([ColumnName],'_Match','')  AS [ColumnName]"
    FOREACH ($column IN $columnArray)
    {
        $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches 
        ,$($column)"
    }
    $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
        FROM
        (
        SELECT
           *
        FROM
            $recSchemaName.$sourceTableName
        ) src
        
        UNPIVOT
        ( 
            [ColumnMatched]
            FOR ColumnName IN ("
    FOREACH ($column IN $columnArray)
    {
        IF ($column -eq $columnArray[0]){
            $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
                 $($column)_Match"
        }
        ELSE {$SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
                ,$($column)_Match"
        }
    }
    $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
                              )
        ) AS unpvt
        WHERE 
            [matched] = 0 
            AND [NotExist] IS NULL 
            AND [ColumnMatched] = 0
        )
        INSERT INTO [Report].[RecDetailsMismatches]
        (
            [RecName]
            ,[RecTable]
            ,[TargetTable]
            ,[PrimaryKey]
            ,[ColumnName]
            ,[ColumnValue_Source]
            ,[ColumnValue_Target]
        )
        SELECT
            '$recName'                                         AS [RecName]
            ,'$recSchemaName.$sourceTableName'                 AS [RecTable]
            ,'$recSchemaName.$targetTableName'                 AS [TargetTable]
            ,a.[PrimaryKey]
            ,a.[ColumnName]
            ,CASE"
    FOREACH ($column IN $columnArray)
    {
        $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches 
        WHEN [ColumnName] = '$column' THEN CAST(a.[$column] AS NVARCHAR(MAX))"
    }     
    $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
            END                                                AS [ColumnValue_Source]
            ,CASE"
    FOREACH ($column IN $columnArray)
    {
        $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches 
        WHEN [ColumnName] = '$column' THEN CAST(b.[$column] AS NVARCHAR(MAX))"
    }     
    $SQL_RecDetailMistmatches = "$SQL_RecDetailMistmatches
             END                                               AS [ColumnValue_Target]   
        FROM
            CTE a
        LEFT JOIN
            $recDatabaseName.$recSchemaName.$targetTableName b
            ON a.[PrimaryKey] = b.$targetPK  
    "
    #write-host $SQL_RecDetailMistmatches
    Invoke-SqlCmd -Query $SQL_RecDetailMistmatches -Server $instanceName -Database $recDatabaseName -querytimeout 0 

    #########################################################################
    # 2.Rec Detail Not Exist Report
    #########################################################################
    #Clear RecDetailNotExist of existing recName records
    $SQL_recDetailNotExistDelete = "DELETE FROM [Report].[RecDetailsNotExist] WHERE [RecName] = '$recName'"
    Invoke-SqlCmd -Query $SQL_recDetailNotExistDelete -Server $instanceName -Database $recDatabaseName -querytimeout 0 

    $SQL_recDetailNotExist = "
    INSERT INTO [Report].[RecDetailsNotExist]
    (
        [RecName]
        ,[PrimaryKey]
        ,[NotExist]
    )
    SELECT
        '$recName'
        ,[$sourcePK]
        ,[NotExist]
    FROM
        [$recDatabaseName].[$recSchemaName].[$sourceTableName]
    WHERE
        [NotExist] IS NOT NULL
    "
    #write-host $SQL_recDetailNotExist
    Invoke-SqlCmd -Query $SQL_recDetailNotExist -Server $instanceName -Database $recDatabaseName -querytimeout 0 

    #########################################################################
    # 3.Rec Summary Report
    #########################################################################
    #Clear recSummary of existing recName records
    $endDateTime = get-date -uFormat "%Y-%m-%d %T"
    $SQL_recDetailDelete = "DELETE FROM [Report].[RecSummary] WHERE [RecName] = '$recName'"
    Invoke-SqlCmd -Query $SQL_recDetailDelete -Server $instanceName -Database $recDatabaseName -querytimeout 0     

    $SQL_RecSummary = "
    INSERT INTO [Report].[RecSummary]
    (
        [RecName]
        ,[TotalSourceRecords]
        ,[TotalTargetRecords]
        ,[Matches]
        ,[Mismatches]
        ,[NotExistInTarget]
        ,[NotExistInSource]
        ,[ReportRunDate]
        ,[ReportRuntime(sec)]
    )
    SELECT
        '$recName'                              AS [RecName]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [NotExist] IS NULL OR [NotExist] = 'Target')
                                                AS [TotalSourceRecords]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [NotExist] IS NULL OR [NotExist] = 'Source')
                                                AS [TotalTargetRecords]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [Matched] = 1)
                                                AS [Matches]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [Matched] = 0 AND [NotExist] IS NULL)
                                                AS [Mismatches]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [NotExist] = 'Target')
                                                AS [NotExistInTarget]
        ,(SELECT COUNT(1) FROM [$recDatabaseName].[$recSchemaName].[$sourceTableName] WHERE [NotExist] = 'Source')
                                                AS [NotExistInSource]
        ,'$startDateTime'                       AS [ReportRunDate]
        ,(SELECT DATEDIFF(ss,'$startDateTime','$endDateTime'))
                                                AS [ReportRuntime(sec)]
    "
    Invoke-SqlCmd -Query $SQL_RecSummary -Server $instanceName -Database $recDatabaseName -querytimeout 0 
    
    $tbStatus.AppendText("`r`nReconciliation completed!")
    $btnStart.Enabled          = $true

}
        
}
############################################################################
#MENU ITEMS
############################################################################
$menuMain              = New-Object System.Windows.Forms.MenuStrip
$menuFile              = New-Object System.Windows.Forms.ToolStripMenuItem
$menuOpen              = New-Object System.Windows.Forms.ToolStripMenuItem
$menuSave              = New-Object System.Windows.Forms.ToolStripMenuItem
$menuSaveAs            = New-Object System.Windows.Forms.ToolStripMenuItem

# Main ToolStrip
$Form.Controls.Add($mainToolStrip)
 
# Main Menu Bar
$Form.Controls.Add($menuMain)
 
# Menu Options - File
$menuFile.Text = "File"
$menuMain.Items.Add($menuFile)

# Menu Options - File / Open

$menuOpen.Image        = [System.IconExtractor]::Extract("shell32.dll", 4, $true)
$menuOpen.ShortcutKeys = "Control, O"
$menuOpen.Text         = "Open"
$menuOpen.Add_Click({
    $openFile = Open-FileDialog
    IF ($openFile -ne "") {
        Set-Variable -Name "SaveAsFileName" -Value $openFile -Scope global
        $fileoutput = (Get-Content $openFile -Raw) | ConvertFrom-Json
        $tbServer.Text = $fileoutput.psobject.properties.Where({$_.name -eq "instanceName"}).value
        $tbREDatabase.Text = $fileoutput.psobject.properties.Where({$_.name -eq "recDatabaseName"}).value
        $tbRESchema.Text = $fileoutput.psobject.properties.Where({$_.name -eq "recSchemaName"}).value
        $tbREName.Text = $fileoutput.psobject.properties.Where({$_.name -eq "recName"}).value
        $tbSourceDatabase.Text = $fileoutput.psobject.properties.Where({$_.name -eq "sourceDatabaseName"}).value
        $tbSourceTableName.Text = $fileoutput.psobject.properties.Where({$_.name -eq "sourceTableName"}).value
        $tbSourcePK.Text = $fileoutput.psobject.properties.Where({$_.name -eq "sourcePK"}).value
        $tbSourceSQLFile.Text = $fileoutput.psobject.properties.Where({$_.name -eq "SQL_sourceQueryPath"}).value
        $tbTargetDatabase.Text = $fileoutput.psobject.properties.Where({$_.name -eq "targetDatabaseName"}).value
        $tbTargetTableName.Text = $fileoutput.psobject.properties.Where({$_.name -eq "targetTableName"}).value
        $tbTargetPK.Text = $fileoutput.psobject.properties.Where({$_.name -eq "targetPK"}).value
        $tbTargetSQLFile.Text = $fileoutput.psobject.properties.Where({$_.name -eq "SQL_targetQueryPath"}).value
        #$tbColumns.Text = $fileoutput.psobject.properties.Where({$_.name -eq "columnArray"}).value
        $tbColumns.Text = ""
        $columnArray = $fileoutput.psobject.properties.Where({$_.name -eq "columnArray"}).value
        FOR($i = 0; $i -le $columnArray.count -1; $i++)
        {
            IF($i -eq 0) {$tbColumns.AppendText($columnArray[$i])} 
            ELSE{$tbColumns.AppendText("`r`n,$($columnArray[$i])")} 
        } 
        {$tbColumns.Text.AppendText($column)}

        $tbStatus.Text = "$($openFile) sucessfully opened."
        $menuSave.Enabled = $true
    }
})
[void]$menuFile.DropDownItems.Add($menuOpen)

# Menu Options - File / Save
$menuSave.Image        = [System.IconExtractor]::Extract("shell32.dll", 36, $true)
$menuSave.ShortcutKeys = "F2"
$menuSave.Text         = "Save"
$menuSave.Enabled      = $false
$menuSave.Add_Click({
    $columnArray = $tbColumns.Text.Split(",").trim() -replace "`r`n", ""                     
            $jsonOutput = 
"{
    `"instanceName`": `"$($tbServer.Text.replace('\','\\'))`"
    ,`"recDatabaseName`": `"$($tbREDatabase.Text.replace('\','\\'))`"
    ,`"recSchemaName`": `"$($tbRESchema.Text.replace('\','\\'))`"
    ,`"recName`": `"$($tbREName.Text.replace('\','\\'))`"
    ,`"sourceDatabaseName`": `"$($tbSourceDatabase.Text.replace('\','\\'))`"
    ,`"sourceTableName`": `"$($tbSourceTableName.Text.replace('\','\\'))`"
    ,`"sourcePK`": `"$($tbSourcePK.Text.replace('\','\\'))`"
    ,`"SQL_sourceQueryPath`": `"$($tbSourceSQLFile.Text.replace('\','\\'))`"
    ,`"targetDatabaseName`": `"$($tbTargetDatabase.Text.replace('\','\\'))`"
    ,`"targetTableName`": `"$($tbTargetTableName.Text.replace('\','\\'))`"
    ,`"targetPK`": `"$($tbTargetPK.Text.replace('\','\\'))`"
    ,`"SQL_targetQueryPath`": `"$($tbTargetSQLFile.Text.replace('\','\\'))`"
    ,`"columnArray`": ["
    FOR($i = 0; $i -le $columnArray.count -1; $i++)
    {
        IF($i -eq 0) {$jsonOutput = $jsonOutput + "`"$($columnArray[$i])`""} 
        ELSE {$jsonOutput = $jsonOutput + ",`"$($columnArray[$i])`""} 
    } 
    $jsonOutput = $jsonOutput + "]
}"
            Set-Content -Path $SaveAsFileName -Value $jsonOutput
            $tbStatus.Text = "$($SaveAsFileName) successfully saved."

})
[void]$menuFile.DropDownItems.Add($menuSave)
 
# Menu Options - File / Save As
$menuSaveAs.Image        = [System.IconExtractor]::Extract("shell32.dll", 45, $true)
$menuSaveAs.ShortcutKeys = "Control, S"
$menuSaveAs.Text         = "Save As"
$menuSaveAs.Add_Click({ 
    $saveAS = SaveAs
    IF($saveAS -ne ""){
        Set-Variable -Name "SaveAsFileName" -Value $saveAS -Scope global
        
        $columnArray = $tbColumns.Text.Split(",").trim() -replace "`r`n", ""                     
        $jsonOutput  = 
"{
    `"instanceName`": `"$($tbServer.Text.replace('\','\\'))`"
    ,`"recDatabaseName`": `"$($tbREDatabase.Text.replace('\','\\'))`"
    ,`"recSchemaName`": `"$($tbRESchema.Text.replace('\','\\'))`"
    ,`"recName`": `"$($tbREName.Text.replace('\','\\'))`"
    ,`"sourceDatabaseName`": `"$($tbSourceDatabase.Text.replace('\','\\'))`"
    ,`"sourceTableName`": `"$($tbSourceTableName.Text.replace('\','\\'))`"
    ,`"sourcePK`": `"$($tbSourcePK.Text.replace('\','\\'))`"
    ,`"SQL_sourceQueryPath`": `"$($tbSourceSQLFile.Text.replace('\','\\'))`" 
    ,`"targetDatabaseName`": `"$($tbTargetDatabase.Text.replace('\','\\'))`"
    ,`"targetTableName`": `"$($tbTargetTableName.Text.replace('\','\\'))`"
    ,`"targetPK`": `"$($tbTargetPK.Text.replace('\','\\'))`"
    ,`"SQL_targetQueryPath`": `"$($tbTargetSQLFile.Text.replace('\','\\'))`"
    ,`"columnArray`": ["
    FOR($i = 0; $i -le $columnArray.count -1; $i++)
    {
        IF($i -eq 0) {$jsonOutput = $jsonOutput + "`"$($columnArray[$i])`""} 
        ELSE {$jsonOutput = $jsonOutput + ",`"$($columnArray[$i])`""} 
    } 
    $jsonOutput = $jsonOutput + "]
}"
            Set-Content -Path $SaveAsFileName -Value $jsonOutput
            $tbStatus.Text = "$($SaveAsFileName) successfully saved as."
            $menuSave.Enabled = $true
        }
})
[void]$menuFile.DropDownItems.Add($menuSaveAs)


############################################################################
#REC ENGINE INPUTS
############################################################################
$tbWidth                         = 250
$browseX                         = 343
$lblREHeader                     = New-Object system.Windows.Forms.Label
$lblREHeader.text                = "RecEngine Settings"
$lblREHeader.AutoSize            = $true
$lblREHeader.width               = 25
$lblREHeader.height              = 10
$lblREHeader.location            = New-Object System.Drawing.Point(10,25)
$lblREHeader.Font                = [System.Drawing.Font]::new('Microsoft Sans Serif', 12, [System.Drawing.FontStyle]::Bold)

$lblServer                       = New-Object system.Windows.Forms.Label
$lblServer.text                  = "Server:"
$lblServer.AutoSize              = $true
$lblServer.width                 = 25
$lblServer.height                = 10
$lblServer.location              = New-Object System.Drawing.Point(33,53)
$lblServer.Font                  = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbServer                        = New-Object system.Windows.Forms.TextBox
$tbServer.multiline              = $false
$tbServer.width                  = 250
$tbServer.height                 = 20
$tbServer.location               = New-Object System.Drawing.Point(85,50)
$tbServer.Font                   = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbServer.Text                   = $instanceName 
$tbServer.add_TextChanged({     validateTextBoxes})

$lblREDatabase                   = New-Object system.Windows.Forms.Label
$lblREDatabase.text              = "Database:"
$lblREDatabase.AutoSize          = $true
$lblREDatabase.width             = 25
$lblREDatabase.height            = 10
$lblREDatabase.location          = New-Object System.Drawing.Point(17,78)
$lblREDatabase.Font              = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbREDatabase                    = New-Object system.Windows.Forms.TextBox
$tbREDatabase.multiline          = $false
$tbREDatabase.width              = 250
$tbREDatabase.height             = 20
$tbREDatabase.location           = New-Object System.Drawing.Point(85,75)
$tbREDatabase.Font               = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbREDatabase.Text               = $recDatabaseName 
$tbREDatabase.add_TextChanged({ validateTextBoxes})

$lblRESchema                     = New-Object system.Windows.Forms.Label
$lblRESchema.text                = "Schema:"
$lblRESchema.AutoSize            = $true
$lblRESchema.width               = 25
$lblRESchema.height              = 10
$lblRESchema.location            = New-Object System.Drawing.Point(23,103)
$lblRESchema.Font                = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbRESchema                      = New-Object system.Windows.Forms.TextBox
$tbRESchema.multiline            = $false
$tbRESchema.width                = $tbWidth                         
$tbRESchema.height               = 20
$tbRESchema.location             = New-Object System.Drawing.Point(85,100)
$tbRESchema.Font                 = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbRESchema.Text                 = $recSchemaName 
$tbRESchema.add_TextChanged({validateTextBoxes})

$lblREName                       = New-Object system.Windows.Forms.Label
$lblREName.text                  = "Rec Name:"
$lblREName.AutoSize              = $true
$lblREName.width                 = 25
$lblREName.height                = 10
$lblREName.location              = New-Object System.Drawing.Point(10,128)
$lblREName.Font                  = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbREName                        = New-Object system.Windows.Forms.TextBox
$tbREName.multiline              = $false
$tbREName.width                  = $tbWidth                         
$tbREName.height                 = 20
$tbREName.location               = New-Object System.Drawing.Point(85,125)
$tbREName.Font                   = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbREName.add_TextChanged({validateTextBoxes})

#SOURCE SETTINGS INPUTS
$lblSourceSettings               = New-Object system.Windows.Forms.Label
$lblSourceSettings.text          = "Source Settings"
$lblSourceSettings.AutoSize      = $true
$lblSourceSettings.width         = 25
$lblSourceSettings.height        = 10
$lblSourceSettings.location      = New-Object System.Drawing.Point(10,165)
$lblSourceSettings.Font          = [System.Drawing.Font]::new('Microsoft Sans Serif', 12, [System.Drawing.FontStyle]::Bold)


$lblSourceDatabase               = New-Object system.Windows.Forms.Label
$lblSourceDatabase.text          = "Database:"
$lblSourceDatabase.AutoSize      = $true
$lblSourceDatabase.width         = 25
$lblSourceDatabase.height        = 10
#$lblSourceDatabase.Anchor        = 'top,right'
$lblSourceDatabase.location      = New-Object System.Drawing.Point(17,193)
$lblSourceDatabase.Font          = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbSourceDatabase                = New-Object system.Windows.Forms.TextBox
$tbSourceDatabase.multiline      = $false
$tbSourceDatabase.width          = $tbWidth                         
$tbSourceDatabase.height         = 20
$tbSourceDatabase.location       = New-Object System.Drawing.Point(85,190)
$tbSourceDatabase.Font           = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbSourceDatabase.add_TextChanged({ validateTextBoxes})

$lblSourceTableName              = New-Object system.Windows.Forms.Label
$lblSourceTableName.text         = "Table:"
$lblSourceTableName.AutoSize     = $true
$lblSourceTableName.width        = 25
$lblSourceTableName.height       = 10
$lblSourceTableName.location     = New-Object System.Drawing.Point(40,217)
$lblSourceTableName.Font         = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbSourceTableName               = New-Object system.Windows.Forms.TextBox
$tbSourceTableName.multiline     = $false
$tbSourceTableName.width         = $tbWidth                         
$tbSourceTableName.height        = 20
$tbSourceTableName.location      = New-Object System.Drawing.Point(85,215)
$tbSourceTableName.Font          = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbSourceTableName.add_TextChanged({validateTextBoxes})

$lblSourcePK                     = New-Object system.Windows.Forms.Label
$lblSourcePK.text                = "PK:"
$lblSourcePK.AutoSize            = $true
$lblSourcePK.width               = 25
$lblSourcePK.height              = 10
#$lblSourcePK.Anchor              = 'top,right'
$lblSourcePK.location            = New-Object System.Drawing.Point(53,243)
$lblSourcePK.Font                = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbSourcePK                      = New-Object system.Windows.Forms.TextBox
$tbSourcePK.multiline            = $false
$tbSourcePK.width                = $tbWidth                         
$tbSourcePK.height               = 20
$tbSourcePK.location             = New-Object System.Drawing.Point(85,240)
$tbSourcePK.Font                 = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbSourcePK.add_TextChanged({validateTextBoxes})

$lblSourceSQLFile                = New-Object system.Windows.Forms.Label
$lblSourceSQLFile.text           = "SQL file:"
$lblSourceSQLFile.AutoSize       = $true
$lblSourceSQLFile.width          = 25
$lblSourceSQLFile.height         = 10
$lblSourceSQLFile.location       = New-Object System.Drawing.Point(25,267)
$lblSourceSQLFile.Font           = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbSourceSQLFile                 = New-Object system.Windows.Forms.TextBox
$tbSourceSQLFile.multiline       = $false
$tbSourceSQLFile.width           = $tbWidth                         
$tbSourceSQLFile.height          = 20
$tbSourceSQLFile.location        = New-Object System.Drawing.Point(85,265)
$tbSourceSQLFile.Font            = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbSourceSQLFile.add_TextChanged({  validateTextBoxes
                                    
                                #rite-host $SQL_sourceQueryPath 
                                })

$btnSourceBrowse                 = New-Object system.Windows.Forms.Button
$btnSourceBrowse.text            = "Browse"
$btnSourceBrowse.width           = 75
$btnSourceBrowse.height          = 24
$btnSourceBrowse.location        = New-Object System.Drawing.Point($browseX,265)
$btnSourceBrowse.Font            = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$btnSourceBrowse.Add_Click({
                            $sourcefile = Select-FileDialog
                            IF($sourcefile -ne ""){$tbSourceSQLFile.Text = $sourcefile}
                           })


#TARGET SETTINGS INPUTS
$lblTargetSetting                = New-Object system.Windows.Forms.Label
$lblTargetSetting.text           = "Target Settings"
$lblTargetSetting.AutoSize       = $true
$lblTargetSetting.width          = 25
$lblTargetSetting.height         = 10
$lblTargetSetting.location       = New-Object System.Drawing.Point(10,305)
$lblTargetSetting.Font           = [System.Drawing.Font]::new('Microsoft Sans Serif', 12, [System.Drawing.FontStyle]::Bold)

$lblTargetDatabase               = New-Object system.Windows.Forms.Label
$lblTargetDatabase.text          = "Database:"
$lblTargetDatabase.AutoSize      = $true
$lblTargetDatabase.width         = 25
$lblTargetDatabase.height        = 10
#$lblTargetDatabase.Anchor        = 'top,right'
$lblTargetDatabase.location      = New-Object System.Drawing.Point(17,333)
$lblTargetDatabase.Font          = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbTargetDatabase                = New-Object system.Windows.Forms.TextBox
$tbTargetDatabase.multiline      = $false
$tbTargetDatabase.width          = $tbWidth                         
$tbTargetDatabase.height         = 20
$tbTargetDatabase.location       = New-Object System.Drawing.Point(85,330)
$tbTargetDatabase.Font           = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbTargetDatabase.add_TextChanged({validateTextBoxes})

$lblTargetTableName              = New-Object system.Windows.Forms.Label
$lblTargetTableName.text         = "Table:"
$lblTargetTableName.AutoSize     = $true
$lblTargetTableName.width        = 25
$lblTargetTableName.height       = 10
$lblTargetTableName.location     = New-Object System.Drawing.Point(40,357)
$lblTargetTableName.Font         = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbTargetTableName               = New-Object system.Windows.Forms.TextBox
$tbTargetTableName.multiline     = $false
$tbTargetTableName.width         = $tbWidth                         
$tbTargetTableName.height        = 20
$tbTargetTableName.location      = New-Object System.Drawing.Point(85,355)
$tbTargetTableName.Font          = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbTargetTableName.add_TextChanged({validateTextBoxes})

$lblTargetPK                     = New-Object system.Windows.Forms.Label
$lblTargetPK.text                = "PK:"
$lblTargetPK.AutoSize            = $true
$lblTargetPK.width               = 25
$lblTargetPK.height              = 10
#$lblTargetPK.Anchor              = 'top,right'
$lblTargetPK.location            = New-Object System.Drawing.Point(53,383)
$lblTargetPK.Font                = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbTargetPK                      = New-Object system.Windows.Forms.TextBox
$tbTargetPK.multiline            = $false
$tbTargetPK.width                = $tbWidth                         
$tbTargetPK.height               = 20
$tbTargetPK.location             = New-Object System.Drawing.Point(85,380)
$tbTargetPK.Font                 = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbTargetPK.add_TextChanged({validateTextBoxes})

$lblTargetSQLFile                = New-Object system.Windows.Forms.Label
$lblTargetSQLFile.text           = "SQL file:"
$lblTargetSQLFile.AutoSize       = $true
$lblTargetSQLFile.width          = 25
$lblTargetSQLFile.height         = 10
$lblTargetSQLFile.location       = New-Object System.Drawing.Point(25,407)
$lblTargetSQLFile.Font           = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)

$tbTargetSQLFile                 = New-Object system.Windows.Forms.TextBox
$tbTargetSQLFile.multiline       = $false
$tbTargetSQLFile.width           = $tbWidth                         
$tbTargetSQLFile.height          = 20
$tbTargetSQLFile.location        = New-Object System.Drawing.Point(85,405)
$tbTargetSQLFile.Font            = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbTargetSQLFile.add_TextChanged({validateTextBoxes})

$btnTargetBrowse                 = New-Object system.Windows.Forms.Button
$btnTargetBrowse.text            = "Browse"
$btnTargetBrowse.width           = 75
$btnTargetBrowse.height          = 24
$btnTargetBrowse.location        = New-Object System.Drawing.Point($browseX,405)
$btnTargetBrowse.Font            = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$btnTargetBrowse.Add_Click({$targetfile = Select-FileDialog
                            IF($targetfile -ne ""){$tbTargetSQLFile.text = $targetfile}
                            })

#COLUMNS INPUT
$lblColumns                      = New-Object system.Windows.Forms.Label
$lblColumns.text                 = "Columns to Compare"
$lblColumns.AutoSize             = $true
$lblColumns.width                = 25
$lblColumns.height               = 10
$lblColumns.location             = New-Object System.Drawing.Point(450,25)
$lblColumns.Font                 = [System.Drawing.Font]::new('Microsoft Sans Serif', 12, [System.Drawing.FontStyle]::Bold)

$tbColumns                       = New-Object system.Windows.Forms.TextBox
$tbColumns.multiline             = $true
$tbColumns.width                 = 325
$tbColumns.height                = 380
$tbColumns.location              = New-Object System.Drawing.Point(450,50)
$tbColumns.Font                  = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbColumns.Scrollbars            = "Vertical"
$tbColumns.add_TextChanged({validateTextBoxes})

#STATUS
$lblStatus                       = New-Object system.Windows.Forms.Label
$lblStatus.text                  = "Status"
$lblStatus.AutoSize              = $true
$lblStatus.width                 = 25
$lblStatus.height                = 10
$lblStatus.location              = New-Object System.Drawing.Point(10,474)
$lblStatus.Font                  = [System.Drawing.Font]::new('Microsoft Sans Serif', 12, [System.Drawing.FontStyle]::Bold)

$tbStatus                        = New-Object system.Windows.Forms.TextBox
$tbStatus.multiline              = $true
$tbStatus.width                  = 765
$tbStatus.height                 = 50
$tbStatus.location               = New-Object System.Drawing.Point(10,500)
$tbStatus.Font                   = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Regular)
$tbStatus.ReadOnly               = $true
$tbStatus.Scrollbars             = "Vertical"

#START
$btnStart                        = New-Object system.Windows.Forms.Button
$btnStart.text                   = "START"
$btnStart.width                  = 120
$btnStart.height                 = 24
$btnStart.location               = New-Object System.Drawing.Point(10,440)
$btnStart.Font                   = [System.Drawing.Font]::new('Microsoft Sans Serif', 10, [System.Drawing.FontStyle]::Bold)
$btnStart.Enabled                = $false
$btnStart.Add_Click({   $btnStart.Enabled = $false 
                        $tbStatus.Text = ""
                        recExecution
                    })



$Form.controls.AddRange(@(
        $tbSourceSQLFile
        ,$btnSourceBrowse
        ,$tbStatus
        ,$lblSourceSettings
        ,$tbColumns
        ,$lblSourceSQLFile
        ,$lblServer
        ,$tbServer
        ,$lblSourceDatabase
        ,$tbSourceDatabase
        ,$lblSourceTableName
        ,$tbSourceTableName
        ,$lblREHeader
        ,$lblREDatabase
        ,$tbREDatabase
        ,$lblRESchema
        ,$tbRESchema
        ,$lblREName
        ,$tbREName
        ,$lblSourcePK
        ,$tbSourcePK
        ,$tbTargetSQLFile
        ,$btnTargetBrowse
        ,$lblTargetSetting
        ,$lblTargetSQLFile
        ,$lblTargetDatabase
        ,$tbTargetDatabase
        ,$lblTargetTableName
        ,$tbTargetTableName
        ,$lblTargetPK
        ,$tbTargetPK
        ,$lblColumns
        ,$lblStatus
        ,$btnStart))

        
[void]$Form.ShowDialog()