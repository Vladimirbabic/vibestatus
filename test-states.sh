#!/bin/bash
# Test script to cycle through Claude Indicator states

STATUS_FILE="/tmp/claude-indicator-status.json"

echo "Testing Claude Indicator states..."
echo "Watch the widget in the bottom-right corner!"
echo ""

echo "1. Setting to WORKING (orange runway lights)..."
echo '{"state":"working","message":"Processing..."}' > "$STATUS_FILE"
sleep 3

echo "2. Setting to NEEDS INPUT (blue pulsing)..."
echo '{"state":"needs_input","message":"Waiting for input"}' > "$STATUS_FILE"
sleep 3

echo "3. Setting to IDLE (green)..."
echo '{"state":"idle","message":"Ready"}' > "$STATUS_FILE"
sleep 2

echo ""
echo "Cycling through states again..."

for i in {1..3}; do
    echo "  Working..."
    echo '{"state":"working","message":"Processing..."}' > "$STATUS_FILE"
    sleep 2

    echo "  Idle..."
    echo '{"state":"idle","message":"Ready"}' > "$STATUS_FILE"
    sleep 1
done

echo ""
echo "Done! The widget should now show 'Ready' (green)."
