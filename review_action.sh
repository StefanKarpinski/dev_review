#!/bin/bash
# Move a .review/ item to .delete/ or .archive/ and append a note.
# Usage: review_action.sh <delete|archive> <item> <note>

action="$1"
item="$2"
note="$3"

if [ -z "$action" ] || [ -z "$item" ]; then
  echo "Usage: review_action.sh <delete|archive> <item> <note>" >&2
  exit 1
fi

cd ~/dev

case "$action" in
  delete)
    mkdir -p .delete
    mv ".review/$item" ".delete/$item"
    echo "- \`$item\` — $note" >> .delete/NOTES.md
    echo "Moved $item to .delete/"
    ;;
  archive)
    mkdir -p .archive
    mv ".review/$item" ".archive/$item"
    if [ ! -f .archive/NOTES.md ]; then
      echo "# Archived Items" > .archive/NOTES.md
      echo "" >> .archive/NOTES.md
    fi
    echo "- \`$item\` — $note" >> .archive/NOTES.md
    echo "Moved $item to .archive/"
    ;;
  *)
    echo "Unknown action: $action (expected 'delete' or 'archive')" >&2
    exit 1
    ;;
esac
