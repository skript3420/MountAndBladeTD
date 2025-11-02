<?php
// ### DATABASE SETTINGS (OVERWRITTEN BY Load_Settings.ps1) ###
$db_host = "localhost";
$db_user = "root";
$db_pass = "your_password";
$db_name = "warband_database";
$db_table = "players";

// ### VARIABLE SETTINGS (OVERWRITTEN BY Load_Settings.ps1) ###
$event_var = "event";
$event_get = "1";
$event_set = "2";
$id_col = "user_id";
$gold_col = "gold";

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

// Prevent SQL Injection (VERY IMPORTANT!)
$user_id_safe = $conn->real_escape_string($user_id);

// --- Event Processing ---

if ($event == $event_get) {
    // EVENT: RETRIEVE DATA (GET)
    $sql = "SELECT $gold_col FROM $db_table WHERE $id_col = '$user_id_safe' LIMIT 1";
    $result = $conn->query($sql);

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo $row[$gold_col]; // Return only the gold value as a string
    } else {
        // Player not found. 
        // Optional: Create new player with 0 gold.
        // For now, we return 0, as the player might not exist yet.
        echo "0"; 
    }

} elseif ($event == $event_set) {
    // EVENT: SAVE DATA (SET)
    if (isset($_GET[$gold_col])) {
        $gold = $_GET[$gold_col];
        
        // Prevent SQL Injection
        $gold_safe = $conn->real_escape_string($gold);

        // Check if the user exists, otherwise insert (UPSERT logic)
        // This ensures the player is created if they don't exist,
        // or updated if they do exist.
        $sql = "INSERT INTO $db_table ($id_col, $gold_col) VALUES ('$user_id_safe', '$gold_safe')
                ON DUPLICATE KEY UPDATE $gold_col = '$gold_safe'";

        if ($conn->query($sql) === TRUE) {
            echo "Success"; // Confirmation to Warband (optional)
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
