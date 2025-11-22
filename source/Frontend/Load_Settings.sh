#!/bin/bash

# Description: Linux port of Load_Settings.ps1
# Stops script on error
set -e

# === HELPER FUNCTION FOR ERRORS ===
exit_script() {
    echo "ERROR: $1"
    echo "Press Enter to exit."
    read -r
    exit 1
}

# === 1. FILENAMES AND PATHS ===
ModuleDir="../Module_system 1.171"
ModuleScriptIn="$ModuleDir/module_scripts.py"
ModuleScriptBackup="$ModuleDir/module_scripts_old.py"
PhpTemplateIn="webpage_template.php"

BuildDir="../../build"
PhpOut="$BuildDir/webpage.php"

SettingsFile="databaseSettings.txt"

# === 2. PRE-FLIGHT CHECKS ===
echo "Checking for required files..."

if [ ! -f "$ModuleScriptIn" ]; then
    exit_script "Could not find module_scripts.py at: $ModuleScriptIn"
fi
if [ ! -f "$SettingsFile" ]; then
    exit_script "Could not find $SettingsFile."
fi
if [ ! -f "$PhpTemplateIn" ]; then
    exit_script "Could not find $PhpTemplateIn."
fi

echo "All required files found."

# === 2.5. ENSURE BUILD DIRECTORY EXISTS ===
echo "Checking for build directory: $BuildDir..."
if [ ! -d "$BuildDir" ]; then
    echo "Build directory not found. Creating $BuildDir..."
    mkdir -p "$BuildDir" || exit_script "Could not create build directory."
    echo "Build directory created successfully."
else
    echo "Build directory found."
fi

# === 3. PARSE SETTINGS ===
echo "Loading settings from $SettingsFile..."
declare -A Settings

# Read file line by line, look for DB_ or VAR_, split by =, trim whitespace
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Trim leading/trailing whitespace (and Windows \r)
    key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r//g')

    if [[ $key == DB_* ]] || [[ $key == VAR_* ]]; then
        if [ -n "$key" ]; then
            Settings["$key"]="$value"
        fi
    fi
done < "$SettingsFile"

echo "Settings loaded successfully."

# === 4. CREATE BACKUP ===
echo "Creating backup: $ModuleScriptBackup..."
cp -f "$ModuleScriptIn" "$ModuleScriptBackup" || exit_script "Could not create backup."
echo "Backup created successfully."

# === 5. MODIFY module_scripts.py ===
echo "Modifying $ModuleScriptIn..."

# Prepare Variables for logic
idRegUrl="{${Settings[VAR_ID_REG]}}"
goldRegUrl="{${Settings[VAR_GOLD_REG]}}"

loadURL="${Settings[DB_URL_ADDRESS]}?${Settings[DB_ID_FIELD_NAME]}=$idRegUrl&${Settings[VAR_EVENT_PARAM_NAME]}=${Settings[VAR_EVENT_GET]}"
saveURL="${Settings[DB_URL_ADDRESS]}?${Settings[DB_ID_FIELD_NAME]}=$idRegUrl&${Settings[DB_GOLD_FIELD_NAME]}=$goldRegUrl&${Settings[VAR_EVENT_PARAM_NAME]}=${Settings[VAR_EVENT_SET]}"

echo "  Built Load URL: $loadURL"
echo "  Built Save URL: $saveURL"

# Prepare Python variables (escaped quotes)
pyEventVar="\":${Settings[VAR_EVENT_PARAM_NAME]}\""
pyGoldVar="\":${Settings[DB_GOLD_FIELD_NAME]}\""
pyIdVar="\":${Settings[DB_ID_FIELD_NAME]}\""

# Use sed to replace lines ONLY within the DATABASE_FUNCTIONS block
# We use | as a delimiter because URLs contain /
sed -i "/#<DATABASE_FUNCTIONS_START>/,/#<DATABASE_FUNCTIONS_END>/ {
    /#<URL_GET_MARKER>/ s|^\([[:space:]]*\).*|\1(send_message_to_url, \"@$loadURL\"), #<URL_GET_MARKER>|
    /#<URL_SET_MARKER>/ s|^\([[:space:]]*\).*|\1(send_message_to_url, \"@$saveURL\"), #<URL_SET_MARKER>|
    /#<VAR_EVENT_REG>/  s|^\([[:space:]]*\).*|\1(assign, $pyEventVar, ${Settings[VAR_EVENT_REG]}), #<VAR_EVENT_REG>|
    /#<VAR_ID_REG>/     s|^\([[:space:]]*\).*|\1(assign, $pyIdVar, ${Settings[VAR_ID_REG]}), #<VAR_ID_REG>|
    /#<VAR_GOLD_REG>/   s|^\([[:space:]]*\).*|\1(assign, $pyGoldVar, ${Settings[VAR_GOLD_REG]}), #<VAR_GOLD_REG>|
    /#<FAIL_EVENT_NO>/  s|^\([[:space:]]*\).*|\1(eq, $pyEventVar, ${Settings[VAR_EVENT_FAIL]}), #<FAIL_EVENT_NO>|
    /#<SUCCESS_EVENT_NO>/ s|^\([[:space:]]*\).*|\1(eq, $pyEventVar, ${Settings[VAR_EVENT_SUCCESS]}), #<SUCCESS_EVENT_NO>|
}" "$ModuleScriptIn"

echo "Successfully modified $ModuleScriptIn."

# === 6. EDIT PHP FILE ===
echo "Replacing placeholders in $PhpTemplateIn and creating $PhpOut..."
cp "$PhpTemplateIn" "$PhpOut"

for key in "${!Settings[@]}"; do
    value="${Settings[$key]}"
    # Escape slashes in value for sed
    safeValue=$(echo "$value" | sed 's/\//\\\//g')
    # Replace [KEY] with VALUE globally
    sed -i "s/\[$key\]/$safeValue/g" "$PhpOut"
done

echo "Successfully created $PhpOut."

# === 7. FINISH ===
echo "-------------------------------------"
echo "Settings successfully loaded."
echo " - $ModuleScriptIn has been modified."
echo " - $PhpOut has been created/updated in $BuildDir."
echo "-------------------------------------"
echo "Press Enter to exit."
read -r