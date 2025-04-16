#!/usr/bin/env fish

# GitHub repository details
set REPO "Syntist/proton-tkg-builder"
set GITHUB_API "https://api.github.com/repos/$REPO/actions/runs"

# Replace YOUR_GITHUB_TOKEN with your Personal Access Token
set TOKEN "NEED TOKEN"

# Directory to save and extract files
set TARGET_DIR "$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p $TARGET_DIR

# Fetch the latest workflow runs
echo "Fetching the latest workflow runs..."
set RUNS (curl -s -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    $GITHUB_API)

# Check if any workflow runs are available
if test (echo $RUNS | jq -r '.workflow_runs | length') -eq 0
    echo "No workflow runs found."
    exit 1
end

# Find the latest completed successful run
set LATEST_RUN (echo $RUNS | jq -r '.workflow_runs | map(select(.status == "completed" and .conclusion == "success")) | sort_by(.created_at) | last')

if test -z "$LATEST_RUN"
    echo "No successful workflow runs found."
    exit 1
end

# Get the run ID of the latest successful run
set RUN_ID (echo $LATEST_RUN | jq -r '.id')

echo "Latest successful run ID: $RUN_ID"

# Now check if the build is successful and only delete the old folders if it is
if test (echo $LATEST_RUN | jq -r '.conclusion') = "success"
    # Delete existing proton_tkg_* folders
    echo "Checking for existing proton_tkg_* folders..."
    set OLD_FOLDERS (find $TARGET_DIR -maxdepth 1 -type d -name "proton_tkg_*")
    if test -n "$OLD_FOLDERS"
        echo "Deleting old Proton-TKG folders: $OLD_FOLDERS"
        rm -rf $OLD_FOLDERS
    else
        echo "No existing proton_tkg_* folders found."
    end
else
    echo "Latest build did not succeed. Skipping folder deletion."
end

# Fetch the artifacts for the latest run
set ARTIFACTS_URL "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/artifacts"
echo "Fetching artifacts for run $RUN_ID..."
set ARTIFACT_INFO (curl -s -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    $ARTIFACTS_URL)

# Get the first artifact's download URL and name
set ARTIFACT_URL (echo $ARTIFACT_INFO | jq -r '.artifacts[0].archive_download_url')
set ARTIFACT_NAME (echo $ARTIFACT_INFO | jq -r '.artifacts[0].name')

if test -z "$ARTIFACT_URL"
    echo "No artifacts found for this run."
    exit 1
end

# Download the artifact
set ZIP_FILE "$TARGET_DIR/$ARTIFACT_NAME.zip"
echo "Downloading artifact to $ZIP_FILE..."
curl -L -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    $ARTIFACT_URL -o $ZIP_FILE

if test $status -ne 0
    echo "Failed to download the artifact."
    exit 1
end

echo "Download completed successfully!"

# Extract the .zip file
echo "Extracting $ZIP_FILE..."
unzip -q $ZIP_FILE -d $TARGET_DIR
if test $status -ne 0
    echo "Failed to extract the .zip file."
    rm $ZIP_FILE
    exit 1
end

# Find the .tar file inside the extracted contents
set TAR_FILE (find $TARGET_DIR -maxdepth 1 -type f -name "*.tar" | head -n 1)
if test -z "$TAR_FILE"
    echo "No .tar file found inside the .zip."
    rm $ZIP_FILE
    exit 1
end

# Extract the .tar file
echo "Extracting $TAR_FILE..."
tar -xf $TAR_FILE -C $TARGET_DIR
if test $status -ne 0
    echo "Failed to extract the .tar file."
    rm $ZIP_FILE
    exit 1
end

# Clean up: delete the .zip and .tar files
echo "Cleaning up..."
rm $ZIP_FILE
rm $TAR_FILE

echo "Extraction completed! Files are in $TARGET_DIR."
echo "Ensure PROTON_STANDALONE_START = 1 and UMU_NO_RUNTIME = 1 in Env Var"
