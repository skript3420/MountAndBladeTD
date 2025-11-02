<#
.DESCRIPTION
    This script performs the following actions:
    1. Checks if all required files are present.
    2. Reads the database settings (DB_ variables) and register settings (VAR_ variables)
        from "databaseSettings.txt".
    3. Creates a backup of "module_scripts.py".
    4. Modifies "module_scripts.py" by finding the #<DATABASE_FUNCTIONS_START/END>
        markers and replacing the URLs inside the save_player_gold and
        load_player_gold definitions using the loaded settings.
    5. Creates "webpage.php" from "webpage_template.php" and saves it in the $BuildDir.
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
Write-Host ""

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
Write-Host ""


# === 3. PARSE SETTINGS ===
Write-Host "Loading settings from $SettingsFile..."
try {
    # Get all lines that start with "DB_" or "VAR_" and process them
    Get-Content -Path $SettingsFile | Where-Object { $_ -match "^(DB_|VAR_)" } | ForEach-Object {
        # Split the line at the '=' sign
        $key, $value = $_ -Split '=', 2
        $key = $key.Trim()
        $value = $value.Trim()
        
        # Dynamically create a variable in the script scope
        New-Variable -Name $key -Value $value -Scope Script
        Write-Host "Variable $key set to $value"
    }
} catch {
    Exit-Script "ERROR reading or parsing $SettingsFile : `n$($_.Exception.Message)"
}
Write-Host ""

# === 4. CREATE BACKUP ===
Write-Host "Creating backup: $ModuleScriptBackup..."
try {
    Copy-Item -Path $ModuleScriptIn -Destination $ModuleScriptBackup -Force
    Write-Host "Backup created successfully."
} catch {
    Exit-Script "ERROR: Could not create backup $ModuleScriptBackup. Aborting.`n$($_.Exception.Message)"
}
Write-Host ""

# === 5. MODIFY module_scripts.py (Robust Method) ===
Write-Host "Modifying $ModuleScriptIn using bounded markers..."
try {
    $content = Get-Content -Path $ModuleScriptIn -Raw
    
    # Define your markers
    $startMarker = "#<DATABASE_FUNCTIONS_START>"
    $endMarker = "#<DATABASE_FUNCTIONS_END>"

    # Extract the block
    $regex = "(?ms)($startMarker)([\s\S]*?)($endMarker)"
    
    if ($content -match $regex) {
        $preBlock = $matches[1]  # Retains the start marker
        $dbBlock = $matches[2]   # The content to be changed
        $postBlock = $matches[3] # Retains the end marker

        Write-Host "Database block found. Applying replacements..."

        # --- Perform your replacements ONLY on the $dbBlock ---

        # --- save_player_gold (Uses DB_EVENT_SET) ---
        # This regex finds the *entire* URL string for send_message_to_url
        # inside the save_player_gold script.
        $saveRegex = '((?s)\("save_player_gold",.*?send_message_to_url, "@)(.*?)("\))'
        
        # Build the new URL string from variables (now including $VAR_ID and $VAR_GOLD)
        $saveURL = "$($DB_URL_ADDRESS)?$($DB_ID)=$($VAR_ID)&$($DB_GOLD)=$($VAR_GOLD)&$($DB_EVENT)=$($DB_EVENT_SET)"
        
        $dbBlock = $dbBlock -creplace $saveRegex, ('$1' + $saveURL + '$3')
        Write-Host "save_player_gold (URL) replaced with: $saveURL"


        # --- load_player_gold (Uses DB_EVENT_GET) ---
        # This regex finds the *entire* URL string for send_message_to_url
        # inside the load_player_gold script.
        $loadRegex = '((?s)\("load_player_gold",.*?send_message_to_url, "@)(.*?)("\))'
        
        # Build the new URL string from variables (now including $VAR_ID)
        $loadURL = "$($DB_URL_ADDRESS)?$($DB_ID)=$($VAR_ID)&$($DB_EVENT)=$($DB_EVENT_GET)"
        
        $dbBlock = $dbBlock -creplace $loadRegex, ('$1' + $loadURL + '$3')
        Write-Host "load_player_gold (URL) replaced with: $loadURL"

        
        # Reassemble the entire content
        $newContent = $content -creplace $regex, ($preBlock + $dbBlock + $postBlock)

        # Save the file
        Set-Content -Path $ModuleScriptIn -Value $newContent -Encoding Ascii -NoNewline
        Write-Host "Successfully patched $ModuleScriptIn."
        
    } else {
        # This error occurs if the markers were not found in module_scripts.py
        Exit-Script "ERROR: Could not find markers '$startMarker' and '$endMarker' in $ModuleScriptIn. No changes made. Please add the markers to your Python file."
    }
} catch {
    Exit-Script "ERROR modifying $ModuleScriptIn.`n$($_.Exception.Message)"
}
Write-Host ""

# === 6. EDIT PHP FILE ===
Write-Host "Replacing placeholders in $PhpTemplateIn and creating $PhpOut..."
try {
    # Read the template as *one* single text block
    $phpContent = Get-Content -Path $PhpTemplateIn -Raw

    # Perform all replacements sequentially in memory
    # Note: -creplace is case-sensitive
    $phpContent = $phpContent -creplace '\[DB_HOST\]', $DB_HOST
    $phpContent = $phpContent -creplace '\[DB_USER\]', $DB_USER
    $phpContent = $phpContent -creplace '\[DB_PASS\]', $DB_PASS
    $phpContent = $phpContent -creplace '\[DB_NAME\]', $DB_NAME
    $phpContent = $phpContent -creplace '\[DB_TABLE\]', $DB_TABLE
    $phpContent = $phpContent -creplace '\[DB_EVENT_VAR\]', $DB_EVENT
    $phpContent = $phpContent -creplace '\[DB_EVENT_GET_VAL\]', $DB_EVENT_GET
    $phpContent = $phpContent -creplace '\[DB_EVENT_SET_VAL\]', $DB_EVENT_SET
    $phpContent = $phpContent -creplace '\[DB_ID_COL\]', $DB_ID
    $phpContent = $phpContent -creplace '\[DB_GOLD_COL\]', $DB_GOLD

    # Write the destination file *once*
    Set-Content -Path $PhpOut -Value $phpContent -Encoding Default
    
    Write-Host "$PhpOut created successfully."

} catch {
    Exit-Script "ERROR while creating $PhpOut.`n$($_.Exception.Message)"
}
Write-Host ""

# === 7. COMPLETION ===
Write-Host "Done! $ModuleScriptIn and $PhpOut have been created/updated."
Write-Host "Press Enter to exit."
$null = Read-Host