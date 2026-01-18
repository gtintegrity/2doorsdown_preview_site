#!/bin/bash
set -e

# Usage: ./repair_and_extract.sh <path-to-zip-file>
# This script attempts to extract a ZIP file with multiple fallback strategies:
# 1. Test and extract with unzip
# 2. Extract with 7z if unzip fails
# 3. Repair with zip -FF and then extract if 7z fails

ZIP_FILE="$1"
OUTPUT_DIR="site"
REPAIRED_ZIP="repaired.zip"

if [ -z "$ZIP_FILE" ]; then
    echo "Error: No ZIP file specified"
    echo "Usage: $0 <path-to-zip-file>"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: ZIP file '$ZIP_FILE' not found"
    exit 1
fi

echo "Processing ZIP file: $ZIP_FILE"

# Remove output directory if it exists
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Strategy 1: Try unzip with test first
echo "Strategy 1: Attempting extraction with unzip..."
if unzip -t "$ZIP_FILE" > /dev/null 2>&1; then
    echo "ZIP file integrity check passed"
    if unzip -o -d "$OUTPUT_DIR" "$ZIP_FILE"; then
        echo "Successfully extracted with unzip"
        EXTRACTION_SUCCESS=true
    else
        echo "unzip extraction failed despite passing integrity check"
        EXTRACTION_SUCCESS=false
    fi
else
    echo "ZIP file integrity check failed with unzip"
    EXTRACTION_SUCCESS=false
fi

# Strategy 2: Try 7z if unzip failed
if [ "$EXTRACTION_SUCCESS" != "true" ]; then
    echo "Strategy 2: Attempting extraction with 7z..."
    if command -v 7z > /dev/null 2>&1; then
        if 7z x "$ZIP_FILE" -o"$OUTPUT_DIR" -y; then
            echo "Successfully extracted with 7z"
            EXTRACTION_SUCCESS=true
        else
            echo "7z extraction failed"
            EXTRACTION_SUCCESS=false
        fi
    else
        echo "7z not available"
        EXTRACTION_SUCCESS=false
    fi
fi

# Strategy 3: Try repairing and extracting if both unzip and 7z failed
if [ "$EXTRACTION_SUCCESS" != "true" ]; then
    echo "Strategy 3: Attempting to repair ZIP file and extract..."
    if command -v zip > /dev/null 2>&1; then
        # Clean up any existing repaired zip
        rm -f "$REPAIRED_ZIP"
        
        if zip -FF "$ZIP_FILE" --out "$REPAIRED_ZIP"; then
            echo "ZIP file repaired successfully"
            if unzip -o -d "$OUTPUT_DIR" "$REPAIRED_ZIP"; then
                echo "Successfully extracted repaired ZIP"
                EXTRACTION_SUCCESS=true
            else
                echo "Failed to extract repaired ZIP"
                EXTRACTION_SUCCESS=false
            fi
        else
            echo "Failed to repair ZIP file"
            EXTRACTION_SUCCESS=false
        fi
        
        # Clean up repaired zip
        rm -f "$REPAIRED_ZIP"
    else
        echo "zip command not available for repair"
        EXTRACTION_SUCCESS=false
    fi
fi

# Check if extraction was successful
if [ "$EXTRACTION_SUCCESS" != "true" ]; then
    echo "Error: All extraction strategies failed"
    exit 1
fi

# Flatten top level if there's only one directory at the root
echo "Checking if top level needs flattening..."
ITEMS_COUNT=$(ls -A "$OUTPUT_DIR" | wc -l)

if [ "$ITEMS_COUNT" -eq 1 ]; then
    ITEM=$(ls -A "$OUTPUT_DIR")
    ITEM_PATH="$OUTPUT_DIR/$ITEM"
    
    if [ -d "$ITEM_PATH" ]; then
        echo "Flattening single top-level directory: $ITEM"
        # Move contents up one level
        # Use find to safely move files and avoid glob expansion issues
        find "$ITEM_PATH" -mindepth 1 -maxdepth 1 -exec mv -t "$OUTPUT_DIR/" {} +
        # Remove the now-empty directory
        rmdir "$ITEM_PATH"
        echo "Top level flattened successfully"
    else
        echo "Top level item is a file, no flattening needed"
    fi
else
    echo "Multiple items at top level ($ITEMS_COUNT items), no flattening needed"
fi

echo "Extraction and processing completed successfully"
exit 0
