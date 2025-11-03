<?php
// Safe functions to comply with Warband encoding UTF-8 without BOM
function safe_echo($output_string) {
    // Force the string to be UTF-8
    $utf8_string = mb_convert_encoding($output_string, 'UTF-8', 'auto');
    
    // Remove the UTF-8 BOM (hex: EF BB BF) from the beginning of the string
    $cleaned_string = preg_replace('/^\x{EF}\x{BB}\x{BF}/', '', $utf8_string);
    
    echo $cleaned_string;
}

function safe_die($output_string) {
    safe_echo($output_string); // Use our new clean function
    exit(); // Stop the script
}


// ### DATABASE SETTINGS (OVERWRITTEN BY Load_Settings.ps1) ###
$db_host = "[DB_HOST]";
$db_user = "[DB_USER]";
$db_pass = "[DB_PASS]";
$db_name = "[DB_NAME]";
$db_table = "[DB_TABLE]";

// ### VARIABLE SETTINGS (OVERWRITTEN BY Load_Settings.ps1) ###
$event_var = "[VAR_EVENT_PARAM_NAME]";
$event_get = "[VAR_EVENT_GET]";
$event_set = "[VAR_EVENT_SET]";
$event_fail = "[VAR_EVENT_FAIL]";
$event_success = "[VAR_EVENT_SUCCESS]";
$id_col = "[DB_ID_FIELD_NAME]";
$gold_col = "[DB_GOLD_FIELD_NAME]";

// Error handling: Ensure minimal GET parameters are present
if (!isset($_GET[$event_var]) || !isset($_GET[$id_col])) {
    safe_die("$event_fail|0|0"); // USE SAFE_DIE
}

// Retrieve parameters
$event = $_GET[$event_var];
$user_id = $_GET[$id_col];

// --- Database Connection ---
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    safe_die("$event_fail|0|0"); // USE SAFE_DIE
}

// Prevent SQL Injection
$user_id_safe = $conn->real_escape_string($user_id);

// --- Event Processing ---
if ($event == $event_get) {
    // EVENT: RETRIEVE DATA (GET)
    $sql = "SELECT $gold_col FROM $db_table WHERE $id_col = '$user_id_safe' LIMIT 1";
    try {
        $result = $conn->query($sql);
    } catch (Exception $e) {
        safe_die("$event_fail|0|0"); // USE SAFE_DIE
    }
    $result = $conn->query($sql);
    
    $gold_value = "0"; // Default gold value
    
    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $gold_value = $row[$gold_col];
        // Prevent SQL Injection
        safe_echo("$event_success|$user_id_safe|$gold_value"); // USE SAFE_ECHO
    }

    else{
        try{
             $sql = "INSERT INTO $db_table ($id_col, $gold_col) VALUES ('$user_id_safe', '$gold_value')
                ON DUPLICATE KEY UPDATE $gold_col = '$gold_value'";

            if ($conn->query($sql) === TRUE) {
                // Confirmation response: key=value
                safe_echo("$event_success|$user_id_safe|$gold_value"); // USE SAFE_ECHO
            } else {
                safe_die("$event_fail|0|0"); // USE SAFE_DIE
            }
        } catch (Exception $e) {
            safe_die("$event_fail|0|0"); // USE SAFE_DIE
        }
    }

} elseif ($event == $event_set) {
    // EVENT: SAVE DATA (SET)
    if (isset($_GET[$gold_col])) {
        $gold_value = $_GET[$gold_col];
        
        // Input Validation: Must be a non-negative integer
        if (!ctype_digit($gold_value)) {
            safe_die("$event_fail|0|0"); // USE SAFE_DIE
        }
        // Prevent SQL Injection
        $gold_safe = $conn->real_escape_string($gold_value);
        // UPSERT logic: Insert or Update
        $sql = "INSERT INTO $db_table ($id_col, $gold_col) VALUES ('$user_id_safe', '$gold_safe')
                ON DUPLICATE KEY UPDATE $gold_col = '$gold_safe'";
        
        try {
            if ($conn->query($sql) === TRUE) {
                // Confirmation response: key=value
                safe_echo("$event_success|$user_id_safe|$gold_safe"); // USE SAFE_ECHO
            } else {
                safe_die("$event_fail|0|0"); // USE SAFE_DIE
            }
        } catch (Exception $e) {
            safe_die("$event_fail|0|0"); // USE SAFE_DIE
        }
        
    } else {
        safe_die("$event_fail|0|0"); // USE SAFE_DIE
    }
    
} else {
    safe_die("$event_fail|0|0"); // USE SAFE_DIE
}

$conn->close();
?>