#!/bin/bash

# Run swift build
echo "Running swift build..."
swift build -c release

# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Swift build failed. Exiting."
    exit 1
fi

# Copy .env file
echo "Copying .env file..."
cp .env .build/release/

# Check if the copy was successful
if [ $? -ne 0 ]; then
    echo "Failed to copy .env file. Exiting."
    exit 1
fi

# Copy entire Resources folder
echo "Copying Resources folder..."
cp -R Resources .build/release/

# Check if the copy was successful
if [ $? -ne 0 ]; then
    echo "Failed to copy serviceAccounts.json file. Exiting."
    exit 1
fi
