#!/bin/bash

echo "Fixing HTML file to include config scripts directly..."

# Create a backup
cp index.html index.html.backup

# Replace SSI includes with actual script tags
sed -i '' 's|<script><!--#include virtual="/config.js" --></script>|<script src="config.js"></script>|g' index.html
sed -i '' 's|<script><!--#include virtual="/interface_config.js" --></script>|<script src="interface_config.js"></script>|g' index.html

echo "HTML file fixed!"
