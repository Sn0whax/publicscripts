#!/usr/bin/env fish

# GitHub API token for Proton-TKG-WineUP-NTSYNC update
set TOKEN "TOKEN_HERE"

# === Update Selection Prompt ===
echo "👽Select an option:"
echo "1) Update both Proton-CachyOS SLR v3 and Proton-TKG-WineUP-NTSYNC"
echo "2) Update both Proton-CachyOS SLR v3 and Proton-GE"
echo "3) Update only Proton-TKG-WineUP-NTSYNC (Requires GitHub API Token)"
echo "4) Update only Proton-CachyOS SLR v3"
echo "5) Update only Proton-GE"
echo "6) Update Proton-TKG-WineUP-NTSYNC, Proton-CachyOS, and Proton-GE"
read -P "Enter your choice (1-6): " USER_INPUT

set INSTALL_TKG 0
set INSTALL_CACHY 0
set INSTALL_GE 0

switch $USER_INPUT
    case 1
        echo "Proceeding with Proton-CachyOS and Proton-TKG-WineUP-NTSYNC updates..."
        set INSTALL_CACHY 1
        set INSTALL_TKG 1
    case 2
        echo "Proceeding with Proton-CachyOS and Proton-GE updates..."
        set INSTALL_CACHY 1
        set INSTALL_GE 1
    case 3
        echo "Proceeding with only Proton-TKG-WineUP-NTSYNC update..."
        set INSTALL_TKG 1
    case 4
        echo "Proceeding with only Proton-CachyOS update..."
        set INSTALL_CACHY 1
    case 5
        echo "Proceeding with only Proton-GE update..."
        set INSTALL_GE 1
    case 6
        echo "Proceeding with Proton-TKG-WineUP-NTSYNC, Proton-CachyOS, and Proton-GE updates..."
        set INSTALL_TKG 1
        set INSTALL_CACHY 1
        set INSTALL_GE 1
    case '*'
        echo "Invalid input. Please enter 1, 2, 3, 4, 5, or 6."
        exit 1
end

set TARGET_DIR "$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p $TARGET_DIR

# === Install Proton-TKG-WineUP-NTSYNC if selected ===
if test $INSTALL_TKG -eq 1
    set REPO "Frogging-Family/wine-tkg-git"
    set ARTIFACT_NAME "Proton nopackage Arch Linux NTSYNC CI"
    set GITHUB_API "https://api.github.com/repos/$REPO/actions/runs"
    set PAGES 3

    echo "Searching GitHub Actions for latest successful '$ARTIFACT_NAME' build..."

    set RUN_ID ""
    set REMOTE_VERSION ""
    for PAGE in (seq 1 $PAGES)
        set RUNS_JSON (curl -s -H "Authorization: token $TOKEN" \
            "$GITHUB_API?per_page=100&page=$PAGE")

        if test -z "$RUNS_JSON"
            continue
        end

        set FOUND_ID (echo $RUNS_JSON | jq -r \
            ".workflow_runs[] | select(.conclusion==\"success\" and .name==\"$ARTIFACT_NAME\") | .id" | head -n 1)

        if test -n "$FOUND_ID"
            set RUN_ID $FOUND_ID
            # get artifact name to extract remote version
            set ARTIFACTS_JSON (curl -s -H "Authorization: token $TOKEN" \
                "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/artifacts")
            set REMOTE_ARTIFACT_NAME (echo $ARTIFACTS_JSON | jq -r '.artifacts[0].name')
            set REMOTE_VERSION (string replace -r '^proton_tkg_' '' $REMOTE_ARTIFACT_NAME)
            echo "✅ Found successful run: $RUN_ID (version $REMOTE_VERSION)"
            break
        end
    end

    if test -z "$RUN_ID"
        echo "❌ No successful runs found."
        exit 1
    end

    # Check local installed folder
    set LOCAL_FOLDER (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*" | head -n 1)
    if test -n "$LOCAL_FOLDER"
        set LOCAL_BASENAME (basename $LOCAL_FOLDER)
        set LOCAL_VERSION (string match -r 'proton_tkg_[^_]+_[^_]+_[^_]+(?=_)' $LOCAL_BASENAME)
        set LOCAL_VERSION (string replace '^proton_tkg_' '' $LOCAL_VERSION)
        set LOCAL_RUN_ID (string match -r 'run\d+' $LOCAL_BASENAME)
        set LOCAL_RUN_ID (string replace 'run' '' $LOCAL_RUN_ID)
        echo "Local version: $LOCAL_VERSION (run $LOCAL_RUN_ID)"

        if test $LOCAL_RUN_ID -ge $RUN_ID
            echo "✅ Installed Proton-TKG-WineUP-NTSYNC is up to date (run $LOCAL_RUN_ID ≥ remote $RUN_ID). Skipping update."
            set INSTALL_TKG 0
        else
            echo "⬆️  Update available (local run $LOCAL_RUN_ID < remote run $RUN_ID). Proceeding."
            rm -rf $LOCAL_FOLDER
        end
    end

    if test $INSTALL_TKG -eq 1
        set ARTIFACT_URL (echo $ARTIFACTS_JSON | jq -r '.artifacts[0].archive_download_url')
        set ZIP_FILE "$TARGET_DIR/$REMOTE_ARTIFACT_NAME.zip"
        echo "⬇️  Downloading Proton-TKG-WineUP-NTSYNC artifact to $ZIP_FILE..."
        curl -L -H "Authorization: token $TOKEN" -o $ZIP_FILE $ARTIFACT_URL
        if test $status -ne 0
            echo "❌ Download failed."
            exit 1
        end

        echo "📦 Extracting $ZIP_FILE..."
        unzip -q $ZIP_FILE -d $TARGET_DIR
        set TAR_FILE (find $TARGET_DIR -maxdepth 1 -type f -name "*.tar" | head -n 1)
        if test -z "$TAR_FILE"
            echo "❌ No .tar file found inside ZIP."
            rm $ZIP_FILE
            exit 1
        end
        tar -xf $TAR_FILE -C $TARGET_DIR
        rm $ZIP_FILE $TAR_FILE

        set extracted_folder (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*" | head -n 1)
        set new_folder_name (basename $extracted_folder)_run$RUN_ID
        mv $extracted_folder "$TARGET_DIR/$new_folder_name"
        echo "✅ Installed Proton-TKG-WineUP-NTSYNC as '$new_folder_name'"
    end
end

# === Proton-CachyOS update (placeholder, unchanged) ===
if test $INSTALL_CACHY -eq 1
    echo "Updating Proton-CachyOS... (implementation not shown here)"
    # Add your existing Proton-CachyOS update logic here
end

# === Proton-GE update (placeholder, unchanged) ===
if test $INSTALL_GE -eq 1
    echo "Updating Proton-GE... (implementation not shown here)"
    # Add your existing Proton-GE update logic here
end

echo "All selected updates completed."
