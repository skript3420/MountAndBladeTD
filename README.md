# Garrison Tower Defense (GTD) - Mount & Blade: Warband

[![Mount & Blade](https://img.shields.io/badge/Mount%20%26%20Blade-Warband-orange.svg)](https://www.taleworlds.com/)
[![Module System](https://img.shields.io/badge/Module%20System-1.171-green.svg)](https://forums.taleworlds.com/index.php?topic=118039.0)

> **A Native-compatible cooperative tower defense server modification for Mount & Blade: Warband**

Originally online under the name GothicTD Server, this is an INDEPENDET recreation of their multiplayer server.

---


## 🎮 Overview

**Gothic Tower Defense** is a multiplayer modification that converts Mount & Blade: Warband into a Invasion like cooperative PvE tower defense game. Players spawn as ranged troops and must work together to eliminate 20 waves of AI-controlled bots while defending King Harlaus.

The mod features:
- **Progressive difficulty** through 20 bot waves
- **Level-based progression** with equipment upgrades
- **Persistent player progress** via optional database integration
- **Custom map support** with teleportation doors and ammo refill stations
- **Native compatibility** - works with vanilla Warband installations

---

## 💾 Server Setup

### Building from Source / Database Setup

This section covers **two different approaches** depending on your needs:

#### Prerequisites

- **Python 2.7.x** installed and accessible via PATH environment variable
- **Mount & Blade: Warband** installation
- **PowerShell** (Windows) or Bash (Linux/macOS)
- **Optional**: MySQL/MariaDB and PHP 7.4+ (for persistent player data)

---

#### **Option A: Quick Start - Use Pre-Built Module** (No Building Required)

Choose this if you want to run the server immediately without modifying the module system.

**Setup Steps:**

1. **Download Release**
   - Pull the latest pre-built release from the repository
   - Extract to your desired location

2. **Enable Database Persistence**
   
   If you want persistent player progression, for Security Reasons a non-public DB setup, e.g. [AMP stack](https://docs.oracle.com/cd/E19253-01/817-6295/ggdfc/index.html), running on the same machine as the warband server is strongly recommended!

   a. **Set Up MySQL/MariaDB Database**
      ```sql
      CREATE DATABASE warband;
      USE warband;
      CREATE TABLE players (
          unique_id VARCHAR(255) PRIMARY KEY,
          gold INT DEFAULT 0
      );
      ```

   b. **Configure Web Server**
      - Ensure PHP 7.4+ is installed with MySQL/MariaDB extensions
      - Copy `build/webpage.php` to your web server directory (e.g., `C:\xampp\htdocs\`)
      - Edit the PHP file's database credentials if they differ from defaults:
        ```php
        $db_host = "localhost";
        $db_user = "root";
        $db_pass = "";  // Set your password
        $db_name = "warband";
        $db_table = "players";
        ```

   c. **Verify Database URL**
      - The pre-built module expects: `http://localhost/webpage.php`
      - If your URL differs, you'll need **Option B** to rebuild with custom settings

3. **Start the Server**
   - Navigate to `build/Mount&Blade Warband Dedicated/`
   - Run `GTD_start_server.bat`

---

#### **Option B: Build from Source** (For Modifications & Custom Database)

Choose this if you need to:
- Modify game mechanics or scripts
- Use custom database settings (non-localhost, different field names, etc.)
- Change the database URL endpoint
- Customize terrain, flora, or other module data

**Build Steps:**

1. **Clone the Repository**
   ```bash
   git clone https://github.com/skript3420/MountAndBladeTD.git
   cd MountAndBladeTD
   ```

2. **(Optional) Modify Game Mechanics**

   If you want to customize gameplay before building:

   a. **Basic Modifications** - Edit these files in `source/Module_system 1.171/`:
      - `module_constants.py` - Game constants, values, and settings
      - `module_troops.py` - Troop definitions, equipment, and stats

   b. **Advanced Modifications** - For deeper changes, also edit:
      - `module_mission_templates.py` - Mission logic, triggers, and events
      - `module_scripts.py` - Custom scripts and game logic functions

   c. **Learning Resources**
      - New to modding? Read [The Ultimate Introduction to Modding](https://forums.taleworlds.com/index.php?threads/the-ultimate-introduction-to-modding-starting-out-read-this.240255/)
      - TaleWorlds [Module System Documentation](https://forums.taleworlds.com/index.php?board=165.0)

3. **Configure Database Integration** (Optional but Recommended)

   a. **Set Up Your Database**
      ```sql
      CREATE DATABASE your_database_name;
      USE your_database_name;
      CREATE TABLE your_table_name (
          your_id_field VARCHAR(255) PRIMARY KEY,
          your_gold_field INT DEFAULT 0
      );
      ```

   b. **Edit Configuration File**
      - Open `source/Frontend/databaseSettings.txt`
      - Update with your custom values:
      ```ini
      # Database connection
      DB_HOST = localhost                    # Your database host
      DB_USER = root                         # Your database user
      DB_PASS = your_password                # Your database password
      DB_NAME = warband                      # Your database name
      DB_TABLE = players                     # Your table name
      
      # Database field names
      DB_ID_FIELD_NAME = unique_id           # Primary key field
      DB_GOLD_FIELD_NAME = gold              # Gold/score field
      
      # Web server URL
      DB_URL_ADDRESS = http://localhost/webpage.php   # Your PHP script URL
      ```

   c. **Run Configuration Script**
      ```powershell
      # Windows PowerShell
      cd source/Frontend
      .\Load_Settings.ps1
      ```
      ```bash
      # Linux/macOS (if bash version exists)
      cd source/Frontend
      ./Load_Settings.sh
      ```
      
      This script will:
      - Read your settings from `databaseSettings.txt`
      - Update `module_scripts.py` with database connection code
      - Generate a customized `webpage.php` file in `build/`

   d. **Deploy PHP Script**
      - Copy generated `build/webpage.php` to your web servers serving directory
      - Ensure it's accessible at the URL specified in `DB_URL_ADDRESS`
      - Test by visiting the URL (should show error without parameters)

3. **Build the Module System**
   ```bash
   cd source/Module_system 1.171
   build_module.bat              # Windows
   # or
   python build_module.py        # Linux/macOS
   ```
   This compiles all Python module files and exports to:
   `build/Mount&Blade Warband Dedicated/Modules/Native/`

4. **Build Flora/Terrain Data** (Only if Modified)
   ```bash
   cd source/Module_data 1.171
   python Flora_kinds.py
   python Ground_specs.py
   python Skyboxes.py
   ```
   Copy generated `.txt` files to `build/Mount&Blade Warband Dedicated/Data/`

5. **Deploy to Warband**
   - **Option 1**: Copy entire `build/Mount&Blade Warband Dedicated/` to your Warband installation
   - **Option 2**: Set `export_dir` in `source/Module_system 1.171/module_info.py` to point directly to your Warband directory, then rebuild

6. **Start the Server**
   - Navigate to your Warband dedicated server directory
   - Run `GTD_start_server.bat` (or use the command line)

---

#### **Quick Decision Guide**

| Scenario | Choose This Option |
|----------|-------------------|
| Just want to play/host quickly | **Option A** |
| Using default database settings (`localhost`, standard fields) | **Option A** |
| Need custom database host or credentials | **Option B** |
| Want to modify game mechanics, waves, or scripts | **Option B** |
| Developing custom features or maps | **Option B** |
| Remote database server | **Option B** |
| Different web server URL | **Option B** |

---

## 🗺️ Map Creation

Gothic Tower Defense supports custom maps with special requirements.

### Creating/Editing Maps

1. **Enable Edit Mode**
   - Launch Warband → Configure → Advanced → Enable Edit Mode
   - Start Custom Battle → Press `Ctrl+E` to open editor

2. **Required Elements**

   **Teleportation Doors:**
   - Place `door_destructible` scene props
   - Set matching **Variation ID (Var)** to link door pairs
   - Example: Door A (Var: 1) ↔ Door B (Var: 1)

   **Spawn Points:**
   - **Points 0-31**: Enemy bot spawns
   - **Point 32**: King Harlaus (surround with AI barriers!)
   - **Points 33-63**: Player spawns

   **Ammo Refill Chests:**
   - Place `chest_b` scene props for ammunition resupply

3. **Export Map**
   - Save scene as `multi_scene_1.sco` (or custom name)
   - Place in `Modules/Native/SceneObj/`
   - Update map name in server settings if not using default


---

### Database Configuration (`databaseSettings.txt`)

See [Database Setup](#database-setup-optional) section for full details.

---

## 🔧 Technical Details

### Module System Version
- **Version**: 1.171 (Mount & Blade: Warband)
- **Compatibility**: Native module (no additional mods required)
- **Enhancement**: WSE2 (Warband Script Enhancer 2) support

### Key Technical Features

**Database Communication:**
- Uses HTTP GET requests for data retrieval
- PHP backend for MySQL/MariaDB integration
- Warband Registers: `reg0` (event type), `reg1` (user ID), `reg2` (gold/score)
- UTF-8 encoding without BOM in HTTP responses for Warband compatibility
---

## 👏 Credits

- **Original Mod Creator**: Yberion (GothicTD Server)
- **Module System**: TaleWorlds Entertainment
- **WSE2 (Warband Script Enhancer 2)**: Version 4.8.4
  - **WSE2 Team**: cmpxchg8b, AgentSmith, and community
  - **Original WSE Team**: Xenoargh, Caba'drin, and the WSE community
- **Morgh's Editor**
- **Module System Documentation**: Lav

## 📜 License

This project !NOT including external Software! is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

### Warband Dedicated Server License

This modification is built upon Mount & Blade: Warband's dedicated server. Users must comply with [Taleworlds License for the Warband Dedicated server](https://www.taleworlds.com/en/Games/Warband)

### Disclaimer

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

This is a community-created modification and is not officially endorsed or supported by TaleWorlds Entertainment. Use at your own risk.

---

## 🔗 Links

- **Original Mod Forum**: [TaleWorlds Forums - Gothic Tower Defense](https://forums.taleworlds.com/index.php?threads/gothic_tower_defense.258896/)
- **Mount & Blade Official**: [TaleWorlds Website](https://www.taleworlds.com/)
- **Module System Documentation**: [TaleWorlds Modding Forums](https://forums.taleworlds.com/index.php?board=165.0)
- **WSE2**: [Warband Script Enhancer](https://forums.taleworlds.com/index.php?threads/warband-script-enhancer-2-v1-1-3-9.384882/)

---
