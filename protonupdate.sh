#!/usr/bin/env fish

# GitHub API token for Proton-TKG update (required for Syntist Proton-TKG)
set TOKEN "YOUR_TOKEN_HERE"

# === Update Selection Prompt ===
echo "Select an option:"
echo "1) Update both Syntist Proton-TKG and Proton-CachyOS"
echo "2) Update only Syntist Proton-TKG"
echo "3) Update only Proton-CachyOS"
echo "4) Update only Proton-GE"
echo "5) Update Syntist Proton-TKG, Proton-CachyOS, and Proton-GE"
echo -n "Enter your choice (1-5): "
read -l USER_INPUT

set INSTALL_TKG 0
set INSTALL_CACHY 0
set INSTALL_GE 0
switch $USER_INPUT
    case 1
        echo "Proceeding with Syntist Proton-TKG and Proton-CachyOS updates..."
        set INSTALL_TKG 1
        set INSTALL_CACHY 1
    case 2
        echo "Proceeding with only Syntist Proton-TKG update..."
        set INSTALL_TKG 1
    case 3
        echo "Proceeding with only Proton-CachyOS update..."
        set INSTALL_CACHY 1
    case 4
        echo "Proceeding with only Proton-GE update..."
        set INSTALL_GE 1
    case 5
        echo "Proceeding with Syntist Proton-TKG, Proton-CachyOS, and Proton-GE updates..."
        set INSTALL_TKG 1
        set INSTALL_CACHY 1
        set INSTALL_GE 1
    case '*'
        echo "Invalid input. Please enter 1, 2, 3, 4, or 5."
        exit 1
end

set TARGET_DIR "$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p $TARGET_DIR

# === Install Proton-TKG if selected ===
if test $INSTALL_TKG -eq 1
    set REPO "Syntist/proton-tkg-builder"
    set GITHUB_API "https://api.github.com/repos/$REPO/actions/runs"

    echo "Fetching the latest workflow runs for Syntist Proton-TKG..."
    set RUNS (curl -s -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        $GITHUB_API)

    if test (echo $RUNS | jq -r '.workflow_runs | length') -eq 0
        echo "No workflow runs found for Syntist Proton-TKG."
        exit 1
    end

    set LATEST_RUN (echo $RUNS | jq -r '.workflow_runs | map(select(.status == "completed" and .conclusion == "success")) | sort_by(.created_at) | last')

    if test -z "$LATEST_RUN"
        echo "No successful workflow runs found for Syntist Proton-TKG."
        exit 1
    end

    set RUN_ID (echo $LATEST_RUN | jq -r '.id')
    echo "Latest successful run ID for Syntist Proton-TKG: $RUN_ID"

    # Check existing installed Proton-TKG folder for embedded run ID
    set installed_folder (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*" | head -n 1)
    if test -z "$installed_folder"
        echo "No existing Proton-TKG installation found. Proceeding with update."
        set proceed_update 1
    else
        set folder_name (basename $installed_folder)
        # Extract run ID from folder name, expecting pattern like proton_tkg_10.5.r5_run12345
        set run_id_str (string match -r 'run[0-9]+' $folder_name)
        if test -z "$run_id_str"
            echo "Existing Proton-TKG folder does not contain run ID. Proceeding with update."
            set proceed_update 1
        else
            set local_run_id (string replace 'run' '' $run_id_str)
            if test $RUN_ID -le $local_run_id
                echo "Installed Proton-TKG is up to date (run ID $local_run_id). Skipping update."
                set proceed_update 0
            else
                echo "Newer Proton-TKG update detected (local run ID $local_run_id < latest run ID $RUN_ID). Proceeding with update."
                set proceed_update 1
            end
        end
    end

    if test $proceed_update -eq 1
        if test (echo $LATEST_RUN | jq -r '.conclusion') = "success"
            echo "Deleting old Proton-TKG folders..."
            set OLD_FOLDERS (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*")
            if test -n "$OLD_FOLDERS"
                rm -rf $OLD_FOLDERS
                echo "Old Proton-TKG folders deleted."
            else
                echo "No old Proton-TKG folders found."
            end
        else
            echo "Latest Proton-TKG build did not succeed. Aborting update."
            exit 1
        end

        set ARTIFACTS_URL "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/artifacts"
        echo "Fetching artifacts for run $RUN_ID..."
        set ARTIFACT_INFO (curl -s -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github+json" \
            $ARTIFACTS_URL)

        set ARTIFACT_URL (echo $ARTIFACT_INFO | jq -r '.artifacts[0].archive_download_url')
        set ARTIFACT_NAME (echo $ARTIFACT_INFO | jq -r '.artifacts[0].name')

        if test -z "$ARTIFACT_URL"
            echo "No artifacts found for this Proton-TKG run."
            exit 1
        end

        set ZIP_FILE "$TARGET_DIR/$ARTIFACT_NAME.zip"
        echo "Downloading Proton-TKG artifact to $ZIP_FILE..."
        curl -L -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github+json" \
            $ARTIFACT_URL -o $ZIP_FILE

        if test $status -ne 0
            echo "Failed to download Proton-TKG artifact."
            exit 1
        end

        echo "Extracting $ZIP_FILE..."
        unzip -q $ZIP_FILE -d $TARGET_DIR
        if test $status -ne 0
            echo "Failed to extract Proton-TKG .zip file."
            rm $ZIP_FILE
            exit 1
        end

        set TAR_FILE (find $TARGET_DIR -maxdepth 1 -type f -name "*.tar" | head -n 1)
        if test -z "$TAR_FILE"
            echo "No .tar file found inside Proton-TKG .zip."
            rm $ZIP_FILE
            exit 1
        end

        echo "Extracting $TAR_FILE..."
        tar -xf $TAR_FILE -C $TARGET_DIR
        if test $status -ne 0
            echo "Failed to extract Proton-TKG .tar file."
            rm $ZIP_FILE
            exit 1
        end

        # Clean up zip and tar files
        rm $ZIP_FILE
        rm $TAR_FILE

        # Rename extracted folder to include run ID
        # Find the extracted proton_tkg_* folder (should be only one)
        set extracted_folder (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*" | head -n 1)
        if test -z "$extracted_folder"
            echo "Could not find extracted Proton-TKG folder to rename."
            exit 1
        end

        set new_folder_name (basename $extracted_folder)_run$RUN_ID
        mv $extracted_folder "$TARGET_DIR/$new_folder_name"
        echo "Renamed Proton-TKG folder to $new_folder_name"

        echo "Proton-TKG installed in $TARGET_DIR."
        echo "Ensure PROTON_STANDALONE_START = 1 and UMU_NO_RUNTIME = 1 in Env Var"
    end
end

# === Proton-CachyOS Helper Functions ===
function compare_cachyos_versions
    # Compare CachyOS versions as integers (dates)
    # Returns 1 if $argv[1] > $argv[2], 0 if equal, -1 if less
    set v1 (math $argv[1])
    set v2 (math $argv[2])
    if test $v1 -gt $v2
        echo 1
    else if test $v1 -lt $v2
        echo -1
    else
        echo 0
    end
end

function get_local_cachyos_version
    # Find local proton-cachyos* folder and extract date version from folder name
    set target_dir "$HOME/.local/share/Steam/compatibilitytools.d"
    set folder (find $target_dir -maxdepth 1 -type d -name "proton-cachyos*" | head -n 1)
    if test -z "$folder"
        echo ""
        return
    end
    set folder_name (basename $folder)
    # Extract date string from folder name, e.g. proton-cachyos-20250402-slr-x86_64_v3
    set date_version (string match -r '[0-9]{8}' $folder_name)
    echo $date_version
end

# === Install Proton-CachyOS if selected ===
if test $INSTALL_CACHY -eq 1
    set CACHY_REPO "CachyOS/proton-cachyos"
    set CACHY_RELEASE_API "https://api.github.com/repos/$CACHY_REPO/releases/latest"

    echo "Fetching the latest Proton-CachyOS release..."
    set RELEASE_INFO (curl -s -H "Accept: application/vnd.github+json" $CACHY_RELEASE_API)

    if test -z "$RELEASE_INFO"
        echo "Failed to fetch Proton-CachyOS release information."
        exit 1
    end

    set ASSET_URL (echo $RELEASE_INFO | jq -r '.assets[] | select(.name | test("proton-cachyos-.*-slr-x86_64_v3.tar.xz")) | .browser_download_url')
    set ASSET_NAME (echo $RELEASE_INFO | jq -r '.assets[] | select(.name | test("proton-cachyos-.*-slr-x86_64_v3.tar.xz")) | .name')

    if test -z "$ASSET_URL"
        echo "No matching Proton-CachyOS .tar.xz asset found."
        exit 1
    end

    set remote_cachyos_version (string match -r '[0-9]{8}' $ASSET_NAME)
    set local_cachyos_version (get_local_cachyos_version)

    if test -n "$local_cachyos_version"
        set cmp_result (compare_cachyos_versions $remote_cachyos_version $local_cachyos_version)
        if test $cmp_result -le 0
            echo "Local Proton-CachyOS version ($local_cachyos_version) is up-to-date or newer than remote ($remote_cachyos_version). Skipping update."
            set INSTALL_CACHY 0
        else
            echo "Remote Proton-CachyOS version ($remote_cachyos_version) is newer than local ($local_cachyos_version). Proceeding with update."
        end
    else
        echo "No local Proton-CachyOS version found. Proceeding with update."
    end

    if test $INSTALL_CACHY -eq 1
        echo "Checking for existing proton-cachyos* folders..."
        set OLD_CACHY_FOLDERS (find $TARGET_DIR -maxdepth 1 -type d -name "proton-cachyos*")
        if test -n "$OLD_CACHY_FOLDERS"
            echo "Deleting old Proton-CachyOS folders: $OLD_CACHY_FOLDERS"
            rm -rf $OLD_CACHY_FOLDERS
        else
            echo "No existing proton-cachyos* folders found."
        end

        set TAR_FILE "$TARGET_DIR/$ASSET_NAME"
        echo "Downloading Proton-CachyOS asset to $TAR_FILE..."
        curl -L $ASSET_URL -o $TAR_FILE

        if test $status -ne 0
            echo "Failed to download the Proton-CachyOS asset."
            exit 1
        end

        echo "Extracting $TAR_FILE..."
        tar -xJf $TAR_FILE -C $TARGET_DIR
        if test $status -ne 0
            echo "Failed to extract the Proton-CachyOS .tar.xz file."
            rm $TAR_FILE
            exit 1
        end

        echo "Cleaning up Proton-CachyOS files..."
        rm $TAR_FILE

        echo "Proton-CachyOS installed in $TARGET_DIR."
        echo "Ensure PROTON_STANDALONE_START = 1 and UMU_NO_RUNTIME = 1 in Env Var"
    end
end

# === Proton-GE Helper Functions ===
function compare_ge_versions
    # Compare Proton-GE versions (format "major-minor", e.g., "9-27")
    # Returns 1 if remote ($argv[1]) > local ($argv[2]), 0 if equal, -1 if local > remote
    set remote_version $argv[1]
    set local_version $argv[2]

    # Validate remote version
    if not string match -qr '^[0-9]+-[0-9]+$' "$remote_version"
        echo 1
        return
    end

    # Validate local version
    if not string match -qr '^[0-9]+-[0-9]+$' "$local_version"
        echo 1
        return
    end

    # Split versions into major and minor parts
    set remote_parts (string split '-' $remote_version)
    set local_parts (string split '-' $local_version)

    set remote_major $remote_parts[1]
    set remote_minor $remote_parts[2]
    set local_major $local_parts[1]
    set local_minor $local_parts[2]

    # Compare major versions
    if test $remote_major -gt $local_major
        echo 1
        return
    else if test $remote_major -lt $local_major
        echo -1
        return
    end

    # If major versions are equal, compare minor versions
    if test $remote_minor -gt $local_minor
        echo 1
        return
    else if test $remote_minor -lt $local_minor
        echo -1
        return
    end

    echo 0
end

function get_local_ge_version
    # Find local GE-Proton* folder and extract version string "major-minor" (e.g., "9-27")
    set target_dir "$HOME/.local/share/Steam/compatibilitytools.d"
    # Match only GE-ProtonX-Y folders (e.g., GE-Proton9-27)
    set folder (find $target_dir -maxdepth 1 -type d -name "GE-Proton[0-9]*-[0-9]*" | sort -V | tail -n 1)
    if test -z "$folder"
        echo ""
        return
    end
    set folder_name (basename $folder)
    # Extract first matching version in format "major-minor" (e.g., "9-27") after "GE-Proton"
    set ge_version (string match -r 'GE-Proton([0-9]+-[0-9]+)' $folder_name | string replace 'GE-Proton' '' | head -n 1)
    # Validate version format (e.g., "X-Y")
    if test -z "$ge_version"
        echo ""
        return
    end
    if not string match -qr '^[0-9]+-[0-9]+$' "$ge_version"
        echo ""
        return
    end
    echo $ge_version
end

# === Install Proton-GE if selected ===
if test $INSTALL_GE -eq 1
    set GE_REPO "GloriousEggroll/proton-ge-custom"
    set GE_RELEASE_API "https://api.github.com/repos/$GE_REPO/releases/latest"

    echo "Fetching the latest Proton-GE release..."
    set RELEASE_INFO (curl -s -H "Accept: application/vnd.github+json" $GE_RELEASE_API)

    if test -z "$RELEASE_INFO"
        echo "Failed to fetch Proton-GE release information."
        exit 1
    end

    set ASSET_URL (echo $RELEASE_INFO | jq -r '.assets[] | select(.name | test("GE-Proton[0-9]+-[0-9]+\\\.tar\\\.gz")) | .browser_download_url')
    set ASSET_NAME (echo $RELEASE_INFO | jq -r '.assets[] | select(.name | test("GE-Proton[0-9]+-[0-9]+\\\.tar\\\.gz")) | .name')

    if test -z "$ASSET_URL"
        echo "No matching Proton-GE .tar.gz asset found."
        exit 1
    end

    set remote_ge_version (string match -r '[0-9]+-[0-9]+' $ASSET_NAME | string trim)
    set local_ge_version (get_local_ge_version | string trim)

    if test -n "$local_ge_version"
        set cmp_result (compare_ge_versions "$remote_ge_version" "$local_ge_version")
        if test $cmp_result -le 0
            echo "Local Proton-GE version ($local_ge_version) is up-to-date or newer than remote ($remote_ge_version). Skipping update."
            set INSTALL_GE 0
        else
            echo "Remote Proton-GE version ($remote_ge_version) is newer than local ($local_ge_version). Proceeding with update."
        end
    else
        echo "No local Proton-GE version found. Proceeding with update."
    end

    if test $INSTALL_GE -eq 1
        echo "Checking for existing GE-Proton* folders..."
        set OLD_GE_FOLDERS (find $TARGET_DIR -maxdepth 1 -type d -name "GE-Proton*")
        if test -n "$OLD_GE_FOLDERS"
            echo "Deleting old Proton-GE folders: $OLD_GE_FOLDERS"
            rm -rf $OLD_GE_FOLDERS
        else
            echo "No existing GE-Proton* folders found."
        end

        set TAR_FILE "$TARGET_DIR/$ASSET_NAME"
        echo "Downloading Proton-GE asset to $TAR_FILE..."
        curl -L $ASSET_URL -o $TAR_FILE

        if test $status -ne 0
            echo "Failed to download the Proton-GE asset."
            exit 1
        end

        echo "Extracting $TAR_FILE..."
        tar -xzf $TAR_FILE -C $TARGET_DIR
        if test $status -ne 0
            echo "Failed to extract the Proton-GE .tar.gz file."
            rm $TAR_FILE
            exit 1
        end

        echo "Cleaning up Proton-GE files..."
        rm $TAR_FILE

        echo "Proton-GE installed in $TARGET_DIR."
        echo "Ensure PROTON_STANDALONE_START = 1 in Env Var"
    end
end
