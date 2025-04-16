#!/usr/bin/env fish

# === Update Selection Prompt ===
echo "Select an option:"
echo "1) Update both Syntist Proton-TKG and Proton-CachyOS"
echo "2) Update only Syntist Proton-TKG (ensure you have a Github Token)"
echo "3) Update only Proton-CachyOS"
echo -n "Enter your choice (1-3): "
read -l USER_INPUT

set INSTALL_TKG 0
set INSTALL_CACHY 0
switch $USER_INPUT
    case 1
        echo "Proceeding with both Syntist Proton-TKG and Proton-CachyOS updates..."
        set INSTALL_TKG 1
        set INSTALL_CACHY 1
    case 2
        echo "Proceeding with only Syntist Proton-TKG update..."
        set INSTALL_TKG 1
    case 3
        echo "Proceeding with only Proton-CachyOS update..."
        set INSTALL_CACHY 1
    case '*'
        echo "Invalid input. Please enter 1, 2, or 3."
        exit 1
end

# === Install Proton-TKG if selected ===
if test $INSTALL_TKG -eq 1
    # GitHub repository details
    set REPO "Syntist/proton-tkg-builder"
    set GITHUB_API "https://api.github.com/repos/$REPO/actions/runs"
    # YOU NEED A TOKEN FOR ARTIFACTS
    set TOKEN "NEED TOKEN"

    set TARGET_DIR "$HOME/.local/share/Steam/compatibilitytools.d"
    mkdir -p $TARGET_DIR

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

    if test (echo $LATEST_RUN | jq -r '.conclusion') = "success"
        echo "Checking for existing proton_tkg_* folders..."
        set OLD_FOLDERS (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*")
        if test -n "$OLD_FOLDERS"
            echo "Deleting old Proton-TKG folders: $OLD_FOLDERS"
            rm -rf $OLD_FOLDERS
        else
            echo "No existing proton_tkg_* folders found."
        end
    else
        echo "Latest Syntist Proton-TKG build did not succeed. Skipping folder deletion."
    end

    set ARTIFACTS_URL "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/artifacts"
    echo "Fetching artifacts for run $RUN_ID..."
    set ARTIFACT_INFO (curl -s -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        $ARTIFACTS_URL)

    set ARTIFACT_URL (echo $ARTIFACT_INFO | jq -r '.artifacts[0].archive_download_url')
    set ARTIFACT_NAME (echo $ARTIFACT_INFO | jq -r '.artifacts[0].name')

    if test -z "$ARTIFACT_URL"
        echo "No artifacts found for this Syntist Proton-TKG run."
        exit 1
    end

    set ZIP_FILE "$TARGET_DIR/$ARTIFACT_NAME.zip"
    echo "Downloading Syntist Proton-TKG artifact to $ZIP_FILE..."
    curl -L -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        $ARTIFACT_URL -o $ZIP_FILE

    if test $status -ne 0
        echo "Failed to download the Syntist Proton-TKG artifact."
        exit 1
    end

    echo "Extracting $ZIP_FILE..."
    unzip -q $ZIP_FILE -d $TARGET_DIR
    if test $status -ne 0
        echo "Failed to extract the Syntist Proton-TKG .zip file."
        rm $ZIP_FILE
        exit 1
    end

    set TAR_FILE (find $TARGET_DIR -maxdepth 1 -type f -name "*.tar" | head -n 1)
    if test -z "$TAR_FILE"
        echo "No .tar file found inside the Syntist Proton-TKG .zip."
        rm $ZIP_FILE
        exit 1
    end

    echo "Extracting $TAR_FILE..."
    tar -xf $TAR_FILE -C $TARGET_DIR
    if test $status -ne 0
        echo "Failed to extract the Syntist Proton-TKG .tar file."
        rm $ZIP_FILE
        exit 1
    end

    echo "Cleaning up Syntist Proton-TKG files..."
    rm $ZIP_FILE
    rm $TAR_FILE

    echo "Syntist Proton-TKG installed in $TARGET_DIR."
    echo "Ensure PROTON_STANDALONE_START = 1 and UMU_NO_RUNTIME = 1 in Env Var"
end

# === Install Proton-CachyOS if selected ===
if test $INSTALL_CACHY -eq 1
    set CACHY_REPO "CachyOS/proton-cachyos"
    set CACHY_RELEASE_API "https://api.github.com/repos/$CACHY_REPO/releases/latest"
    set TARGET_DIR "$HOME/.local/share/Steam/compatibilitytools.d"
    mkdir -p $TARGET_DIR

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
