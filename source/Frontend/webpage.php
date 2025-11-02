<?php
// ### DATENBANK-EINSTELLUNGEN (WIRD DURCH .BAT ERSETZT) ###
$db_host = "localhost";
$db_user = "root";
$db_pass = "your_password";
$db_name = "warband_database";
$db_table = "players";

// ### VARIABLEN-EINSTELLUNGEN (WIRD DURCH .BAT ERSETZT) ###
$event_var = "event";
$event_get = "1";
$event_set = "2";
$id_col = "user_id";
$gold_col = "gold";

// Fehlerbehandlung: Sicherstellen, dass die minimalen GET-Parameter vorhanden sind
if (!isset($_GET[$event_var]) || !isset($_GET[$id_col])) {
    die("Error: Missing parameters.");
}

// Parameter abrufen
$event = $_GET[$event_var];
$user_id = $_GET[$id_col];

// --- Datenbankverbindung ---
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// SQL-Injection verhindern (SEHR WICHTIG!)
$user_id_safe = $conn->real_escape_string($user_id);

// --- Event-Verarbeitung ---

if ($event == $event_get) {
    // EVENT: DATEN ABRUFEN (GET)
    $sql = "SELECT $gold_col FROM $db_table WHERE $id_col = '$user_id_safe' LIMIT 1";
    $result = $conn->query($sql);

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo $row[$gold_col]; // Nur den Goldwert als String zurückgeben
    } else {
        // Spieler nicht gefunden. 
        // Optional: Neuen Spieler mit 0 Gold erstellen.
        // Vorerst geben wir 0 zurück, da der Spieler vielleicht noch nicht existiert.
        echo "0"; 
    }

} elseif ($event == $event_set) {
    // EVENT: DATEN SPEICHERN (SET)
    if (isset($_GET[$gold_col])) {
        $gold = $_GET[$gold_col];
        
        // SQL-Injection verhindern
        $gold_safe = $conn->real_escape_string($gold);

        // Überprüfen, ob der Benutzer existiert, sonst einfügen (UPSERT-Logik)
        // Dies stellt sicher, dass der Spieler erstellt wird, falls er nicht existiert,
        // oder aktualisiert wird, falls er existiert.
        $sql = "INSERT INTO $db_table ($id_col, $gold_col) VALUES ('$user_id_safe', '$gold_safe')
                ON DUPLICATE KEY UPDATE $gold_col = '$gold_safe'";

        if ($conn->query($sql) === TRUE) {
            echo "Success"; // Bestätigung an Warband (optional)
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
