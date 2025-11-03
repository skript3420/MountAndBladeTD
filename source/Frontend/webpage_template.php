<?php
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
$id_col = "[DB_ID_FIELD_NAME]";
$gold_col = "[DB_GOLD_FIELD_NAME]";

// Error handling: Ensure minimal GET parameters are present
if (!isset($_GET[$event_var]) || !isset($_GET[$id_col])) {
    die("Error: Missing parameters.");
}

// Retrieve parameters
$event = $_GET[$event_var];
$user_id = $_GET[$id_col];

// --- Database Connection ---
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Prevent SQL Injection
$user_id_safe = $conn->real_escape_string($user_id);

// --- Event Processing ---

if ($event == $event_get) {
    // EVENT: RETRIEVE DATA (GET)
    $sql = "SELECT $gold_col FROM $db_table WHERE $id_col = '$user_id_safe' LIMIT 1";
    $result = $conn->query($sql);

    $gold_value = "0";

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $gold_value = $row[$gold_col];
    }
    
    // Response Format for Warband: key=value
    echo "$id_col=" . $user_id_safe . "\n";
    echo "$gold_col=" . $gold_value;


} elseif ($event == $event_set) {
    // EVENT: SAVE DATA (SET)
    if (isset($_GET[$gold_col])) {
        $gold = $_GET[$gold_col];
        
        // Input Validation: Must be a non-negative integer
        if (!ctype_digit($gold)) {
            die("Error: Invalid gold value. Must be a non-negative integer.");
        }
        
        // Prevent SQL Injection
        $gold_safe = $conn->real_escape_string($gold);

        // UPSERT logic: Insert or Update
        $sql = "INSERT INTO $db_table ($id_col, $gold_col) VALUES ('$user_id_safe', '$gold_safe')
                ON DUPLICATE KEY UPDATE $gold_col = '$gold_safe'";

        if ($conn->query($sql) === TRUE) {
            // Confirmation response: key=value
            echo "$id_col=" . $user_id_safe . "\n";
            echo "$gold_col=" . $gold_safe;
        } else {
            echo "Error: " . $conn->error;
        }
    } else {
        echo "Error: Missing gold parameter for SET event.";
    }
} else {
    echo "Error: Invalid event type.";
}

$conn->close();
?>