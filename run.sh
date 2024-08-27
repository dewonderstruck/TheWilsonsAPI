#!/bin/bash

# Run the app
echo "Starting the app..."
cd .build/release
./App serve --env production --hostname 0.0.0.0 --port 8080
