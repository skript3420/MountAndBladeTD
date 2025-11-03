<#
.DESCRIPTION
    This script performs the following actions:
    1. Checks if all required files are present.
    2. Reads all database (DB_) and variable (VAR_) settings
        from "databaseSettings.txt" into a dynamic hashtable.
    3. Creates a backup of "module_scripts.py".
    4. Modifies "module_scripts.py" within the #<DATABASE_FUNCTIONS_START/END> block
        by finding lines with *both* a function (e.g., (assign, ) and a marker (e.g., #<MARKER>)
        and rebuilding those lines using dynamic values from the settings file.
        This version fixes the "True" output to the console.
    5. Creates "webpage.php" from "webpage_template.php" by dynamically replacing
        all found [KEY] placeholders and saves it in the $BuildDir.
#>

# Stop the script on terminating errors
$ErrorActionPreference = 'Stop'

# === HELPER FUNCTION FOR ERRORS ===
function Exit-Script($errorMessage) {
    Write-Error $errorMessage
    Write-Host "Press Enter to exit."
    $null = Read-Host
    exit 1
}

# === 1. FILENAMES AND PATHS ===
$ModuleDir          = "..\Module_system 1.171"
$ModuleScriptIn     = "$ModuleDir\module_scripts.py"
$ModuleScriptBackup = "$ModuleDir\module_scripts_old.py"
$PhpTemplateIn      = "webpage_template.php"

$BuildDir           = "..\..\build"
$PhpOut             = "$BuildDir\webpage.php"

$SettingsFile       = "databaseSettings.txt"

# === 2. PRE-FLIGHT CHECKS ===
Write-Host "Checking for required files..."

if (-not (Test-Path -Path $ModuleScriptIn -PathType Leaf)) {
    Exit-Script "ERROR: Could not find module_scripts.py at the expected location: `n$ModuleScriptIn `n`nPlease make sure this .ps1 file is placed in the correct directory. `nAborting."
}
if (-not (Test-Path -Path $SettingsFile -PathType Leaf)) {
    Exit-Script "ERROR: Could not find $SettingsFile. Aborting."
}
if (-not (Test-Path -Path $PhpTemplateIn -PathType Leaf)) {
    Exit-Script "ERROR: Could not find $PhpTemplateIn. Aborting."
}

Write-Host "All required files found."

# === 2.5. ENSURE BUILD DIRECTORY EXISTS ===
Write-Host "Checking for build directory: $BuildDir..."
if (-not (Test-Path -Path $BuildDir -PathType Container)) {
    Write-Host "Build directory not found. Creating $BuildDir..."
    try {
        New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null
        Write-Host "Build directory created successfully."
    } catch {
        Exit-Script "ERROR: Could not create build directory $BuildDir. Aborting.`n$($_.Exception.Message)"
    }
} else {
    Write-Host "Build directory found."
}


# === 3. PARSE SETTINGS ===
Write-Host "Loading settings from $SettingsFile..."
$Settings = @{} # Create a hashtable to store all settings
try {
    Get-Content -Path $SettingsFile | Where-Object { $_ -match "^(DB_|VAR_)" } | ForEach-Object {
        $key, $value = $_ -Split '=', 2
        $key = $key.Trim()
        $value = $value.Trim()
        
        if (-not [string]::IsNullOrEmpty($key)) {
            $Settings[$key] = $value
            #Write-Host "  Loaded: $key = $value"
        }
    }
} catch {
    Exit-Script "ERROR reading or parsing $SettingsFile : `n$($_.Exception.Message)"
}
Write-Host "Settings loaded successfully."

# === 4. CREATE BACKUP ===
Write-Host "Creating backup: $ModuleScriptBackup..."
try {
    Copy-Item -Path $ModuleScriptIn -Destination $ModuleScriptBackup -Force | Out-Null
    Write-Host "Backup created successfully."
} catch {
    Exit-Script "ERROR: Could not create backup $ModuleScriptBackup. Aborting.`n$($_.Exception.Message)"
}

# === 5. MODIFY module_scripts.py (Precise Line-by-Line Rebuild) ===
Write-Host "Modifying $ModuleScriptIn..."
try {
    $content = Get-Content -Path $ModuleScriptIn -Raw

    # Define markers
    $startMarker = "#<DATABASE_FUNCTIONS_START>"
    $endMarker = "#<DATABASE_FUNCTIONS_END>"

    # Extract the block
    $regex = "(?ms)($startMarker)([\s\S]*?)($endMarker)"
    if ($content -match $regex) {
        $preBlock = $matches[1] # Start marker
        $dbBlock = $matches[2]  # Content to change
        $postBlock = $matches[3] # End marker

        # --- 1. Build URLs from Settings ---
        $idRegUrl = "{$($Settings['VAR_ID_REG'])}"
        $goldRegUrl = "{$($Settings['VAR_GOLD_REG'])}"

        $loadURL = "$($Settings['DB_URL_ADDRESS'])?$($Settings['DB_ID_FIELD_NAME'])=$idRegUrl&$($Settings['VAR_EVENT_PARAM_NAME'])=$($Settings['VAR_EVENT_GET'])"
        $saveURL = "$($Settings['DB_URL_ADDRESS'])?$($Settings['DB_ID_FIELD_NAME'])=$idRegUrl&$($Settings['DB_GOLD_FIELD_NAME'])=$goldRegUrl&$($Settings['VAR_EVENT_PARAM_NAME'])=$($Settings['VAR_EVENT_SET'])"
        
        Write-Host "  Built Load URL: $loadURL"
        Write-Host "  Built Save URL: $saveURL"

        # --- 2. Add ":[variable]" to variables from Settings ---
        $pyEventVar = '":' + $Settings['VAR_EVENT_PARAM_NAME'] + '"'
        $pyGoldVar  = '":' + $Settings['DB_GOLD_FIELD_NAME'] + '"'
        $pyIdVar    = '":' + $Settings['DB_ID_FIELD_NAME'] + '"'

        # --- 3. Process the block line by line ---
        $newDbBlockLinesList = [System.Collections.ArrayList]@()
        
        ($dbBlock -split "\r?\n") | ForEach-Object {
            $line = $_
            
            $null = $line -match '^(\s*)'
            $indent = $matches[1]

            $newLine = $line # Default to original line

            if ($line -match "\s\(send_message_to_url," -and $line -match "#<URL_GET_MARKER>") {
                $newLine = "$indent(send_message_to_url, ""@$loadURL""), #<URL_GET_MARKER>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(send_message_to_url," -and $line -match "#<URL_SET_MARKER>") {
                $newLine = "$indent(send_message_to_url, ""@$saveURL""), #<URL_SET_MARKER>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(assign," -and $line -match "#<VAR_EVENT_REG>") {
                $newLine = "$indent(assign, $pyEventVar, $($Settings['VAR_EVENT_REG'])), #<VAR_EVENT_REG>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(assign," -and $line -match "#<VAR_ID_REG>") {
                $newLine = "$indent(assign, $pyIdVar, $($Settings['VAR_ID_REG'])), #<VAR_ID_REG>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(assign," -and $line -match "#<VAR_GOLD_REG>") {
                $newLine = "$indent(assign, $pyGoldVar, $($Settings['VAR_GOLD_REG'])), #<VAR_GOLD_REG>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(eq," -and $line -match "#<FAIL_EVENT_NO>") {
                $newLine = "$indent(eq, $pyEventVar, $($Settings['VAR_EVENT_FAIL'])), #<FAIL_EVENT_NO>"
                Write-Host "  Rebuilt: $newline"
            } elseif ($line -match "\s\(eq," -and $line -match "#<SUCCESS_EVENT_NO>") {
                $newLine = "$indent(eq, $pyEventVar, $($Settings['VAR_EVENT_SUCCESS'])), #<SUCCESS_EVENT_NO>"
                Write-Host "  Rebuilt: $newline"
            }
            
            $null = $newDbBlockLinesList.Add($newLine)
        }

        # Join lines using `n (LF) to prevent \r\n (CRLF) issues
        $newDbBlock = $newDbBlockLinesList -join "`n"

        # Reassemble the full file content
        $newContent = $content -replace [regex]::Escape($dbBlock), $newDbBlock
        
        Set-Content -Path $ModuleScriptIn -Value $newContent -Encoding 'Default'
        Write-Host "Successfully modified $ModuleScriptIn."

    } else {
        Write-Warning "Could not find start/end markers '$startMarker' and '$endMarker' in $ModuleScriptIn. No changes made. Please add the markers to your Python file."
    }
} catch {
    Exit-Script "ERROR modifying $ModuleScriptIn.`n$($_.Exception.Message)"
}


# === 6. EDIT PHP FILE (Dynamic Method) ===
Write-Host "Replacing placeholders in $PhpTemplateIn and creating $PhpOut..."
try {
    $phpContent = Get-Content -Path $PhpTemplateIn -Raw

    foreach ($key in $Settings.Keys) {
        $value = $Settings[$key]
        $placeholder = "\[" + [regex]::Escape($key) + "\]"
        
        if ($phpContent -match $placeholder) {
            $phpContent = $phpContent -creplace $placeholder, $value
        }
    }

    Set-Content -Path $PhpOut -Value $phpContent -Encoding UTF8
    Write-Host "Successfully created $PhpOut."
} catch {
    Exit-Script "ERROR processing $PhpTemplateIn or creating $PhpOut.`n$($_.Exception.Message)"
}

# === 7. FINAL PROMPT ===
Write-Host "-------------------------------------"
Write-Host "Settings successfully loaded."
Write-Host " - $ModuleScriptIn has been modified."
Write-Host " - $PhpOut has been created/updated in $BuildDir."
Write-Host "-------------------------------------"
Write-Host "Press Enter to exit."
$null = Read-Host